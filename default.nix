let
  npins = import ./npins;
  flake-inputs = import npins.flake-inputs;
  fallbackInputs = flake-inputs { root = ./.; };
in

{
  nixpkgs ? fallbackInputs.nixpkgs,
  criomos-lib ? (import ./criomos-lib.nix),
  ...
}@inputs:

let
  lib = nixpkgs.lib // criomos-lib;

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
      pkgs = local.mkPkgs { inherit nixpkgs lib; localSystem = { inherit system; }; };
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

  inherit (builtins)
    filter
    mapAttrs
    match
    replaceStrings
    toJSON
    ;

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

  sanitizeDeployAddress =
    address:
    if address == null || address == "" then
      null
    else
      let
        parts = builtins.split "/" address;
        cleaned = builtins.head parts;
      in
      if cleaned == "" then null else cleaned;

  mkRemoteTargets =
    node:
    let
      yggAddress = sanitizeDeployAddress node.yggAddress;
    in
    filter (target: target.target != null && target.target != "") [
      {
        kind = "ygg";
        target = yggAddress;
      }
    ];

  mkDeployManifest =
    clusterName: nodeName: node:
    builtins.toFile "criomos-deploy-${clusterName}-${nodeName}.json" (
      toJSON {
        schema = "criomos-deploy-manifest-v1";
        cluster = clusterName;
        nodes = {
          ${nodeName} = {
            nodeName = nodeName;
            buildAttribute = ".#crioZones.${clusterName}.${nodeName}.os";
            expectedHostname = node.name;
            remoteTargets = mkRemoteTargets node;
          };
        };
      }
    );

  mkNodeDerivations =
    preNodeName: crioZone:
    let
      inherit (crioZone) users;
      inherit (crioZone.node) system;
      pkgsAndWorld = mkPkgsAndWorldFromSystem system;
      inherit (pkgsAndWorld) pkgs world;
      horizon = crioZone;
      mkUserHome =
        userName: user:
        let
          inherit (world) pkdjz;
          modules = homeModules ++ [ inputs.niri-flake.homeModules.config ];
          extraSpecialArgs = {
            inherit
              criomos-lib
              pkdjz
              world
              horizon
              user
              inputs
              ;
          };
          evalHomeManager = inputs.home-manager.lib.homeManagerConfiguration;
          evaluation = evalHomeManager { inherit modules extraSpecialArgs pkgs; };
        in
        evaluation.config.home.activationPackage;

      mkUserEmacs =
        userName: user:
        let
          inherit (world.pkdjz) mkEmacs;
        in
        mkEmacs { inherit user; };

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

      criosBuild = mkCriomOS ({ _withUsers = false; } // commonArgs);
      criosBuildFull = mkCriomOS ({ _withUsers = true; } // commonArgs);

    in
    {
      os = criosBuild.os;
      fullOs = criosBuildFull.os;
      vm = criosBuild.vm;
      home = mapAttrs mkUserHome users;
      emacs = mapAttrs mkUserEmacs users;
      deployManifest = mkDeployManifest horizon.cluster.name horizon.node.name horizon.node;
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
        tests = {
          pki-bootstrap = import ./nix/tests/pki-bootstrap.nix { inherit pkgs; };
        };
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
