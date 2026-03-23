{
  lib,
  src,
  pkgs,
  hob,
  tree-sitter-capnp,
  tree-sitter-cozo,
}:
with builtins;
let
  emacs-overlay = src;
  inherit (pkgs) writeText emacsPackagesFor delta;

  emacs = pkgs.emacs-pgtk;
  emacsPackages = emacsPackagesFor emacs;
  inherit (emacsPackages)
    withPackages
    melpaBuild
    trivialBuild
    ;

  parseLib = import (emacs-overlay + /parse.nix) { inherit pkgs lib; };
  inherit (parseLib) parsePackagesFromUsePackage;

  customPackages = {
    elisp-autofmt = pkgs.emacsPackages.elisp-autofmt.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        substituteInPlace elisp-autofmt.el \
          --replace 'defcustom elisp-autofmt-python-bin nil' \
                    "defcustom elisp-autofmt-python-bin \"${pkgs.python3}/bin/python3\""
      '';
    });

    base16-theme =
      let
        src = hob.base16-theme;
      in
      trivialBuild {
        pname = "base16-theme";
        version = src.shortRev;
        inherit src;
      };

    gptel = emacsPackages.gptel.overrideAttrs (attrs: {
      src = hob.gptel;
    });

    jujutsu =
      let
        src = hob.jujutsu-el;
      in
      trivialBuild {
        pname = "jujutsu-el";
        version = src.shortRev;
        inherit src;
        packageRequires = with emacsPackages; [
          ht
          dash
          s
        ];
      };

    magit-delta = emacsPackages.magit-delta.overrideAttrs (attrs: {
      buildInputs = attrs.buildInputs ++ [ pkgs.delta ];
    });

    md-roam =
      let
        src = hob.md-roam;
      in
      trivialBuild {
        pname = "md-roam";
        version = src.shortRev;
        inherit src;
        packageRequires = with emacsPackages; [
          markdown-mode
          org-roam
        ];
      };

    superchat =
      let
        src = hob.superchat;
      in
      trivialBuild {
        pname = "superchat";
        version = src.shortRev;
        inherit src;

        # Superchat rides GPTel (chat), writes Markdown, and optionally uses Org for memory.
        packageRequires = with emacsPackages; [
          gptel
          markdown-mode
          org
          dash
          s
          transient
        ];

        /*
          Nix sandbox notes:
          - Emacs runs in batch with HOME=/homeless-shelter (not writable).
          - Superchat enables auto tasks at load time and tries to create ~/.emacs.d/superchat.
          - We both export a writable HOME and turn those timers off during byte-compile.
        */
        preBuild = ''
          export HOME="$TMPDIR"
        '';

        # These -evals run before files are loaded for compilation.
        byteCompileFlags = [
          # Disable any auto tasks that would mkdir in HOME during build
          "-eval"
          "(setq superchat-memory-auto-prune-enabled nil)"
          "-eval"
          "(setq superchat-memory-auto-insights-enabled nil)"
          "-eval"
          "(setq superchat-session-auto-save nil)"
          # Point data dir somewhere harmless during build just in case
          "-eval"
          "(setq superchat-data-directory (expand-file-name \"superchat-build/\" temporary-file-directory))"
        ];

        # Optional: quiet native compilation issues if you use native-comp Emacs
        # nativeCompile = false;
      };

    tera-mode =
      let
        src = hob.tera-mode;
      in
      trivialBuild {
        pname = "tera-mode";
        inherit src;
        version = src.shortRev;
        commit = src.rev;
      };

    toodoo =
      let
        src = hob.toodoo-el;
      in
      trivialBuild {
        pname = "toodoo";
        inherit src;
        version = src.shortRev;
        commit = src.rev;
      };

    ultra-scroll =
      let
        src = hob.ultra-scroll;
      in
      trivialBuild {
        pname = "ultra-scroll";
        version = src.shortRev;
        inherit src;
      };

    xah-fly-keys =
      let
        src = hob.xah-fly-keys;
      in
      trivialBuild {
        pname = "xah-fly-keys";
        inherit src;
        version = src.shortRev;
        commit = src.rev;
      };
  };

  overiddenEmacsPackages = emacsPackages // customPackages;

in

{ user, emacsThemeDir ? null }:
let
  loadTheme = if emacsThemeDir != null then ''
    (add-to-list 'custom-theme-load-path "${emacsThemeDir}")
    (let ((mode-file (expand-file-name "darkman/current-mode"
                       (or (getenv "XDG_STATE_HOME")
                           (expand-file-name ".local/state" "~")))))
      (when (file-readable-p mode-file)
        (let ((mode (string-trim (with-temp-buffer
                                   (insert-file-contents mode-file)
                                   (buffer-string)))))
          (pcase mode
            ("dark" (load-theme 'ignis-dark t))
            ("light" (load-theme 'ignis-light t))))))
  '' else "";

  commonPackagesEl = readFile ./packages.el;
  launcherCommonEl = readFile ./selector-common.el;
  launcherStyleEl = readFile ./vertico.el;
  syntEl = readFile ./synth.el;

  packagesEl = concatStringsSep "\n" [
    commonPackagesEl
    launcherCommonEl
    launcherStyleEl
    syntEl
  ];

  usePackagesNames = lib.unique (parsePackagesFromUsePackage {
    configText = packagesEl;
    alwaysEnsure = true;
  });

  mkPackageError =
    name:
    let
      coreEmacsPackageNames = [
        "auth-source-pass"
        "treesit"
      ];
      packageIsInCore = elem name coreEmacsPackageNames;
    in
    if packageIsInCore then
      null
    else
      builtins.trace "Emacs package ${name}, declared wanted with use-package, not found." null;

  findPackage = name: overiddenEmacsPackages.${name} or (mkPackageError name);
  usePackages = map findPackage usePackagesNames;

  elpaHeader = readFile ./elpaHeader.el;
  elpaFooter = ";;; default.el ends here";
  defaultEl = elpaHeader + packagesEl + loadTheme + elpaFooter;

  mkStringHash = String: builtins.hashString "sha256" String;
  shortHashString = string: builtins.substring 0 7 (mkStringHash string);

  defaultElPackage = trivialBuild {
    pname = "default-el";
    version = shortHashString defaultEl;
    src = writeText "default.el" defaultEl;
    packageRequires = usePackages;
  };

  treeSitterPackages = [
    (emacsPackages.treesit-grammars.with-all-grammars)
    tree-sitter-capnp
    tree-sitter-cozo
  ];

  autoformatPackages = with pkgs.python3Packages; [
    mdformat
    mdformat-gfm
    mdformat-frontmatter
    mdformat-footnote
    mdformat-gfm-alerts
  ];

  nonElispPackages = treeSitterPackages ++ autoformatPackages;

  allEmacsPackages = usePackages ++ [ defaultElPackage ] ++ nonElispPackages;

  emacs = withPackages allEmacsPackages;

in
emacs
