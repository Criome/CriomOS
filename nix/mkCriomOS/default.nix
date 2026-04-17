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
  inherit (horizon.node) typeIs;
  inherit (horizon.node.methods) behavesAs sizedAtLeast;


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

  complexModule = import ./complex.nix;
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
    complexModule
    networkModule
  ];

  claudeDesktopModule = {
    imports = [ inputs.claude-for-linux.nixosModules.default ];
    programs.claude-desktop.enable = true;
  };

  featureModules =
    (optional (behavesAs.edge && !behavesAs.iso) edgeModule)
    ++ (optional (behavesAs.router && !behavesAs.iso) ./router)
    ++ (optional (behavesAs.bareMetal && !behavesAs.iso) metalModule)
    ++ (optional behavesAs.largeAI llmModule)
    ++ (optional (sizedAtLeast.min && !behavesAs.iso) claudeDesktopModule)
    ++ (optionals _withUsers usersModules);

  nixosModules = baseModules ++ featureModules;

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
      inputs
      ;
  };

  # VM uses the same feature modules but without the disk/ISO-specific module
  vmModules =
    [ usersModule nixModule normalizeModule complexModule networkModule ]
    ++ featureModules;

  evaluation = evalNixos {
    useIsoModule = behavesAs.iso;
    moduleArgs = nixosArgs;
    modules = nixosModules;
  };

  vmEvaluation = evalNixos {
    useQemuVmModule = true;
    moduleArgs = nixosArgs;
    modules = vmModules;
  };

in
{
  os = if behavesAs.iso then evaluation.config.system.build.isoImage else evaluation.config.system.build.toplevel;
  vm = vmEvaluation.config.system.build.vm;
}
