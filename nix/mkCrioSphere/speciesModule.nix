{
  kor,
  lib,
  config,
  preClusters,
  ...
}:
let
  inherit (builtins) attrNames attrValues;
  inherit (kor) arkSistymMap;
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

  machineArkz = attrNames arkSistymMap;
  sistymz = attrValues arkSistymMap;

  butlodyrz = [
    "uefi"
    "mbr"
    "uboot"
  ];
  kibordz = [
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
    saiz = mkOption {
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

    stail = mkOption {
      type = enum [
        "vim"
        "emacs"
      ];
      default = "emacs";
    };

    preCriomes = mkOption {
      type = attrsOf (submodule preCriomeSubmodule);
    };

    kibord = mkOption {
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
          "metyl"
          "pod"
        ];
        default = "metyl";
      };

      ark = mkOption {
        type = nullOr (enum machineArkz);
        default = null;
      };

      korz = mkOption {
        type = int;
        default = 1;
      };

      modyl = mkOption {
        type = nullOr str;
        default = null;
      };

      mothyrBord = mkOption {
        type = nullOr (enum mothyrBordSpeciesNames);
        default = null;
      };

      ubyrNode = mkOption {
        type = nullOr str;
        default = null;
      };

      ubyrUser = mkOption {
        type = nullOr str;
        default = null;
      };
    };
  };

  IoOptions = {
    kibord = mkOption {
      type = enum kibordz;
      default = "colemak";
    };

    butlodyr = mkOption {
      type = enum butlodyrz;
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

  mothyrBordSpeciesNames = [ "ondyfaind" ];

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
      kibordz
      butlodyrz
      magnytiud
      metnodeNames
      nodeSpecies
      sistymz
      ;
  };

}
