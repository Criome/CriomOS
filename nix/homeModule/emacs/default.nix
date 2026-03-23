{
  pkgs,
  pkdjz,
  user,
  crioZone,
  emacsThemeDir ? null,
  ...
}:
let
  inherit (pkdjz) mkEmacs;
  package = mkEmacs { inherit user emacsThemeDir; };

  baseDependencies = with pkgs; [
    nil
    nodejs
    # Collision - unknown source
    # gh
  ];

  tokenizedAider =
    let
      gopassPath = "openai/api-key"; # gopass: first line is the key
      anthropicPath = "anthropic/api-key"; # optional
      baseUrl = null; # e.g. "https://api.openai.com/v1" or null
      aiderBin = "${pkgs.aider-chat}/bin/aider"; # use pinned aider
    in
    pkgs.writeScriptBin "aider" ''
      #!${pkgs.mksh}/bin/mksh
      set -euo pipefail

      _firstline() { ${pkgs.coreutils}/bin/head -n1; }
      _gp() { ${pkgs.gopass}/bin/gopass show -o "$1" | _firstline; }

      # Export only into this process env (not globally)
      : "''${OPENAI_API_KEY:=}"
      if [ -z "$OPENAI_API_KEY" ]; then
        OPENAI_API_KEY="$(_gp ${gopassPath})"
        export OPENAI_API_KEY
      fi

      : "''${ANTHROPIC_API_KEY:=}"
      if [ -z "$ANTHROPIC_API_KEY" ] && ${pkgs.gopass}/bin/gopass ls >/dev/null 2>&1; then
        if ${pkgs.gopass}/bin/gopass ls | ${pkgs.gnugrep}/bin/grep -qxF "${anthropicPath}" 2>/dev/null; then
          ANTHROPIC_API_KEY="$(_gp ${anthropicPath})"
          export ANTHROPIC_API_KEY
        fi
      fi

      ${if baseUrl != null then ''export OPENAI_BASE_URL="${baseUrl}"'' else ""}

      exec "${aiderBin}" "$@"
    '';

  synthElDependencies = [
    tokenizedAider
  ];

in
{
  home = {
    file.".emacs".text = builtins.readFile ./init.el;

    packages = [ package ] ++ baseDependencies ++ synthElDependencies;

    sessionVariables = {
      EDITOR = "emacsclient -c";
    };
  };

  programs.emacs.package = package;

  services = {
    emacs = {
      enable = true;
      inherit package;
      startWithUserSession = "graphical";
    };
  };
}
