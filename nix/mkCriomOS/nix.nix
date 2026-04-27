{
  lib,
  criomos-lib,
  pkdjz,
  pkgs,
  hob,
  horizon,
  world,
  constants,
  ...
}:
with builtins;
let
  inherit (lib)
    boolToString
    mapAttrsToList
    optionals
    optional
    optionalAttrs
    ;

  inherit (pkdjz) exportJSON;

  inherit (horizon.cluster.methods) trustedBuildPreCriomes;
  inherit (horizon) node;
  inherit (horizon.node.methods)
    builderConfigs
    cacheURLs
    dispatchersSshPreCriomes
    sizedAtLeast
    isBuilder
    isDispatcher
    isNixCache
    hasNixPreCriad
    ;

  inherit (constants.fileSystem.nix) preCriad;
  inherit (constants.network.nix) serve;

  optionalNixpkgsRef = optionalAttrs (hob.nixpkgs ? ref) { inherit (hob.nixpkgs) ref; };

  flakeEntriesOverrides = {
    lib = {
      owner = "nix-community";
      repo = "nixpkgs.lib";
    };

    nixpkgs = {
      owner = "criome";
      repo = "nixpkgs";
      inherit (hob.nixpkgs) rev;
    }
    // optionalNixpkgsRef;

    nixpkgs-master = {
      owner = "NixOS";
      repo = "nixpkgs";
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
        to = {
          repo = name;
          type = "github";
        } // value;
      };
    in
    mapAttrsToList mkFlakeEntry entriesMap;

  criomOSFlakeEntries = mkFlakeEntriesListFromSet flakeEntriesOverrides;

  nixOSFlakeEntries =
    let
      nixOSFlakeRegistry = criomos-lib.importJSON world.pkdjz.flake-registry;
    in
    nixOSFlakeRegistry.flakes;

  filterOutRegistry =
    entry:
    let
      flakeName = entry.from.id;
      flakeOverrideNames = attrNames flakeEntriesOverrides;
      entryIsOverridden = elem flakeName flakeOverrideNames;
    in
    !entryIsOverridden;

  filteredNixosFlakeEntries = filter filterOutRegistry nixOSFlakeEntries;

  nixFlakeRegistry = {
    flakes = criomOSFlakeEntries ++ filteredNixosFlakeEntries;
    version = 2;
  };

  nixFlakeRegistryJson = exportJSON "nixFlakeRegistry.json" nixFlakeRegistry;

in
{
  networking = {
    firewall = {
      allowedTCPPorts =
        optionals isNixCache [
          serve.ports.external
          80
        ]
        ++ optional (node.name == "prometheus") 11436;
    };
  };

  nix = {
    package = pkgs.nixVersions.latest;

    channel.enable = false;

    settings = {
      trusted-users = [
        "root"
        "@nixdev"
      ];

      allowed-users = [
        "@users"
        "nix-serve"
      ];

      build-cores = node.nbOfBuildCores;

      connect-timeout = 5;
      fallback = true;

      trusted-public-keys = trustedBuildPreCriomes;
      substituters = cacheURLs;
      trusted-binary-caches = cacheURLs;

      auto-optimise-store = true;

      # Builder fetches dep closures from cache.nixos.org itself
      # rather than streaming through the dispatcher.
      builders-use-substitutes = isDispatcher;
    };

    # Build receiver — gated on isBuilder. nix.sshServe creates a
    # restricted `nix-ssh` user (no shell, no PTY, only allowed
    # command is `nix-daemon --stdio`). The three flags below were
    # missing from the previous archive config — without them, build
    # dispatch silently fails:
    #   write = true     → lets clients upload .drv inputs
    #   trusted = true   → adds nix-ssh to trusted-users so the
    #                      daemon will actually *build* on its behalf
    #                      (not just substitute)
    #   protocol = ssh-ng → newer/efficient protocol (vs legacy ssh)
    # `keys` is filtered to dispatchers only (was exNodesSshPreCriomes,
    # which over-authorised every ex-node).
    sshServe = {
      enable = isBuilder;
      protocol = "ssh-ng";
      write = true;
      trusted = true;
      keys = dispatchersSshPreCriomes;
    };

    # Build dispatcher — gated on isDispatcher. buildMachines is
    # mapped from horizon's builderConfigs, with publicHostKey
    # populated from each builder's SSH host pubkey (added to
    # mkBuilder for this fix). Without publicHostKey the root
    # no-TTY daemon cannot answer the host-trust prompt.
    distributedBuilds = isDispatcher;
    buildMachines = map (b: {
      inherit (b) hostName sshUser sshKey supportedFeatures system systems maxJobs;
      protocol = "ssh-ng";
      speedFactor = 10;
      publicHostKey = b.publicHostKey;
    }) (optionals isDispatcher builderConfigs);

    # Lowest priorities
    daemonCPUSchedPolicy = "idle";
    daemonIOSchedPriority = 7;

    extraOptions = ''
      flake-registry = ${nixFlakeRegistryJson}
      experimental-features = nix-command flakes recursive-nix
      keep-derivations = ${boolToString sizedAtLeast.med}
      keep-outputs = ${boolToString sizedAtLeast.max}

      # !include <path>:  include without an error for missing file.
      !include nixTokens
    '';
  };

  # known_hosts entries for every builder this dispatcher will
  # connect to. Without these, root nix-daemon (no TTY) fails the
  # first-connection trust prompt and the build silently hangs.
  programs.ssh.knownHosts = lib.listToAttrs (map (b: {
    name = b.hostName;
    value.publicKey = b.publicHostKeyLine;
  }) (optionals isDispatcher builderConfigs));

  # nix-ssh user/group are managed by nix.sshServe — the old
  # nixBuilder user pattern is dropped. nix-serve user kept for
  # the binary-cache role (separate concern).
  users = {
    groups = {
      nixdev = { };
    }
    // (optionalAttrs isNixCache {
      nix-serve = {
        gid = 199;
      };
    });

    users = optionalAttrs isNixCache {
      nix-serve = {
        uid = 199;
        group = "nix-serve";
      };
    };
  };
}
