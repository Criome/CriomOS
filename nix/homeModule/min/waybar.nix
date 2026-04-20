{
  pkgs,
  horizon,
  config,
  ...
}:
let
  inherit (horizon.node.methods) behavesAs;
  colors = config.lib.stylix.colors.withHashtag;

  muted = colors.base03;
  fg = colors.base05;
  yellow = colors.base0A;

  sysMonitor = "btm";
  displaySystemInfo = "${pkgs.ghostty}/bin/ghostty -e ${sysMonitor}";
  launchVolumeControl = "pwvucontrol";
  launcher = "${pkgs.nwg-drawer}/bin/nwg-drawer";

in
{
  programs.waybar = {
    enable = behavesAs.edge;

    settings.main = {
      position = "bottom";
      layer = "top";
      height = 30;
      margin-top = 0;
      margin-bottom = 4;
      margin-left = 8;
      margin-right = 8;
      modules-left = [
        "custom/launcher"
        "niri/workspaces"
      ];
      modules-center = [ "clock" ];
      modules-right = [
        "cpu"
        "memory"
        "disk"
        "pulseaudio"
        "network"
        "battery"
        "tray"
        "custom/power"
      ];
      clock = {
        format = " {:%H:%M}";
        tooltip = "true";
        tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        format-alt = " {:%d/%m}";
        calendar = {
          format.today = "<b>{}</b>";
        };
      };
      "niri/workspaces" = {
        format = "{icon}";
        format-icons = {
          "1" = "I";
          "2" = "II";
          "3" = "III";
          "4" = "IV";
          "5" = "V";
          "6" = "VI";
          "7" = "VII";
          "8" = "VIII";
          "9" = "IX";
          "10" = "X";
        };
      };
      cpu = {
        format = " {usage}%";
        format-alt = " {avg_frequency} GHz";
        interval = 5;
        on-click-right = displaySystemInfo;
      };
      memory = {
        format = "󰟜 {}%";
        format-alt = "󰟜 {used} GiB";
        interval = 5;
        on-click-right = displaySystemInfo;
      };
      disk = {
        format = "󰋊 {percentage_used}%";
        format-alt = "󰋊 {free}";
        interval = 60;
        on-click-right = displaySystemInfo;
      };
      network = {
        format-wifi = " {signalStrength}%";
        format-ethernet = "󰀂";
        tooltip-format = "Connected to {essid} {ifname} via {gwaddr}";
        format-linked = "{ifname} (No IP)";
        format-disconnected = "󰖪";
      };
      tray = {
        icon-size = 18;
        spacing = 6;
      };
      pulseaudio = {
        format = "{icon}{volume}%";
        format-muted = " {volume}%";
        format-icons = {
          default = [ " " ];
        };
        scroll-step = 2;
        on-click = launchVolumeControl;
      };
      battery = {
        format = "{icon}{capacity}%";
        format-icons = [ " " " " " " " " " " ];
        format-charging = " {capacity}%";
        format-full = " {capacity}%";
        format-warning = " {capacity}%";
        interval = 10;
        states.warning = 20;
        tooltip = true;
        tooltip-format = "{time}";
      };
      "custom/launcher" = {
        format = "󰀻";
        on-click = launcher;
        tooltip = false;
      };
      "custom/power" = {
        format = "⏻";
        tooltip = false;
        on-click = "${pkgs.writeShellScript "power-menu" ''
          choice=$(printf 'Lock\nSuspend\nLogout\nReboot\nShutdown' | ${pkgs.wofi}/bin/wofi --show dmenu --prompt Session --cache-file /dev/null)
          case "$choice" in
            Lock) systemctl --user start criomos-lock-session.service;;
            Suspend) systemctl suspend;;
            Logout) niri msg action quit;;
            Reboot) systemctl reboot;;
            Shutdown) systemctl poweroff;;
          esac
        ''}";
      };
    };
  };
}
