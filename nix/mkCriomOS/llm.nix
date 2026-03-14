{
  lib,
  pkgs,
  config,
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

  litellmProxy = pkgs.callPackage ../litellm-proxy.nix { };
  llamaCppPackage = pkgs.callPackage ../llama-cpp-prometheus.nix { inherit pkgs; };
  yamlFormat = pkgs.formats.yaml { };

  prometheusLitellmPort = 11434;
  liHome = "/home/li";
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
            path = "${liHome}/.local/share/prometheus-llama/models/DeepSeek-R1-Distill-Llama-70B-Q8_0-00001-of-00002.gguf";
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

  mkRuntimeModel = index: spec:
    let
      source = if hasAttr "source" spec then spec.source else {
        kind = "fetchurl";
        url = spec.artifact.url;
        sha256 = spec.artifact.sha256;
        filename = if hasAttr "filename" spec.artifact then spec.artifact.filename else null;
      };
      modelPath =
        if source.kind == "fetchurl"
        then pkgs.fetchurl {
          url = source.url;
          sha256 = source.sha256;
        }
        else source.path;
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
        modelPath
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
      enable_pre_call_checks = true;
      model_group_alias = foldl' (
        acc: model:
        acc // {
          ${model.primaryAlias} = model.canonicalId;
          ${model.canonicalId} = model.canonicalId;
        }
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
        User = "li";
        WorkingDirectory = liHome;
        Environment = [
          "HOME=${liHome}"
        ];

        ExecStart =
          "${llamaCppPackage}/bin/llama-server"
          + " --host ::"
          + " --port ${toString model.port}"
          + " --model ${model.modelPath}"
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
  environment.etc."litellm-router.yaml" = {
    source = litellmRouterFile;
    mode = "0644";
  };

  networking.firewall.allowedTCPPorts = [ prometheusLitellmPort ] ++ builtins.map (model: model.port) runtimeModels;

  systemd.services = llamaServices // {
    prometheus-litellm = {
      description = "Prometheus LiteLLM gateway";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      restartTriggers = [ config.environment.etc."litellm-router.yaml".source ];

      serviceConfig = {
        Type = "simple";
        User = "li";
        WorkingDirectory = liHome;
        Environment = [
          "HOME=${liHome}"
        ];

        ExecStart =
          "${litellmProxy}/bin/litellm"
          + " --config ${litellmRouterConfigPath}"
          + " --host ::"
          + " --port ${toString prometheusLitellmPort}";

        Restart = "on-failure";
        RestartSec = 5;
      };

      wantedBy = [ "multi-user.target" ];
    };
  };
}
