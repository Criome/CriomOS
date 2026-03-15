{
  lib,
  pkgs,
  config,
  horizon,
  ...
}:
let
  inherit (builtins)
    elemAt
    genList
    hasAttr
    length
    listToAttrs
    pathExists
    readFile
    toString
    fromJSON
    ;
  inherit (lib) foldl';

  # Merge multiple GGUF shards into a single file
  # Takes a list of shard derivations and produces a merged FOD
  mergeGgufShards = shards:
    pkgs.runCommand "merged-gguf"
      {
        nativeBuildInputs = [ pkgs.coreutils ];
        allowSubstitutes = true;
        preferLocalBuild = true;
      }
      (
        let
          shardNames = builtins.map (s: s.name) shards;
          shardPaths = builtins.map (s: s.outPath) shards;
          # Sort shards by their filename to ensure consistent merge order
          sortedShards = builtins.sort (a: b: a < b) shardPaths;
          shardFileNames = builtins.map (p: builtins.baseNameOf p) sortedShards;
        in
        builtins.concatStringsSep "\n" (
          builtins.map (shardPath:
            ''
              cat ${shardPath} >> $out/merged.gguf
            ''
          ) sortedShards
        )
      );

  litellmProxy = pkgs.callPackage ../litellm-proxy.nix { };
  llamaCppPackage = pkgs.callPackage ../llama-cpp-prometheus.nix { inherit pkgs; };
  yamlFormat = pkgs.formats.yaml { };

  prometheusLitellmPort = 11434;

  # Use a dedicated static system user for the llama runtime. This avoids
  # depending on any horizon/config user selection and ensures a canonical
  # persistent state location under /var/lib/llama.
  runtimeUser = "llama";
  runtimeHome = "/var/lib/llama";


  prometheusApiKey = "sk-no-key-required";
  litellmRouterConfigPath = "/etc/litellm-router.yaml";

  prometheusLockPath = ../../data/config/pi/prometheus-model-lock.json;
  prometheusLock = if pathExists prometheusLockPath then fromJSON (readFile prometheusLockPath) else { servedModels = [ ]; };

  legacyModel =
    if hasAttr "servedModels" prometheusLock then
      [ ]
    else
      [
        {
          modelId = prometheusLock.modelId;
          canonicalId = if hasAttr "canonicalId" prometheusLock then prometheusLock.canonicalId else prometheusLock.modelId;
          alias = if hasAttr "alias" prometheusLock then prometheusLock.alias else "prometheus-main-sanity";
          primaryAlias = if hasAttr "primaryAlias" prometheusLock then prometheusLock.primaryAlias else "main-sanity";
          serviceSuffix = if hasAttr "primaryAlias" prometheusLock then prometheusLock.primaryAlias else "sanity";
          descriptor = if hasAttr "descriptor" prometheusLock then prometheusLock.descriptor else prometheusLock.modelId;
          source = if hasAttr "artifact" prometheusLock then {
            kind = "fetchurl";
            url = prometheusLock.artifact.url;
            sha256 = prometheusLock.artifact.sha256;
            filename = if hasAttr "filename" prometheusLock.artifact then prometheusLock.artifact.filename else null;
          } else {
            kind = "local";
            path = "/var/lib/llama/models/DeepSeek-R1-Distill-Llama-70B-Q8_0-00001-of-00002.gguf";
            filename = "DeepSeek-R1-Distill-Llama-70B-Q8_0-00001-of-00002.gguf";
          };
          reasoning = if hasAttr "reasoning" prometheusLock then prometheusLock.reasoning else false;
          contextWindow = if hasAttr "contextWindow" prometheusLock then prometheusLock.contextWindow else 8192;
          maxTokens = if hasAttr "maxTokens" prometheusLock then prometheusLock.maxTokens else 2048;
          ctxSize = if hasAttr "ctxSize" prometheusLock then prometheusLock.ctxSize else 8192;
          port = 11436;
        }
      ];

  servedModelSpecs = if hasAttr "servedModels" prometheusLock then prometheusLock.servedModels else legacyModel;

  # Create a multi-shard model derivation
  # Uses fetchurl for each shard, then merges them
  # Nix will reuse existing store paths if content hashes match
  mkMultiShardModel = shards:
    let
      # Create fetchurl derivations for each shard
      # These are FODs, so Nix will find existing paths with matching hashes
      fetchedShards = builtins.map (shard:
        pkgs.fetchurl {
          url = shard.url;
          sha256 = shard.sha256;
        }
      );

      # Get the filename from the first shard for output naming
      firstShard = builtins.head shards;
      firstShardFilename = firstShard.filename;

      # Sort shards by filename for consistent merge order
      sortedShardPaths = builtins.sort (a: b: 
        let
          aName = builtins.elemAt shards (builtins.elemIdx a fetchedShards).name;
          bName = builtins.elemAt shards (builtins.elemIdx b fetchedShards).name;
        in
        aName.filename < bName.filename
      ) fetchedShards;

      # Merge all shards into a single model
      merged = pkgs.runCommand "merged-model-${firstShardFilename}"
        {
          nativeBuildInputs = [ pkgs.coreutils ];
          allowSubstitutes = true;
          preferLocalBuild = true;
        }
        ''
          ${builtins.concatStringsSep "\n" (
            builtins.map (shardPath:
              ''
                cat ${shardPath} >> $out
              ''
            ) sortedShardPaths
          )}
        '';
    in merged;

  mkRuntimeModel = index: spec:
    let
      source = if hasAttr "source" spec then spec.source else {
        kind = "fetchurl";
        url = spec.artifact.url;
        sha256 = spec.artifact.sha256;
        filename = if hasAttr "filename" spec.artifact then spec.artifact.filename else null;
      };
      modelPath =
        if source.kind == "multi-shard"
        then mkMultiShardModel source.shards
        else if source.kind == "fetchurl"
        then pkgs.fetchurl {
          url = source.url;
          sha256 = source.sha256;
        }
        else source.path;
      # For multi-shard models, the merged file is at $out/merged.gguf
      modelPathStr =
        if source.kind == "multi-shard"
        then "${modelPath}/merged.gguf"
        else modelPath;
      canonicalId = if hasAttr "canonicalId" spec then spec.canonicalId else spec.modelId;
      primaryAlias = if hasAttr "primaryAlias" spec then spec.primaryAlias else canonicalId;
      serviceSuffix = if hasAttr "serviceSuffix" spec then spec.serviceSuffix else primaryAlias;
      alias = if hasAttr "alias" spec then spec.alias else "prometheus-${primaryAlias}";
      descriptor = if hasAttr "descriptor" spec then spec.descriptor else canonicalId;
      reasoning = if hasAttr "reasoning" spec then spec.reasoning else false;
      contextWindow = if hasAttr "contextWindow" spec then spec.contextWindow else 8192;
      maxTokens = if hasAttr "maxTokens" spec then spec.maxTokens else 2048;
      ctxSize = if hasAttr "ctxSize" spec then spec.ctxSize else contextWindow;
      port = if hasAttr "port" spec then spec.port else 11436 + index;
    in
    {
      inherit
        alias
        canonicalId
        contextWindow
        ctxSize
        descriptor
        maxTokens
        modelPathStr
        port
        primaryAlias
        reasoning
        serviceSuffix
        ;
      order = index + 1;
      serviceName = "prometheus-llama-${serviceSuffix}";
    };

  runtimeModels = genList (index: mkRuntimeModel index (elemAt servedModelSpecs index)) (length servedModelSpecs);

  litellmRouterData = {
    model_list = builtins.map (
      model: {
        model_name = model.canonicalId;
        litellm_params = {
          model = "openai/${model.alias}";
          api_base = "http://127.0.0.1:${toString model.port}/v1";
          api_key = prometheusApiKey;
        };
        order = model.order;
      }
    ) runtimeModels;
    router_settings = {
      enable_pre_call_checks = false;
      model_group_alias = foldl' (
        acc: model:
        if model.primaryAlias == model.canonicalId
        then acc // { ${model.canonicalId} = model.canonicalId; }
        else acc // { ${model.primaryAlias} = model.canonicalId; ${model.canonicalId} = model.canonicalId; }
      ) { } runtimeModels;
    };
    litellm_settings = {
      drop_params = true;
      modify_params = true;
      logging.level = "info";
    };
  };

  litellmRouterFile = yamlFormat.generate "litellm-router.yaml" litellmRouterData;

  mkLlamaService = model: {
    name = model.serviceName;
    value = {
      description = "${model.descriptor} llama.cpp OpenAI-compatible service";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      serviceConfig = {
        Type = "simple";
        User = runtimeUser;
        WorkingDirectory = runtimeHome;
        Environment = [
          "HOME=${runtimeHome}"
          # Runtime ROCm gfx enumeration override for gfx1151 (Strix Halo) on current ROCm stack
          "HSA_OVERRIDE_GFX_VERSION=11.5.1"
        ];

        ExecStart =
          "${llamaCppPackage}/bin/llama-server"
          + " --host ::"
          + " --port ${toString model.port}"
          + " --model ${model.modelPathStr}"
          + " --n-gpu-layers 99"
          + " --alias ${model.alias}"
          + " --api-key ${prometheusApiKey}"
          + " --parallel 1"
          + " --ctx-size ${toString model.ctxSize}"
          + " --no-warmup"
          + " --no-mmap"
          + " --no-webui";

        Restart = "on-failure";
        RestartSec = 5;
      };

      wantedBy = [ "multi-user.target" ];
    };
  };

  llamaServices = listToAttrs (builtins.map mkLlamaService runtimeModels);

in
{
  # Declare the dedicated system user/group for the llama runtime and grant
  # it access to typical GPU device groups. Kept here in the module's
  # resulting attribute set so it is applied when this module is used.
  users.users.llama = {
    isSystemUser = true;
    description = "llama runtime user";
    home = runtimeHome;
    createHome = false;
    group = "llama";
    extraGroups = [ "video" "render" ];
    password = "*";
  };
  users.groups.llama = {};

  environment.etc."litellm-router.yaml" = {
    source = litellmRouterFile;
    mode = "0644";
  };

  networking.firewall.allowedTCPPorts = [ prometheusLitellmPort ] ++ builtins.map (model: model.port) runtimeModels;

  # Ensure the llama runtime state directory and models subdirectory are
  # created declaratively on boot and owned by the dedicated "llama" user.
  # We use systemd.StateDirectory for services and systemd.tmpfiles to
  # guarantee /var/lib/llama/models exists for local-model fallbacks.
  # Leave a composable list-based tmpfiles declaration (do not force it).
  systemd.tmpfiles.rules = [
    # Create /var/lib/llama (StateDirectory will normally manage this too
    # while the unit is active). Ensure models subdir exists persistently.
    "d /var/lib/llama 0755 llama llama - -"
    "d /var/lib/llama/models 0755 llama llama - -"
    # Fix permissions on DeepSeek model file for llama user access
    "L+ /home/li/.local/share/prometheus-llama/models/DeepSeek-R1-Distill-Llama-70B-Merged.gguf - - llama users - -"
  ];

  # Inject StateDirectory = "llama" into generated per-model services so
  # systemd creates/owns /var/lib/llama at runtime for the llama user.
  # We add the same for the gateway proxy service.
  systemd.services = lib.mapAttrs (_: svc: svc // {
    serviceConfig = svc.serviceConfig // { StateDirectory = "llama"; };
  }) llamaServices // {
    prometheus-litellm = {
      description = "Prometheus LiteLLM gateway";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      restartTriggers = [ config.environment.etc."litellm-router.yaml".source ];

      serviceConfig = {
        Type = "simple";
        User = runtimeUser;
        WorkingDirectory = runtimeHome;
        Environment = [
          "HOME=${runtimeHome}"
        ];

        ExecStart =
          "${litellmProxy}/bin/litellm"
          + " --config ${litellmRouterConfigPath}"
          + " --host ::"
          + " --port ${toString prometheusLitellmPort}";

        Restart = "on-failure";
        RestartSec = 5;
        StateDirectory = "llama";
      };

      wantedBy = [ "multi-user.target" ];
    };
  };
}
