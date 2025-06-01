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

  codingPackages = with pkgs; [
    pandoc
    gitkraken
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
      ]
      ++ (optionals isCodeDev codingPackages)
      ++ (optionals isMultimediaDev semaDevPackages);
  };

  programs = {
    chromium = {
      enable = true;
      extensions = [
        { id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; } # ublock origin
        { id = "dbepggeogbaibhgnhhndojpepiihcmeb"; } # vimium
      ];
    };

    obs-studio = {
      enable = true;
      plugins = with pkgs.obs-studio-plugins; [
        droidcam-obs
        wlrobs
        pkdjz.obs-ndi
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
