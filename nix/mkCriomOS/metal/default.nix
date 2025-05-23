{
  lib,
  horizon,
  config,
  pkgs,
  ...
}:
let
  inherit (builtins) readFile genList concatStringsSep;
  inherit (lib)
    mkIf
    optional
    optionals
    optionalString
    optionalAttrs
    isOdd
    ;
  inherit (lib.generators) toINI;
  inherit (horizon.node) typeIs;
  inherit (horizon.node.machine) model cores;
  inherit (horizon.node.methods)
    sizedAtLeast
    tcipIzIntel
    modelIzThinkpad
    impozyzHaipyrThreding
    useColemak
    computerIs
    ;

  enableWaydroid = sizedAtLeast.max && !typeIs.router;

  # TODO
  hasTouchpad = true;

  hasQuickSyncSupport = model == "ThinkPadE15Gen2Intel";
  hasThunderbolt = model == "ThinkPadE15Gen2Intel";
  hasNvme = model == "ThinkPadE15Gen2Intel";
  requiresSofFirmware = model == "ThinkPadE15Gen2Intel";

  izX230 = model == "ThinkPadX230";
  izX240 = model == "ThinkPadX240";

  enabledExtendedPowerSave = true;

  cpuFreqGovernor = if enabledExtendedPowerSave then "powersave" else "schedutil";

  hasModelSpecificPowerTweaks = model == "ThinkPadE15Gen2Intel";

  modelSpecificPowerTweaks = {
    ThinkPadE15Gen2Intel = {
      powerUpCommands = ''
        echo 0 > /sys/devices/platform/thinkpad_acpi/leds/tpacpi::power/brightness
      '';
      powerDownCommands = "";
    };
  };

  soundCardIndex = {
    ThinkPadX230 = "PCH";
    ThinkPadX240 = "PCH";
  };

  mainSoundCard = soundCardIndex."${model}" or "0";

  modelKernelModulesIndex = {
    ThinkPadX250 = [
      "usb_storage"
      "rtsx_pci_sdmmc"
    ];
  };

  modelSpecificKernelModules = modelKernelModulesIndex."${model}" or [ ];

  # (Todo Hack)
  useVaapiIntel = true;
  hasOpenClSupport = sizedAtLeast.max;

  waydroidPackages = with pkgs; [
    wl-clipboard
    python3Packages.pyclip
  ];

  intelGraphicsPackages =
    optionals enableWaydroid waydroidPackages
    ++ optional useVaapiIntel pkgs.vaapiIntel
    ++ optional hasOpenClSupport pkgs.intel-compute-runtime;

in
{
  hardware = {
    cpu.intel.updateMicrocode = tcipIzIntel;

    firmware =
      with pkgs;
      [
        firmwareLinuxNonfree
        intel2200BGFirmware
        rtl8192su-firmware
        zd1211fw
        alsa-firmware
        libreelec-dvb-firmware
      ]
      ++ optional computerIs.rpi3B raspberrypiWirelessFirmware
      ++ optional requiresSofFirmware sof-firmware;

    ledger.enable = typeIs.edj;

    graphics.extraPackages =
      optionals tcipIzIntel intelGraphicsPackages
      ++ optional hasQuickSyncSupport pkgs.intel-media-driver;

  };

  location.provider = if sizedAtLeast.min then "geoclue2" else "manual";

  boot = {
    extraModulePackages =
      [ ]
      ++ (optional modelIzThinkpad config.boot.kernelPackages.acpi_call)
      ++ (optional sizedAtLeast.max config.boot.kernelPackages.v4l2loopback);

    initrd = {
      availableKernelModules =
        modelSpecificKernelModules ++ (optional hasThunderbolt "thunderbolt") ++ (optional hasNvme "nvme");
    };

    kernelModules = [ "coretemp" ];

    extraModprobeConfig = (
      optionalString sizedAtLeast.max ''
        options v4l2loopback devices=2 card_label="camera","obs" exclusive_caps=1
      ''
    );

    kernelParams =
      (optionals tcipIzIntel [ "intel_pstate=disable" ])
      ++ (optionals computerIs.rpi3B [
        "cma=32M"
        "console=ttyS0,115200n8"
        "console=ttyAMA0,11520n8"
        "console=tty0"
        "dtparam=audio=on"
      ]);

  };

  powerManagement = {
    inherit cpuFreqGovernor;
    powertop.enable = true;
  } // (optionalAttrs hasModelSpecificPowerTweaks modelSpecificPowerTweaks."${model}");

  programs = { };

  console.useXkbConfig = useColemak;

  environment = {
    systemPackages =
      with pkgs;
      [ lm_sensors ]
      ++ optionals tcipIzIntel [
        libva-utils
        i7z
      ]
      ++ optionals sizedAtLeast.max [ v4l-utils ];

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
    };

    udev.extraRules = ''
      # USBasp - USB programmer for Atmel AVR controllers
      SUBSYSTEM=="usb", ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="05dc", GROUP="plugdev"
      # Pro-micro kp-boot-bootloader - Ergodone keyboard
      SUBSYSTEM=="usb", ATTRS{idVendor}=="1209", ATTRS{idProduct}=="bb05", GROUP="plugdev"
      SUBSYSTEM!="usb", GOTO="librem5_rules_end"
      # Librem 5 USB flash
      ATTR{idVendor}=="1fc9", ATTR{idProduct}=="012b", GROUP+="plugdev", TAG+="uaccess"
      ATTR{idVendor}=="0525", ATTR{idProduct}=="a4a5", GROUP+="plugdev", TAG+="uaccess"
      ATTR{idVendor}=="0525", ATTR{idProduct}=="b4a4", GROUP+="plugdev", TAG+="uaccess"
      ATTR{idVendor}=="316d", ATTR{idProduct}=="4c05", GROUP+="plugdev", TAG+="uaccess"
      LABEL="librem5_rules_end"
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

      digimend.enable = false; # !typeIs.sentyr; # Broken
    };

    logind = {
      lidSwitch = if typeIs.sentyr then "ignore" else "suspend";
      lidSwitchExternalPower = if typeIs.edj then "suspend" else "ignore";
    };

    thinkfan = mkIf modelIzThinkpad {
      enable = true;
      levels = (
        if izX230 then
          [
            [
              0
              0
              60
            ]
            [
              1
              59
              62
            ]
            [
              2
              60
              64
            ]
            [
              3
              61
              66
            ]
            [
              6
              62
              69
            ]
            [
              7
              67
              85
            ]
            [
              127
              80
              32767
            ]
          ]
        else if izX240 then
          [
            [
              0
              0
              55
            ]
            [
              1
              49
              60
            ]
            [
              2
              51
              61
            ]
            [
              3
              53
              63
            ]
            [
              6
              56
              65
            ]
            [
              7
              60
              85
            ]
            [
              127
              80
              32767
            ]
          ]
        else
          [
            [
              0
              0
              55
            ]
            [
              1
              48
              60
            ]
            [
              2
              50
              61
            ]
            [
              3
              52
              63
            ]
            [
              6
              56
              65
            ]
            [
              7
              60
              85
            ]
            [
              127
              80
              32767
            ]
          ]
      );
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
        # TODO - increase interval rise
        brightnessup = {
          action = ''
            ${pkgs.light}/bin/light -A 1
          '';
          event = "video/brightnessup";
        };
        brightnessdown = {
          action = ''
            ${pkgs.light}/bin/light -U 1
          '';
          event = "video/brightnessdown";
        };
      };

    };
  };

  virtualisation = {
    libvirtd.enable = (sizedAtLeast.max && !typeIs.router);
    waydroid.enable = enableWaydroid;
    spiceUSBRedirection.enable = sizedAtLeast.max;
  };
}
