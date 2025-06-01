# Flakes are a perfect example of bad design
{
  description = "CriomOS";

  outputs = inputs: import ./default.nix { inherit inputs; };

  inputs = {
    # Nixpkgs & lib
    nixpkgs.url = "github:criome/nixpkgs/testing";
    lib.url = "github:criome/lib/testing";
    lib.inputs.nixpkgs.follows = "nixpkgs";

    # Nixpkgs overlays
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";

    # Horizon
    maisiliym.url = "github:LiGoldragon/maisiliym/testing";
    goldragon.url = "github:LiGoldragon/goldragon";
    seahawk.url = "github:criome/seahawk";

    # Todo - binary cache
    attic.url = "github:zhaofengli/attic";

    # Misc
    kibord.url = "github:LiGoldragon/kibord/testing";
    skrips.url = "github:criome/skrips/testing";

    # Websites - TODO: bad design
    mkZolaWebsite.url = "github:criome/mkZolaWebsite";
    goldragonWebsite = {
      url = "github:LiGoldragon/webpage";
      flake = false;
    };
    seahawkWebsite = {
      url = "github:AnaSeahawk/website";
      flake = false;
    };

    # pkdjz
    base16-styles = {
      url = "github:samme/base16-styles";
      flake = false;
    };
    base16-theme = {
      url = "github:league/base16-emacs";
      flake = false;
    };
    flake-registry = {
      url = "github:NixOS/flake-registry";
      flake = false;
    };
    flake-utils.url = "github:numtide/flake-utils";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    jujutsu-el = {
      url = "github:bennyandresen/jujutsu.el";
      flake = false;
    };
    lojix = {
      url = "github:criome/lojix";
      flake = false;
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
        clj-nix.follows = "clj-nix";
      };
    };
    md-roam = {
      url = "github:nobiot/md-roam";
      flake = false;
    };
    mfgtools = {
      url = "github:NXPmicro/mfgtools";
      flake = false;
    };
    ndi = {
      url = "github:LiGoldragon/ndi";
      flake = false;
    };
    shen = {
      url = "github:criome/shen";
      flake = false;
    };
    shen-mode = {
      url = "github:NHALX/shen-mode";
      flake = false;
    };
    tera-mode = {
      url = "github:svavs/tera-mode";
      flake = false;
    };
    videocut = {
      url = "github:kanehekili/VideoCut";
      flake = false;
    };
    xah-fly-keys = {
      url = "github:xahlee/xah-fly-keys";
      flake = false;
    };
  };
}
