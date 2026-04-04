{
  horizon,
  world,
  homeModules,
  criomos-lib,
  inputs,
  ...
}:
let
  inherit (builtins) mapAttrs;
  inherit (world) pkdjz;

  mkUserConfig = name: user: {
    imports = [ inputs.niri-flake.homeModules.config ];
    _module.args = {
      inherit user;
    };
  };

in
{
  home-manager = {
    backupFileExtension = "backup";
    extraSpecialArgs = {
      inherit
        pkdjz
        world
        horizon
        criomos-lib
        inputs
        ;
    };
    sharedModules = homeModules;
    useGlobalPkgs = true;
    users = mapAttrs mkUserConfig horizon.users;
  };
}
