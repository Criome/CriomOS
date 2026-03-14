{
  lib,
  pkgs,
  criomos-lib,
  pkdjz,
  user,
  horizon,
  config,
  profile,
  world,
  litellmProxy,
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
    isCodeDev
    isMultimediaDev
    ;
  inherit (user) githubId name methods;
  inherit (profile) dark;
  inherit (pkgs) writeText;

  homeDir = config.home.homeDirectory;

  isPrometheusNode = node.name == "prometheus";
  isOuranosNode = node.name == "ouranos";

  # Prefer a directly-routable IP for cross-node calls (Ouranos → Prometheus).
  # The criome domain name is not guaranteed to resolve in the current environment.
  prometheusCriomeHost =
    let
      prometheusNode = horizon.exNodes.prometheus or null;
      prometheusNodeIp =
        if prometheusNode != null && builtins.hasAttr "nodeIp" prometheusNode
        then prometheusNode.nodeIp
        else null;
      prometheusDomainName =
        if prometheusNode != null
        then prometheusNode.criomeDomainName
        else "prometheus.${horizon.cluster.name}.criome";
    in
    if prometheusNodeIp != null && prometheusNodeIp != ""
    then prometheusNodeIp
    else prometheusDomainName;

  # Current session runtime truth: the working overlay path is Prometheus tailnet IP.
  # System MagicDNS integration is not yet authoritative for user-space consumers.
  prometheusOverlayHost = if isOuranosNode then "100.64.0.1" else prometheusCriomeHost;

  # Prometheus runs the llama.cpp server locally; other nodes should route to the Prometheus overlay.
  prometheusLlamaUpstreamHost = if isPrometheusNode then "127.0.0.1" else prometheusOverlayHost;

  terminalFontFamily = if sizedAtLeast.med then "FiraMono Nerd Font" else "DejaVu Sans Mono";

  # Todo(Those data files should be in a top arg called data)
  colemakZedKeys = criomos-lib.importJSON ./../../../data/ZedKeymaps/goldragon-colemak.json;

  fzfColemakBinds = import ./fzfColemak.nix;

  fzfBinds = (optionals useColemak fzfColemakBinds);

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

  fontPackages = with pkgs; [
    dejavu_fonts
    nerd-fonts.fira-mono
    nerd-fonts.fira-code
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
    wofi
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

  prometheusLlamaPort = 11436;
  prometheusLlamaApiKey = "sk-no-key-required";

  # Runtime model assets live in the user's home. Do not hard-code presets to
  # non-existent files; generate the preset at service start from the canonical
  # filenames that actually exist on disk.
  prometheusLlamaModelDir = "${homeDir}/.local/share/prometheus-llama/models";
  prometheusLlamaPreset = "${homeDir}/.config/prometheus-llama/models.ini";

  prometheusLlamaCanonicalModels = [
    {
      section = "prometheus-main-sanity";
      file = "llama-3.2-1b-instruct-q4_k_m.gguf";
      alias = "llama-3.2-1b-instruct";
    }
  ];

  litellmRouterYaml = ''
    ---
    model_list:
      - model_name: llama-3.2-1b-instruct
        litellm_params:
          model: openai/prometheus-main-sanity
          api_base: http://${prometheusLlamaUpstreamHost}:${toString prometheusLlamaPort}/v1
          api_key: ${prometheusLlamaApiKey}
        order: 1
    router_settings:
      enable_pre_call_checks: true
      model_group_alias:
        main-sanity: llama-3.2-1b-instruct
        llama-3.2-1b-instruct: llama-3.2-1b-instruct
    litellm_settings:
      drop_params: true
      modify_params: true
      logging:
        level: info
  '';

  prometheusModelCatalogPath = ../../../data/config/pi/prometheus-model-catalog.json;
  prometheusModelCatalog = builtins.fromJSON (builtins.readFile prometheusModelCatalogPath);
  piAgentGatewayProvider =
    if builtins.hasAttr "provider" prometheusModelCatalog
    then prometheusModelCatalog.provider
    else "prometheus";
  piAgentGatewayApiKey = "sk-no-key-required";
  prometheusAliasPrefix = "${piAgentGatewayProvider}/";
  prometheusAliasPrefixLen = builtins.stringLength prometheusAliasPrefix;
  stripProviderPrefix = alias:
    let
      aliasLen = builtins.stringLength alias;
    in if aliasLen >= prometheusAliasPrefixLen && builtins.substring 0 prometheusAliasPrefixLen alias == prometheusAliasPrefix
       then builtins.substring prometheusAliasPrefixLen (aliasLen - prometheusAliasPrefixLen) alias
       else alias;
  prometheusModels =
    if builtins.hasAttr "models" prometheusModelCatalog
    then prometheusModelCatalog.models
    else [];
  prometheusCanonicalModelIds = builtins.map (model: model.id) prometheusModels;
  prometheusAliasQualifiedEnabled =
    if builtins.hasAttr "enabledAliases" prometheusModelCatalog
    then prometheusModelCatalog.enabledAliases
    else [];
  piAgentModelAliases = builtins.map stripProviderPrefix prometheusAliasQualifiedEnabled;
  piAgentEnabledModels =
    builtins.concatLists [
      (builtins.map (model: "${piAgentGatewayProvider}/${model}") prometheusCanonicalModelIds)
      prometheusAliasQualifiedEnabled
    ];
  prometheusModelMetadata =
    builtins.listToAttrs (
      builtins.map (model:
        {
          name = model.id;
          value = {
            descriptor =
              if builtins.hasAttr "descriptor" model
              then model.descriptor
              else model.id;
            reasoning =
              if builtins.hasAttr "reasoning" model
              then model.reasoning
              else false;
            contextWindow =
              if builtins.hasAttr "contextWindow" model
              then model.contextWindow
              else 128000;
            maxTokens =
              if builtins.hasAttr "maxTokens" model
              then model.maxTokens
              else 32768;
          };
        }
      ) prometheusModels
    );
  prometheusAliasTargets =
    if builtins.hasAttr "aliasTargets" prometheusModelCatalog
    then prometheusModelCatalog.aliasTargets
    else { };
  mkPrometheusModelEntry = modelId:
    let
      aliasTarget =
        if builtins.hasAttr modelId prometheusAliasTargets
        then builtins.getAttr modelId prometheusAliasTargets
        else null;
      canonicalId = if aliasTarget == null then modelId else aliasTarget;
      info = builtins.getAttr canonicalId prometheusModelMetadata;
      label =
        if aliasTarget == null
        then info.descriptor
        else "alias for ${info.descriptor}";
    in
    {
      id = modelId;
      name = "prometheus/${modelId} (${label})";
      reasoning = info.reasoning;
      input = [ "text" ];
      contextWindow = info.contextWindow;
      maxTokens = info.maxTokens;
      cost = {
        input = 0;
        output = 0;
        cacheRead = 0;
        cacheWrite = 0;
      };
    };
  piAgentGatewayBaseUrl =
    if builtins.hasAttr "serviceEndpoints" prometheusModelCatalog
      && builtins.hasAttr "canonical" prometheusModelCatalog.serviceEndpoints
    then prometheusModelCatalog.serviceEndpoints.canonical
    else "http://[202:68bc:1221:1b13:5397:2a56:4aea:d4a9]:11434/v1";
  piAgentModels = {
    providers = {
      ${piAgentGatewayProvider} = {
        baseUrl = piAgentGatewayBaseUrl;
        api = "openai-completions";
        apiKey = piAgentGatewayApiKey;
        models = builtins.map mkPrometheusModelEntry (prometheusCanonicalModelIds ++ piAgentModelAliases);
      };
    };
  };
  piAgentSettings = {
    defaultProvider =
      if builtins.hasAttr "defaultProvider" prometheusModelCatalog
      then prometheusModelCatalog.defaultProvider
      else piAgentGatewayProvider;
    defaultModel =
      if builtins.hasAttr "defaultModel" prometheusModelCatalog
      then prometheusModelCatalog.defaultModel
      else (if builtins.length piAgentModelAliases > 0 then builtins.head piAgentModelAliases else "main-deepseek");
    enabledModels = piAgentEnabledModels;
    hideThinkingBlock = false;
    defaultThinkingLevel = "medium";
    compaction = { enabled = false; };
  };
  piAgentModelsJson = toJSON piAgentModels;
  piAgentSettingsJson = toJSON piAgentSettings;

  AIPackages = with pkgs; [
    gemini-cli
    claude-code
    codex
    opencode
    llama-cpp
    litellmProxy
  ];

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
    ++ (optionals isCodeDev unixDeveloperPackages)
    ++ (optionals isMultimediaDev (
      with pkgs;
      [
        inkscape
      ]
    ));

  worldPackages = with world; [
    skrips.user
  ];

in
assert builtins.length prometheusModels > 0;
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
      enable = isCodeDev;
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

    swaync = {
      enable = sizedAtLeast.min;
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
      enable = isCodeDev;
      nix-direnv.enable = isCodeDev;
    };

    foot = {
      enable = true;
      settings = {
        main = {
          include = toString footThemeFile;
          font = "${terminalFontFamily}:size=14";
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
      userEmail = methods.emailAddress;
      userName = name;
      signing = mkIf hasPreCriome {
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
      enable = isCodeDev;
    };

    jujutsu = {
      enable = isCodeDev;
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
      enable = isCodeDev;
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

    # TODO broken
    zed-editor = {
      enable = isCodeDev;
      package = pkgs.zed-editor;
      extraPackages = with pkgs; [ ];
      userKeymaps = optionalAttrs useColemak colemakZedKeys;
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

    bottom = {
      enable = true;
      settings = { };
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

      initContent =
        builtins.readFile ../nonNix/zshrc
        + ''
          if [[ $options[zle] = on ]]; then
          . ${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.zsh
          fi
        ''
        + (optionalString useColemak (builtins.readFile ../nonNix/colemak.zsh));
    };

    zoxide.enable = true;
  };

  home = {
    packages = fontPackages ++ nixpkgsPackages ++ worldPackages ++ AIPackages;

    activation = optionalAttrs isOuranosNode {
      removeLegacyLitellmGateway = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        export XDG_RUNTIME_DIR="/run/user/$(id -u)"
        systemctl --user stop litellm-gateway.service 2>/dev/null || true
        systemctl --user disable litellm-gateway.service 2>/dev/null || true
        systemctl --user daemon-reload 2>/dev/null || true
        rm -f ${homeDir}/.config/litellm-router.yaml
      '';
    };

    pointerCursor = {
      package = pkgs.vanilla-dmz;
      name = "Vanilla-DMZ";
    };

    file =
      {
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
      }
      // (optionalAttrs isOuranosNode {
        ".pi/agent/models.json".text = piAgentModelsJson;
        ".pi/agent/settings.json".text = piAgentSettingsJson;
      })
      // (optionalAttrs isPrometheusNode {
        ".config/litellm-router.yaml".text = litellmRouterYaml;
        ".config/prometheus-llama/.keep".text = "";
        ".local/share/prometheus-llama/.keep".text = "";
      });
  };

  systemd = {
    user.services = { };
  };

  xdg = {
    configFile = {
      "fontconfig/conf.d/10-CriomOS-fonts-paths.conf".text = mkFontConf;
    };

    mimeApps = {
      enable = true;
      defaultApplications =
        let
          defaultBrowser = "chromium.desktop";
          defaultMailer = "evolution.desktop";
          defaultAudioPlayer = "mpv.desktop";
        in
        {
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
