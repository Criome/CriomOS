{
  lib,
  pkgs,
  hob,
  system,
}:
let
  l = lib // builtins;
  inherit (world) pkdjz mkZolaWebsite;

  mkLambda =
    { closure, lambda }:
    let
      requiredInputs = l.functionArgs lambda;
      inputs = l.intersectAttrs requiredInputs closure;
    in
    lambda inputs;

  mkSubWorld =
    {
      lambda,
      mods,
      src ? null,
    }:
    let
      Mods = [
        "pkgs"
        "pkgsStatic"
        "pkgsSet"
        "hob"
        "pkdjz"
        "world"
        "worldSet"
      ];

      useMod = l.genAttrs Mods (n: (l.elem n mods));

      # Warning: sets shadowing
      closure =
        l.optionalAttrs useMod.pkgs pkgs
        // l.optionalAttrs useMod.pkgsStatic pkgs.pkgsStatic
        // l.optionalAttrs useMod.world world
        // l.optionalAttrs useMod.pkdjz pkdjz
        // l.optionalAttrs useMod.hob { inherit hob; }
        // l.optionalAttrs useMod.pkgsSet { inherit pkgs; }
        // l.optionalAttrs useMod.worldSet { inherit world; }
        // {
          inherit
            lib
            system
            src
            mkLambda
            ;
        };

    in
    mkLambda { inherit closure lambda; };

  makeSpoke =
    spokName:
    spoke@{ ... }:
    let
      priMkSubWorld =
        name:
        SubWorld@{
          mods ? [ ],
          lambda,
          ...
        }:
        let
          src = SubWorld.src or spoke;
        in
        mkSubWorld {
          inherit
            src
            mods
            lambda
            ;
        };

      priMkHobWorld =
        name:
        HobWorld@{
          mods ? [ "pkgs" ],
          lambda,
          ...
        }:
        let
          impliedSrc = hob.${name} or null;
          src = HobWorld.src or impliedSrc;
        in
        mkSubWorld {
          inherit
            src
            mods
            lambda
            ;
        };

      mkHobWorlds =
        HobWorlds:
        let
          priHobWorlds = HobWorlds hob;
        in
        l.mapAttrs priMkHobWorld priHobWorlds;

      # TODO - Bad design
      spokeIsWebsite = spokeName: spokName == (spokeName + "Website");

      optionalSystemAttributes = {
        packages = spoke.packages.${system} or { };
        legacyPackages = spoke.legacyPackages.${system} or { };
      };

    in
    if (l.hasAttr "HobWorlds" spoke) then
      mkHobWorlds spoke.HobWorlds
    else if (l.hasAttr "SubWorld" spoke) then
      priMkSubWorld spokName spoke.SubWorld
    else if (spokeIsWebsite spokName) then
      mkZolaWebsite { src = spoke; }
    else
      spoke // optionalSystemAttributes;

  world = l.mapAttrs makeSpoke hob;

in
world
