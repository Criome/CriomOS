{
  lib,
  pkgs,
  user,
  pkdjz,
  ...
}:
let
  inherit (lib) optionals;
  inherit (user.methods) isMultimediaDev sizedAtLeast;

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

  windowsEmulationsPackages = with pkgs; [
    bottles
  ];

in
lib.mkIf sizedAtLeast.max {
  home = {
    packages =
      with pkgs;
      [
        # freecad # broken
        wasistlos
        gitkraken
      ]
      ++ windowsEmulationsPackages
      ++ codingPackages
      ++ (optionals isMultimediaDev semaDevPackages);
  };

  programs = {
    chromium = {
      enable = true;
      package = pkgs.google-chrome;
    };

    obs-studio = {
      enable = true;
      package = pkgs.obs-studio;
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
