{
  pkgs,
  lib,
  user,
  ...
}:
let
  darkScheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-hard.yaml";
  lightScheme = "${pkgs.base16-schemes}/share/themes/gruvbox-light-hard.yaml";

  /*
    Parse base16 YAML into a Nix attrset at build time.
  */
  parseScheme = scheme:
    (lib.importJSON (pkgs.runCommand "base16-to-json" {
      nativeBuildInputs = [ pkgs.yq-go ];
    } ''
      yq -o=json '.' ${scheme} > $out
    '')).palette;

  dark = parseScheme darkScheme;
  light = parseScheme lightScheme;

  /*
    Generate OSC escape sequences to live-update all terminal colors.
    base16 → ANSI 16-color mapping (standard base16-shell order):
      0=base00  1=base08  2=base0B  3=base0A  4=base0D  5=base0E  6=base0C  7=base05
      8=base03  9=base08 10=base0B 11=base0A 12=base0D 13=base0E 14=base0C 15=base07
    OSC 4;N;color sets palette slot N.
    OSC 10/11/12 set foreground, background, cursor.
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
    The switch script does everything darkman needs for a full theme transition:
    1. dconf — GTK/Qt apps react immediately
    2. XDG portal — Firefox, Electron, Flatpak apps react
    3. OSC sequences — all running terminals change colors
    4. hyprctl — Hyprland border colors update
    5. waybar — restart picks up GTK theme change
    6. emacs — load new theme in running daemon
    New terminal windows also get correct colors via the zsh hook below.
  */
  /*
    mkApplyScript: called by darkman scripts (no darkman set — avoids loop).
    Applies theme to all running apps that don't follow the XDG portal.
  */
  mkApplyScript = { mode, scheme }:
    let
      c = parseScheme scheme;
      oscSeq = mkOscSequence c;
      dconfMode = if mode == "dark" then "prefer-dark" else "prefer-light";
      emacsTheme = if mode == "dark" then "modus-vivendi" else "modus-operandi";
    in
    pkgs.writeShellScript "apply-${mode}" ''
      # GTK via dconf
      ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/color-scheme "'${dconfMode}'"

      # Terminals (OSC escape sequences to all PTYs)
      SEQ="${oscSeq}"
      for pty in /dev/pts/[0-9]*; do
        printf "$SEQ" > "$pty" 2>/dev/null || true
      done

      # Hyprland borders
      ${pkgs.hyprland}/bin/hyprctl keyword general:col.active_border "rgb(${strip c.base0E}) rgb(${strip c.base0D}) 45deg" 2>/dev/null || true
      ${pkgs.hyprland}/bin/hyprctl keyword general:col.inactive_border "rgb(${strip c.base01})" 2>/dev/null || true

      # Waybar
      ${pkgs.procps}/bin/pkill -9 waybar 2>/dev/null || true
      sleep 0.5
      ${pkgs.procps}/bin/pgrep -x waybar >/dev/null || { waybar & disown; }

      # Emacs
      ${pkgs.emacs-pgtk}/bin/emacsclient --eval "(load-theme '${emacsTheme} t)" 2>/dev/null || true

      # Persist mode for new shell sessions
      mkdir -p "''${XDG_STATE_HOME:-$HOME/.local/state}/darkman"
      echo "${mode}" > "''${XDG_STATE_HOME:-$HOME/.local/state}/darkman/current-mode"
    '';

  applyDark = mkApplyScript { mode = "dark"; scheme = darkScheme; };
  applyLight = mkApplyScript { mode = "light"; scheme = lightScheme; };

  /*
    Shell hook: new terminals query the current darkman mode and apply
    the right colors via OSC sequences. This ensures new foot windows
    match the current theme even though foot.ini is always dark.
  */
  darkOsc = mkOscSequence dark;
  lightOsc = mkOscSequence light;
  terminalInitHook = ''
    __darkman_init_theme() {
      local mode
      mode=$(cat "''${XDG_STATE_HOME:-$HOME/.local/state}/darkman/current-mode" 2>/dev/null) || return
      if [ "$mode" = "light" ]; then
        printf "${lightOsc}"
      fi
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
      targets.ghostty.enable = false;
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
