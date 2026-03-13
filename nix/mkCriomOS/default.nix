{
  lib,
  criomos-lib,
  world,
  horizon,
  hob, # TODO: deprecate for `inputs`
  homeModules,
  inputs,
  _withUsers ? true,
}:
let
  inherit (lib) optional optionals;
  inherit (world) pkdjz home-manager;
  inherit (pkdjz) evalNixos;
  inherit (horizon) node;
  inherit (horizon.node.methods) behavesAs;

  isPrometheusNode = node.name == "prometheus";

  constants = import ./constants.nix;
  usersModule = import ./users.nix;
  nixModule = import ./nix.nix;
  normalizeModule = import ./normalize.nix;
  networkModule = import ./network;
  edgeModule = import ./edge;
  llmModule = import ./llm.nix;

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
    ++ (optional isPrometheusNode llmModule)
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

  buildNixOSIso = evaluation.config.system.build.isoImage;
  buildNixOS = evaluation.config.system.build.toplevel;

in
if behavesAs.iso then buildNixOSIso else buildNixOS
