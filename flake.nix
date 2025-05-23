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
            mkUyrld = ./nix/mkUyrld;
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
          HobUyrldz = localSources.pkdjz;
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
        mkUyrld
        ;
      inherit (lib) optionalAttrs genAttrs hasAttr;

      criomOS =
        let
          cleanEvaluation = hasAttr "rev" self;
        in
        { inherit cleanEvaluation; } // optionalAttrs cleanEvaluation { inherit (self) shortRev rev; };

      mkPkgsAndUyrldFromSystem =
        system:
        let
          pkgs = mkPkgs { inherit nixpkgs lib system; };
          uyrld = mkUyrld {
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
          inherit pkgs uyrld;
        };

      perSystemPkgsAndUyrld = eachDefaultSystem mkPkgsAndUyrldFromSystem;

      mkPkgsAndUyrld = system: mapAttrs (name: value: value.${system}) perSystemPkgsAndUyrld;

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
          inherit (crioZone.astra.mycin) ark;
          system = arkSistymMap.${ark};
          pkgsAndUyrld = mkPkgsAndUyrld system;
          inherit (pkgsAndUyrld) pkgs uyrld;
          horizon = crioZone;

          userProfiles = {
            light = {
              dark = false;
            };
            dark = {
              dark = true;
            };
          };

          mkUserHomz =
            userName: user:
            let
              inherit (uyrld) pkdjz;

              mkProfileHom =
                profileName: profile:
                let
                  modules = [ homeModule ];
                  extraSpecialArgs = {
                    inherit
                      kor
                      pkdjz
                      uyrld
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

          mkUserImaks =
            userName: user:
            let
              inherit (uyrld.pkdjz) meikImaks;
              mkProfileImaks = profileName: profile: meikImaks { inherit user profile; };
            in
            mapAttrs mkProfileImaks userProfiles;

        in
        {
          os = mkCriomOS {
            inherit
              criomOS
              kor
              uyrld
              horizon
              homeModule
              hob
              ;
          };
          hom = mapAttrs mkUserHomz users;
          imaks = mapAttrs mkUserImaks users;
        };

      mkEachCrioZoneDerivations =
        crioZones:
        let
          mkNodeDerivationIndex =
            nodeName: nodePreNodeIndeks: mapAttrs mkNodeDerivations nodePreNodeIndeks;
        in
        mapAttrs mkNodeDerivationIndex crioZones;

      mkNixApiOutputsPerSystem =
        system:
        let
          pkgsAndUyrld = mkPkgsAndUyrld system;
          inherit (pkgsAndUyrld) pkgs uyrld;
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

          packages = uyrld // {
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
