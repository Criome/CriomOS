{
  kor,
  lib,
  src,
  pkgs,
  hob,
  tdlib,
}:
with builtins;
let
  emacs-overlay = src;
  inherit (pkgs) writeText emacsPackagesFor delta;

  emacs = pkgs.emacs29-pgtk;
  emacsPackages = emacsPackagesFor emacs;
  inherit (emacsPackages)
    elpaBuild
    withPackages
    melpaBuild
    trivialBuild
    ;

  parseLib = import (emacs-overlay + /parse.nix) { inherit pkgs lib; };
  inherit (parseLib) parsePackagesFromUsePackage;

  customPackages = {
    base16-theme =
      let
        src = hob.base16-theme;
      in
      trivialBuild {
        pname = "base16-theme";
        version = src.shortRev;
        inherit src;
      };

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

    shen-mode =
      let
        src = hob.shen-mode;
      in
      melpaBuild {
        pname = "shen-mode";
        inherit src;
        commit = src.rev;
        version = "0.1";
        recipe = pkgs.writeText "recipe" ''
          (shen-mode
           :repo "NHALX/shen-mode"
           :fetcher github)
        '';
      };

    telega = emacsPackages.telega.overrideAttrs (
      attrs:
      let
        src = hob.telega-el;
        filteredBuildInputs = filter (pkg: pkg != pkgs.tdlib) attrs.buildInputs;
      in
      {
        inherit src;
        version = "0.8.150";
        buildInputs = filteredBuildInputs ++ [ tdlib ];
      }
    );

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

{ user, profile }:
let
  emacsTheme = if profile.dark then "'modus-vivendi" else "'modus-operandi";

  loadTheme = ''
    (load-theme ${emacsTheme} t)
  '';

  commonPackagesEl = readFile ./packages.el;
  launcherCommonEl = readFile ./selector-common.el;
  launcherStyleEl = readFile ./vertico.el;

  packagesEl = concatStringsSep "\n" [
    commonPackagesEl
    launcherCommonEl
    launcherStyleEl
  ];

  usePackagesNames = kor.unique (parsePackagesFromUsePackage {
    configText = packagesEl;
    alwaysEnsure = true;
  });

  mkPackageError =
    name:
    let
      coreEmacsPackageNames = [ "auth-source-pass" ];
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

  defaultElPackage = trivialBuild {
    pname = "default-el";
    version = kor.shortHashString defaultEl;
    src = writeText "default.el" defaultEl;
    packageRequires = usePackages;
  };

  treeSitterPackages = [ (emacsPackages.treesit-grammars.with-all-grammars) ];

  allEmacsPackages = usePackages ++ [ defaultElPackage ] ++ treeSitterPackages;

  emacs = withPackages allEmacsPackages;

in
emacs
