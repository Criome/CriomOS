{ pkgs, lib, config, ... }:
let
  terminal = "${pkgs.ghostty}/bin/ghostty";
  launcher = "wofi --show drun";
  lock = "${pkgs.hyprlock}/bin/hyprlock";

  modifier = "SUPER";

  # Colemak navigation
  left = "N";
  right = "I";
  up = "U";
  down = "E";

  strip = color: builtins.substring 1 6 color;
  colors = config.lib.stylix.colors.withHashtag;

in
{
  home.packages = with pkgs; [
    hyprnome
    hyprlock
    grimblast
  ];

  home.activation.hyprlandReload = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    ${pkgs.hyprland}/bin/hyprctl reload 2>/dev/null || true
  '';

  xdg.configFile."hypr/hyprland.conf".text = ''
    exec-once = waybar

    monitor = , preferred, auto, 1

    # --- Input ---
    input {
      accel_profile = flat
      repeat_rate = 50
      repeat_delay = 350
      follow_mouse = 1
      mouse_refocus = 0
      sensitivity = 0
      touchpad {
        natural_scroll = yes
        disable_while_typing = no
      }
    }

    device {
      name = at-translated-set-2-keyboard
      resolve_binds_by_sym = 1
      kb_layout = us
      kb_variant = colemak
      kb_options = ctrl:nocaps,altwin:swap_alt_win
    }

    # --- General ---
    general {
      gaps_in = 3
      gaps_out = 3
      border_size = 3
      col.active_border = rgb(${strip colors.base0E}) rgb(${strip colors.base0D}) 45deg
      col.inactive_border = rgb(${strip colors.base01})
      layout = master
      resize_on_border = true
    }

    # --- Decoration ---
    decoration {
      rounding = 0
      dim_inactive = false
      dim_modal = true

      blur {
        enabled = false
      }

      shadow {
        enabled = false
      }
    }

    # --- Animations ---
    animations {
      enabled = yes

      bezier = easeOutQuint, 0.23, 1, 0.32, 1
      bezier = linear, 0, 0, 1, 1
      bezier = almostLinear, 0.5, 0.5, 0.75, 1
      bezier = quick, 0.15, 0, 0.1, 1

      animation = global,        1, 10,  default
      animation = border,        1, 5.4, easeOutQuint
      animation = windows,       1, 4.8, easeOutQuint
      animation = windowsIn,     1, 4.1, easeOutQuint, popin 87%
      animation = windowsOut,    1, 1.5, linear,        popin 87%
      animation = fadeIn,        1, 1.7, almostLinear
      animation = fadeOut,       1, 1.5, almostLinear
      animation = fade,          1, 3,   quick
      animation = workspaces,    1, 1.9, almostLinear,  slide
    }

    # --- Master layout ---
    master {
      mfact = 0.65
      new_on_top = false
      orientation = left
    }

    # --- Binds ---
    binds {
      allow_workspace_cycles = yes
    }

    # --- Gestures ---
    gesture = 3, horizontal, workspace

    # --- Variables ---
    $M   = ${modifier}
    $MS  = ${modifier}_SHIFT
    $MA  = ${modifier}_ALT
    $MC  = ${modifier}_CONTROL

    # Launch
    bind = $MS, Return, exec, ${terminal}
    bind = $M,  O,      exec, ${launcher}

    # Window
    bind = $M,  Q,     killactive
    bind = $M,  SPACE, togglefloating
    bind = $M,  B,     centerwindow
    bind = $M,  X,     pin
    bind = $M,  T,     fullscreen
    bind = $MA, delete, exit

    # Screenshot
    bind = $M, P,     exec, grimblast --notify save screen
    bind = $M, Print, exec, grimblast copy area

    # Master layout navigation (Colemak)
    bind = $M,  Return, layoutmsg, swapwithmaster master
    bind = $M,  ${down},  layoutmsg, cyclenext
    bind = $M,  ${up},    layoutmsg, cycleprev
    bind = $MS, ${down},  layoutmsg, swapnext
    bind = $MS, ${up},    layoutmsg, swapprev
    bind = $M,  ${left},  layoutmsg, addmaster
    bind = $M,  ${right}, layoutmsg, removemaster
    bind = $MS, ${left},  layoutmsg, mfact -0.05
    bind = $MS, ${right}, layoutmsg, mfact +0.05

    # Focus cycling
    bind = $M,  Tab, cyclenext
    bind = $M,  Tab, bringactivetotop
    bind = $MS, Tab, cyclenext, prev
    bind = $MS, Tab, bringactivetotop

    # Workspace cycling (hyprnome)
    bind = $MC, ${up},    exec, hyprnome --previous
    bind = $MC, ${down},  exec, hyprnome
    bind = $MC, ${left},  exec, hyprnome --previous --move
    bind = $MC, ${right}, exec, hyprnome --move

    # Special workspace
    bind = $M,  F2, togglespecialworkspace
    bind = $MS, F2, movetoworkspace, special

    # Mouse — scroll through workspaces
    bind  = $M, mouse_right, workspace, e+1
    bind  = $M, mouse_left,  workspace, e-1
    bindm = $M, mouse:272,  movewindow
    bindm = $M, mouse:273,  resizewindow

    # Volume
    bindl = , XF86AudioMute,        exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
    bindl = , XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+
    bindl = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-

    # --- Window rules ---
    windowrule {
      name = suppress-maximize
      match:class = .*
      suppress_event = maximize
    }

    # --- Misc ---
    misc {
      disable_hyprland_logo = yes
      force_default_wallpaper = 0
    }
  '';

  # --- hypridle ---
  xdg.configFile."hypr/hypridle.conf".text = ''
    general {
      lock_cmd = pidof hyprlock || ${lock}
      before_sleep_cmd = loginctl lock-session
      after_sleep_cmd = hyprctl dispatch dpms on
    }

    listener {
      timeout = 600
      on-timeout = hyprctl dispatch dpms off
      on-resume = hyprctl dispatch dpms on
    }

    listener {
      timeout = 3600
      on-timeout = loginctl lock-session
    }
  '';

  # --- hyprlock ---
  xdg.configFile."hypr/hyprlock.conf".text = ''
    general {
      hide_cursor = true
    }

    background {
      color = rgb(${strip colors.base00})
    }

    input-field {
      size = 250, 50
      outline_thickness = 3
      outer_color = rgb(${strip colors.base0D})
      inner_color = rgb(${strip colors.base01})
      font_color = rgb(${strip colors.base05})
      fade_on_empty = true
      placeholder_text = <i>password</i>
      halign = center
      valign = center
    }

    label {
      text = $TIME
      color = rgb(${strip colors.base05})
      font_size = 64
      font_family = IosevkaTerm Nerd Font
      halign = center
      valign = top
      position = 0, -100
    }
  '';

  services = {
    hypridle = {
      enable = true;
    };
  };
}
