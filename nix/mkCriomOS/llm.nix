{
  lib,
  pkgs,
  config,
  horizon,
  ...
}:
let
  inherit (builtins)
    concatStringsSep
    elemAt
    fromJSON
    genList
    head
    length
    listToAttrs
    map
    pathExists
    readFile
    toString
    ;
  inherit (lib) foldl';

  litellmProxy = pkgs.callPackage ../litellm-proxy.nix { };
  llamaCppPackage = pkgs.callPackage ../llama-cpp-prometheus.nix { inherit pkgs; };
  yamlFormat = pkgs.formats.yaml { };

  nodeName = horizon.node.name;

  # Unified config — single source of truth for all LLM services
  configPath = ../../data/config/largeAI/litellm.json;
  cfg = fromJSON (readFile configPath);

  gatewayPort = cfg.gatewayPort;
  apiKey = cfg.apiKey;

  runtimeUser = "llama";
  runtimeHome = "/var/lib/llama";

  litellmRouterConfigPath = "/etc/litellm-router.yaml";

  # Resolve model source to a store path
  mkModelPath = spec:
    let source = spec.source; in
    if source.kind == "multi-shard"
    then
      let
        fetched = map (shard: {
          drv = pkgs.fetchurl { url = shard.url; sha256 = shard.sha256; };
          inherit (shard) filename;
        }) source.shards;
        modelDir = pkgs.runCommand "model-shards-${spec.modelId}" {} (
          "mkdir -p $out\n"
          + concatStringsSep "\n" (map (s: "ln -s ${s.drv} $out/${s.filename}") fetched)
        );
      in "${modelDir}/${(head source.shards).filename}"
    else if source.kind == "fetchurl"
    then pkgs.fetchurl { url = source.url; sha256 = source.sha256; }
    else if source.kind == "local-file"
    then pkgs.runCommand "local-file-${source.filename}"
      { nativeBuildInputs = [ pkgs.coreutils ]; allowSubstitutes = true; preferLocalBuild = true; }
      "cp ${source.path} $out"
    else source.path;

  mkRuntimeModel = index: spec: {
    inherit (spec) modelId descriptor reasoning contextWindow maxTokens ctxSize port;
    alias = "${nodeName}-${spec.modelId}";
    canonicalId = spec.modelId;
    serviceName = "${nodeName}-llama-${spec.modelId}";
    modelPathStr = mkModelPath spec;
    order = index + 1;
  };

  runtimeModels = genList (i: mkRuntimeModel i (elemAt cfg.models i)) (length cfg.models);

  litellmRouterData = {
    model_list = map (model: {
      model_name = model.canonicalId;
      litellm_params = {
        model = "openai/${model.alias}";
        api_base = "http://127.0.0.1:${toString model.port}/v1";
        api_key = apiKey;
      };
      order = model.order;
    }) runtimeModels;

    router_settings = cfg.routerSettings // {
      model_group_alias = foldl' (acc: model:
        acc // { ${model.canonicalId} = model.canonicalId; }
      ) { } runtimeModels;
    };

    litellm_settings = cfg.litellmSettings;
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
          "HSA_OVERRIDE_GFX_VERSION=11.5.1"
        ];

        ExecStart =
          "${llamaCppPackage}/bin/llama-server"
          + " --host ::"
          + " --port ${toString model.port}"
          + " --model ${model.modelPathStr}"
          + " --n-gpu-layers 99"
          + " --alias ${model.alias}"
          + " --api-key ${apiKey}"
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

  llamaServices = listToAttrs (map mkLlamaService runtimeModels);

in
{
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

  networking.firewall.allowedTCPPorts = [ gatewayPort ] ++ map (model: model.port) runtimeModels;

  systemd.tmpfiles.rules = [
    "d /var/lib/llama 0755 llama llama - -"
    "d /var/lib/llama/models 0755 llama llama - -"
  ];

  systemd.services = lib.mapAttrs (_: svc: svc // {
    serviceConfig = svc.serviceConfig // { StateDirectory = "llama"; };
  }) llamaServices // {
    "${nodeName}-litellm" = {
      description = "${nodeName} LiteLLM gateway";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      restartTriggers = [ config.environment.etc."litellm-router.yaml".source ];

      serviceConfig = {
        Type = "simple";
        User = runtimeUser;
        WorkingDirectory = runtimeHome;
        Environment = [ "HOME=${runtimeHome}" ];

        ExecStart =
          "${litellmProxy}/bin/litellm"
          + " --config ${litellmRouterConfigPath}"
          + " --host ::"
          + " --port ${toString gatewayPort}";

        Restart = "on-failure";
        RestartSec = 5;
        StateDirectory = "llama";
      };

      wantedBy = [ "multi-user.target" ];
    };
  };
}
