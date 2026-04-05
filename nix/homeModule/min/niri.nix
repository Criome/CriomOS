{ pkgs, config, user, ... }:
let
  terminal = "${pkgs.ghostty}/bin/ghostty";
  inherit (user.methods) useFastRepeat;

  a = config.lib.niri.actions;

in
{
  programs.niri.settings.environment = {
    "XDG_CURRENT_DESKTOP" = "niri:GNOME";
  };

  home.packages = with pkgs; [
    grim
    slurp
    wl-clipboard
    gnome-control-center
  ];

  programs.niri = {
    settings = {
      prefer-no-csd = true;

      input = {
        keyboard = {
          xkb = {
            layout = "us";
            variant = "colemak";
            options = "ctrl:nocaps,altwin:swap_ralt_rwin";
          };
          repeat-delay = if useFastRepeat then 200 else 600;
          repeat-rate = if useFastRepeat then 50 else 25;
        };
        touchpad = {
          tap = true;
          natural-scroll = true;
          dwt = false;
        };
        mouse = {
          accel-profile = "flat";
        };
        focus-follows-mouse = {
          enable = true;
          max-scroll-amount = "0%";
        };
      };

      outputs."*" = {
        scale = 1.0;
      };

      layout = {
        gaps = 8;
        default-column-width.proportion = 1.0;
        preset-column-widths = [
          { proportion = 0.33333; }
          { proportion = 0.5; }
          { proportion = 0.66667; }
          { proportion = 1.0; }
        ];
        center-focused-column = "never";

        border = {
          enable = false;
        };
        focus-ring = {
          enable = true;
          width = 3;
          active.color = "${config.lib.stylix.colors.withHashtag.base0D}";
          inactive.color = "${config.lib.stylix.colors.withHashtag.base02}";
        };
      };

      window-rules = [
        {
          geometry-corner-radius =
            let r = 8.0; in { top-left = r; top-right = r; bottom-left = r; bottom-right = r; };
          clip-to-geometry = true;
        }
      ];

      spawn-at-startup = [
        { command = [ "mako" ]; }
        { command = [ "noctalia-shell" ]; }
        { command = [ "${pkgs.networkmanagerapplet}/bin/nm-applet" "--indicator" ]; }
        { command = [ "${pkgs.blueman}/bin/blueman-applet" ]; }
      ];

      animations = {
        window-open.kind.easing = { curve = "ease-out-expo"; duration-ms = 200; };
        window-close.kind.easing = { curve = "ease-out-quad"; duration-ms = 150; };
        workspace-switch.kind.easing = { curve = "ease-out-expo"; duration-ms = 250; };
        horizontal-view-movement.kind.easing = { curve = "ease-out-expo"; duration-ms = 200; };
        config-notification-open-close.kind.easing = { curve = "ease-out-quad"; duration-ms = 200; };
      };

      binds = {
        # Launch
        "Mod+Shift+Return".action = a.spawn terminal;
        "Mod+O" = { action = a.toggle-overview; repeat = false; };
        "Mod+D".action = a.spawn "noctalia-shell" "ipc" "call" "launcher" "toggle";
        "Mod+Space".action = a.spawn "noctalia-shell" "ipc" "call" "launcher" "toggle";

        # Window
        "Mod+Q".action = a.close-window;
        "Mod+T".action = a.fullscreen-window;
        "Mod+Alt+Delete".action = a.quit { skip-confirmation = true; };

        # Focus (Colemak: N=left I=right U=up E=down)
        "Mod+N".action = a.focus-column-left;
        "Mod+I".action = a.focus-column-right;
        "Mod+U".action = a.focus-window-up;
        "Mod+E".action = a.focus-window-down;

        # Move window
        "Mod+Shift+N".action = a.move-column-left;
        "Mod+Shift+I".action = a.move-column-right;
        "Mod+Shift+U".action = a.move-window-up;
        "Mod+Shift+E".action = a.move-window-down;

        # Column management
        "Mod+Comma".action = a.consume-window-into-column;
        "Mod+Period".action = a.expel-window-from-column;

        # Resize
        "Mod+R".action = a.switch-preset-column-width;
        "Mod+Minus".action = a.set-column-width "-10%";
        "Mod+Equal".action = a.set-column-width "+10%";
        "Mod+Shift+Minus".action = a.set-window-height "-10%";
        "Mod+Shift+Equal".action = a.set-window-height "+10%";
        "Mod+F".action = a.maximize-column;
        "Mod+B".action = a.center-column;

        # Workspaces (Colemak U=up E=down)
        "Mod+Ctrl+U".action = a.focus-workspace-up;
        "Mod+Ctrl+E".action = a.focus-workspace-down;
        "Mod+Ctrl+Shift+U".action = a.move-column-to-workspace-up;
        "Mod+Ctrl+Shift+E".action = a.move-column-to-workspace-down;
        "Mod+Page_Up".action = a.focus-workspace-up;
        "Mod+Page_Down".action = a.focus-workspace-down;
        "Mod+Shift+Page_Up".action = a.move-column-to-workspace-up;
        "Mod+Shift+Page_Down".action = a.move-column-to-workspace-down;

        # Tab/focus cycling
        "Mod+Tab".action = a.focus-workspace-previous;

        # Monitor (Colemak N=left I=right)
        "Mod+Ctrl+N".action = a.focus-monitor-left;
        "Mod+Ctrl+I".action = a.focus-monitor-right;
        "Mod+Ctrl+Shift+N".action = a.move-column-to-monitor-left;
        "Mod+Ctrl+Shift+I".action = a.move-column-to-monitor-right;

        # Numbered workspaces
        "Mod+1".action.focus-workspace = 1;
        "Mod+2".action.focus-workspace = 2;
        "Mod+3".action.focus-workspace = 3;
        "Mod+4".action.focus-workspace = 4;
        "Mod+5".action.focus-workspace = 5;
        "Mod+Ctrl+1".action.move-window-to-workspace = 1;
        "Mod+Ctrl+2".action.move-window-to-workspace = 2;
        "Mod+Ctrl+3".action.move-window-to-workspace = 3;
        "Mod+Ctrl+4".action.move-window-to-workspace = 4;
        "Mod+Ctrl+5".action.move-window-to-workspace = 5;

        # Mouse scroll workspaces
        "Mod+WheelScrollDown" = {
          action = a.focus-workspace-down;
          cooldown-ms = 150;
        };
        "Mod+WheelScrollUp" = {
          action = a.focus-workspace-up;
          cooldown-ms = 150;
        };

        # Screenshot
        "Mod+P".action = a.spawn "sh" "-c" ''grim - | wl-copy'';
        "Mod+Print".action = a.spawn "sh" "-c" ''grim -g "$(slurp)" - | wl-copy'';

        # Volume
        "XF86AudioMute".action = a.spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle";
        "XF86AudioRaiseVolume".action = a.spawn "wpctl" "set-volume" "-l" "1" "@DEFAULT_AUDIO_SINK@" "5%+";
        "XF86AudioLowerVolume".action = a.spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-";

        # Brightness
        "XF86MonBrightnessUp".action = a.spawn "${pkgs.brightnessctl}/bin/brightnessctl" "set" "5%+";
        "XF86MonBrightnessDown".action = a.spawn "${pkgs.brightnessctl}/bin/brightnessctl" "set" "5%-";

        # Lock
        "Mod+L".action = a.spawn "sh" "-c" "noctalia-shell ipc call lockScreen lock && sleep 3 && niri msg action power-off-monitors";

        # Hotkey overlay
        "Mod+Shift+S".action = a.show-hotkey-overlay;
      };

      gestures = {
        hot-corners.enable = true;
      };
    };
  };
}
