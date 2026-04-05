{
  pkgs,
  lib,
  user,
  inputs,
  ...
}:
let
  inherit (builtins) toJSON;
  inherit (user.methods) sizedAtLeast;

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
    postInstall = ''
      jj=$out/share/vscode/extensions/visualjj.visualjj/dist/bin/jj
      if [ -f "$jj" ]; then
        ${pkgs.patchelf}/bin/patchelf \
          --set-interpreter "$(cat ${pkgs.stdenv.cc}/nix-support/dynamic-linker)" \
          --set-rpath "${lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]}" \
          "$jj"
      fi
    '';
  };

  claude-code = pkgs.vscode-utils.buildVscodeMarketplaceExtension {
    mktplcRef = {
      name = "claude-code";
      publisher = "anthropic";
      version = "2.1.92";
    };
    vsix = pkgs.fetchurl {
      name = "claude-code-2.1.92-linux-x64.vsix";
      url = "https://open-vsx.org/api/anthropic/claude-code/linux-x64/2.1.92/file/anthropic.claude-code-2.1.92@linux-x64.vsix";
      hash = "sha256-dZ9625x6qCWwI2tY/GP3QSNoG/Sxi6nZGHNFnSSIy+Y=";
    };
    postInstall = ''
      extDir="$out/share/vscode/extensions/anthropic.claude-code"

      # Replace bundled native binary with Nix-built one (Go binary can't survive patchelf)
      rm -f "$extDir/resources/native-binary/claude"
      ln -s ${pkgs.vscode-extensions.anthropic.claude-code}/share/vscode/extensions/anthropic.claude-code/resources/native-binary/claude \
        "$extDir/resources/native-binary/claude"

      # Fix hardcoded dark theme in diff view
      substituteInPlace "$extDir/webview/index.js" \
        --replace-fail 'theme:"vs-dark"' \
        'theme:document.body.classList.contains("vscode-light")?"vs":"vs-dark"'
    '';
  };

  askiWasm = inputs.aski.packages.${pkgs.system}.tree-sitter-aski-wasm;

  vscode-aski =
    let
      src = builtins.fetchGit {
        url = "https://github.com/LiGoldragon/vscode-aski.git";
        rev = "7e7cfd5fe4bc1b2ff4e5da12b55b6e6e94b46cc3";
      };
    in
    pkgs.buildNpmPackage {
      pname = "vscode-extension-criome-vscode-aski";
      version = "0.3.0";
      inherit src;
      npmDepsHash = "sha256-0JjCGpgLQM79CUhV6//fEcJJr79BmtqPIq9a2mtWDiQ=";
      dontNpmBuild = true;
      buildPhase = ''
        npx esbuild src/extension.ts --bundle --outfile=out/extension.js --external:vscode --external:web-tree-sitter --format=cjs --platform=node
      '';
      installPhase = ''
        extDir=$out/share/vscode/extensions/criome.vscode-aski
        mkdir -p $extDir $extDir/grammars
        cp -r out package.json language-configuration.json $extDir/
        # WASM + queries from aski flake (pure Nix build)
        cp ${askiWasm}/tree-sitter-aski.wasm $extDir/grammars/
        cp -r ${askiWasm}/queries $extDir/
        # web-tree-sitter WASM needed at runtime
        mkdir -p $extDir/node_modules/web-tree-sitter
        cp -rL node_modules/web-tree-sitter/. $extDir/node_modules/web-tree-sitter/
      '';
      passthru = {
        vscodeExtPublisher = "criome";
        vscodeExtName = "vscode-aski";
        vscodeExtUniqueId = "criome.vscode-aski";
      };
    };

  settingsJson = toJSON {
    # Theme — stylix generates base16 theme, darkman switches via portal
    "window.autoDetectColorScheme" = true;
    "workbench.preferredDarkColorTheme" = "Default Dark Modern";
    "workbench.preferredLightColorTheme" = "Default Light Modern";

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

    # Claude Code
    "claudeCode.allowDangerouslySkipPermissions" = true;
    "claudeCode.initialPermissionMode" = "bypassPermissions";

    # Telemetry off
    "telemetry.telemetryLevel" = "off";
    "update.mode" = "none";

    # Editor
    "editor.renderWhitespace" = "boundary";
    "editor.minimap.enabled" = false;
    "files.trimTrailingWhitespace" = true;
    "files.insertFinalNewline" = true;
  };

in
lib.mkIf sizedAtLeast.med {

  programs.vscode = {
    enable = true;
    package = pkgs.vscodium;

    profiles.default = {
      extensions = [
        visualjj
        claude-code
        vscode-aski
        pkgs.vscode-extensions.mkhl.direnv
        pkgs.vscode-extensions.jnoortheen.nix-ide
      ];
    };
  };

  home.activation.seedVscodiumSettings =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      settings="$HOME/.config/VSCodium/User/settings.json"
      mkdir -p "$(dirname "$settings")"

      if [ ! -e "$settings" ] || [ -L "$settings" ]; then
        rm -f "$settings"
        cat > "$settings" << 'SETTINGS'
      ${settingsJson}
      SETTINGS
      fi
    '';
}
