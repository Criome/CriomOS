{
  kor,
  lib,
  pkgs,
  pkdjz,
  user,
  hyraizyn,
  config,
  profile,
  uyrld,
  hob,
  ...
}:
let
  inherit (builtins) toString readFile toJSON;
  inherit (lib) optionalAttrs;
  inherit (kor)
    optionalString
    optionals
    mkIf
    optional
    importJSON
    ;
  inherit (pkdjz) kynvyrt;
  inherit (hyraizyn) astra;
  inherit (user.spinyrz)
    iuzColemak
    hazPreCriome
    gitSigningKey
    matrixID
    saizAtList
    izNiksDev
    izSemaDev
    ;
  inherit (user) githubId neim spinyrz;
  inherit (profile) dark;
  inherit (pkgs) writeText;

  homeDir = config.home.homeDirectory;

  colemakZedKeys = importJSON ./zed_colemak_keybindings.json;

  fzfColemakBinds = import ./fzfColemak.nix;

  fzfBinds = (optionals iuzColemak fzfColemakBinds);

  mkFzfBinds = list: "--bind=" + (builtins.concatStringsSep "," list);

  fzfBindsString = optionalString (fzfBinds != [ ]) (mkFzfBinds fzfBinds);

  fzfTheme = if dark then import ./fzfDark.nix else import ./fzfLight.nix;
  fzfBase16Map = import ./fzfBase16map.nix;

  mkFzfColor =
    n: v:
    let
      color = fzfTheme.${v};
    in
    color;

  fzfColors = builtins.mapAttrs mkFzfColor fzfBase16Map;

  waylandQtpass = pkgs.qtpass.override { pass = waylandPass; };
  waylandPass = pkgs.pass.override {
    x11Support = false;
    waylandSupport = true;
  };

  fontDeriveicynz =
    [ pkgs.noto-fonts-cjk-sans ]
    ++ (optionals saizAtList.med (
      with pkgs;
      [
        pkdjz.nerd-fonts.firaCode
        fira-code
      ]
    ));

  mkFcCache = pkgs.makeFontsCache { fontDirectories = fontDeriveicynz; };

  mkFontPaths = kor.concatMapStringsSep "\n" (path: "<dir>${path}/share/fonts</dir>") fontDeriveicynz;

  mkFontConf = ''
    <?xml version='1.0'?>
    <!DOCTYPE fontconfig SYSTEM 'fonts.dtd'>
    <fontconfig>
      ${mkFontPaths}
      <cachedir>${mkFcCache}</cachedir>
    </fontconfig>
  '';

  mkFootSrcTheme =
    themeName:
    let
      themeString = readFile (pkgs.foot.src + "/themes/${themeName}");
    in
    writeText "foot-theme-${themeName}" themeString;

  footThemeFile =
    let
      darkTheme = mkFootSrcTheme "derp";
      lightTheme = mkFootSrcTheme "selenized-white";
    in
    if dark then darkTheme else lightTheme;

  bleedingEdgeGraphicalPackages = [ ];

  modernGraphicalPackages = with pkgs; [
    # C
    # ctags
    swaylock
    grim
    slurp
    waybar
    wayland-warpd
    zathura
    wl-clipboard
    libnotify
    imv
    wf-recorder
    libva-utils
    ffmpeg-full
    # start("GTK")
    wofi
    gitg
    pwvucontrol # Pipewire audio GTK UI
    sonata
    dino
    ptask
    transmission-remote-gtk
    bookworm
    # start("Qt")
    adwaita-qt
    qgnomeplatform
    waylandQtpass
    waylandPass
    # helvum # Broken? Pipewire nodes UI
    coppwr # Pipewire Nodes UI
    # TODO('hyraizyn language')
    (hunspellWithDicts [ hunspellDicts.en-us-large ])
    (aspellWithDicts (
      ds: with ds; [
        en
        en-computers
        en-science
      ]
    ))
    hunspellDicts.en-us-large
  ];

  brootConfig = toJSON { };

  wayland-warpd = pkgs.warpd.override { withX = false; };

  unixUtilities =
    with pkgs;
    [
      erdtree # Disk usage
      lsof # List open files
      delta # Git diff viewew
      cpulimit # Limit a process' CPU usage
      yggdrasil
      usbutils
      pciutils
      efivar # Hardware
      lshw
      gptfdisk
      parted # Disk utils
      wireguard-tools
    ]
    ++ (optionals (astra.mycin.ark == "x86-64") [ i7z ]);

  programmingTools = with pkgs; [
    # C
    stdenv.cc
    # Rust
    pkdjz.nightlyRustDevEnv
    # Nix
    nil
    nixfmt-rfc-style
    npins
    # Clojure
    clojure
    babashka
    neil
    clj-kondo
    leiningen
    cljfmt
    # lisp
    zprint
    # Flashing
    avrdude
    # Shell
    shfmt
    # Other
    meld # GTK diff editor
    gg-jj # Jujutsu GUI
    lazyjj # # jujutsu TUI
    just
    difftastic
    tokei # Lines of code
  ];

  unixDeveloperPackages = unixUtilities ++ programmingTools;

  nixpkgsPackages =
    with pkgs;
    [
      mksh # saner bash
      retry
      ncpamixer
      mpv
      flac
      shntool
      dvtm
      abduco # Multiplexer/session
      vis # regex Editor
      tree
      ncdu # File visualizing
      unzip
      unrar
      fuse
      cryptsetup
      # Network
      sshfs-fuse
      ifmetric
      curl
      wget
      transmission_4
      aria2 # multi-protocol download
      rsync
      nload
      nmap
      iftop
      # Wireless
      iw
      wirelesstools
      acpi
      sox # audio capture
      tio # serial tty
      androidenv.androidPkgs.platform-tools # adb/fastboot
      #== rust
      sd
      ripgrep
      fd
      eza
      bat
      broot
      eva # tui calculator
    ]
    ++ bleedingEdgeGraphicalPackages # (Todo configure)
    ++ modernGraphicalPackages # (Todo configure)
    ++ (optionals izNiksDev unixDeveloperPackages)
    ++ (optionals izSemaDev (
      with pkgs;
      [
        inkscape
      ]
    ));

  uyrldPackages = with uyrld; [
    pkdjz.shen-bootstrap
    skrips.user
    # clojure-lsp.packages.default
  ];

in
mkIf saizAtList.min {
  services = {
    dunst = {
      enable = true;
      # (TODO theme)
      settings = {
        global = {
          geometry = "300x5-30+50";
          transparency = 10;
          frame_color = "#eceff1";
          font = "Fira Code 10";
        };

        urgency_normal = {
          background = "#37474f";
          foreground = "#eceff1";
          timeout = 10;
        };
      };
    };

    pantalaimon = {
      enable = false; # TODO
      settings = {
        Default = {
          LogLevel = "Debug";
          SSL = true;
        };
        local-matrix = {
          Homeserver = "https://matrix.org";
          ListenAddress = "127.0.0.1";
          ListenPort = 8009;
          IgnoreVerification = true;
          SSL = false;
        };
      };
    };

    gammastep = {
      enable = true;
      provider = "geoclue2";
      temperature = {
        day = 3500;
        night = 2700;
      };
    };

    gpg-agent = {
      enable = true;
      verbose = true;
      pinentryPackage = pkgs.pinentry-gnome3;
      defaultCacheTtl = 10800;
      maxCacheTtl = 86400;
      defaultCacheTtlSsh = 3600;
      maxCacheTtlSsh = 86400;
      enableSshSupport = true;
      sshKeys = (optional hazPreCriome user.preCriomes.${astra.neim}.keygrip);
    };

    mpd = {
      enable = true;
      musicDirectory = "~/Music";
    };

    pueue = {
      enable = izNiksDev;
      settings = {
        shared = { };
        client = {
          dark_mode = dark;
        };
        daemon = {
          default_parallel_tasks = 1;
        };
      };
    };
  };

  programs = {
    bat = {
      enable = true;
      config = {
        theme = "gruvbox-${if dark then "dark" else "light"}";
        pager = "less -FR";
      };
    };

    direnv = {
      enable = izNiksDev;
      nix-direnv.enable = izNiksDev;
    };

    foot = {
      enable = true;
      settings = {
        main = {
          include = toString footThemeFile;
          font = "Fira Code:size=9";
        };
      };
    };

    fzf = {
      enable = true;
      colors = fzfColors;
      defaultCommand = "fd --type f";
      defaultOptions = [ fzfBindsString ];
    };

    git = {
      enable = true;
      userEmail = spinyrz.emailAddress;
      userName = neim;
      signing = mkIf hazPreCriome {
        key = gitSigningKey;
        signByDefault = true;
      };
      extraConfig = {
        pull.rebase = true;
        init.defaultBranch = "main";
        github.user = githubId;
        ghq.root = "/git";
        hub.protocol = "ssh";
      };
    };

    gpg = {
      enable = true;
      settings = { };
    };

    joshuto = {
      enable = izNiksDev;
    };

    jujutsu = {
      enable = izNiksDev;
      settings = {
        ui = {
          diff-instructions = false;
          diff.tool = [
            "difft"
            "--color=always"
            "$left"
            "$right"
          ];
        };
        user = {
          name = neim;
          email = spinyrz.emailAddress;
        };
        signing = {
          sign-all = true;
          backend = "gpg";
          key = gitSigningKey;
        };
      };
    };

    lapce = {
      enable = izNiksDev;
      plugins = [ ];
      settings = {
        core = {
          modal = true;
          color-theme = if dark then "Lapce Dark" else "Lapce Light";
        };
        editor = {
          font-family = "FiraCode Nerd Font";
          font-size = 16;
          bracket-pair-colorization = true;
          highlight-matching-brackets = true;
        };
        ui = {
          open-editors-visible = false;
          font-size = 14;
        };
      };
    };

    zed-editor = {
      enable = true;
      package = pkgs.zed-editor;
      extraPackages = with pkgs; [ ];
      userKeymaps = optionalAttrs iuzColemak colemakZedKeys;
      userSettings =
        let
          darkTheme = "base16-bright";
          lightTheme = "base16-selenized-white";
        in
        {
          theme = if dark then darkTheme else lightTheme;
          vim_mode = true;
        };
      extensions = [ ];
    };

    htop = {
      enable = true;
      settings = {
        highlight_base_name = 1;
      };
    };

    starship = {
      enable = true;
    };

    zsh = {
      enable = true;
      dotDir = ".config/zsh";
      history = {
        ignoreDups = true;
        expireDuplicatesFirst = true;
      };

      defaultKeymap = "viins";

      sessionVariables = {
        RSYNC_OLD_ARGS = 1;
      };

      shellAliases = {
        tsync = "rsync --progress --recursive";
        nsync = "rsync --checksum --progress --recursive";
        dsync = "rsync --checksum --progress --recursive --delete";
      };

      initExtra =
        builtins.readFile ../nonNix/zshrc
        + ''
          if [[ $options[zle] = on ]]; then
          . ${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.zsh
          fi
        ''
        + (optionalString iuzColemak (builtins.readFile ../nonNix/colemak.zsh));
    };

    zoxide.enable = true;
  };

  home = {
    packages = nixpkgsPackages ++ uyrldPackages;

    pointerCursor = {
      package = pkgs.vanilla-dmz;
      name = "Vanilla-DMZ";
    };

    file = {
      ".config/gtk-3.0/settings.ini".text = ''
        [Settings]
        gtk-application-prefer-dark-theme=${if dark then "1" else "0"}
      '';

      ".config/IJHack/QtPass.conf".text = ''
        [General]
        autoclearSeconds=20
        passwordLength=32
        useTrayIcon=false
        hideContent=false
        hidePassword=true
        clipBoardType=1
        hideOnClose=false
        passExecutable=${waylandPass}/bin/pass
        passTemplate=login\nurl
        pwgenExecutable=${pkgs.pwgen}bin/pwgen
        startMinimized=false
        templateAllFields=false
        useAutoclear=true
        useTrayIcon=false
        version=${pkgs.qtpass.version}
      '';

      ".config/broot/conf.toml".text = brootConfig;

      ".cargo/config.toml".source = kynvyrt {
        neim = "cargo-config";
        format = "toml";
        valiu = {
          build.target-dir = "${homeDir}/.cargo/sharedTarget";
          unstable.weak-dep-features = true;
        };
      };
    };
  };

  xdg = {
    configFile = {
      "fontconfig/conf.d/10-niksIuzyr-fonts.conf".text = mkFontConf;
    };

    mimeApps = {
      enable = true;
      defaultApplications =
        let
          defaultBrowser = "chromium.desktop";
          defaultMailer = "evolution.desktop";
        in
        {
          "application/zip" = "org.gnome.FileRoller.desktop";

          "x-scheme-handler/tg" = "org.telegram.desktop.desktop";
          "x-scheme-handler/tonsite" = "org.telegram.desktop.desktop";

          "application/epub+zip" = "calibre-ebook-viewer.desktop";
          "application/pdf" = "org.pwmt.zathura-pdf-mupdf.desktop";

          "text/html" = defaultBrowser;
          "x-scheme-handler/http" = defaultBrowser;
          "x-scheme-handler/https" = defaultBrowser;
          "x-scheme-handler/ftp" = defaultBrowser;
          "x-scheme-handler/chrome" = defaultBrowser;
          "application/x-extension-htm" = defaultBrowser;
          "application/x-extension-html" = defaultBrowser;
          "application/x-extension-shtml" = defaultBrowser;
          "application/xhtml+xml" = defaultBrowser;
          "application/x-extension-xhtml" = defaultBrowser;
          "application/x-extension-xht" = defaultBrowser;

          "x-scheme-handler/about" = defaultBrowser;
          "x-scheme-handler/unknown" = defaultBrowser;

          "x-scheme-handler/mailto" = defaultMailer;
          "x-scheme-handler/news" = defaultMailer;
          "x-scheme-handler/snews" = defaultMailer;
          "x-scheme-handler/nntp" = defaultMailer;
          "x-scheme-handler/feed" = defaultMailer;
          "message/rfc822" = defaultMailer;
          "application/rss+xml" = defaultMailer;
          "application/x-extension-rss" = defaultMailer;
        };
    };

  };
}
