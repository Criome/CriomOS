{
  lib,
  config,
  horizon,
  ...
}:
let
  inherit (horizon.node.methods) behavesAs;
  colors = config.lib.stylix.colors.withHashtag;
in
lib.mkIf behavesAs.edge {
  programs.noctalia-shell = {
    enable = true;
    systemd.enable = false;
    settings = {
      bar.widgets = {
        left = [
          { id = "Launcher"; }
          { id = "MediaMini"; }
        ];
        center = [
          { id = "Workspace"; }
        ];
        right = [
          { id = "Tray"; }
          { id = "Battery"; displayMode = "graphic"; }
          { id = "Volume"; }
          { id = "Brightness"; }
          { id = "ControlCenter"; }
        ];
      };
    };
  };

  services.mako = {
    enable = true;
    settings = {
      font = lib.mkForce "IosevkaTerm Nerd Font 11";
      background-color = lib.mkForce "${colors.base01}ee";
      text-color = lib.mkForce colors.base05;
      border-color = lib.mkForce "${colors.base02}aa";
      border-size = 2;
      border-radius = 12;
      padding = "12";
      margin = "8";
      width = 380;
      height = 120;
      default-timeout = 5000;
      layer = "overlay";
      anchor = "top-right";
      icons = true;
      icon-path = "";
      max-icon-size = 48;
      max-visible = 3;
      group-by = "app-name";

      "urgency=critical" = {
        border-color = lib.mkForce "${colors.base08}cc";
        default-timeout = 0;
      };
    };
  };
}
