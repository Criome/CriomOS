{
  description = "CriomOS";

  inputs = {
    hob.url = "github:criome/hob/testing";
    nixpkgs.url = "github:criome/nixpkgs/testing";

    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";

    # Todo - binary cache
    attic.url = "github:zhaofengli/attic";

    maisiliym.url = "github:LiGoldragon/maisiliym";
    goldragon.url = "github:LiGoldragon/goldragon";
    seahawk.url = "github:criome/seahawk";
  };

  outputs =
    inputs@{ self, nixpkgs, ... }:
    let
      localSources =
        let
          importInput = name: value: import value;
          modulePaths = {
            kor = ./nix/kor;
            mkPkgs = ./nix/mkPkgs;
            mkDatom = ./nix/mkDatom;
            mkWorld = ./nix/mkWorld;
            mkCrioSphere = ./nix/mkCrioSphere;
            mkCrioZones = ./nix/mkCrioZones;
            mkCriomOS = ./nix/mkCriomOS;
            pkdjz = ./nix/pkdjz;
            homeModule = ./nix/homeModule;
            nodeNames = ./nodeNames.nix;
            tests = ./nix/tests;
            files = ./nix/files;
          };
        in
        mapAttrs importInput modulePaths;

      localHobSources = {
        inherit nixpkgs;
        inherit (inputs) rust-overlay;
        inherit (localSources) mkWebpage;
        pkdjz = {
          HobWorlds = localSources.pkdjz;
        };
      };

      hob = inputs.hob.value // localHobSources;

      inherit (hob) flake-utils lib;
      inherit (localSources)
        kor
        nodeNames
        mkPkgs
        homeModule
        mkCriomOS
        mkWorld
        ;
      inherit (lib) optionalAttrs genAttrs hasAttr;

      criomOS =
        let
          cleanEvaluation = hasAttr "rev" self;
        in
        { inherit cleanEvaluation; } // optionalAttrs cleanEvaluation { inherit (self) shortRev rev; };

      mkPkgsAndWorldFromSystem =
        system:
        let
          pkgs = mkPkgs { inherit nixpkgs lib system; };
          world = mkWorld {
            inherit
              lib
              pkgs
              system
              hob
              localSources
              ;
          };
        in
        {
          inherit pkgs world;
        };

      perSystemPkgsAndWorld = eachDefaultSystem mkPkgsAndWorldFromSystem;

      mkPkgsAndWorld = system: mapAttrs (name: value: value.${system}) perSystemPkgsAndWorld;

      mkDatom = import inputs.mkDatom { inherit kor lib; };

      inherit (builtins) mapAttrs;
      inherit (kor) arkSistymMap;
      inherit (flake-utils.lib) eachDefaultSystem;

      generateCrioSphereProposalFromName =
        name:
        let
          subCriomeConfig = inputs."${name}".NodeProposal or { };
          explicitNodes = subCriomeConfig.nodes or { };
          implicitNodes = import ./implicitNodes.nix;
          allNodes = explicitNodes // implicitNodes;
        in
        subCriomeConfig // { nodes = allNodes; };

      uncheckedCrioSphereProposal = genAttrs nodeNames generateCrioSphereProposalFromName;

      mkNodeDerivations =
        preNodeName: crioZone:
        let
          inherit (crioZone) users;
          inherit (crioZone.astra.machine) ark;
          system = arkSistymMap.${ark};
          pkgsAndWorld = mkPkgsAndWorld system;
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
              criomOS
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
          pkgsAndWorld = mkPkgsAndWorld system;
          inherit (pkgsAndWorld) pkgs world;
          inherit (pkgs) symlinkJoin linkFarm;

          devShell = pkgs.mkShell {
            # TODO
          };

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

          packages = world // {
            inherit pkgs;
            hob = hobOutputs;
            fullHob = allMeinHobOutputs;
          };

          tests = import inputs.tests { inherit lib mkDatom; };

        in
        {
          inherit tests packages devShell;
        };

      perSystemAllOutputs = eachDefaultSystem mkNixApiOutputsPerSystem;

      proposedCrioSphere = localSources.mkCrioSphere { inherit uncheckedCrioSphereProposal kor lib; };
      proposedCrioZones = localSources.mkCrioZones { inherit kor lib proposedCrioSphere; };

    in
    perSystemAllOutputs
    // {
      crioZones = mkEachCrioZoneDerivations proposedCrioZones;
    };
}
