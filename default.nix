{
  inputs ? (import ./mkInputs.nix),
}:
let
  inherit (inputs) nixpkgs lib;

  localSources =
    let
      importInput = name: value: import value;
      modulePaths = {
        kor = ./nix/kor;
        mkPkgs = ./nix/mkPkgs;
        mkWorld = ./nix/mkWorld;
        mkCrioSphere = ./nix/mkCrioSphere;
        mkCrioZones = ./nix/mkCrioZones;
        mkCriomOS = ./nix/mkCriomOS;
        pkdjz = ./nix/pkdjz;
        homeModule = ./nix/homeModule;
        nodeNames = ./nodeNames.nix;
        files = ./nix/files; # TODO: use?
      };
    in
    mapAttrs importInput modulePaths;

  hob =
    let
      hobInputs = removeAttrs inputs nodeNames;
      adHocHobSpokes = {
        inherit (localSources) mkWebpage;
        pkdjz.HobWorlds = localSources.pkdjz;
      };
    in
    hobInputs // adHocHobSpokes;

  inherit (localSources)
    kor
    nodeNames
    mkPkgs
    homeModule
    mkCriomOS
    mkWorld
    ;

  mkPkgsAndWorldFromSystem =
    system:
    let
      pkgs = mkPkgs { inherit nixpkgs lib system; };
    in
    {
      inherit pkgs;
      world = mkWorld {
        inherit
          lib
          pkgs
          system
          hob
          localSources
          ;
      };
    };

  inherit (builtins) mapAttrs;
  inherit (kor) archToSystemMap;

  generateCrioSphereProposalFromName =
    name:
    let
      subCriomeConfig = inputs."${name}".NodeProposal or { };
      explicitNodes = subCriomeConfig.nodes or { };
      implicitNodes = import ./implicitNodes.nix;
      allNodes = explicitNodes // implicitNodes;
    in
    subCriomeConfig // { nodes = allNodes; };

  uncheckedCrioSphereProposal = lib.genAttrs nodeNames generateCrioSphereProposalFromName;

  mkNodeDerivations =
    preNodeName: crioZone:
    let
      inherit (crioZone) users;
      inherit (crioZone.node.machine) arch;
      system = archToSystemMap.${arch};
      pkgsAndWorld = mkPkgsAndWorldFromSystem system;
      inherit (pkgsAndWorld) pkgs world;
      horizon = crioZone;

      userProfiles = {
        light = {
          dark = false;
        };
        dark = {
          dark = true;
        };
      };

      mkUserHomes =
        userName: user:
        let
          inherit (world) pkdjz;

          mkProfileHom =
            profileName: profile:
            let
              modules = [ homeModule ];
              extraSpecialArgs = {
                inherit
                  kor
                  pkdjz
                  world
                  horizon
                  user
                  profile
                  ;
              };
              evalHomeManager = hob.home-manager.lib.homeManagerConfiguration;
              evaluation = evalHomeManager { inherit modules extraSpecialArgs pkgs; };
            in
            evaluation.config.home.activationPackage;
        in
        mapAttrs mkProfileHom userProfiles;

      mkUserEmacs =
        userName: user:
        let
          inherit (world.pkdjz) mkEmacs;
          mkProfileEmacs = profileName: profile: mkEmacs { inherit user profile; };
        in
        mapAttrs mkProfileEmacs userProfiles;

    in
    {
      os = mkCriomOS {
        inherit
          kor
          world
          horizon
          homeModule
          hob
          ;
      };
      hom = mapAttrs mkUserHomes users;
      emacs = mapAttrs mkUserEmacs users;
    };

  mkEachCrioZoneDerivations =
    crioZones:
    let
      mkNodeDerivationIndex = nodeName: nodePreNodeIndeks: mapAttrs mkNodeDerivations nodePreNodeIndeks;
    in
    mapAttrs mkNodeDerivationIndex crioZones;

  mkNixApiOutputsPerSystem =
    system:
    let
      pkgsAndWorld = mkPkgsAndWorldFromSystem system;
      inherit (pkgsAndWorld) pkgs world;
      inherit (pkgs) symlinkJoin linkFarm;

      mkHobOutput =
        name: src:
        symlinkJoin {
          inherit name;
          paths = [ src.outPath ];
        };

      hobOutputs = mapAttrs mkHobOutput hob;

      mkSpokFarmEntry = name: spok: {
        inherit name;
        path = spok.outPath;
      };

      allMeinHobOutputs = linkFarm "hob" (kor.mapAttrsToList mkSpokFarmEntry hobOutputs);

    in
    {
      packages = world // {
        inherit pkgs;
        hob = hobOutputs;
        fullHob = allMeinHobOutputs;
      };
    };

  perSystemAllOutputs = inputs.flake-utils.lib.eachDefaultSystem mkNixApiOutputsPerSystem;

  proposedCrioSphere = localSources.mkCrioSphere { inherit uncheckedCrioSphereProposal kor lib; };
  proposedCrioZones = localSources.mkCrioZones { inherit kor lib proposedCrioSphere; };

in
perSystemAllOutputs
// {
  crioZones = mkEachCrioZoneDerivations proposedCrioZones;
}
