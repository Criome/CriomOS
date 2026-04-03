{
  pkgs,
  lib,
  user,
  ...
}:
let
  inherit (user.methods) isCodeDev sizedAtLeast;

  patchBinary = bin: ''
    if [ -f "${bin}" ]; then
      ${pkgs.patchelf}/bin/patchelf \
        --set-interpreter "$(cat ${pkgs.stdenv.cc}/nix-support/dynamic-linker)" \
        --set-rpath "${lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]}" \
        "${bin}"
    fi
  '';

  visualjj = pkgs.vscode-utils.buildVscodeMarketplaceExtension {
    mktplcRef = {
      name = "visualjj";
      publisher = "visualjj";
      version = "0.27.0";
    };
    vsix = pkgs.fetchurl {
      name = "visualjj-0.27.0-linux-x64.vsix";
      url = "https://open-vsx.org/api/visualjj/visualjj/linux-x64/0.27.0/file/visualjj.visualjj-0.27.0@linux-x64.vsix";
      hash = "sha256-4w/A3C9WWfKbZF3LnaLR9aZ78hvU+lrEXS8nnMbgzeA=";
    };
    postInstall = patchBinary "$out/share/vscode/extensions/visualjj.visualjj/dist/bin/jj";
  };

  claude-code = pkgs.vscode-utils.buildVscodeMarketplaceExtension {
    mktplcRef = {
      name = "claude-code";
      publisher = "anthropic";
      version = "2.1.90";
    };
    vsix = pkgs.fetchurl {
      name = "claude-code-2.1.90-linux-x64.vsix";
      url = "https://open-vsx.org/api/anthropic/claude-code/linux-x64/2.1.90/file/anthropic.claude-code-2.1.90@linux-x64.vsix";
      hash = "sha256-ij8sE8JCXKhQzSarOECjhEijGVxLCFUA0PmqlOF3ZoQ=";
    };
    postInstall = patchBinary "$out/share/vscode/extensions/anthropic.claude-code/resources/native-binary/claude";
  };

in
lib.mkIf (sizedAtLeast.med && isCodeDev) {

  programs.vscode = {
    enable = true;
    package = pkgs.vscodium;

    profiles.default = {
      extensions = [
        visualjj
        claude-code
        pkgs.vscode-extensions.mkhl.direnv
        pkgs.vscode-extensions.jnoortheen.nix-ide
      ];

      userSettings = {
        # Darkman portal — auto dark/light with stylix base16 as dark theme
        "window.autoDetectColorScheme" = true;

        # jj as primary SCM — hide git, show VisualJJ in Source Control panel
        "git.enabled" = false;
        "git.autoRepositoryDetection" = false;
        "visualjj.showSourceControlColocated" = true;

        # direnv — auto-reload on .envrc change
        "direnv.restart.automatic" = true;

        # Nix
        "nix.enableLanguageServer" = true;

        # Terminal
        "terminal.integrated.defaultProfile.linux" = "zsh";

        # Suppress welcome tab and extension walkthroughs
        "workbench.startupEditor" = "none";
        "workbench.welcomePage.walkthroughs.openOnInstall" = false;

        # Extensions managed by Nix — no marketplace updates
        "extensions.autoUpdate" = false;
        "extensions.autoCheckUpdates" = false;

        # Telemetry off
        "telemetry.telemetryLevel" = "off";
        "update.mode" = "none";

        # Editor
        "editor.renderWhitespace" = "boundary";
        "editor.minimap.enabled" = false;
        "files.trimTrailingWhitespace" = true;
        "files.insertFinalNewline" = true;
      };
    };
  };
}
