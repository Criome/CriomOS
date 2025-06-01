{
  lib,
  nixpkgs,
  localSystem,
  config,
  crossSystem ? localSystem,
  overlays ? [ ],
  crossOverlays ? [ ],
  stdenvStages ? import (nixpkgs + /pkgs/stdenv),
  ...
}@args:

let
  config0 = config;
  crossSystem0 = crossSystem;

in
let
  inherit (lib) throwIfNot;

  checked =
    throwIfNot (lib.isList overlays) "The overlays argument to nixpkgs must be a list." lib.foldr
      (x: throwIfNot (lib.isFunction x) "All overlays passed to nixpkgs must be functions.")
      (r: r)
      overlays
      throwIfNot
      (lib.isList crossOverlays)
      "The crossOverlays argument to nixpkgs must be a list."
      lib.foldr
      (x: throwIfNot (lib.isFunction x) "All crossOverlays passed to nixpkgs must be functions.")
      (r: r)
      crossOverlays;

  localSystem = lib.systems.elaborate args.localSystem;

  crossSystem =
    let
      system = lib.systems.elaborate crossSystem0;
    in
    if crossSystem0 == null || lib.systems.equals system localSystem then localSystem else system;

  configEval = lib.evalModules {
    modules = [
      (nixpkgs + /pkgs/top-level/config.nix)
      (
        { options, ... }:
        {
          _file = "nixpkgs.config";
          config = config0;
        }
      )
    ];
    class = "nixpkgsConfig";
  };

  # take all the rest as-is
  config = lib.showWarnings configEval.config.warnings configEval.config;

  nixpkgsFun = newArgs: import (nixpkgs + /pkgs/top-level) (args // newArgs);

  allPackages =
    newArgs:
    import (nixpkgs + /pkgs/top-level/stage.nix) (
      {
        inherit lib nixpkgsFun;
      }
      // newArgs
    );

  boot = import (nixpkgs + /pkgs/stdenv/booter.nix) { inherit lib allPackages; };

  stages = stdenvStages {
    inherit
      lib
      localSystem
      crossSystem
      config
      overlays
      crossOverlays
      ;
  };

  pkgs = boot stages;

in
checked pkgs
