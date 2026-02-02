{
  horizon,
  world,
  homeModules,
  criomos-lib,
  ...
}:
let
  inherit (builtins) mapAttrs;
  inherit (world) pkdjz;

  profile = {
    dark = false;
  };

  mkUserConfig = name: user: {
    _module.args = {
      inherit user profile;
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
        ;
    };
    sharedModules = homeModules;
    useGlobalPkgs = true;
    users = mapAttrs mkUserConfig horizon.users;
  };
}
