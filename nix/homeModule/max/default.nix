{
  lib,
  pkgs,
  user,
  pkdjz,
  ...
}:
let
  inherit (lib) optionals;
  inherit (user.methods) isCodeDev isMultimediaDev sizedAtLeast;

  obs-beta = pkgs.obs-studio.overrideAttrs (attrs: {
    src = pkgs.fetchFromGitHub {
      owner = "obsproject";
      repo = "obs-studio";
      rev = "31.1.0-beta2";
      hash = "sha256-HqiEIyi3lUUwkBUHgI0spXvwnXEg0V9XObGd58mfQXM=";
      fetchSubmodules = true;
    };
    nativeBuildInputs = attrs.nativeBuildInputs ++ [ pkgs.kdePackages.extra-cmake-modules ];
  });

  codingPackages = with pkgs; [
    pandoc
  ];

  semaDevPackages = with pkgs; [
    krita
    calibre
    virt-manager
    gimp
    discord-ptb
  ];

  candidatePackages = with pkgs; [
    qpwgraph
    tenacity
    lapce
    pavucontrol # TODO: pwvucontrol doesnt display virtual sources
  ];

in
lib.mkIf sizedAtLeast.max {
  home = {
    packages =
      with pkgs;
      [
        # freecad # broken
        wineWowPackages.waylandFull
        whatsapp-for-linux
        gitkraken
      ]
      ++ (optionals isCodeDev codingPackages)
      ++ (optionals isMultimediaDev semaDevPackages);
  };

  programs = {
    chromium = {
      enable = true;
      package = pkgs.google-chrome;
      # Broken with google's version
      # extensions = [
      #   { id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; } # ublock origin
      #   { id = "dbepggeogbaibhgnhhndojpepiihcmeb"; } # vimium
      # ];
    };

    obs-studio = {
      enable = true;
      package = obs-beta;
      plugins = with pkgs.obs-studio-plugins; [
        droidcam-obs
        wlrobs
        # pkdjz.obs-ndi # TODO broken
        obs-pipewire-audio-capture
        # advanced-scene-switcher # TODO broken.build
        obs-move-transition
        obs-vaapi
        waveform
      ];
    };

  };

  services = {
    easyeffects = {
      enable = true;
    };
  };
}
