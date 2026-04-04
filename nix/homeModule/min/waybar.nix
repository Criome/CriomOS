{
  pkgs,
  horizon,
  config,
  ...
}:
let
  inherit (horizon.node.methods) behavesAs;
  colors = config.lib.stylix.colors.withHashtag;

  red = colors.base08;
  green = colors.base0B;
  yellow = colors.base0A;
  blue = colors.base0D;
  magenta = colors.base0E;
  cyan = colors.base0C;
  orange = colors.base09;

  # TODO - module for packages
  sysMonitor = "btm";
  launcher = "rofi -show drun";
  displaySystemInfo = "${pkgs.ghostty}/bin/ghostty -e ${sysMonitor}";
  launchVolumeControl = "pwvucontrol";

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
        "tray"
      ];
      modules-center = [ "clock" ];
      modules-right = [
        "cpu"
        "memory"
        "disk"
        "pulseaudio"
        "network"
        "battery"
        "niri/language"
        "custom/notification"
      ];
      clock = {
        calendar = {
          format = {
            today = "<span color='${green}'><b>{}</b></span>";
          };
        };
        format = "  {:%H:%M}";
        tooltip = "true";
        tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        format-alt = "  {:%d/%m}";
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
        format = "<span foreground='${green}'> </span>";
        tooltip = true;
        tooltip-format = "{usage}% · {avg_frequency} GHz";
        interval = 5;
        on-click-right = displaySystemInfo;
      };
      memory = {
        format = "<span foreground='${cyan}'>󰟜 </span>";
        tooltip = true;
        tooltip-format = "{used} / {total} GiB ({percentage}%)";
        interval = 5;
        on-click-right = displaySystemInfo;
      };
      disk = {
        format = "<span foreground='${orange}'>󰋊 </span>";
        tooltip = true;
        tooltip-format = "{used} / {total} ({percentage_used}%)";
        interval = 60;
        on-click-right = displaySystemInfo;
      };
      network = {
        format-wifi = "<span foreground='${magenta}'> </span>";
        format-ethernet = "<span foreground='${magenta}'>󰀂 </span>";
        tooltip-format = "{essid} · {ifname} via {gwaddr} ({signalStrength}%)";
        format-linked = "{ifname} (No IP)";
        format-disconnected = "<span foreground='${magenta}'>󰖪 </span>";
      };
      tray = {
        icon-size = 20;
        spacing = 8;
      };
      pulseaudio = {
        format = "<span foreground='${blue}'>{icon}</span>";
        format-muted = "<span foreground='${blue}'> </span>";
        format-icons = {
          default = [ " " ];
        };
        tooltip = true;
        tooltip-format = "{volume}%";
        scroll-step = 2;
        on-click = launchVolumeControl;
      };
      battery = {
        format = "<span foreground='${yellow}'>{icon}</span>";
        format-icons = [
          " "
          " "
          " "
          " "
          " "
        ];
        format-charging = "<span foreground='${yellow}'> </span>";
        format-full = "<span foreground='${yellow}'> </span>";
        format-warning = "<span foreground='${yellow}'> </span>";
        interval = 5;
        states = {
          warning = 20;
        };
        tooltip = true;
        tooltip-format = "{capacity}% · {time}";
      };
      "niri/language" = {
        format = "<span foreground='${yellow}'> </span>";
        tooltip = true;
        tooltip-format = "{}";
      };
      "custom/launcher" = {
        format = "";
        on-click = launcher;
        tooltip = "true";
      };
      "custom/notification" = {
        tooltip = false;
        format = "{icon} ";
        format-icons = {
          notification = "<span foreground='red'><sup></sup></span>  <span foreground='${red}'></span>";
          none = "  <span foreground='${red}'></span>";
          dnd-notification = "<span foreground='red'><sup></sup></span>  <span foreground='${red}'></span>";
          dnd-none = "  <span foreground='${red}'></span>";
          inhibited-notification = "<span foreground='red'><sup></sup></span>  <span foreground='${red}'></span>";
          inhibited-none = "  <span foreground='${red}'></span>";
          dnd-inhibited-notification = "<span foreground='red'><sup></sup></span>  <span foreground='${red}'></span>";
          dnd-inhibited-none = "  <span foreground='${red}'></span>";
        };
        return-type = "json";
        exec-if = "which swaync-client";
        exec = "swaync-client -swb";
        on-click = "swaync-client -t -sw";
        on-click-right = "swaync-client -d -sw";
        escape = true;
      };

    };
  };
}
