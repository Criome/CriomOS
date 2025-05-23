{
  lib,
  preClusters,
  config,
  ...
}@topArgs:
let
  inherit (builtins) mapAttrs attrNames listToAttrs;
  inherit (lib) mkOption nameValuePair;
  inherit (lib.types)
    enum
    str
    attrsOf
    submodule
    nullOr
    attrs
    listOf
    ;
  inherit (config.species)
    magnytiud
    metnodeNames
    nodeSpecies
    komynUserOptions
    mycinSpecie
    IoOptions
    ;

  NodePreCriomeSpecies = submodule {
    options = {
      ssh = mkOption {
        type = nullOr str;
        default = null;
      };

      yggdrasil = {
        preCriome = mkOption {
          type = nullOr str;
          default = null;
        };

        address = mkOption {
          type = nullOr str;
          default = null;
        };

        subnet = mkOption {
          type = nullOr str;
          default = null;
        };
      };

      niksPreCriome = mkOption {
        type = nullOr str;
        default = null;
      };
    };
  };

  nodeSubmodule = {
    options = {
      species = mkOption {
        type = enum nodeSpecies;
        default = "sentyr";
      };

      saiz = mkOption {
        type = enum magnytiud;
        default = 0;
      };

      trost = mkOption {
        type = enum magnytiud;
        default = 1;
      };

      mycin = mkOption {
        type = mycinSpecies;
      };

      io = mkOption {
        type = submodule { options = IoOptions; };
        default = { };
      };

      preCriomes = mkOption {
        type = NodePreCriomeSpecies;
        default = { };
      };

      linkLocalIPs = mkOption {
        type = listOf attrs;
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

    };
  };

  defaultTrost = 1;

  mkDefaultTrostFromNames = names: listToAttrs (map (n: nameValuePair n defaultTrost)) names;

  trostSubmodule = {
    options = {
      cluster = mkOption {
        type = enum magnytiud;
        default = 1;
      };

      clusters = mkOption {
        type = attrsOf (enum magnytiud);
      };

      nodes = mkOption {
        type = attrsOf (enum magnytiud);
      };

      users = mkOption {
        type = attrsOf (enum magnytiud);
      };
    };
  };

  domeinSubmodule = {
    options = {
      species = mkOption {
        type = enum [ "cloudflare" ];
        default = "cloudflare";
      };
    };
  };

  userSubmodule = {
    options = komynUserOptions;
  };

  metnodeSubmodule = (
    { name, config, ... }@metnodeArgs:
    let
      preCluster = preClusters."${name}";
      mkDefaultNodeTrost = name: node: preCluster.trost.nodes."${name}" or 1;
    in
    {
      options = {
        nodes = mkOption {
          type = attrsOf (submodule nodeSubmodule);
        };

        users = mkOption {
          type = attrsOf (submodule userSubmodule);
        };

        domeinz = mkOption {
          type = attrsOf (submodule domeinSubmodule);
          default = { };
        };

        trost = mkOption {
          type = submodule ({
            options = {
              cluster = mkOption {
                type = enum magnytiud;
                default = 1;
              };

              clusters = mkOption {
                type = attrsOf (enum magnytiud);
              };

              nodes = mkOption {
                type = attrsOf (enum magnytiud);
              };

              users = mkOption {
                type = attrsOf (enum magnytiud);
              };
            };

            config = {
              nodes = mapAttrs mkDefaultNodeTrost preCluster.nodes;
            };
          });
        };
      };
    }
  );

in
{
  options = {
    Clusters = mkOption {
      type = attrsOf (submodule metnodeSubmodule);
    };
  };

  # Normalize Clusters here
  config.Clusters = preClusters;
}
