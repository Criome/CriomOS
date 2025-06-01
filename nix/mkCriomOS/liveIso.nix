{
  pkgs,
  lib,
  horizon,
  kor,
  world,
  homeModule,
  ...
}:
let
  inherit (builtins) mapAttrs;
  inherit (lib) mkOverride;
  inherit (world) mkHomeConfig pkdjz;

  criomosVersion = "unversioned"; # TODO

  useMetalModule = horizon.node.machine.species == "metal";
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
  boot = {
    supportedFilesystems = mkOverride 10 [
      "btrfs"
      "vfat"
      "xfs"
      "ntfs"
      "ntfs3g"
    ];
  };

  hardware.enableAllFirmware = useMetalModule;

  home-manager = {
    backupFileExtension = "backup";
    extraSpecialArgs = {
      inherit
        kor
        pkdjz
        world
        horizon
        ;
    };
    sharedModules = [ homeModule ];
    useGlobalPkgs = true;
    users = mapAttrs mkUserConfig horizon.users;
  };

  isoImage = {
    isoBaseName = "CriomOS";
    volumeID = "CriomOS-${criomosVersion}-${pkgs.stdenv.hostPlatform.uname.processor}";

    makeUsbBootable = true;
    makeEfiBootable = true;
  };

}
