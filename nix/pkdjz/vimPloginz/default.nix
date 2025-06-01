{
  hob,
  vimUtils,
  fzf,
}:
let
  inherit (builtins) mapAttrs;
  inherit (vimUtils) buildVimPluginFrom2Nix;

  implaidSpoks = (import ./../nvimPloginz/spoksFromHob.nix) hob;

  eksplisitSpoks = { };

  mkImplaidSpoks = name: spok: spok;

  spoks = eksplisitSpoks // (mapAttrs (n: s: s) implaidSpoks);

  fzf-vim-core = buildVimPluginFrom2Nix {
    pname = "fzf";
    version = fzf.version;
    src = fzf.src;
  };

  overridesIndeks = {
    fzf-vim = {
      dependencies = [ fzf-vim-core ];
    };
  };

  forkIndeks = { };

  buildVimPlogin =
    {
      name,
      src,
      overrides,
    }:
    let
    in
    buildVimPluginFrom2Nix (
      {
        pname = name;
        version = src.shortRev;
        inherit src;
      }
      // overrides
    );

  mkSpok =
    name: src:
    let
      overrides = overridesIndeks.${name} or { };
    in
    buildVimPlogin { inherit name src overrides; };

  ryzylt = mapAttrs mkSpok spoks;

in
ryzylt
