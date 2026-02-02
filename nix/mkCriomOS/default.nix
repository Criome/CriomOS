{
  lib,
  criomos-lib,
  world,
  horizon,
  hob, # TODO: deprecate for `inputs`
  inputs,
  homeModules,
  _withUsers ? true,
}:
let
  inherit (lib) optional optionals;
  inherit (world) pkdjz home-manager;
  inherit (pkdjz) evalNixos;
  inherit (horizon.node.methods) behavesAs;

  constants = import ./constants.nix;
  usersModule = import ./users.nix;
  nixModule = import ./nix.nix;
  normalizeModule = import ./normalize.nix;
  networkModule = import ./network;
  edgeModule = import ./edge;

  disksModule =
    if behavesAs.virtualMachine then
      import ./pod.nix
    else if behavesAs.iso then
      import ./liveIso.nix
    else
      import ./preInstalled.nix;

  metalModule = import ./metal;

  usersModules = [
    ./userHomes.nix
    home-manager.nixosModules.default
  ];

  baseModules = [
    usersModule
    disksModule
    nixModule
    normalizeModule
    networkModule
  ];

  nixosModules =
    baseModules
    ++ (optional behavesAs.edge edgeModule)
    ++ (optional behavesAs.router ./router)
    ++ (optional behavesAs.bareMetal metalModule)
    ++ (optionals _withUsers usersModules);

  nixosArgs = {
    inherit
      constants
      lib
      criomos-lib
      world
      pkdjz
      horizon
      homeModules
      hob
      ;
  };

  evaluation = evalNixos {
    useIsoModule = behavesAs.iso;
    moduleArgs = nixosArgs;
    modules = nixosModules;
  };

  # TODO - unused leftover
  buildNixOSVM = evaluation.config.system.build.vm;

  buildNixOSIso = evaluation.config.system.build.isoImage;
  buildNixOS = evaluation.config.system.build.toplevel;

in
if behavesAs.iso then buildNixOSIso else buildNixOS
