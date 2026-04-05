{
  lib,
  horizon,
  ...
}:
let
  inherit (horizon.node.methods) behavesAs;
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
          { id = "NotificationHistory"; }
          { id = "Battery"; displayMode = "graphic"; }
          { id = "Volume"; }
          { id = "Brightness"; }
          { id = "ControlCenter"; }
        ];
      };
    };
  };
}
