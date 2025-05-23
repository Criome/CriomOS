{
  criomOS,
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

  useRouterModule = typeIs.haibrid || typeIs.router;
  useEdjModule = typeIs.edj || typeIs.haibrid || typeIs.edjTesting;
  useIsoModule = !usePodModule && (io.disks == { });

  usersModule = import ./users.nix;
  nixModule = import ./nix.nix;
  normalizeModule = import ./normalize.nix;
  networkModule = import ./network;
  edjModule = import ./edj;

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
    ++ (optional useEdjModule edjModule)
    ++ (optional useRouterModule ./router)
    ++ (optional useIsoModule home-manager.nixosModules.default)
    ++ (optional useMetalModule metalModule);

  nixosArgs = {
    inherit
      kor
      world
      pkdjz
      horizon
      criomOS
      homeModule
      hob
      ;
    konstynts = import ./konstynts.nix;
  };

  evaluation = evalNixos {
    inherit useIsoModule;
    moduleArgs = nixosArgs;
    modules = nixosModules;
  };

  bildNiksOSVM = evaluation.config.system.build.vm;
  bildNiksOSIso = evaluation.config.system.build.isoImage;
  bildNiksOS = evaluation.config.system.build.toplevel;

in
if useIsoModule then bildNiksOSIso else bildNiksOS
