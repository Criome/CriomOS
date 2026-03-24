{
  lib,
  pkgs,
  criomos-lib,
  pkdjz,
  user,
  horizon,
  config,
  world,
  litellmProxy,
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
    isCodeDev
    isMultimediaDev
    ;
  inherit (user) githubId name methods;
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
      section = "prometheus-llama-3.2-1b-instruct";
      file = "llama-3.2-1b-instruct-q4_k_m.gguf";
      alias = "llama-3.2-1b-instruct";
    }
  ];

  litellmRouterYaml = ''
    ---
    model_list:
      - model_name: llama-3.2-1b-instruct
        litellm_params:
          model: openai/prometheus-llama-3.2-1b-instruct
          api_base: http://${prometheusLlamaUpstreamHost}:${toString prometheusLlamaPort}/v1
          api_key: ${prometheusLlamaApiKey}
        order: 1
      - model_name: nemotron-3-super-120b-a12b
        litellm_params:
          model: openai/prometheus-nemotron-3-super-120b-a12b
          api_base: http://${prometheusLlamaUpstreamHost}:11437/v1
          api_key: ${prometheusLlamaApiKey}
        order: 2
    router_settings:
      enable_pre_call_checks: false
      model_group_alias:
        llama-3.2-1b-instruct: llama-3.2-1b-instruct
        nemotron-3-super-120b-a12b: nemotron-3-super-120b-a12b
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
    else "http://[200:ca41:6b12:fba:d7bc:cfc6:4aaa:165f]:11434/v1";
  piAgentModels = {
    providers = {
      ${piAgentGatewayProvider} = {
        baseUrl = piAgentGatewayBaseUrl;
        api = "openai-completions";
        authRequired = false;
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
      else (if builtins.length piAgentModelAliases > 0 then builtins.head piAgentModelAliases else "qwen3.5-35b-a3b");
    enabledModels = piAgentEnabledModels;
    hideThinkingBlock = false;
    defaultThinkingLevel = "medium";
    compaction = { enabled = false; };
  };
  piAgentModelsJson = toJSON piAgentModels;
  piAgentSettingsJson = toJSON piAgentSettings;

  piAgent = inputs.llm-agents.packages.${pkgs.system}.pi or null;

  AIPackages = with pkgs; [
    gemini-cli
    claude-code
    codex
    opencode
    llama-cpp
    litellmProxy
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
    ++ (optionals isCodeDev unixDeveloperPackages)
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

  nightshift = pkgs.writeShellScriptBin "nightshift" ''
    case "''${1:-on}" in
      on)  ${busctlBin} --user set-property ${gammaRelayBus} Temperature q "''${2:-3500}" ;;
      off) ${busctlBin} --user set-property ${gammaRelayBus} Temperature q 6500 ;;
      *)   ${busctlBin} --user set-property ${gammaRelayBus} Temperature q "$1" ;;
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
          dark_mode = config.stylix.polarity == "dark";
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
        pager = "less -FR";
      };
    };

    direnv = {
      enable = isCodeDev;
      nix-direnv.enable = isCodeDev;
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
      enable = isCodeDev;
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
    packages = fontPackages ++ nixpkgsPackages ++ worldPackages ++ AIPackages ++ [
      nordvpnSeed
      pkgs.wl-gammarelay-rs
      nightshift
      brightness
    ];

    activation = { };

    file =
      {
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
      // (optionalAttrs (isOuranosNode || isPrometheusNode) {
        ".pi/agent/models.json".text = piAgentModelsJson;
        ".pi/agent/settings.json".text = piAgentSettingsJson;
        ".pi/settings.json" = {
          text = piAgentSettingsJson;
          force = true;
        };
      })
      // (optionalAttrs isPrometheusNode {
        ".config/litellm-router.yaml".text = litellmRouterYaml;
        ".config/prometheus-llama/.keep".text = "";
        ".local/share/prometheus-llama/.keep".text = "";
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

      nightshift-on = {
        Unit.Description = "Set warm color temperature at night";
        Service = {
          Type = "oneshot";
          ExecStart = "${pkgs.bash}/bin/bash -c '${busctlBin} --user set-property ${gammaRelayBus} Temperature q 3500'";
        };
      };

      nightshift-off = {
        Unit.Description = "Set neutral color temperature during day";
        Service = {
          Type = "oneshot";
          ExecStart = "${pkgs.bash}/bin/bash -c '${busctlBin} --user set-property ${gammaRelayBus} Temperature q 6500'";
        };
      };
    };

    user.timers = {
      nightshift-on = {
        Unit.Description = "Warm color temperature at 20:00";
        Timer = {
          OnCalendar = "*-*-* 20:00:00";
          Persistent = true;
        };
        Install.WantedBy = [ "timers.target" ];
      };

      nightshift-off = {
        Unit.Description = "Neutral color temperature at 07:00";
        Timer = {
          OnCalendar = "*-*-* 07:00:00";
          Persistent = true;
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };
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
