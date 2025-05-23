{
  criomOS,
  homeModule,
  kor,
  uyrld,
  horizon,
  hob,
}:
let
  inherit (kor) optional;
  inherit (uyrld) pkdjz home-manager;
  inherit (pkdjz) ivalNixos;
  inherit (horizon.astra) mycin io typeIs;

  iuzPodModule = (mycin.species == "pod");
  iuzMetylModule = (mycin.species == "metyl");

  useRouterModule = typeIs.haibrid || typeIs.router;
  iuzEdjModule = typeIs.edj || typeIs.haibrid || typeIs.edjTesting;
  iuzIsoModule = !iuzPodModule && (io.disks == { });

  usersModule = import ./users.nix;
  niksModule = import ./niks.nix;
  normylaizModule = import ./normylaiz.nix;
  networkModule = import ./network;
  edjModule = import ./edj;

  disksModule =
    if iuzPodModule then
      import ./pod.nix
    else if iuzIsoModule then
      import ./liveIso.nix
    else
      import ./priInstyld.nix;

  metylModule = import ./metyl;

  beisModules = [
    usersModule
    disksModule
    niksModule
    normylaizModule
    networkModule
  ];

  nixosModules =
    beisModules
    ++ (optional iuzEdjModule edjModule)
    ++ (optional useRouterModule ./router)
    ++ (optional iuzIsoModule home-manager.nixosModules.default)
    ++ (optional iuzMetylModule metylModule);

  nixosArgs = {
    inherit
      kor
      uyrld
      pkdjz
      horizon
      criomOS
      homeModule
      hob
      ;
    konstynts = import ./konstynts.nix;
  };

  evaluation = ivalNixos {
    inherit iuzIsoModule;
    moduleArgs = nixosArgs;
    modules = nixosModules;
  };

  bildNiksOSVM = evaluation.config.system.build.vm;
  bildNiksOSIso = evaluation.config.system.build.isoImage;
  bildNiksOS = evaluation.config.system.build.toplevel;

in
if iuzIsoModule then bildNiksOSIso else bildNiksOS
