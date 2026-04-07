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
       `(show-paren-mismatch ((,class (:foreground "${c.base00}" :background "${c.base08}"))))

       ;; Emacs 29+ tree-sitter faces
       `(font-lock-function-call-face ((,class (:foreground "${c.base0D}"))))
       `(font-lock-number-face ((,class (:foreground "${c.base09}"))))
       `(font-lock-operator-face ((,class (:foreground "${c.base0F}"))))
       `(font-lock-property-use-face ((,class (:foreground "${c.base08}"))))
       `(font-lock-punctuation-face ((,class (:foreground "${c.base04}"))))
       `(font-lock-bracket-face ((,class (:foreground "${c.base04}"))))
       `(font-lock-delimiter-face ((,class (:foreground "${c.base04}"))))
       `(font-lock-escape-face ((,class (:foreground "${c.base0C}"))))
       `(font-lock-misc-punctuation-face ((,class (:foreground "${c.base0F}"))))
       `(font-lock-variable-use-face ((,class (:foreground "${c.base05}"))))
       `(font-lock-regexp-face ((,class (:foreground "${c.base0B}"))))
       `(font-lock-regexp-grouping-construct ((,class (:foreground "${c.base0A}"))))
       `(font-lock-regexp-grouping-backslash ((,class (:foreground "${c.base0C}"))))))
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

  /*
    mkApplyScript: darkman calls this on sunrise/sunset.
    Writes real config files and reloads every app that doesn't
    follow the XDG portal natively.
  */
  mkApplyScript = { mode, scheme }:
    let
      c = parseScheme scheme;
      oscSeq = mkOscSequence c;
      dconfMode = if mode == "dark" then "prefer-dark" else "prefer-light";
      gtkTheme = if mode == "dark" then "adw-gtk3-dark" else "adw-gtk3";
      iconTheme = if mode == "dark" then "Papirus-Dark" else "Papirus-Light";
      emacsTheme = if mode == "dark" then "ignis-dark" else "ignis-light";
      fzfColors = mkFzfColors c;
    in
    pkgs.writeShellScript "apply-${mode}" ''
      # --- Portal + dconf (Firefox, Electron, Qt) ---
      ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/color-scheme "'${dconfMode}'"
      ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/gtk-theme "'${gtkTheme}'"
      ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/icon-theme "'${iconTheme}'"

      # --- GTK settings.ini (GTK3 reads file, not dconf) ---
      for v in gtk-3.0 gtk-4.0; do
        mkdir -p "$HOME/.config/$v"
        cat > "$HOME/.config/$v/settings.ini" << 'GTKEOF'
[Settings]
gtk-theme-name=${gtkTheme}
gtk-cursor-theme-name=Bibata-Modern-Classic
gtk-cursor-theme-size=24
gtk-font-name=DejaVu Sans 12
gtk-icon-theme-name=${iconTheme}
GTKEOF
      done

      # --- Ghostty config (darkman owns this file) ---
      mkdir -p "$HOME/.config/ghostty"
      cat > "$HOME/.config/ghostty/config" << 'GHOSTTY'
font-family = IosevkaTerm Nerd Font
font-size = 14
window-decoration = false
gtk-titlebar = false
window-theme = ghostty
background = ${c.base00}
foreground = ${c.base05}
GHOSTTY

      # --- Terminals: OSC sequences to all PTYs ---
      SEQ="${oscSeq}"
      for pty in /dev/pts/[0-9]*; do
        printf "$SEQ" > "$pty" 2>/dev/null || true
      done

      # --- Emacs ---
      ${pkgs.emacs-pgtk}/bin/emacsclient --eval "(progn (add-to-list 'custom-theme-load-path \"${emacsThemeDir}\") (mapc #'disable-theme custom-enabled-themes) (load-theme '${emacsTheme} t))" 2>/dev/null || true

      # --- fzf colors (sourced by new shells) ---
      mkdir -p "''${XDG_STATE_HOME:-$HOME/.local/state}/darkman"
      echo "export FZF_DEFAULT_OPTS=\"\$FZF_DEFAULT_OPTS ${fzfColors}\"" \
        > "''${XDG_STATE_HOME:-$HOME/.local/state}/darkman/fzf-theme.sh"

      # Night shift: decoupled from theme — handled by separate service

      # --- Persist mode ---
      echo "${mode}" > "''${XDG_STATE_HOME:-$HOME/.local/state}/darkman/current-mode"
    '';

  applyDark = mkApplyScript {
    mode = "dark"; scheme = darkScheme;
  };
  applyLight = mkApplyScript {
    mode = "light"; scheme = lightScheme;
  };

  /*
    Shell hook: new terminals get correct colors + fzf theme.
  */
  darkOsc = mkOscSequence dark;
  lightOsc = mkOscSequence light;
  terminalInitHook = ''
    __darkman_init_theme() {
      local state="''${XDG_STATE_HOME:-$HOME/.local/state}/darkman"
      local mode
      mode=$(cat "$state/current-mode" 2>/dev/null) || return
      if [ "$mode" = "light" ]; then
        printf "${lightOsc}"
      else
        printf "${darkOsc}"
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
        pkgs.papirus-icon-theme
        pkgs.adw-gtk3
      ];
      file.".config/emacs-ignis-themes".source = emacsThemeDir;
    };

    gtk.enable = false;

    programs.zsh.initContent = lib.mkBefore terminalInitHook;

    home.activation.reapplyDarkman =
      lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
        ${pkgs.systemd}/bin/systemctl --user restart darkman.service 2>/dev/null || true
        sleep 0.5
        mode=$(cat "''${XDG_STATE_HOME:-$HOME/.local/state}/darkman/current-mode" 2>/dev/null) || true
        if [ -n "$mode" ]; then
          ${pkgs.darkman}/bin/darkman set "$mode" 2>/dev/null || true
        fi
      '';

    services.darkman = {
      enable = true;
      settings = {
        lat = 36.7;
        lng = -4.4;
        usegeoclue = true;
        dbusserver = true;
        portal = true;
      };
      darkModeScripts.switch = ''
        ${applyDark}
        systemctl --user --no-block start nightshift-on || true
      '';
      lightModeScripts.switch = ''
        ${applyLight}
        systemctl --user --no-block start nightshift-off || true
      '';
    };

    stylix = {
      enable = true;
      autoEnable = true;
      polarity = "dark";
      base16Scheme = darkScheme;
      targets = {
        # Darkman switches dark/light via dconf at runtime
        emacs.enable = false;
        ghostty.enable = false;
        vscode.enable = false;
        wezterm.enable = false;
        wofi.enable = false;
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
          package = pkgs.nerd-fonts.iosevka-term;
          name = "IosevkaTerm Nerd Font";
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
