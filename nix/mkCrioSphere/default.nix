{
  kor,
  lib,
  uncheckedCrioSphereProposal,
}:
let
  inherit (lib) evalModules;

  preClusters = uncheckedCrioSphereProposal;

  argumentsModule = {
    config = {
      _module.args = {
        inherit kor lib preClusters;
      };
    };
  };

  clustersModule = import ./clustersModule.nix;
  speciesModule = import ./speciesModule.nix;

  evaluation = evalModules {
    modules = [
      argumentsModule
      clustersModule
      speciesModule
    ];
  };

in
{
  inherit (evaluation.config) species;
  datom = evaluation.config.Clusters;
}
