{
  hob,
  buildNvimPlogin,
  fzf,
}:
let
  inherit (builtins) mapAttrs;

  implaidSpoks = {
    inherit (hob)
      nvim-lspconfig
      ;
  };

  eksplisitSpoks = {
    plenary-kor = hob.plenary-nvim;
  };

  spoks = eksplisitSpoks // (mapAttrs (n: s: s) implaidSpoks);

  overridesIndeks = {
    plenary-kor = {
      installPhase = ''
        runHook preInstall
        mkdir -p $out/lua
        cp -r lua/plenary $out/lua/
        runHook postInstall
      '';
    };
  };

  buildNvimLuaPlogin =
    {
      name,
      src,
      overrides,
    }:
    buildNvimPlogin (
      {
        pname = name;
        version = src.shortRev;
        inherit src;
        namePrefix = "nvimLuaPlogin";
        components = [
          "lua"
          "queries"
          "doc"
        ];
      }
      // overrides
    );

  mkSpok =
    name: src:
    let
      overrides = overridesIndeks.${name} or { };
    in
    buildNvimLuaPlogin { inherit name src overrides; };

  ryzylt = mapAttrs mkSpok spoks;

in
ryzylt
