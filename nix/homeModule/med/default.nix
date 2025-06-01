{
  lib,
  user,
  pkgs,
  pkdjz,
  world,
  ...
}:
let
  inherit (builtins) readFile toJSON;
  inherit (lib) optionalString optionals;
  inherit (pkdjz) kynvyrt;
  inherit (user) githubId;
  inherit (user.methods) isCodeDev useColemak sizedAtLeast;
  inherit (pkgs) mksh;

  tokenaizdWrangler = pkgs.writeScriptBin "wrangler" ''
    #!${mksh}/bin/mksh
    export CLOUDFLARE_API_TOKEN=''${CLOUDFLARE_API_TOKEN:-''$(${pkgs.gopass}/bin/gopass show -o cloudflare.com/token)}
    exec "${pkgs.nodePackages_latest.wrangler}/bin/wrangler" "$@"
  '';

  tokenizedHub = pkgs.writeScriptBin "hub" ''
    #!${mksh}/bin/mksh
    export GITHUB_TOKEN=''${GITHUB_TOKEN:-''$(${pkgs.gopass}/bin/gopass show -o github.com/token)}
    export GITHUB_USER=''${GITHUB_USER:-''$(${pkgs.gopass}/bin/gopass show github.com/token login)}
    exec "${pkgs.gitAndTools.hub}/bin/hub" "$@"
  '';

  tokenizedWrappedHub = pkgs.runCommand "hub" { } ''
    mkdir -p $out/bin
    ln -s ${pkgs.hub}/share $out/
    ln -s ${tokenizedHub}/bin/hub $out/bin/
  '';

  tokenizedGhCli = pkgs.writeScriptBin "gh" ''
    #!${mksh}/bin/mksh
    export GH_TOKEN=''${GITHUB_TOKEN:-''$(${pkgs.gopass}/bin/gopass show -o github.com/token)}
    exec "${pkgs.gh}/bin/gh" "$@"
  '';

  tokenizedWrappedGhCli = pkgs.runCommand "gh" { } ''
    mkdir -p $out/bin
    ln -s ${pkgs.gh}/share $out/
    ln -s ${tokenizedGhCli}/bin/gh $out/bin/
  '';

  lispDevPackages = with pkgs; [
    sbcl
  ];

  codingPackages =
    with pkgs;
    [
      qrencode
      jmtpfs
      # start('bash')
      nix-prefetch-git
      # start('pythonPackages')
      ranger
      # C/C++
      binutils
      openssh
      nginx
      sdcv # cli dictionary
      jq
      djvulibre
      # NodeJS
      # tokenaizdWrangler
      #== go
      ghq
      elvish
      lf
      tokenizedWrappedHub
      tokenizedWrappedGhCli
      hugo
      #== rust
      watchexec
      zola
      git-series
      tree-sitter
      gitAndTools.gitui
      # Python
      world.kibord.kpBootCli
      # Manuals
      unbound.man
    ]
    ++ (with nodePackages; [
      stylelint
      postcss
      node2nix
      prettier
    ]);

  graphicalPackages = with pkgs; [
    ledger-live-desktop
    element-desktop
    telegram-desktop
    losslesscut-bin
  ];

in
lib.mkIf sizedAtLeast.med {
  programs = {
    starship = {
      enable = true;
      settings = {
        cmd_duration = {
          show_notifications = true;
          min_time_to_notify = 10000; # TODO('requires build flag')
        };
        git_status = {
          disabled = true;
        };
      };
    };
  };

  home = {
    packages =
      with pkgs;
      [
        # start('bash')
        taskwarrior3
        # start('pythonPackages')
        yt-dlp
        # ocrmypdf
        # C/C++
        imagemagick
        opusTools
        mediainfo
        #== go
        gopass
        git-bug
        lazygit
        #== rust
        spotify-player
      ]
      ++ graphicalPackages
      ++ optionals isCodeDev (codingPackages ++ lispDevPackages);

    file = {
      # ".config/jesseduffield/lazygit/config.yml".text = { };

      "gh/config.yml".text = toJSON {
        gitProtocol = "ssh";
      };

      ".config/rustfmt/rustfmt.toml".source = kynvyrt {
        name = "rustfmt.toml";
        format = "toml";
        value = {
          edition = "2021";
        };
      };

      ".config/luaformatter/config.yaml".source = kynvyrt {
        name = "luaFormatterConfig.yaml";
        format = "yaml";
        value = {
          indent_width = 2;
          continuation_indent_width = 2;
          align_args = false;
          align_parameter = false;
          align_table_field = false;
          spaces_inside_table_braces = true;
        };
      };

      # start('pythonConfigs')
      ".config/youtube-dl/config".text = ''
        -f 'bestvideo[ext=webm]+bestaudio[ext=webm]/best[ext=webm]/best'
      '';

      ".config/ranger/rc.conf".text = '''' + (optionalString useColemak readFile ./colemak.conf);
      # end('pythonConfigs')

    };
  };
}
