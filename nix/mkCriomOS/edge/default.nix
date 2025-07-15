{
  lib,
  horizon,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf optionals;
  inherit (horizon.node) typeIs;
  inherit (horizon.node.methods) sizedAtLeast behavesAs;

  minPackages = optionals sizedAtLeast.min (
    with pkgs;
    [
      adwaita-icon-theme
      nautilus
      libinput
    ]
  );

  medPackages = with pkgs; [ ];

  maxPackages = with pkgs; [ ];

in
{
  hardware = {
    bluetooth.enable = true;
    graphics.enable32Bit = sizedAtLeast.max;
  };

  environment = {
    systemPackages =
      with pkgs;
      minPackages ++ (optionals sizedAtLeast.med medPackages ++ (optionals sizedAtLeast.max maxPackages));

    gnome.excludePackages = with pkgs; [
      gnome-software
    ];
  };

  programs = {
    browserpass.enable = sizedAtLeast.max;

    dconf.enable = true;
    droidcam.enable = sizedAtLeast.max;
    evolution.enable = true;
    file-roller.enable = sizedAtLeast.med;

    firejail.enable = sizedAtLeast.med;

    hyprland = {
      enable = behavesAs.nextGen;
    };

    regreet = {
      enable = !(sizedAtLeast.min);
      settings = {
        GTK = {
          application_prefer_dark_theme = true;
          cursor_theme_name = "Adwaita";
          icon_theme_name = "Adwaita";
          theme_name = "Adwaita";
        };
      };
    };
  };

  services = {
    avahi.enable = sizedAtLeast.min;

    blueman.enable = sizedAtLeast.med;

    power-profiles-daemon.enable = false;

    dbus.packages = mkIf sizedAtLeast.med [ pkgs.gcr ];

    displayManager.gdm = {
      enable = sizedAtLeast.min;
      autoSuspend = typeIs.edge;
    };

    gvfs.enable = sizedAtLeast.min;

    gnome = {
      at-spi2-core.enable = true;
      core-apps.enable = true;
      evolution-data-server.enable = true;
      gnome-settings-daemon.enable = true;
    };

    tumbler.enable = sizedAtLeast.med;

    desktopManager.gnome.enable = sizedAtLeast.med && typeIs.edge;

    pulseaudio.enable = false;

    xserver = {
      enable = sizedAtLeast.min;
      excludePackages = with pkgs; [ xorg.xorgserver.out ];

      # TODO - investigate difference between this and `programs.hyprland`
      windowManager.hypr.enable = behavesAs.nextGen;
    };
  };
}
