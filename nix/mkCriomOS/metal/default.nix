{
  lib,
  horizon,
  config,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkIf
    optional
    optionals
    optionalString
    optionalAttrs
    ;
  inherit (horizon.node) typeIs;
  inherit (horizon.node.machine) model;
  inherit (horizon.node.methods)
    behavesAs
    sizedAtLeast
    chipIsIntel
    modelIsThinkpad
    useColemak
    computerIs
    ;

  centerIgnoresSuspend = typeIs.center || typeIs.largeAI;

  enableWaydroid = sizedAtLeast.max && behavesAs.edge;

  brightnessCtl = pkgs.callPackage ../../brightness-ctl.nix { };

  # TODO
  hasTouchpad = true;

  needsIntelThrottlingFix = model == "ThinkPadT14Intel";

  modelFirmwareIndex = with pkgs; {
    ThinkPadE15Gen2Intel = [ sof-firmware ];
    ThinkPadT14Intel = [ sof-firmware ];
    rpi3B = [ raspberrypiWirelessFirmware ];
  };

  modelSpecificFirmware = modelFirmwareIndex."${model}" or [ ];

  modelSpecificPowerTweaks = {
    ThinkPadE15Gen2Intel = {
      powerUpCommands = ''
        echo 0 > /sys/devices/platform/thinkpad_acpi/leds/tpacpi::power/brightness
      '';
      powerDownCommands = "";
    };
  };

  hasModelSpecificPowerTweaks = model != null && builtins.hasAttr model modelSpecificPowerTweaks;

  modelKernelModulesIndex = {
    ThinkPadE15Gen2Intel = [
      "nvme"
      "thunderbolt"
    ];
    ThinkPadT14Intel = [
      "nvme"
      "thunderbolt"
      "sd_mod"
    ];
    ThinkPadT14Gen5Intel = [
      "nvme"
      "thunderbolt"
      "sd_mod"
      "xe"
    ];
    ThinkPadX250 = [
      "usb_storage"
      "rtsx_pci_sdmmc"
    ];
  };

  modelSpecificKernelModules = modelKernelModulesIndex."${model}" or [ ];

  waydroidPackages = with pkgs; [
    # Investigate: Clipboard passing still not working reliably
    wl-clipboard
    python3Packages.pyclip
  ];

  # TODO - sort out different `sizedatleast` sets
  printingDriversPkgs = lib.optionals sizedAtLeast.max (
    with pkgs;
    [
      gutenprint # Drivers for many different printers from many different vendors.
      gutenprintBin # Additional, binary-only drivers for some printers.
      hplip # Drivers for HP printers.
      hplipWithPlugin # Drivers for HP printers, with the proprietary plugin.
      postscript-lexmark # Postscript drivers for Lexmark
      samsung-unified-linux-driver # Proprietary Samsung Drivers
      splix # Drivers for printers supporting SPL (Samsung Printer Language).
      brlaser # Drivers for some Brother printers
      brgenml1lpr # Generic drivers for more Brother printers
      brgenml1cupswrapper # ^^^
      epson-escpr2 # Drivers for Epson AirPrint devices
      epson-escpr # Drivers for some other Epson devices
    ]
  );

  intelUtils = with pkgs; [
    libva-utils
    i7z
  ];

  isGenericModel = model == "all-x86-64";

  unknownIntelGpuError = if isGenericModel then [] else throw "Model ${model} missing in Intel GPU drivers lists";

  intelMediaDriverModels = [
    "ThinkPadT14Gen5Intel"
    "ThinkPadT14Intel"
  ];

  gpuUsesMediaDriver = isGenericModel || builtins.elem model intelMediaDriverModels;

  amdGpuModels = [
    "GMKtec EVO-X2"
  ];

  gpuUsesAmdGpu = isGenericModel || builtins.elem model amdGpuModels;

  treatAsIntel = chipIsIntel && !gpuUsesAmdGpu;

  gpuUsesVaapi = isGenericModel || builtins.elem model [
    "ThinkPadX230"
    "ThinkPadX240"
    "ThinkPadX250"
  ];

  intelMediaDrivers = with pkgs; [
    intel-media-driver
    intel-compute-runtime
    vpl-gpu-rt
  ];

  intelGpuDrivers =
    if gpuUsesVaapi then
      [ pkgs.intel-vaapi-driver ]
    else if gpuUsesMediaDriver then
      intelMediaDrivers
    else if treatAsIntel then
      unknownIntelGpuError
    else
      [ ];

in
{
  hardware = {
    cpu.intel.updateMicrocode = chipIsIntel;

    # Hack: TODO - tune per model, see `modelSpecificfirmware`
    enableAllFirmware = true;

    firmware = modelSpecificFirmware;

    ledger.enable = behavesAs.edge;

    graphics.extraPackages = optionals treatAsIntel intelGpuDrivers;
  };

  location.provider = if sizedAtLeast.min then "geoclue2" else "manual";

  boot = {
    extraModulePackages =
      [ ]
      ++ (optional modelIsThinkpad config.boot.kernelPackages.acpi_call)
      ++ (optional sizedAtLeast.max config.boot.kernelPackages.v4l2loopback);

    initrd = {
      availableKernelModules = [
        "xhci_pci"
        "usb_storage"
      ];
    };

    kernelModules = [ "coretemp" ] ++ modelSpecificKernelModules ++ (optional gpuUsesAmdGpu "amdgpu");

    extraModprobeConfig = (
      optionalString sizedAtLeast.max ''
        options v4l2loopback devices=2 card_label="camera","obs" exclusive_caps=1
      ''
    );

    kernelParams =
      lib.concatLists [
        (if computerIs.rpi3B then [
          "cma=32M"
          "console=ttyS0,115200n8"
          "console=ttyAMA0,11520n8"
          "console=tty0"
          "dtparam=audio=on"
        ] else [])
        # Apply broad largeAI tuning where relevant (keeps previous defaults
        # for largeAI machines). The targeted amdgpu.cwsr_enable=0 experiment
        # is intentionally restricted to the GMKtec EVO-X2 model only.
        (if typeIs.largeAI then [
          "amd_iommu=off"
          "amdgpu.gttsize=131072"
          "ttm.pages_limit=33554432"
          "ttm.page_pool_size=33554432"
        ] else [])
        (if model == "GMKtec EVO-X2" then [
          # Disable AMGPU CWSR on the Strix Halo (GMKtec EVO-X2) to work
          # around KFD/ROCm instability observed on that specific model.
          "amdgpu.cwsr_enable=0"
        ] else [])
      ];

  };

  powerManagement =
    let
      pmBase = {
        powertop.enable = true;
      };
      intelPowerCommands = optionalAttrs chipIsIntel {
        # Linux path expects firmware configured with a small fixed UMA (UMA_SPECIFIED), a modest framebuffer (≈1G/512MiB), and Linux-side GTT/TTM tuning.
        powerUpCommands = ''
          echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo
        '';
      };
    in pmBase
      // (optionalAttrs hasModelSpecificPowerTweaks modelSpecificPowerTweaks."${model}")
      // intelPowerCommands;

  programs = { };

  console.useXkbConfig = useColemak;

  environment = {
    systemPackages =
      with pkgs;
      [ lm_sensors ]
      ++ optionals chipIsIntel intelUtils
      ++ optionals sizedAtLeast.max [ v4l-utils ]
      ++ optionals enableWaydroid waydroidPackages
      ++ optionals typeIs.largeAI [
        curl
        jq
        htop
      ];

  };

  users.groups.plugdev = { };

  services = {
    # TODO
    fwupd.enable = true;

    geoclue2 = {
      enable = sizedAtLeast.min;
      enableDemoAgent = lib.mkOverride 0 true;
      geoProviderUrl = "https://beacondb.net/v1/geolocate";
      appConfig.redshift = {
        isAllowed = true;
        isSystem = true;
      };
    };

    localtimed = {
      enable = sizedAtLeast.min;
    };

    printing = {
      enable = true;
      cups-pdf.enable = sizedAtLeast.min;
      drivers = printingDriversPkgs;
    };

    throttled.enable = needsIntelThrottlingFix;

    udev.extraRules = ''
      # USBasp - USB programmer for Atmel AVR controllers
      SUBSYSTEM=="usb", ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="05dc", GROUP="plugdev"
      # Pro-micro kp-boot-bootloader - Ergodone keyboard
      SUBSYSTEM=="usb", ATTRS{idVendor}=="1209", ATTRS{idProduct}=="bb05", GROUP="plugdev"
      # TODO - Broken
      # SUBSYSTEM!="usb", GOTO="librem5_rules_end"
      # Librem 5 USB flash
      # ATTR{idVendor}=="1fc9", ATTR{idProduct}=="012b", GROUP+="plugdev", TAG+="uaccess"
      # ATTR{idVendor}=="0525", ATTR{idProduct}=="a4a5", GROUP+="plugdev", TAG+="uaccess"
      # ATTR{idVendor}=="0525", ATTR{idProduct}=="b4a4", GROUP+="plugdev", TAG+="uaccess"
      # ATTR{idVendor}=="316d", ATTR{idProduct}=="4c05", GROUP+="plugdev", TAG+="uaccess"
      # LABEL="librem5_rules_end"
    '';

    libinput = {
      enable = hasTouchpad;
      touchpad = {
        naturalScrolling = true;
        tapping = true;
      };
    };

    xserver = {
      xkb.variant = optionalString useColemak "colemak";
      xkb.options = "caps:ctrl_modifier, altwin:swap_alt_win";

      autoRepeatDelay = 200;
      autoRepeatInterval = 28;

      digimend.enable = false; # !typeIs.center; # Broken
    };

    logind.settings.Login = {
      HandleLidSwitch = if centerIgnoresSuspend then "ignore" else "suspend";
      HandleLidSwitchExternalPower = if behavesAs.lowPower then "suspend" else "ignore";
    };

    thinkfan = mkIf modelIsThinkpad {
      enable = true;
      # TODO
      sensors = [
        {
          type = "hwmon";
          query = "/sys/devices/virtual/thermal/thermal_zone0/temp";
        }
      ];
    };

    udisks2.enable = true;

    acpid = {
      enable = true;

      handlers = {
        mute = {
          action = ''
            wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
          '';
          event = "button/mute";
        };
        volumeup = {
          action = ''
            wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
          '';
          event = "button/volumeup";
        };
        volumedown = {
          action = ''
            wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
          '';
          event = "button/volumedown";
        };
        mutemic = {
          action = ''
            wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
          '';
          event = "button/f20";
        };
        brightnessup = {
          action = ''
            ${brightnessCtl}/bin/brightness-ctl up
          '';
          event = "video/brightnessup";
        };
        brightnessdown = {
          action = ''
            ${brightnessCtl}/bin/brightness-ctl down
          '';
          event = "video/brightnessdown";
        };
      };

    };
  };

  virtualisation = {
    libvirtd.enable = (sizedAtLeast.max && behavesAs.edge);
    waydroid.enable = enableWaydroid;
    spiceUSBRedirection.enable = sizedAtLeast.max;
  };
}
