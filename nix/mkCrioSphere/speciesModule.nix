{
  kor,
  lib,
  config,
  preClusters,
  ...
}:
let
  inherit (builtins) attrNames attrValues;
  inherit (kor) archToSystemMap;
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

  magnytiud = [
    0
    1
    2
    3
  ];

  machineArchs = attrNames archToSystemMap;
  systems = attrValues archToSystemMap;

  bootloaders = [
    "uefi"
    "mbr"
    "uboot"
  ];
  keyboards = [
    "qwerty"
    "colemak"
  ];

  nodeSpecies = [
    "sentyr"
    "haibrid"
    "edj"
    "edjTesting"
    "mediaBroadcast"
    "router"
  ];

  metnodeNames = attrNames preClusters;

  preCriomeSubmodule = {
    options = {
      ssh = mkOption {
        type = str;
      };

      keygrip = mkOption {
        type = str;
      };
    };
  };

  komynUserOptions = {
    size = mkOption {
      type = enum magnytiud;
      default = 0;
    };

    species = mkOption {
      type = enum [
        "Niks"
        "Sema"
        "Onlimityd"
      ];
      default = "Sema";
    };

    style = mkOption {
      type = enum [
        "vim"
        "emacs"
      ];
      default = "emacs";
    };

    preCriomes = mkOption {
      type = attrsOf (submodule preCriomeSubmodule);
    };

    keyboard = mkOption {
      type = enum [
        "colemak"
        "qwerty"
      ];
      default = "colemak";
    };

    githubId = mkOption {
      type = nullOr str;
      default = null;
    };

  };

  machineSpecies = submodule {
    options = {
      species = mkOption {
        type = enum [
          "metal"
          "pod"
        ];
        default = "metal";
      };

      arch = mkOption {
        type = nullOr (enum machineArchs);
        default = null;
      };

      cores = mkOption {
        type = int;
        default = 1;
      };

      model = mkOption {
        type = nullOr str;
        default = null;
      };

      motherBoard = mkOption {
        type = nullOr (enum motherBoardSpeciesNames);
        default = null;
      };

      superNode = mkOption {
        type = nullOr str;
        default = null;
      };

      superUser = mkOption {
        type = nullOr str;
        default = null;
      };
    };
  };

  IoOptions = {
    keyboard = mkOption {
      type = enum keyboards;
      default = "colemak";
    };

    bootloader = mkOption {
      type = enum bootloaders;
      default = "uefi";
    };

    disks = mkOption {
      type = attrs;
      default = { };
    };

    swapDevices = mkOption {
      type = listOf attrs;
      default = [ ];
    };
  };

  motherBoardSpeciesNames = [ "ondyfaind" ];

in
{
  options = {
    species = mkOption {
      type = attrs;
      default = { };
    };
  };

  config.species = {
    inherit
      komynUserOptions
      IoOptions
      machineSpecies
      keyboards
      bootloaders
      magnytiud
      metnodeNames
      nodeSpecies
      systems
      ;
  };

}
