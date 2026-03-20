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
    mkOverride
    optional
    mkIf
    optionalString
    optionalAttrs
    ;

  concatSep = lib.concatStringsSep;
  inherit (pkdjz) exportJSON;
  inherit (pkgs) mksh;
  inherit (horizon) exNodes;
  inherit (horizon.node.methods)
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
    concatSep " " [
      node.criomeDomainName
      node.ssh
    ];

  sshKnownHosts = concatSep "\n" (mapAttrsToList mkNodeKnownHost exNodes);

  pipewireFull = pkgs.pipewire.override {
    libpulseaudio = pkgs.pulseaudioFull;
  };

in
{
  boot = {
    kernelParams = [ 
      "consoleblank=300"
      "amdgpu.ppfeaturemask=0xffffffff"
      "amdgpu.gttsize=73728" # 72GB in MiB
    ];

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

    systemPackages = with pkgs; [
      world.skrips.root
      tcpdump
      librist
      openssh
      ntfs3g
      fuse
      ifmetric
      pulseaudioFull

      # Needed for user to setup ikev2 VPN
      networkmanager_strongswan
    ]
    ++ (optional sizedAtLeast.min claude-code);

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
      package = pipewireFull;
      alsa.enable = true;
      jack.enable = false;
      pulse.enable = true;
      wireplumber.enable = true;
    };

    # IKEv2 support
    strongswan.enable = true;

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
