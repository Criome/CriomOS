{
  lib,
  pkgs,
  hob,
  system,
  localSources,
}:
let
  l = lib // builtins;
  inherit (builtins) hasAttr mapAttrs readDir;
  inherit (localSources) kor nodeNames mkPkgs;
  inherit (kor) mkLamdy optionalAttrs genAttrs;
  inherit (world) pkdjz mkZolaWebsite;

  mkTypedZolaWebsite =
    name: flake:
    mkZolaWebsite {
      src = flake;
      name = flake.name or name;
    };

  mkSubWorld =
    SubWorld@{
      lamdy,
      modz,
      self ? src,
      src ? self,
      subWorlds ? { },
    }:
    let
      Modz = [
        "pkgs"
        "pkgsStatic"
        "pkgsSet"
        "hob"
        "mkPkgs"
        "pkdjz"
        "world"
        "worldSet"
      ];

      useMod = genAttrs Modz (n: (l.elem n modz));

      # Warning: sets shadowing
      klozyr =
        optionalAttrs useMod.pkgs pkgs
        // optionalAttrs useMod.pkgsStatic pkgs.pkgsStatic
        // optionalAttrs useMod.world world
        // optionalAttrs useMod.pkdjz pkdjz
        // optionalAttrs useMod.hob { inherit hob; }
        // optionalAttrs useMod.pkgsSet { inherit pkgs; }
        // optionalAttrs useMod.worldSet { inherit world; }
        // optionalAttrs useMod.mkPkgs { inherit mkPkgs; }
        // subWorlds
        // {
          inherit kor lib;
        }
        // {
          inherit system;
        }
        # TODO: deprecate `self` for `src`
        // {
          inherit self;
        }
        // {
          src = self;
        };

    in
    mkLamdy { inherit klozyr lamdy; };

  mkWorldFunction =
    flake:
    mkSubWorld {
      modz = [
        "pkgs"
        "pkdjz"
      ];
      src = flake;
      lamdy = flake.function;
    };

  makeSpoke =
    spokName:
    fleik@{ ... }:
    let
      priMkSubWorld =
        name:
        SubWorld@{
          modz ? [ ],
          lamdy,
          ...
        }:
        let
          src = SubWorld.src or (SubWorld.self or fleik);
          self = src;
        in
        mkSubWorld {
          inherit
            src
            self
            modz
            lamdy
            ;
        };

      priMkHobWorld =
        name:
        HobWorld@{
          modz ? [ "pkgs" ],
          lamdy,
          ...
        }:
        let
          implaidSelf = hob.${name} or null;
          src = HobWorld.src or (HobWorld.self or implaidSelf);
          self = src;
        in
        mkSubWorld {
          inherit
            src
            self
            modz
            lamdy
            ;
        };

      mkHobWorlds =
        HobWorlds:
        let
          priHobWorlds = HobWorlds hob;
        in
        mapAttrs priMkHobWorld priHobWorlds;

      mkSubWorlds =
        SubWorlds:
        let
          priMkSubWorlds =
            name:
            SubWorld@{
              modz ? [ ],
              lamdy,
              ...
            }:
            let
              src = SubWorld.src or (SubWorld.self or fleik);
              self = src;
            in
            mkSubWorld {
              inherit
                src
                self
                modz
                lamdy
                subWorlds
                ;
            };

          subWorlds = mapAttrs priMkSubWorlds SubWorlds;
        in
        subWorlds;

      mkNodeWebpageName = nodeName: [
        (nodeName + "Webpage")
        (nodeName + "Website")
      ];

      nodeWebpageSpokNames = lib.concatMap mkNodeWebpageName nodeNames;

      isWebpageSpok = spokName: l.elem spokName nodeWebpageSpokNames;

      optionalSystemAttributes = {
        packages = fleik.packages.${system} or { };
        legacyPackages = fleik.legacyPackages.${system} or { };
      };

      hasFleikFile =
        let
          fleikDirectoryFiles = readDir fleik;
        in
        hasAttr "fleik.nix" fleikDirectoryFiles;

      makeFleik = { };

      mkNixpkgsHob =
        nixpkgsSet:
        let
          mkPkgsFromNameValue =
            name: value:
            mkPkgs {
              inherit system;
              nixpkgs = value;
            };
        in
        mapAttrs mkPkgsFromNameValue nixpkgsSet;

      typedFlakeMakerIndex = {
        nixpkgsHob = mkNixpkgsHob fleik.value;
        worldFunction = mkWorldFunction fleik;
        zolaWebsite = mkTypedZolaWebsite spokName fleik;
      };

      mkTypedFlake =
        let
          inherit (fleik) type;
        in
        builtins.getAttr type typedFlakeMakerIndex;

    in
    if (hasAttr "type" fleik) then
      mkTypedFlake
    else if (hasAttr "HobWorlds" fleik) then
      mkHobWorlds fleik.HobWorlds
    else if (hasAttr "HobWorld" fleik) then
      priMkHobWorld spokName (fleik.HobWorld hob)
    else if (hasAttr "SubWorlds" fleik) then
      mkSubWorlds fleik.SubWorlds
    else if (hasAttr "SubWorld" fleik) then
      priMkSubWorld spokName fleik.SubWorld
    else if (isWebpageSpok spokName) then
      mkZolaWebsite { src = fleik; }
    # else if hasFleikFile then makeFleik
    else
      fleik // optionalSystemAttributes;

  world = mapAttrs makeSpoke hob;

in
world
