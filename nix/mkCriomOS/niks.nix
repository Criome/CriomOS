{
  kor,
  lib,
  pkgs,
  hob,
  horizon,
  uyrld,
  konstynts,
  config,
  criomOS,
  ...
}:
with builtins;
let
  inherit (lib) boolToString mapAttrsToList importJSON;
  inherit (kor)
    optionals
    mkIf
    optional
    eksportJSON
    optionalAttrs
    ;

  inherit (horizon.cluster.methods) trostydBildPreCriomes;
  inherit (horizon) astra;
  inherit (horizon.astra.methods)
    bildyrKonfigz
    kacURLz
    dispatcyrzSshKiz
    exNodesSshPreCriomes
    sizedAtLeast
    isBuilder
    isNixCache
    isDispatcher
    izNiksCriodaizd
    nixCacheDomain
    ;

  inherit (konstynts.fileSystem.niks) preCriad;
  inherit (konstynts.network.niks) serve;

  jsonHorizonFail = eksportJSON "horizon.json" horizon;

  flakeEntriesOverrides =
    {
      hob = {
        owner = "sajban";
        ref = "autumnCleaning";
      };

      lib = {
        owner = "nix-community";
        repo = "nixpkgs.lib";
      };

      # TODO - broken
      nixpkgs = {
        owner = "NixOS";
        repo = "nixpkgs";
        inherit (hob.nixpkgs) rev;
      } // optionalAttrs (hob.nixpkgs ? ref) { inherit (hob.nixpkgs) ref; };

      nixpkgs-master = {
        owner = "NixOS";
        repo = "nixpkgs";
      };

      xdg-desktop-portal-hyprland = {
        owner = "hyprwm";
      };

    }
    // optionalAttrs criomOS.cleanEvaluation {
      criomOS = {
        owner = "sajban";
        inherit (criomOS) rev;
      };
    };

  mkFlakeEntriesListFromSet =
    entriesMap:
    let
      mkFlakeEntry = name: value: {
        from = {
          id = name;
          type = "indirect";
        };
        to = (
          {
            repo = name;
            type = "github";
          }
          // value
        );
      };
    in
    mapAttrsToList mkFlakeEntry entriesMap;

  criomOSFlakeEntries = mkFlakeEntriesListFromSet flakeEntriesOverrides;

  nixOSFlakeEntries =
    let
      nixOSFlakeRegistry = importJSON uyrld.pkdjz.flake-registry;
    in
    nixOSFlakeRegistry.flakes;

  filterOutRegistry =
    entry:
    let
      flakeName = entry.from.id;
      flakeOverrideNames = attrNames flakeEntriesOverrides;
      entryIsOverridden = elem flakeName flakeOverrideNames;
    in
    !(entryIsOverridden);

  filteredNixosFlakeEntries = filter filterOutRegistry nixOSFlakeEntries;

  nixFlakeRegistry = {
    flakes = criomOSFlakeEntries ++ filteredNixosFlakeEntries;
    version = 2;
  };

  nixFlakeRegistryJson = eksportJSON "nixFlakeRegistry.json" nixFlakeRegistry;

in
{
  environment.etc."horizon.json" = {
    source = jsonHorizonFail;
    mode = "0600";
  };

  networking = {
    firewall = {
      allowedTCPPorts = optionals isNixCache [
        serve.ports.external
        80
      ];
    };
  };

  nix = {
    package = pkgs.nixVersions.latest;

    channel.enable = false;

    settings = {
      trusted-users = [
        "root"
        "@nixdev"
      ] ++ optional isBuilder "nixBuilder";

      allowed-users = [
        "@users"
        "nix-serve"
      ];

      build-cores = astra.nbOfBildKorz;

      connect-timeout = 5;
      fallback = true;

      trusted-public-keys = trostydBildPreCriomes;
      substituters = kacURLz;
      trusted-binary-caches = kacURLz;

      auto-optimise-store = true;
    };

    sshServe.enable = true;
    sshServe.keys = exNodesSshPreCriomes;

    # Lowest priorities
    daemonCPUSchedPolicy = "idle";
    daemonIOSchedPriority = 7;

    extraOptions = ''
      flake-registry = ${nixFlakeRegistryJson}
      experimental-features = nix-command flakes recursive-nix
      secret-key-files = ${preCriad}
      keep-derivations = ${boolToString sizedAtLeast.med}
      keep-outputs = ${boolToString sizedAtLeast.max}
      !include nixTokens
    '';

    distributedBuilds = isDispatcher;
    buildMachines = optionals isDispatcher bildyrKonfigz;

  };

  users = {
    groups =
      {
        nixdev = { };
      }
      // (optionalAttrs isBuilder { nixBuilder = { }; })
      // (optionalAttrs isNixCache {
        nix-serve = {
          gid = 199;
        };
      });

    users =
      (optionalAttrs isNixCache {
        nix-serve = {
          uid = 199;
          group = "nix-serve";
        };
      })
      // (optionalAttrs isBuilder {
        nixBuilder = {
          isNormalUser = true;
          useDefaultShell = true;
          openssh.authorizedKeys.keys = dispatcyrzSshKiz;
        };
      });
  };
}
