let
  npins = import ./npins;
  flake-inputs = import npins.flake-inputs;
  fallbackInputs = flake-inputs { root = ./.; };
in

{
  nixpkgs ? fallbackInputs.nixpkgs,
  lib ? fallbackInputs.lib,
  criomos-lib ? (import ./criomos-lib.nix),
  ...
}@inputs:

let
  mkCriomOS = import ./nix/mkCriomOS;

  local = mapAttrs (_: import) {
    mkPkgs = ./nix/mkPkgs;
    mkWorld = ./nix/mkWorld;
    mkCrioSphere = ./nix/mkCrioSphere;
    mkCrioZones = ./nix/mkCrioZones;
    pkdjz = ./nix/pkdjz;
    criomOSHomeModule = ./nix/homeModule;
    nodeNames = ./nodeNames.nix;
    files = ./nix/files; # TODO: use?
  };

  hob =
    let
      hobInputs = removeAttrs inputs local.nodeNames;
      adHocHobSpokes = {
        inherit (local) mkWebpage;
        pkdjz.HobWorlds = local.pkdjz;
      };
    in
    hobInputs // adHocHobSpokes;

  homeModules = [
    inputs.stylix.homeModules.stylix
    local.criomOSHomeModule
  ];

  mkPkgsAndWorldFromSystem =
    system:
    let
      pkgs = local.mkPkgs { inherit nixpkgs lib system; };
    in
    {
      inherit pkgs;
      world = local.mkWorld {
        inherit
          lib
          pkgs
          system
          criomos-lib
          hob
          ;
      };
    };

  inherit (builtins) mapAttrs;

  crioSphereProposalFromName =
    name:
    let
      subCriomeConfig = inputs."${name}".NodeProposal or { };
      explicitNodes = subCriomeConfig.nodes or { };
      implicitNodes = import ./implicitNodes.nix;
      allNodes = explicitNodes // implicitNodes;
    in
    subCriomeConfig // { nodes = allNodes; };

  uncheckedCrioSphereProposal = lib.genAttrs local.nodeNames crioSphereProposalFromName;

  mkNodeDerivations =
    preNodeName: crioZone:
    let
      inherit (crioZone) users;
      inherit (crioZone.node) system;
      pkgsAndWorld = mkPkgsAndWorldFromSystem system;
      inherit (pkgsAndWorld) pkgs world;
      horizon = crioZone;
      litellmProxy = pkgs.callPackage ./nix/litellm-proxy.nix { };

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

          mkProfileHome =
            profileName: profile:
            let
              modules = homeModules;
              extraSpecialArgs = {
                inherit
                  criomos-lib
                  pkdjz
                  world
                  horizon
                  user
                  profile
                  litellmProxy
                  ;
              };
              evalHomeManager = inputs.home-manager.lib.homeManagerConfiguration;
              evaluation = evalHomeManager { inherit modules extraSpecialArgs pkgs; };
            in
            evaluation.config.home.activationPackage;

        in
        mapAttrs mkProfileHome userProfiles;

      mkUserEmacs =
        userName: user:
        let
          inherit (world.pkdjz) mkEmacs;
          mkProfileEmacs = profileName: profile: mkEmacs { inherit user profile; };
        in
        mapAttrs mkProfileEmacs userProfiles;

      commonArgs = {
        inherit
          lib
          criomos-lib
          world
          horizon
          hob
          homeModules
          inputs
          ;
      };

    in
    {
      os = mkCriomOS ({ _withUsers = false; } // commonArgs);
      fullOs = mkCriomOS ({ _withUsers = true; } // commonArgs);
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

      allMeinHobOutputs = linkFarm "hob" (lib.mapAttrsToList mkSpokFarmEntry hobOutputs);

    in
    {
      packages = world.pkdjz // {
        inherit pkgs;
        hob = hobOutputs;
        fullHob = allMeinHobOutputs;
      };
    };

  # TODO: Consider using a 'system' input
  perSystemAllOutputs = inputs.flake-utils.lib.eachDefaultSystem mkNixApiOutputsPerSystem;

  proposedCrioSphere = local.mkCrioSphere { inherit uncheckedCrioSphereProposal lib; };
  proposedCrioZones = local.mkCrioZones { inherit lib criomos-lib proposedCrioSphere; };

in
perSystemAllOutputs
// {
  crioZones = mkEachCrioZoneDerivations proposedCrioZones;
}
