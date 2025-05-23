inputs@{
  src,
  lib,
  pkgs,
  system,
}:

arguments@{
  pkgs ? inputs.pkgs,
  modules ? [ ],
  moduleArgs ? { },
  iuzQemuVmModule ? false,
  iuzIsoModule ? false,
}:
let
  inherit (lib) evalModules optional;

  noUserModules = lib.evalModules ({
    prefix = [ ];
    modules = baseModules;
  });

  specialArgs = {
    modulesPath = toString (src + /nixos/modules);
  };

  nixpkgsConfig = {
    nixpkgs = {
      inherit pkgs;
    };
  };

  nixpkgsModules = [
    nixpkgsConfig
    src.nixosModules.readOnlyPkgs
  ];

  baseModules = import (src + /nixos/modules/module-list.nix) ++ nixpkgsModules;

  qemuVmModule = import (src + /nixos/modules/virtualisation/qemu-vm.nix);

  isoImageModule = import (src + /nixos/modules/installer/cd-dvd/iso-image.nix);

  moduleArgsModule = {
    _module.args = {
      inherit lib baseModules noUserModules;
    } // moduleArgs;
  };

in
evalModules {
  inherit specialArgs;
  modules =
    arguments.modules
    ++ baseModules
    ++ [ moduleArgsModule ]
    ++ (optional iuzQemuVmModule qemuVmModule)
    ++ (optional iuzIsoModule isoImageModule);
}
