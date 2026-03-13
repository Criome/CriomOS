{
  lib,
  pkgs,
  ...
}:
let
  inherit (builtins) toString;

  litellmProxy = pkgs.callPackage ../litellm-proxy.nix { };

  prometheusLitellmPort = 11434;
  prometheusLlamaBackupPort = 11436;

  # First pass: keep the current on-host model layout.
  liHome = "/home/li";
  prometheusModelPath = "${liHome}/.local/share/prometheus-llama/models/DeepSeek-R1-Distill-Llama-70B-Q8_0-00001-of-00002.gguf";
  prometheusApiKey = "sk-no-key-required";
  # The OS-level gateway should not depend on Home Manager being deployed.
  litellmRouterConfigPath = "/etc/litellm-router.yaml";

in
{
  environment.etc."litellm-router.yaml" = {
    source = ../homeModule/min/litellm-router.yaml;
    mode = "0644";
  };

  networking.firewall.allowedTCPPorts = [
    prometheusLitellmPort
    prometheusLlamaBackupPort
  ];

  systemd.services.prometheus-llama-backup = {
    description = "Prometheus llama.cpp OpenAI-compatible backup service";
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
        "${pkgs.llama-cpp-rocm}/bin/llama-server"
        + " --host ::"
        + " --port ${toString prometheusLlamaBackupPort}"
        + " --model ${prometheusModelPath}"
        + " --n-gpu-layers 99"
        + " --alias prometheus-main-deepseek"
        + " --api-key ${prometheusApiKey}"
        + " --no-webui";

      Restart = "on-failure";
      RestartSec = 5;
    };

    wantedBy = [ "multi-user.target" ];
  };

  systemd.services.prometheus-litellm = {
    description = "Prometheus LiteLLM gateway";
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
        "${litellmProxy}/bin/litellm"
        + " --config ${litellmRouterConfigPath}"
        + " --host ::"
        + " --port ${toString prometheusLitellmPort}";

      Restart = "on-failure";
      RestartSec = 5;
    };

    wantedBy = [ "multi-user.target" ];
  };
}
