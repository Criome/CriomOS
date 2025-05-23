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
  inherit (uyrld) pkdjz mkZolaWebsite;

  mkTypedZolaWebsite =
    name: flake:
    mkZolaWebsite {
      src = flake;
      name = flake.name or name;
    };

  meikSobUyrld =
    SobUyrld@{
      lamdy,
      modz,
      self ? src,
      src ? self,
      sobUyrldz ? { },
    }:
    let
      Modz = [
        "pkgs"
        "pkgsStatic"
        "pkgsSet"
        "hob"
        "mkPkgs"
        "pkdjz"
        "uyrld"
        "uyrldSet"
      ];

      iuzMod = genAttrs Modz (n: (l.elem n modz));

      # Warning: sets shadowing
      klozyr =
        optionalAttrs iuzMod.pkgs pkgs
        // optionalAttrs iuzMod.pkgsStatic pkgs.pkgsStatic
        // optionalAttrs iuzMod.uyrld uyrld
        // optionalAttrs iuzMod.pkdjz pkdjz
        // optionalAttrs iuzMod.hob { inherit hob; }
        // optionalAttrs iuzMod.pkgsSet { inherit pkgs; }
        // optionalAttrs iuzMod.uyrldSet { inherit uyrld; }
        // optionalAttrs iuzMod.mkPkgs { inherit mkPkgs; }
        // sobUyrldz
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
    meikSobUyrld {
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
      priMeikSobUyrld =
        name:
        SobUyrld@{
          modz ? [ ],
          lamdy,
          ...
        }:
        let
          src = SobUyrld.src or (SobUyrld.self or fleik);
          self = src;
        in
        meikSobUyrld {
          inherit
            src
            self
            modz
            lamdy
            ;
        };

      priMeikHobUyrld =
        name:
        HobUyrld@{
          modz ? [ "pkgs" ],
          lamdy,
          ...
        }:
        let
          implaidSelf = hob.${name} or null;
          src = HobUyrld.src or (HobUyrld.self or implaidSelf);
          self = src;
        in
        meikSobUyrld {
          inherit
            src
            self
            modz
            lamdy
            ;
        };

      meikHobUyrldz =
        HobUyrldz:
        let
          priHobUyrldz = HobUyrldz hob;
        in
        mapAttrs priMeikHobUyrld priHobUyrldz;

      meikSobUyrldz =
        SobUyrldz:
        let
          priMeikSobUyrldz =
            name:
            SobUyrld@{
              modz ? [ ],
              lamdy,
              ...
            }:
            let
              src = SobUyrld.src or (SobUyrld.self or fleik);
              self = src;
            in
            meikSobUyrld {
              inherit
                src
                self
                modz
                lamdy
                sobUyrldz
                ;
            };

          sobUyrldz = mapAttrs priMeikSobUyrldz SobUyrldz;
        in
        sobUyrldz;

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
    else if (hasAttr "HobUyrldz" fleik) then
      meikHobUyrldz fleik.HobUyrldz
    else if (hasAttr "HobUyrld" fleik) then
      priMeikHobUyrld spokName (fleik.HobUyrld hob)
    else if (hasAttr "SobUyrldz" fleik) then
      meikSobUyrldz fleik.SobUyrldz
    else if (hasAttr "SobUyrld" fleik) then
      priMeikSobUyrld spokName fleik.SobUyrld
    else if (isWebpageSpok spokName) then
      mkZolaWebsite { src = fleik; }
    # else if hasFleikFile then makeFleik
    else
      fleik // optionalSystemAttributes;

  uyrld = mapAttrs makeSpoke hob;

in
uyrld
