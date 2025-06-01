{
  homeModule,
  kor,
  world,
  horizon,
  hob,
}:
let
  inherit (kor) optional;
  inherit (world) pkdjz home-manager;
  inherit (pkdjz) evalNixos;
  inherit (horizon.node) machine io typeIs;

  usePodModule = (machine.species == "pod");
  useMetalModule = (machine.species == "metal");

  useRouterModule = typeIs.hybrid || typeIs.router;
  useEdgeModule = typeIs.edge || typeIs.hybrid || typeIs.edgeTesting;
  useIsoModule = !usePodModule && (io.disks == { });

  usersModule = import ./users.nix;
  nixModule = import ./nix.nix;
  normalizeModule = import ./normalize.nix;
  networkModule = import ./network;
  edgeModule = import ./edge;

  disksModule =
    if usePodModule then
      import ./pod.nix
    else if useIsoModule then
      import ./liveIso.nix
    else
      import ./preInstalled.nix;

  metalModule = import ./metal;

  baseModules = [
    usersModule
    disksModule
    nixModule
    normalizeModule
    networkModule
  ];

  nixosModules =
    baseModules
    ++ (optional useEdgeModule edgeModule)
    ++ (optional useRouterModule ./router)
    ++ (optional useIsoModule home-manager.nixosModules.default)
    ++ (optional useMetalModule metalModule);

  nixosArgs = {
    inherit
      kor
      world
      pkdjz
      horizon
      homeModule
      hob
      ;
    constants = import ./constants.nix;
  };

  evaluation = evalNixos {
    inherit useIsoModule;
    moduleArgs = nixosArgs;
    modules = nixosModules;
  };

  buildNixOSVM = evaluation.config.system.build.vm;
  buildNixOSIso = evaluation.config.system.build.isoImage;
  buildNixOS = evaluation.config.system.build.toplevel;

in
if useIsoModule then buildNixOSIso else buildNixOS
