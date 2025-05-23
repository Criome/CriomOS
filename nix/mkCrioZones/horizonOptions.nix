{
  config,
  lib,
  clustersSpecies,
  ...
}:
let
  inherit (lib) mkOption;
  inherit (lib.types)
    enum
    str
    attrsOf
    submodule
    nullOr
    bool
    int
    listOf
    attrs
    ;

  inherit (clustersSpecies)
    metnodeNames
    nodeSpecies
    magnytiud
    sistymz
    komynUserOptions
    machineSpecies
    IoOptions
    ;

  nodeOptions = {
    name = mkOption {
      type = str;
    };

    species = mkOption {
      type = enum nodeSpecies;
      default = "sentyr";
    };

    trust = mkOption {
      type = enum magnytiud;
    };

    criomOSName = mkOption {
      type = str;
    };

    sistym = mkOption {
      type = enum sistymz;
    };

    nbOfBuildCores = mkOption {
      type = int;
      default = 1;
    };

    size = mkOption {
      type = enum magnytiud;
    };

    machine = mkOption {
      type = machineSpecies;
    };

    yggPreCriome = mkOption {
      type = nullOr str;
      default = null;
    };

    yggAddress = mkOption {
      type = nullOr str;
      default = null;
    };

    yggSubnet = mkOption {
      type = nullOr str;
      default = null;
    };

    ssh = mkOption {
      type = nullOr str;
      default = null;
    };

    nixPreCriome = mkOption {
      type = nullOr str;
      default = null;
    };

    linkLocalIPs = mkOption {
      type = listOf str;
      default = [ ];
    };

    nodeIp = mkOption {
      type = nullOr str;
      default = null;
    };

    wireguardPreCriome = mkOption {
      type = nullOr str;
      default = null;
    };

    wireguardUntrustedProxies = mkOption {
      type = listOf attrs;
      default = [ ];
    };

    methods = mkOption {
      type = attrs;
      default = { };
    };

    typeIs = mkOption {
      type = attrs;
      default = { };
    };
  };

  clusterSubmodule = {
    options = {
      name = mkOption {
        type = enum metnodeNames;
      };

      methods = mkOption {
        type = attrs;
        default = { };
      };
    };
  };

  nodeOptions = nodeOptions // {
    io = mkOption {
      type = submodule { options = IoOptions; };
      default = { };
    };
  };

  userSubmodule = {
    options = komynUserOptions // {
      name = mkOption {
        type = str;
      };

      trust = mkOption {
        type = enum magnytiud;
      };

      methods = mkOption {
        type = attrs;
        default = { };
      };
    };
  };

  horizonOptions = {
    options = {
      cluster = mkOption {
        type = submodule clusterSubmodule;
      };

      node = mkOption {
        type = submodule { options = nodeOptions; };
      };

      exNodes = mkOption {
        type = attrsOf (submodule {
          options = nodeOptions;
        });
      };

      users = mkOption {
        type = attrsOf (submodule userSubmodule);
      };

      methods = mkOption {
        type = attrs;
        default = { };
      };
    };
  };

in
{
  options = {
    horizon = mkOption {
      type = submodule horizonOptions;
    };

    nodeName = mkOption {
      type = str;
    };

    clusterName = mkOption {
      type = str;
    };

  };

}
