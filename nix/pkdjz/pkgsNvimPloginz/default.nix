{
  src,
  criomos-lib,
  pkgs,
  buildNvimPlogin,
}:
let

  overriddenPkgs = pkgs // {
    buildVimPluginFrom2Nix = buildNvimPlogin;
  };

  overridesLambda = import (src + /pkgs/misc/vim-plugins/overrides.nix);

  overrides = criomos-lib.callWith overridesLambda overriddenPkgs;

  lambda = import (src + /pkgs/misc/vim-plugins/generated.nix);

  closure = overriddenPkgs // {
    inherit overrides;
  };

  plugins = criomos-lib.callWith lambda closure;

  brokenPlugins = [ "minimap-vim" ];

in
removeAttrs plugins brokenPlugins
