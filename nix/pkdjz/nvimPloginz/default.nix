{ hob, buildNvimPlogin }:
let
  inherit (builtins) mapAttrs;

  implaidSpoks = (import ./spoksFromHob.nix) hob;

  eksplisitSpoks = { };

  spoks = eksplisitSpoks // (mapAttrs (n: s: s) implaidSpoks);

  overridesIndeks = { };

  mkSpok =
    name: src:
    let
      overrides = overridesIndeks.${name} or { };
    in
    buildNvimPlogin (
      {
        pname = name;
        version = src.shortRev;
        inherit src;
      }
      // overrides
    );

  ryzylt = mapAttrs mkSpok spoks;

in
ryzylt
