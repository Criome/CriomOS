# Flakes are a perfect example of bad design
{
  description = "CriomOS";

  outputs =
    inputs:
    let
      nonSelfInputs = removeAttrs inputs [ "self" ];
    in
    import ./default.nix nonSelfInputs;

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Nixpkgs overlays
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
    emacs-overlay = {
      url = "github:nix-community/emacs-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Nix ecosystem
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Horizon
    maisiliym.url = "github:LiGoldragon/maisiliym/dev";
    goldragon.url = "github:LiGoldragon/goldragon";
    seahawk.url = "github:criome/seahawk";
    aedifico.url = "github:Criome/aedifico";

    # Todo - binary cache
    attic.url = "github:zhaofengli/attic";

    # Styling
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niri-flake = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # AI coding agents (daily auto-updates)
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Desktop agents
    claude-for-linux.url = "github:Criome/claude-for-linux/update-v1.1.7714";

    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # System
    kibord.url = "github:LiGoldragon/kibord/testing";
    skrips.url = "github:criome/skrips/testing";
    mentci = {
      url = "github:LiGoldragon/Mentci";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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
    gptel = {
      url = "github:karthink/gptel";
      flake = false;
    };
    jujutsu-el = {
      url = "github:bennyandresen/jujutsu.el";
      flake = false;
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
    tree-sitter-capnp = {
      url = "github:tree-sitter-grammars/tree-sitter-capnp";
      flake = false;
    };
    tree-sitter-cozo = {
      url = "github:Criome/tree-sitter-cozo";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    aski = {
      url = "github:Criome/aski";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    codex-cli = {
      url = "github:sadjow/codex-cli-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    superchat = {
      url = "github:yibie/superchat";
      flake = false;
    };
    tera-mode = {
      url = "github:svavs/tera-mode";
      flake = false;
    };
    ultra-scroll = {
      url = "github:jdtsmith/ultra-scroll";
      flake = false;
    };
    xah-fly-keys = {
      url = "github:xahlee/xah-fly-keys";
      flake = false;
    };
  };
}
