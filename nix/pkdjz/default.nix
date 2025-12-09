hob:

let
  pkdjz = {
    buildNvimPlogin = {
      lambda = import ./buildNvimPlogin;
      mods = [
        "pkgs"
        "pkdjz"
      ];
    };

    home-manager = {
      lambda = import ./home-manager;
      mods = [
        "lib"
        "pkgs"
        "hob"
      ];
    };

    evalNixos = {
      lambda = import ./evalNixos;
      mods = [
        "lib"
        "pkgsSet"
      ];
      src = hob.nixpkgs;
    };

    crateOverrides = {
      lambda = import ./crateOverrides;
      mods = [
        "pkgs"
        "lib"
      ];
    };

    kynvyrt = {
      lambda = import ./kynvyrt;
      mods = [
        "pkgs"
        "world"
      ];
    };

    librem5-flash-image = {
      lambda = import ./librem5/flashImage.nix;
    };

    mach-nix = {
      lambda = import ./mach-nix;
    };

    mkEmacs = {
      lambda = import ./mkEmacs;
      mods = [
        "pkgsSet"
        "hob"
        "pkdjz"
      ];
      src = hob.emacs-overlay;
    };

    mfgtools = {
      lambda = import ./mfgtools;
    };

    nvimLuaPloginz = {
      lambda = import ./nvimPloginz/lua.nix;
      mods = [
        "hob"
        "pkdjz"
      ];
    };

    nvimPloginz = {
      lambda = import ./nvimPloginz;
      mods = [
        "hob"
        "pkdjz"
      ];
    };

    pkgsNvimPloginz = {
      lambda = import ./pkgsNvimPloginz;
      mods = [
        "pkgsSet"
        "lib"
        "pkdjz"
      ];
      src = hob.nixpkgs;
    };

    shen-bootstrap = {
      lambda = import ./shen/bootstrap.nix;
      src = hob.shen;
    };

    shen-ecl-bootstrap = {
      lambda = import ./shen/ecl.nix;
    };

    shenPrelude.lambda = import ./shen/prelude.nix;

    slynkPackages = {
      lambda = import ./slynkPackages;
    };

    nix = {
      lambda = import ./nix;
      mods = [
        "pkgs"
        "pkdjz"
      ];
    };

    obs-ndi = {
      mods = [
        "pkgsSet"
        "pkgs"
        "pkdjz"
      ];
      lambda = import ./obs-ndi;
    };

    vimPloginz = {
      lambda = import ./vimPloginz;
      mods = [
        "pkgs"
        "pkdjz"
        "hob"
      ];
    };
  };

  aliases = {
    shen = pkdjz.shen-ecl-bootstrap;
  };

  adHoc = (import ./adHoc.nix) hob;

in
adHoc // pkdjz // aliases
