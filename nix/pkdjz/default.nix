hob:

let
  pkdjz = {
    beaker = {
      lamdy = import ./beaker;
      self = null;
    };

    bildNvimPlogin = {
      lamdy = import ./bildNvimPlogin;
      modz = [
        "pkgs"
        "pkdjz"
      ];
      self = null;
    };

    home-manager = {
      lamdy = import ./home-manager;
      modz = [
        "lib"
        "pkgs"
        "hob"
      ];
    };

    evalNixos = {
      lamdy = import ./evalNixos;
      modz = [
        "lib"
        "pkgsSet"
      ];
      self = hob.nixpkgs;
    };

    kreitOvyraidz = {
      lamdy = import ./kreitOvyraidz;
      modz = [
        "pkgs"
        "lib"
      ];
      self = null;
    };

    kynvyrt = {
      lamdy = import ./kynvyrt;
      modz = [
        "pkgs"
        "world"
      ];
      self = null;
    };

    lib = {
      lamdy = import ./lib;
      modz = [ ];
      self = hob.nixpkgs;
    };

    librem5-flash-image = {
      lamdy = import ./librem5/flashImage.nix;
    };

    mach-nix = {
      lamdy = import ./mach-nix;
    };

    mkEmacs = {
      lamdy = import ./mkEmacs;
      modz = [
        "pkgsSet"
        "hob"
        "pkdjz"
      ];
      self = hob.emacs-overlay;
    };

    mfgtools = {
      lamdy = import ./mfgtools;
    };

    nvimLuaPloginz = {
      lamdy = import ./nvimPloginz/lua.nix;
      modz = [
        "hob"
        "pkdjz"
      ];
      self = null;
    };

    nvimPloginz = {
      lamdy = import ./nvimPloginz;
      modz = [
        "hob"
        "pkdjz"
      ];
      self = null;
    };

    nerd-fonts = {
      lamdy = import ./nerd-fonts;
      self = null;
    };

    nix-dev = {
      lamdy = import ./nix;
      modz = [
        "pkgs"
        "pkdjz"
      ];
      self = hob.nix.maisiliym.dev;
    };

    pkgsNvimPloginz = {
      lamdy = import ./pkgsNvimPloginz;
      modz = [
        "pkgsSet"
        "lib"
        "pkdjz"
      ];
      self = hob.nixpkgs;
    };

    shen-bootstrap = {
      lamdy = import ./shen/bootstrap.nix;
      self = hob.shen;
    };

    shen-ecl-bootstrap = {
      lamdy = import ./shen/ecl.nix;
      self = null;
    };

    remux = {
      lamdy = import ./remux;
      self = hob.videocut;
    };

    shenPrelude.lamdy = import ./shen/prelude.nix;

    slynkPackages = {
      lamdy = import ./slynkPackages;
      self = null;
    };

    niks = {
      lamdy = import ./niks;
      modz = [
        "pkgs"
        "pkdjz"
      ];
    };

    obs-ndi = {
      modz = [
        "pkgsSet"
        "pkgs"
        "pkdjz"
      ];
      src = null;
      lamdy = import ./obs-ndi;
    };

    videocut = {
      lamdy = import ./videocut;
      modz = [
        "pkgs"
        "pkdjz"
      ];
    };

    vimPloginz = {
      lamdy = import ./vimPloginz;
      modz = [
        "pkgs"
        "pkdjz"
        "hob"
      ];
      self = null;
    };
  };

  aliases = {
    shen = pkdjz.shen-ecl-bootstrap;
  };

  adHoc = (import ./adHoc.nix) hob;

in
adHoc // pkdjz // aliases
