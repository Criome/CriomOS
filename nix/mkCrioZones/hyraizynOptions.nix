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
    mycinSpecies
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

    trost = mkOption {
      type = enum magnytiud;
    };

    criomOSName = mkOption {
      type = str;
    };

    sistym = mkOption {
      type = enum sistymz;
    };

    nbOfBildKorz = mkOption {
      type = int;
      default = 1;
    };

    saiz = mkOption {
      type = enum magnytiud;
    };

    mycin = mkOption {
      type = mycinSpecies;
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

    niksPreCriome = mkOption {
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

  astraOptions = nodeOptions // {
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

      trost = mkOption {
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

      astra = mkOption {
        type = submodule { options = astraOptions; };
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

    astraName = mkOption {
      type = str;
    };

    clusterName = mkOption {
      type = str;
    };

  };

}
