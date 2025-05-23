{
  config,
  kor,
  horizon,
  pkgs,
  lib,
  world,
  ...
}:
let
  l = lib // builtins;
  inherit (kor) mapAttrsToList eksportJSON;
  inherit (lib)
    concatStringsSep
    mkOverride
    optional
    mkIf
    optionalString
    optionalAttrs
    ;
  inherit (pkgs) mksh writeScript gnupg;
  inherit (horizon) node exNodes;
  inherit (horizon.node) typeIs;
  inherit (horizon.node.methods) tcipIzIntel sizedAtLeast useColemak;

  # TODO
  hasAudioOutput = true;
  hasVideoOutput = true;
  hasAcceleratedVideoOutput = true;

  jsonHorizonFail = eksportJSON "horizon.json" horizon;

  criomOSShell = mksh + mksh.shellPath;

  mkNodeKnownHost =
    n: node:
    concatStringsSep " " [
      node.criomOSName
      node.ssh
    ];

  sshKnownHosts = concatStringsSep "\n" (mapAttrsToList mkNodeKnownHost exNodes);

in
{
  boot = {
    kernelParams = [ "consoleblank=300" ];

    kernelPackages = pkgs.linuxPackages_latest;

    supportedFilesystems = mkOverride 50 (
      [
        "xfs"
        "btrfs"
      ]
      ++ (optional sizedAtLeast.min "exfat")
    );
  };

  documentation = {
    enable = !config.boot.isContainer;
    nixos.enable = !config.boot.isContainer;
  };

  environment = {
    binsh = criomOSShell;
    shells = [ "/run/current-system/sw${mksh.shellPath}" ];

    etc = {
      "systemd/user-environment-generators/ssh-sock.sh".source = writeScript "user-ssh-sock.sh" ''
        #!${pkgs.mksh}/bin/mksh
          echo "SSH_AUTH_SOCK=$(${gnupg}/bin/gpgconf --list-dirs agent-ssh-socket)"
      '';
      "ssh/ssh_known_hosts".text = sshKnownHosts;
      "horizon.json" = {
        source = jsonHorizonFail;
        mode = "0600";
      };
    };

    systemPackages = with pkgs; [
      world.skrips.root
      tcpdump
      librist
      openssh
    ];

    interactiveShellInit = optionalString useColemak "stty -ixon";
    sessionVariables = (
      optionalAttrs useColemak {
        XKB_DEFAULT_LAYOUT = "us";
        XKB_DEFAULT_VARIANT = "colemak";
      }
    );
  };

  # Overlays are bad - force them off
  nixpkgs.overlays = mkOverride 0 [ ];

  networking.networkmanager = {
    enable = sizedAtLeast.min && !typeIs.router;
  };

  programs = {
    zsh.enable = true;
    adb.enable = sizedAtLeast.med;
    light.enable = hasVideoOutput;
  };

  services = {
    openssh = {
      enable = true;
      settings.PasswordAuthentication = false;
      ports = [ 22 ];
    };

    pipewire = mkIf hasAudioOutput {
      enable = true;
      alsa.enable = true;
      jack.enable = false;
      pulse.enable = true;
      wireplumber.enable = true;
    };

    udev = {
      extraRules = ''
        # What is this for?
        ATTRS{idVendor}=="067b", ATTRS{idProduct}=="2303", GROUP="dialout", MODE="0660"
      '';
    };

  };

  system.stateVersion = "24.05";

  users = {
    defaultUserShell = "/run/current-system/sw/bin/zsh";
    groups.dialout = { };
  };
}
