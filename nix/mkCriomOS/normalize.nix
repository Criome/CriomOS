{
  config,
  horizon,
  pkgs,
  lib,
  world,
  pkdjz,
  ...
}:
let
  inherit (lib)
    mapAttrsToList
    concatStringsSep
    mkOverride
    optional
    mkIf
    optionalString
    optionalAttrs
    ;
  inherit (pkdjz) exportJSON;
  inherit (pkgs) mksh writeScript gnupg;
  inherit (horizon) node exNodes;
  inherit (horizon.node) typeIs;
  inherit (horizon.node.methods)
    chipIsIntel
    sizedAtLeast
    useColemak
    behavesAs
    ;

  # TODO
  hasAudioOutput = true;
  hasVideoOutput = true;

  jsonHorizonFail = exportJSON "horizon.json" horizon;

  criomosShell = mksh + mksh.shellPath;

  mkNodeKnownHost =
    n: node:
    concatStringsSep " " [
      node.criomeDomainName
      node.ssh
    ];

  sshKnownHosts = concatStringsSep "\n" (mapAttrsToList mkNodeKnownHost exNodes);

  audioPackages = with pkgs; [
    # To get all codecs in pipewire
    pulseaudioFull
  ];

in
{
  boot = {
    kernelParams = [ "consoleblank=300" ];

    kernelPackages = pkgs.linuxPackages_latest;

    supportedFilesystems = mkOverride 50 (
      [
        "xfs"
        "btrfs"
        "ntfs"
      ]
      ++ (optional sizedAtLeast.min "exfat")
    );
  };

  documentation = {
    enable = !config.boot.isContainer;
    nixos.enable = !config.boot.isContainer;
  };

  environment = {
    binsh = criomosShell;
    shells = [ "/run/current-system/sw${mksh.shellPath}" ];

    etc = {
      "ssh/ssh_known_hosts".text = sshKnownHosts;
      "horizon.json" = {
        source = jsonHorizonFail;
        mode = "0600";
      };
    };

    systemPackages =
      with pkgs;
      [
        world.skrips.root
        tcpdump
        librist
        openssh
        ntfs3g
        fuse
        ifmetric
      ]
      ++ audioPackages;

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
    enable = sizedAtLeast.min && !behavesAs.router;
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

  system.stateVersion = "25.05";

  users = {
    defaultUserShell = "/run/current-system/sw/bin/zsh";
    groups.dialout = { };
  };
}
