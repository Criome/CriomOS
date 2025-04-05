## Lean version of (nixpkgs + /pkgs/top-level/impure.nix)
args@{
  nixpkgs,
  system ? localSystem.system,
  localSystem ? {
    system = args.system;
  },
  crossSystem ? localSystem,
  lib ? import (nixpkgs + /lib),
  overlays ? [ ],
  config ? {
    allowUnfree = true;
    permittedInsecurePackages = [ "olm-3.2.16" ];
  },
}:
let
  forcedNonOptionalArguments = {
    inherit config overlays localSystem;
  };
  mkPkgsFn = import (nixpkgs + /pkgs/top-level);
  explicitArguments = builtins.removeAttrs args [ "system" ];
  pkgsTopLevelArguments = explicitArguments // forcedNonOptionalArguments;
in
# If `localSystem` was explicitly passed, legacy `system` should
# not be passed, and vice-versa.
assert args ? localSystem -> !(args ? system);
assert args ? system -> !(args ? localSystem);

mkPkgsFn pkgsTopLevelArguments
