{
  pkgs,
  lib,
  user,
  ...
}:
let
  darkScheme = ./ignis.yaml;
  lightScheme = ./ignis-light.yaml;

  parseScheme = scheme:
    (lib.importJSON (pkgs.runCommand "base16-to-json" {
      nativeBuildInputs = [ pkgs.yq-go ];
    } ''
      yq -o=json '.' ${scheme} > $out
    '')).palette;

  dark = parseScheme darkScheme;
  light = parseScheme lightScheme;

  /*
    Generate a base16 Emacs theme from a palette.
    Produces a -theme.el file that can be loaded with (load-theme 'ignis-dark t).
  */
  mkEmacsBase16Theme = { name, c }: pkgs.writeText "${name}-theme.el" ''
    (deftheme ${name} "Base16 ${name} theme.")
    (let ((class '((class color) (min-colors 89))))
      (custom-theme-set-faces
       '${name}
       `(default ((,class (:foreground "${c.base05}" :background "${c.base00}"))))
       `(cursor ((,class (:background "${c.base05}"))))
       `(region ((,class (:background "${c.base02}"))))
       `(highlight ((,class (:background "${c.base01}"))))
       `(hl-line ((,class (:background "${c.base01}"))))
       `(fringe ((,class (:background "${c.base01}"))))
       `(vertical-border ((,class (:foreground "${c.base02}"))))
       `(mode-line ((,class (:foreground "${c.base04}" :background "${c.base01}"))))
       `(mode-line-inactive ((,class (:foreground "${c.base03}" :background "${c.base01}"))))
       `(minibuffer-prompt ((,class (:foreground "${c.base0D}"))))
       `(font-lock-builtin-face ((,class (:foreground "${c.base0C}"))))
       `(font-lock-comment-face ((,class (:foreground "${c.base03}"))))
       `(font-lock-comment-delimiter-face ((,class (:foreground "${c.base03}"))))
       `(font-lock-constant-face ((,class (:foreground "${c.base09}"))))
       `(font-lock-doc-face ((,class (:foreground "${c.base03}"))))
       `(font-lock-function-name-face ((,class (:foreground "${c.base0D}"))))
       `(font-lock-keyword-face ((,class (:foreground "${c.base0E}"))))
       `(font-lock-negation-char-face ((,class (:foreground "${c.base08}"))))
       `(font-lock-preprocessor-face ((,class (:foreground "${c.base0A}"))))
       `(font-lock-string-face ((,class (:foreground "${c.base0B}"))))
       `(font-lock-type-face ((,class (:foreground "${c.base0A}"))))
       `(font-lock-variable-name-face ((,class (:foreground "${c.base08}"))))
       `(font-lock-warning-face ((,class (:foreground "${c.base08}"))))
       `(isearch ((,class (:foreground "${c.base00}" :background "${c.base0A}"))))
       `(lazy-highlight ((,class (:foreground "${c.base00}" :background "${c.base0C}"))))
       `(link ((,class (:foreground "${c.base0D}" :underline t))))
       `(link-visited ((,class (:foreground "${c.base0E}" :underline t))))
       `(button ((,class (:foreground "${c.base0D}" :underline t))))
       `(header-line ((,class (:foreground "${c.base05}" :background "${c.base01}"))))
       `(shadow ((,class (:foreground "${c.base03}"))))
       `(success ((,class (:foreground "${c.base0B}"))))
       `(warning ((,class (:foreground "${c.base0A}"))))
       `(error ((,class (:foreground "${c.base08}"))))
       `(outline-1 ((,class (:foreground "${c.base0D}"))))
       `(outline-2 ((,class (:foreground "${c.base0B}"))))
       `(outline-3 ((,class (:foreground "${c.base0C}"))))
       `(outline-4 ((,class (:foreground "${c.base0E}"))))
       `(outline-5 ((,class (:foreground "${c.base09}"))))
       `(outline-6 ((,class (:foreground "${c.base0A}"))))
       `(org-level-1 ((,class (:foreground "${c.base0D}"))))
       `(org-level-2 ((,class (:foreground "${c.base0B}"))))
       `(org-level-3 ((,class (:foreground "${c.base0C}"))))
       `(org-level-4 ((,class (:foreground "${c.base0E}"))))
       `(line-number ((,class (:foreground "${c.base03}" :background "${c.base01}"))))
       `(line-number-current-line ((,class (:foreground "${c.base05}" :background "${c.base01}"))))
       `(show-paren-match ((,class (:foreground "${c.base00}" :background "${c.base0D}"))))
       `(show-paren-mismatch ((,class (:foreground "${c.base00}" :background "${c.base08}"))))))
    (provide-theme '${name})
  '';

  ignisDarkEmacsTheme = mkEmacsBase16Theme { name = "ignis-dark"; c = dark; };
  ignisLightEmacsTheme = mkEmacsBase16Theme { name = "ignis-light"; c = light; };

  emacsThemeDir = pkgs.runCommand "ignis-emacs-themes" {} ''
    mkdir -p $out
    cp ${ignisDarkEmacsTheme} $out/ignis-dark-theme.el
    cp ${ignisLightEmacsTheme} $out/ignis-light-theme.el
  '';

  /*
    Generate waybar CSS with base16 @define-color variables.
    Written as a real file by darkman — not managed by home-manager.
  */
  mkWaybarCss = c: pkgs.writeText "waybar-style.css" ''
    @define-color base00 ${c.base00}; @define-color base01 ${c.base01};
    @define-color base02 ${c.base02}; @define-color base03 ${c.base03};
    @define-color base04 ${c.base04}; @define-color base05 ${c.base05};
    @define-color base06 ${c.base06}; @define-color base07 ${c.base07};

    @define-color base08 ${c.base08}; @define-color base09 ${c.base09};
    @define-color base0A ${c.base0A}; @define-color base0B ${c.base0B};
    @define-color base0C ${c.base0C}; @define-color base0D ${c.base0D};
    @define-color base0E ${c.base0E}; @define-color base0F ${c.base0F};

    window#waybar, tooltip {
        background: alpha(@base00, 0.95);
        color: @base05;
    }
    * {
        font-family: "FiraMono Nerd Font";
        font-size: 14px;
    }
    tooltip { border-color: @base0D; }
    tooltip label { color: @base05; }

    #wireplumber, #pulseaudio, #sndio,
    #upower, #battery,
    #network, #user, #clock, #backlight,
    #cpu, #disk, #idle_inhibitor, #temperature,
    #mpd, #language, #keyboard-state, #memory,
    #window, #bluetooth { padding: 0 5px; }

    .modules-left #workspaces button,
    .modules-center #workspaces button,
    .modules-right #workspaces button {
        border-bottom: 3px solid transparent;
    }
    .modules-left #workspaces button.focused,
    .modules-left #workspaces button.active,
    .modules-center #workspaces button.focused,
    .modules-center #workspaces button.active,
    .modules-right #workspaces button.focused,
    .modules-right #workspaces button.active {
        border-bottom: 3px solid @base05;
    }
  '';

  darkWaybarCss = mkWaybarCss dark;
  lightWaybarCss = mkWaybarCss light;

  /*
    Generate GTK settings.ini for dark/light.
    Written to ~/.config/gtk-3.0/ and gtk-4.0/ by darkman.
  */
  mkGtkSettings = { isDark }: pkgs.writeText "gtk-settings.ini" ''
    [Settings]
    gtk-application-prefer-dark-theme=${if isDark then "1" else "0"}
  '';

  darkGtkSettings = mkGtkSettings { isDark = true; };
  lightGtkSettings = mkGtkSettings { isDark = false; };

  /*
    Generate fzf color string from base16 palette.
  */
  mkFzfColors = c:
    "--color=bg:${c.base00},bg+:${c.base01},fg:${c.base04},fg+:${c.base06}" +
    ",hl:${c.base0D},hl+:${c.base0D},info:${c.base0A},marker:${c.base0C}" +
    ",prompt:${c.base0A},spinner:${c.base0C},pointer:${c.base0C},header:${c.base0D}";

  /*
    OSC escape sequences for terminal color switching.
  */
  mkOscSequence = c:
    let osc = n: color: ''\033]4;${toString n};${color}\007'';
    in ''
      ${osc 0 c.base00}${osc 1 c.base08}${osc 2 c.base0B}${osc 3 c.base0A}\
      ${osc 4 c.base0D}${osc 5 c.base0E}${osc 6 c.base0C}${osc 7 c.base05}\
      ${osc 8 c.base03}${osc 9 c.base08}${osc 10 c.base0B}${osc 11 c.base0A}\
      ${osc 12 c.base0D}${osc 13 c.base0E}${osc 14 c.base0C}${osc 15 c.base07}\
      \033]10;${c.base05}\007\033]11;${c.base00}\007\033]12;${c.base05}\007'';

  strip = color: builtins.substring 1 6 color;

  /*
    mkApplyScript: darkman calls this on sunrise/sunset.
    Writes real config files and reloads every app that doesn't
    follow the XDG portal natively.
  */
  mkApplyScript = { mode, scheme, waybarCss, gtkSettings }:
    let
      c = parseScheme scheme;
      oscSeq = mkOscSequence c;
      dconfMode = if mode == "dark" then "prefer-dark" else "prefer-light";
      emacsTheme = if mode == "dark" then "ignis-dark" else "ignis-light";
      fzfColors = mkFzfColors c;
    in
    pkgs.writeShellScript "apply-${mode}" ''
      # --- Portal + dconf (Firefox, Electron, Qt) ---
      ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/color-scheme "'${dconfMode}'"

      # --- GTK settings files (file manager, launcher, legacy GTK apps) ---
      mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"
      cp -f ${gtkSettings} "$HOME/.config/gtk-3.0/settings.ini"
      cp -f ${gtkSettings} "$HOME/.config/gtk-4.0/settings.ini"
      chmod 644 "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"

      # --- Ghostty config (darkman owns this file) ---
      mkdir -p "$HOME/.config/ghostty"
      cat > "$HOME/.config/ghostty/config" << 'GHOSTTY'
font-family = FiraMono Nerd Font
font-size = 14
window-decoration = false
gtk-titlebar = false
background = ${c.base00}
foreground = ${c.base05}
GHOSTTY

      # --- Waybar: write CSS, restart ---
      mkdir -p "$HOME/.config/waybar"
      cp -f ${waybarCss} "$HOME/.config/waybar/style.css"
      chmod 644 "$HOME/.config/waybar/style.css"
      ${pkgs.procps}/bin/pkill -9 waybar 2>/dev/null || true
      sleep 0.3
      ${pkgs.procps}/bin/pgrep -x waybar >/dev/null || { waybar & disown; }

      # --- Terminals: OSC sequences to all PTYs ---
      SEQ="${oscSeq}"
      for pty in /dev/pts/[0-9]*; do
        printf "$SEQ" > "$pty" 2>/dev/null || true
      done

      # --- Hyprland borders ---
      ${pkgs.hyprland}/bin/hyprctl keyword general:col.active_border "rgb(${strip c.base0E}) rgb(${strip c.base0D}) 45deg" 2>/dev/null || true
      ${pkgs.hyprland}/bin/hyprctl keyword general:col.inactive_border "rgb(${strip c.base01})" 2>/dev/null || true

      # --- Emacs ---
      ${pkgs.emacs-pgtk}/bin/emacsclient --eval "(progn (add-to-list 'custom-theme-load-path \"${emacsThemeDir}\") (mapc #'disable-theme custom-enabled-themes) (load-theme '${emacsTheme} t))" 2>/dev/null || true

      # --- fzf colors (sourced by new shells) ---
      mkdir -p "''${XDG_STATE_HOME:-$HOME/.local/state}/darkman"
      echo "export FZF_DEFAULT_OPTS=\"\$FZF_DEFAULT_OPTS ${fzfColors}\"" \
        > "''${XDG_STATE_HOME:-$HOME/.local/state}/darkman/fzf-theme.sh"

      # --- Persist mode ---
      echo "${mode}" > "''${XDG_STATE_HOME:-$HOME/.local/state}/darkman/current-mode"
    '';

  applyDark = mkApplyScript {
    mode = "dark"; scheme = darkScheme;
    waybarCss = darkWaybarCss; gtkSettings = darkGtkSettings;
  };
  applyLight = mkApplyScript {
    mode = "light"; scheme = lightScheme;
    waybarCss = lightWaybarCss; gtkSettings = lightGtkSettings;
  };

  /*
    Shell hook: new terminals get correct colors + fzf theme.
  */
  lightOsc = mkOscSequence light;
  terminalInitHook = ''
    __darkman_init_theme() {
      local state="''${XDG_STATE_HOME:-$HOME/.local/state}/darkman"
      local mode
      mode=$(cat "$state/current-mode" 2>/dev/null) || return
      if [ "$mode" = "light" ]; then
        printf "${lightOsc}"
      fi
      [ -f "$state/fzf-theme.sh" ] && source "$state/fzf-theme.sh"
    }
    __darkman_init_theme
  '';

in
{
  config = {
    home = {
      username = user.name;
      homeDirectory = "/home/" + user.name;
      # TODO
      stateVersion = "25.05";
      packages = [
        (pkgs.writeShellScriptBin "theme-dark" ''${pkgs.darkman}/bin/darkman set dark'')
        (pkgs.writeShellScriptBin "theme-light" ''${pkgs.darkman}/bin/darkman set light'')
      ];
    };

    programs.zsh.initContent = lib.mkBefore terminalInitHook;

    services.darkman = {
      enable = true;
      settings = {
        lat = 36.7;
        lng = -4.4;
        dbusserver = true;
        portal = true;
      };
      darkModeScripts.switch = ''${applyDark}'';
      lightModeScripts.switch = ''${applyLight}'';
    };

    stylix = {
      enable = true;
      autoEnable = true;
      polarity = "dark";
      base16Scheme = darkScheme;
      targets = {
        # Darkman manages these at runtime
        emacs.enable = false;
        ghostty.enable = false;
        wezterm.enable = false;
        waybar.enable = false;
        fzf.enable = false;
        gtk.enable = false;
        gnome.enable = false;
      };
      image = pkgs.runCommand "wallpaper.png" {
        nativeBuildInputs = [ pkgs.imagemagick ];
      } ''
        magick -size 1920x1080 xc:${dark.base00} $out
      '';
      cursor = {
        package = pkgs.bibata-cursors;
        name = "Bibata-Modern-Classic";
        size = 24;
      };
      fonts = {
        monospace = {
          package = pkgs.nerd-fonts.fira-mono;
          name = "FiraMono Nerd Font";
        };
        sansSerif = {
          package = pkgs.dejavu_fonts;
          name = "DejaVu Sans";
        };
        serif = {
          package = pkgs.dejavu_fonts;
          name = "DejaVu Serif";
        };
        sizes.terminal = 14;
      };
    };
  };
}
