{
  lib,
  horizon,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf optionals;
  inherit (horizon.node.methods) sizedAtLeast;

  minPackages = optionals sizedAtLeast.min (
    with pkgs;
    [
      adwaita-icon-theme
      nautilus
      libinput
      gnome-control-center
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

    firejail.enable = sizedAtLeast.med;

    niri = {
      enable = sizedAtLeast.min;
      package = pkgs.niri-unstable;
    };

    regreet = {
      enable = sizedAtLeast.min;
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

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    config = {
      niri = {
        default = [ "gnome" "gtk" ];
        "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
      };
      common = {
        default = [ "gtk" ];
      };
    };
  };

  services = {
    avahi.enable = sizedAtLeast.min;

    blueman.enable = sizedAtLeast.min;

    power-profiles-daemon.enable = false;

    dbus.packages = mkIf sizedAtLeast.min [ pkgs.gcr ];

    gvfs.enable = sizedAtLeast.min;

    gnome = {
      at-spi2-core.enable = sizedAtLeast.min;
      core-apps.enable = sizedAtLeast.min;
      evolution-data-server.enable = sizedAtLeast.min;
      gnome-keyring.enable = sizedAtLeast.min;
      gnome-online-accounts.enable = sizedAtLeast.min;
      gnome-settings-daemon.enable = sizedAtLeast.min;
    };

    tumbler.enable = sizedAtLeast.med;

    pulseaudio.enable = false;
  };
}
