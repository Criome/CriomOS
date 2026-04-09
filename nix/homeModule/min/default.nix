{
  lib,
  pkgs,
  criomos-lib,
  pkdjz,
  user,
  horizon,
  config,
  world,
  inputs,
  # Todo(data)
  ...
}:
let
  inherit (builtins) toString readFile toJSON;
  inherit (lib)
    optionalAttrs
    optionalString
    optionals
    mkIf
    optional
    ;
  inherit (pkdjz) kynvyrt;
  inherit (horizon) node;
  inherit (user.methods)
    useColemak
    hasPreCriome
    gitSigningKey
    matrixID
    sizedAtLeast
    isMultimediaDev
    ;
  inherit (user) githubId name methods;
  inherit (pkgs) writeText;

  homeDir = config.home.homeDirectory;

  # Unified LLM config — single source of truth
  largeAIConfigPath = ../../../data/config/largeAI/llm.json;
  largeAIConfig = builtins.fromJSON (builtins.readFile largeAIConfigPath);
  largeAIModels = largeAIConfig.models;

  # Discover the largeAI node from the cluster topology
  largeAINodeEntry =
    let
      matches = lib.filterAttrs
        (_: n: (n.typeIs.largeAI or false) || (n.typeIs."largeAI-router" or false))
        horizon.exNodes;
    in
    if matches != {} then builtins.head (builtins.attrValues matches) else null;

  largeAINodeName =
    if node.methods.behavesAs.largeAI then node.name
    else if largeAINodeEntry != null then largeAINodeEntry.name
    else null;

  largeAIHost =
    if node.methods.behavesAs.largeAI then "127.0.0.1"
    else if largeAINodeEntry != null then largeAINodeEntry.criomeDomainName
    else null;

  hasLargeAI = largeAIHost != null;

  terminalFontFamily = if sizedAtLeast.med then "IosevkaTerm Nerd Font" else "DejaVu Sans Mono";

  # Todo(Those data files should be in a top arg called data)
  colemakZedKeys = criomos-lib.importJSON ./../../../data/ZedKeymaps/goldragon-colemak.json;

  fzfColemakBinds = import ./fzfColemak.nix;

  fzfBinds = (optionals useColemak fzfColemakBinds);

  mkFzfBinds = list: "--bind=" + (builtins.concatStringsSep "," list);

  fzfBindsString = optionalString (fzfBinds != [ ]) (mkFzfBinds fzfBinds);

  waylandQtpass = pkgs.qtpass.override { pass = waylandPass; };
  waylandPass = pkgs.pass.override {
    x11Support = false;
    waylandSupport = true;
  };

  fontPackages = with pkgs; [
    dejavu_fonts
    nerd-fonts.iosevka-term
    nerd-fonts.iosevka
  ];

  mkFcCache = pkgs.makeFontsCache { fontDirectories = fontPackages; };

  mkFontPaths = lib.concatMapStringsSep "\n" (path: "  <dir>${path}/share/fonts</dir>") fontPackages;

  mkFontConf = ''
    <?xml version='1.0'?>
    <!DOCTYPE fontconfig SYSTEM 'fonts.dtd'>
    <fontconfig>
    ${mkFontPaths}
      <cachedir>${mkFcCache}</cachedir>
    </fontconfig>
  '';

  bleedingEdgeGraphicalPackages = [ ];

  modernGraphicalPackages = with pkgs; [
    handlr-regex
    mpv
    # ctags
    swaylock
    grim
    slurp
    wayland-warpd
    zathura
    wl-clipboard
    libnotify
    imv
    wf-recorder
    libva-utils
    ffmpeg-full
    # start("GTK")
    appflowy
    gitg
    pwvucontrol # Pipewire audio GTK UI
    sonata
    dino
    # ptask # Broken
    transmission-remote-gtk
    # start("Qt")
    adwaita-qt
    qgnomeplatform
    waylandQtpass
    waylandPass
    # helvum # Broken? Pipewire nodes UI
    coppwr # Pipewire Nodes UI

    # TODO('horizon language')
    (pkgs.hunspell.withDicts (dicts: [
      dicts.en_GB-ize
      dicts.en_US
    ]))
    (aspellWithDicts (
      ds: with ds; [
        en
        en-computers
        en-science
      ]
    ))

  ];

  brootConfig = toJSON { };

  wayland-warpd = pkgs.warpd.override { withX = false; };

  unixUtilities =
    with pkgs;
    [
      dua # Disk usage
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
    ++ (optionals (node.machine.arch == "x86-64") [ i7z ]);

  programmingTools = with pkgs; [
    # C
    stdenv.cc
    # Rust
    cargo
    # pkdjz.nightlyRustDevEnv # TODO: debug - breaks zsh completions
    # Nix
    nil
    nixfmt
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
    # Python
    python3
    ruff
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

  # Pi agent config — derived entirely from largeAI/llm.json + horizon
  piAgentGatewayProvider = if largeAINodeName != null then largeAINodeName else "local";
  piAgentGatewayBaseUrl =
    if hasLargeAI
    then "http://${largeAIHost}:${toString largeAIConfig.serverPort}/v1"
    else null;

  piAgentModels = {
    providers.${piAgentGatewayProvider} = {
      baseUrl = piAgentGatewayBaseUrl;
      api = "openai-completions";
      authRequired = false;
      apiKey = largeAIConfig.apiKey;
      models = builtins.map (model: {
        id = model.modelId;
        name = "${piAgentGatewayProvider}/${model.modelId} (${model.descriptor})";
        reasoning = model.reasoning;
        input = [ "text" ];
        contextWindow = model.contextWindow;
        maxTokens = model.maxTokens;
        cost = { input = 0; output = 0; cacheRead = 0; cacheWrite = 0; };
      }) largeAIModels;
    };
  };

  piAgentSettings = {
    defaultProvider = piAgentGatewayProvider;
    defaultModel = largeAIConfig.piAgent.defaultModel;
    enabledModels = builtins.map (m: "${piAgentGatewayProvider}/${m.modelId}") largeAIModels;
    hideThinkingBlock = largeAIConfig.piAgent.hideThinkingBlock;
    defaultThinkingLevel = largeAIConfig.piAgent.defaultThinkingLevel;
    compaction = largeAIConfig.piAgent.compaction;
  };

  piAgentModelsJson = toJSON piAgentModels;
  piAgentSettingsJson = toJSON piAgentSettings;

  piAgent = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi or null;

  codex = inputs.codex-cli.packages.${pkgs.stdenv.hostPlatform.system}.default;

  AIPackages = [
    pkgs.gemini-cli
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
    codex
    pkgs.opencode
    pkgs.llama-cpp
  ] ++ optional (piAgent != null) piAgent;

  nixpkgsPackages =
    with pkgs;
    [
      mksh # saner bash
      retry
      ncpamixer
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
      tremc
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
    ++ unixDeveloperPackages
    ++ (optionals isMultimediaDev (
      with pkgs;
      [
        inkscape
      ]
    ));

  nordvpnSeed = pkgs.writeScriptBin "nordvpn-seed" ''
    #!${pkgs.mksh}/bin/mksh
    GOPASS_PATH="nordaccount.com/API-Key"
    KEY_FILE="/etc/nordvpn/privateKey"
    API="https://api.nordvpn.com/v1/users/services/credentials"

    if [ $# -ge 1 ]; then
      TOKEN="$1"
    else
      TOKEN=$(${pkgs.gopass}/bin/gopass show -o "$GOPASS_PATH" 2>/dev/null)
      if [ -z "$TOKEN" ]; then
        print -u2 "no token at gopass path: $GOPASS_PATH"
        exit 1
      fi
    fi

    KEY=$(${pkgs.curl}/bin/curl -sf -u "token:''${TOKEN}" "$API" \
      | ${pkgs.jq}/bin/jq -r .nordlynx_private_key)

    if [ -z "$KEY" ] || [ "$KEY" = "null" ]; then
      print -u2 "failed to derive WireGuard private key from API"
      exit 1
    fi

    print "$KEY" > "$KEY_FILE"
    chmod 600 "$KEY_FILE"
    print "seeded $KEY_FILE"
  '';

  busctlBin = "${pkgs.systemd}/bin/busctl";
  gammaRelayBus = "rs.wl-gammarelay / rs.wl.gammarelay";

  nightTemp = 2700;
  dayTemp = 6500;
  transitionMinutes = 90;
  transitionSteps = 15;

  nightshift = pkgs.writeShellScriptBin "nightshift" ''
    set_temp() { ${busctlBin} --user set-property ${gammaRelayBus} Temperature q "$1"; }
    get_temp() { ${busctlBin} --user get-property ${gammaRelayBus} Temperature 2>/dev/null | awk '{print $2}'; }

    NIGHT=${toString nightTemp}
    DAY=${toString dayTemp}
    MINUTES=${toString transitionMinutes}
    STEPS=${toString transitionSteps}

    # Apply correct temperature for current mode — instant on first call,
    # then gradual if already at screen during transition.
    apply() {
      target=$1
      current=$(get_temp)
      diff=$((current - target))
      [ $diff -lt 0 ] && diff=$((-diff))

      # If far from target (>500K off), jump immediately (login, wake, resume)
      if [ $diff -gt 500 ]; then
        set_temp "$target"
        return
      fi

      # Already close — do a short gradual transition (5 minutes)
      steps=10
      interval=30
      from=$current
      for i in $(seq 1 $steps); do
        elapsed=$(( $(date +%s) - start_time ))
        temp=$(( from + (target - from) * i / steps ))
        set_temp "$temp"
        [ "$i" -lt "$steps" ] && sleep "$interval"
      done
      set_temp "$target"
    }

    start_time=$(date +%s)

    case "''${1:-sync}" in
      sync)
        mode=$(${pkgs.darkman}/bin/darkman get 2>/dev/null || echo "light")
        if [ "$mode" = "dark" ]; then
          apply $NIGHT
        else
          apply $DAY
        fi
        ;;
      on)       apply $NIGHT ;;
      off)      apply $DAY ;;
      instant)  set_temp "''${2:-$NIGHT}" ;;
      *)        set_temp "$1" ;;
    esac
  '';

  brightness = pkgs.writeShellScriptBin "brightness" ''
    if [ -z "$1" ]; then
      ${busctlBin} --user get-property ${gammaRelayBus} Brightness
    else
      ${busctlBin} --user set-property ${gammaRelayBus} Brightness d "$1"
    fi
  '';

  worldPackages = with world; [
    skrips.user
  ];

in
assert builtins.length largeAIModels > 0;
mkIf sizedAtLeast.min {
  fonts.fontconfig = {
    enable = true;
    # TODO
    defaultFonts = {
      monospace = [ ];
      sansSerif = [ ];
      serif = [ ];
      emoji = [ ];
    };
  };

  services = {
    dunst = {
      enable = !sizedAtLeast.min;
      settings = {
        global = {
          geometry = "300x5-30+50";
          transparency = 10;
        };

        urgency_normal = {
          timeout = 10;
        };
      };
    };

    hyprsunset = {
      enable = false;
    };
    gammastep = {
      enable = false;
    };

    gpg-agent = {
      enable = true;
      verbose = true;
      pinentry.package = pkgs.pinentry-gnome3;
      defaultCacheTtl = 10800;
      maxCacheTtl = 86400;
      defaultCacheTtlSsh = 3600;
      maxCacheTtlSsh = 86400;
      enableSshSupport = true;
      sshKeys = (optional hasPreCriome user.preCriomes.${node.name}.keygrip);
    };

    mpd = {
      enable = true;
      musicDirectory = "~/Music";
    };

    pueue = {
      enable = true;
      settings = {
        shared = { };
        client = {
          dark_mode = config.stylix.polarity == "dark";
        };
        daemon = {
          default_parallel_tasks = 1;
        };
      };
    };

    # swaync disabled — noctalia handles notifications natively
    swaync.enable = false;
  };

  programs = {
    bat = {
      enable = true;
      config = {
        pager = "less -FR";
      };
    };

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    ghostty = {
      enable = true;
      installVimSyntax = true;
    };

    wezterm = {
      enable = false;
      extraConfig = ''
        local function scheme_for_appearance(appearance)
          if appearance:find "Dark" then
            return "Equilibrium Dark"
          else
            return "Equilibrium Light"
          end
        end

        wezterm.on("window-config-reloaded", function(window, pane)
          local overrides = window:get_config_overrides() or {}
          local scheme = scheme_for_appearance(window:get_appearance())
          if overrides.color_scheme ~= scheme then
            overrides.color_scheme = scheme
            window:set_config_overrides(overrides)
          end
        end)

        return {
          font = wezterm.font("IosevkaTerm Nerd Font"),
          font_size = 14.0,
          color_scheme = scheme_for_appearance(wezterm.gui.get_appearance()),
          window_decorations = "NONE",
          hide_tab_bar_if_only_one_tab = true,
          enable_wayland = true,
          enable_kitty_keyboard = true,
        }
      '';
      colorSchemes = {
        "Equilibrium Dark" = {
          ansi = [ "#0c1118" "#f04339" "#7f8b00" "#bb8801" "#008dd1" "#6a7fd2" "#00948b" "#afaba2" ];
          brights = [ "#7b776e" "#df5923" "#949088" "#22262d" "#cac6bd" "#e3488e" "#181c22" "#e7e2d9" ];
          background = "#0c1118";
          foreground = "#afaba2";
          cursor_bg = "#afaba2";
          cursor_fg = "#0c1118";
          selection_bg = "#22262d";
          selection_fg = "#afaba2";
        };
        "Equilibrium Light" = {
          ansi = [ "#f5f0e7" "#d02023" "#637200" "#9d6f00" "#0073b5" "#4e66b6" "#007a72" "#43474e" ];
          brights = [ "#73777f" "#bf3e05" "#5a5f66" "#d8d4cb" "#2c3138" "#c42775" "#e7e2d9" "#181c22" ];
          background = "#f5f0e7";
          foreground = "#43474e";
          cursor_bg = "#43474e";
          cursor_fg = "#f5f0e7";
          selection_bg = "#d8d4cb";
          selection_fg = "#43474e";
        };
      };
    };

    fzf = {
      enable = true;
      defaultCommand = "fd --type f";
      defaultOptions = [ fzfBindsString ];
    };

    git = {
      enable = true;
      signing = mkIf hasPreCriome {
        key = gitSigningKey;
        signByDefault = true;
      };
      settings = {
        user.email = methods.emailAddress;
        user.name = name;
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
      enable = true;
    };

    jujutsu = {
      enable = true;
      settings = {
        ui = {
          diff-instructions = false;
          diff-formatter = [
            "difft"
            "--color=always"
            "$left"
            "$right"
          ];
        };
        user = {
          name = name;
          email = methods.emailAddress;
        };
        signing = mkIf hasPreCriome {
          behavior = "own";
          backend = "gpg";
          key = gitSigningKey;
        };
      };
    };

    lapce = {
      enable = true;
      plugins = [ ];
      settings = {
        core = {
          modal = true;
          color-theme = if config.stylix.polarity == "dark" then "Lapce Dark" else "Lapce Light";
        };
        editor = {
          font-family = "Iosevka Nerd Font";
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

    # TODO broken
    zed-editor = {
      enable = true;
      package = pkgs.zed-editor;
      extraPackages = with pkgs; [ ];
      userKeymaps = optionalAttrs useColemak colemakZedKeys;
      userSettings = {
          vim_mode = true;
        };
      extensions = [ ];
    };

    bottom = {
      enable = true;
      settings = { };
    };

    starship = {
      enable = true;
    };

    zsh = {
      enable = true;
      dotDir = "${config.xdg.configHome}/zsh";
      history = {
        ignoreDups = true;
        expireDuplicatesFirst = true;
      };

      defaultKeymap = "viins";

      sessionVariables = {
        RSYNC_OLD_ARGS = 1;
        QT_QPA_PLATFORM = "wayland";
      };

      shellAliases = {
        tsync = "rsync --progress --recursive";
        nsync = "rsync --checksum --progress --recursive";
        dsync = "rsync --checksum --progress --recursive --delete";
      };

      initContent =
        builtins.readFile ../nonNix/zshrc
        + ''
          if [[ $options[zle] = on ]]; then
          . ${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.zsh
          fi
        ''
        + (optionalString useColemak (builtins.readFile ../nonNix/colemak.zsh));
    };

    wofi = {
      enable = true;
    };

    zoxide.enable = true;
  };

  home = {
    packages = fontPackages ++ nixpkgsPackages ++ worldPackages ++ AIPackages ++ [
      nordvpnSeed
      pkgs.wl-gammarelay-rs
      nightshift
      brightness
    ];

    activation = { }
      // (optionalAttrs hasLargeAI {
        seedPiAgentConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          pi_agent_dir="$HOME/.pi/agent"
          mkdir -p "$pi_agent_dir"

          if [ ! -e "$pi_agent_dir/settings.json" ] || [ -L "$pi_agent_dir/settings.json" ]; then
            rm -f "$pi_agent_dir/settings.json"
            cat > "$pi_agent_dir/settings.json" << 'SETTINGS'
          ${piAgentSettingsJson}
          SETTINGS
          fi

          if [ ! -e "$pi_agent_dir/models.json" ] || [ -L "$pi_agent_dir/models.json" ]; then
            rm -f "$pi_agent_dir/models.json"
            cat > "$pi_agent_dir/models.json" << 'MODELS'
          ${piAgentModelsJson}
          MODELS
          fi
        '';
      });

    file =
      {
        ".local/bin/xdg-open" = {
          executable = true;
          text = ''
            #!/bin/sh
            exec ${pkgs.handlr-regex}/bin/handlr open "$@"
          '';
        };

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
          pwgenExecutable=${pkgs.pwgen}/bin/pwgen
          startMinimized=false
          templateAllFields=false
          useAutoclear=true
          useTrayIcon=false
          version=${pkgs.qtpass.version}
        '';

        ".config/broot/conf.toml".text = brootConfig;
      }
      // (optionalAttrs hasLargeAI {
        ".pi/settings.json" = {
          text = piAgentSettingsJson;
          force = true;
        };
      });
  };

  systemd = {
    user.services = {
      wl-gammarelay-rs = {
        Unit = {
          Description = "DBus interface for display temperature, brightness and gamma control";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${pkgs.wl-gammarelay-rs}/bin/wl-gammarelay-rs";
          Restart = "on-failure";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

      nightshift-sync = {
        Unit = {
          Description = "Sync color temperature to current dark/light mode";
          Requires = [ "wl-gammarelay-rs.service" ];
          After = [ "wl-gammarelay-rs.service" ];
        };
        Service = {
          Type = "oneshot";
          ExecStartPre = "${pkgs.coreutils}/bin/sleep 1";
          ExecStart = "${nightshift}/bin/nightshift sync";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

      nightshift-on = {
        Unit = {
          Description = "Warm color temperature transition";
          Requires = [ "wl-gammarelay-rs.service" ];
          After = [ "wl-gammarelay-rs.service" ];
          Conflicts = [ "nightshift-off.service" ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${nightshift}/bin/nightshift on";
          RemainAfterExit = false;
        };
      };

      nightshift-off = {
        Unit = {
          Description = "Neutral color temperature transition";
          Requires = [ "wl-gammarelay-rs.service" ];
          After = [ "wl-gammarelay-rs.service" ];
          Conflicts = [ "nightshift-on.service" ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${nightshift}/bin/nightshift off";
          RemainAfterExit = false;
        };
      };
    };
  };

  xdg = {
    configFile = {
      "fontconfig/conf.d/10-CriomOS-fonts-paths.conf".text = mkFontConf;

      "uwsm/env".text = ''
        export SSH_AUTH_SOCK="''${XDG_RUNTIME_DIR}/gnupg/S.gpg-agent.ssh"
        export NIXOS_OZONE_WL=1
        export QT_QPA_PLATFORM=wayland
        export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
        export GDK_BACKEND=wayland
        export SDL_VIDEODRIVER=wayland
        export MOZ_ENABLE_WAYLAND=1
        export _JAVA_AWT_WM_NONREPARENTING=1
      '';
    };

    configFile."handlr/handlr.toml".text = ''
      expand_wildcards = true
    '';

    dataFile."mime/packages/aski.xml".text = ''
      <?xml version="1.0" encoding="UTF-8"?>
      <mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
        <mime-type type="text/x-aski">
          <comment>Aski source</comment>
          <glob pattern="*.aski"/>
        </mime-type>
      </mime-info>
    '';

    mimeApps = {
      enable = true;
      defaultApplications =
        let
          defaultBrowser = "chromium.desktop";
          defaultMailer = "evolution.desktop";
          defaultAudioPlayer = "mpv.desktop";
        in
        {
          "text/x-aski" = "emacs.desktop";
          "audio/x-m4b" = defaultAudioPlayer;
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
