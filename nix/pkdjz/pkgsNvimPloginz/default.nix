{
  src,
  mkLambda,
  pkgs,
  buildNvimPlogin,
}:
let

  ovyridynPkgs = pkgs // {
    buildVimPluginFrom2Nix = buildNvimPlogin;
  };

  overridesLambda = import (src + /pkgs/misc/vim-plugins/overrides.nix);

  overrides = mkLambda {
    lambda = overridesLambda;
    closure = ovyridynPkgs;
  };

  lambda = import (src + /pkgs/misc/vim-plugins/generated.nix);

  closure = ovyridynPkgs // {
    inherit overrides;
  };

  plugins = mkLambda {
    inherit lambda closure;
  };

  brokenPlugins = [ "minimap-vim" ];

in
removeAttrs plugins brokenPlugins
