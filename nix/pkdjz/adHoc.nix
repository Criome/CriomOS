hob:
let
  inherit (builtins) mapAttrs;

in
{
  exportJSON = {
    lambda = { }: name: datom: builtins.toFile name (builtins.toJSON datom);
  };

  base16-styles = {
    lambda =
      { src, stdenv }:
      stdenv.mkDerivation {
        name = "base16-styles";
        inherit src;
        phases = [
          "unpackPhase"
          "installPhase"
        ];
        installPhase = ''
          mkdir -p $out/lib
          cp -R ./{scss,css,sass} $out/lib
        '';
      };
  };

  flake-registry = {
    lambda = { src, copyPathToStore }: copyPathToStore (src + /flake-registry.json);
  };

  jumpdrive = {
    mods = [
      "pkgs"
      "pkdjz"
    ];
    src = null;
    lambda =
      {
        stdenv,
        fetchurl,
        mksh,
        writeScriptBin,
        mfgtools,
      }:
      let
        mkRelease =
          name: versionAndNarHashes:
          let
            inherit (versionAndNarHashes) version narHash;

            url = "https://github.com/dreemurrs-embedded/Jumpdrive/releases/download/${version}/${name}.tar.xz";

            src = fetchurl {
              inherit url;
              hash = narHash;
            };

            launcherName = "jumpdrive-" + name;
            dataDirectorySuffix = "/share/jumpdrive/${name}";

            dataPkgName = name + "-data";

            dataPkg = stdenv.mkDerivation {
              name = dataPkgName;
              inherit src;
              phases = [
                "unpackPhase"
                "installPhase"
              ];

              unpackPhase = "tar xf $src";

              installPhase = ''
                mkdir -p $out${dataDirectorySuffix}
                cp -R ./* $out${dataDirectorySuffix}
              '';
            };

            dataDirectory = dataPkg + dataDirectorySuffix;

            launcherScript = writeScriptBin launcherName ''
              #!${mksh}/bin/mksh
              cd ${dataDirectory}
              ${mfgtools}/bin/uuu ${name}.lst
            '';

          in
          launcherScript;

        releasesNarHashes = {
          purism-librem5 = {
            version = "0.8";
            narHash = "sha256-tEtl16tyu/GbAWceDXZTP4R+ajmAksIzwmwlWYZkTYc=";
          };
        };

        releases = mapAttrs mkRelease releasesNarHashes;

      in
      releases;
  };

  ndi = {
    lambda =
      {
        src,
        lib,
        stdenv,
        requireFile,
        avahi,
        obs-studio-plugins,
      }:
      let
        version = "5.5.x";
        majorVersion = builtins.head (builtins.splitVersion version);
        installerName = "Install_NDI_SDK_v${majorVersion}_Linux";

      in
      stdenv.mkDerivation rec {
        pname = "ndi";
        inherit version src;

        buildInputs = [ avahi ];

        buildPhase = ''
          echo y | ./${installerName}.sh
        '';

        installPhase = ''
          mkdir $out
          cd "NDI SDK for Linux";
          mv bin/x86_64-linux-gnu $out/bin
          for i in $out/bin/*; do
            patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" "$i"
          done
          patchelf --set-rpath "${avahi}/lib:${stdenv.cc.libc}/lib" $out/bin/ndi-record
          mv lib/x86_64-linux-gnu $out/lib
          for i in $out/lib/*; do
            if [ -L "$i" ]; then continue; fi
            patchelf --set-rpath "${avahi}/lib:${stdenv.cc.libc}/lib" "$i"
          done
          mv include examples $out/
          mkdir -p $out/share/doc/${pname}-${version}
          mv licenses $out/share/doc/${pname}-${version}/licenses
          mv logos $out/share/doc/${pname}-${version}/logos
          mv documentation/* $out/share/doc/${pname}-${version}/
        '';

        # Stripping breaks ndi-record.
        dontStrip = true;

        passthru.updateScript = ./update.py;

        meta = {
          homepage = "https://ndi.tv/sdk/";
          description = "NDI Software Developer Kit";
          platforms = [ "x86_64-linux" ];
          hydraPlatforms = [ ];
        };
      };
  };

  netresolve = {
    lambda =
      {
        src,
        stdenv,
        bash,
        automake,
        autoconf,
        pkg-config,
        libtool,
        c-ares,
        libasyncns,
      }:
      stdenv.mkDerivation {
        pname = "netresolve";
        version = src.shortRev;
        inherit src;
        nativeBuildInputs = [
          pkg-config
          autoconf
          automake
          libtool
        ];
        buildInputs = [
          c-ares
          libasyncns
        ];
        postPatch = ''
          substituteInPlace autogen.sh --replace "/bin/bash" "${bash}/bin/bash"
        '';
        configureScript = "./autogen.sh";
      };
  };

  nightlyRustDevEnv = {
    src = hob.rust-overlay;
    mods = [ "pkgs" ];
    lambda =
      { src, pkgs }:
      let
        rust-bin = src.lib.mkRustBin { } pkgs;
      in
      rust-bin.fromRustupToolchain {
        channel = "nightly";
        components = [
          "rust-analyzer"
          "rust-src"
        ];
      };
  };

  noi = {
    src = null;
    lambda =
      {
        lib,
        appimageTools,
        fetchurl,
      }:

      appimageTools.wrapType2 rec {
        pname = "noi";
        version = "0.4.0";

        src = fetchurl {
          url = "https://github.com/lencx/Noi/releases/download/v${version}/Noi_linux_${version}.Appimage";
          hash = "sha256-ZwI1MpEoQn48zaan/GB7St6b15jtPHjwoUfD6bPkA3A=";
        };

        extraInstallCommands =
          let
            contents = appimageTools.extract { inherit pname version src; };
          in
          ''
            install -m 644 -D ${contents}/Noi.desktop -t $out/share/applications
            echo "Icon=noi" >> $out/share/applications/Noi.desktop
            install -m 644 -D ${contents}/usr/lib/noi/resources/icons/icon.png \
              $out/share/icons/hicolor/512x512/apps/noi.png
          '';

        meta = {
          description = "AI-enhanced, customizable browser";
          homepage = "https://noi.nofwl.com";
          license = lib.licenses.unfree;
          sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
          mainProgram = "noi";
        };
      };
  };

  davinci-resolve = {
    mods = [ "pkgs" ];
    lambda =
      {
        davinci-resolve-studio,
        hexdump,
        replaceDependencies,
      }:
      let
        nonFhsOriginalDavici = davinci-resolve-studio.passthru.davinci;
        davinciPatched = nonFhsOriginalDavici.overrideAttrs (
          finalAttrs: prevAttrs: {
            # https://stackoverflow.com/a/17168777
            preFixup = ''
              pattern="\x55\x41\x57\x41\x56\x53\x48\x83\xec.\x49\x89\xfe\xc7\x47\x34\xff\xff\xff\xff\x85\xf6\x0f\x84....\x89\xf5\x81\xfe\x13\xfc\xff\xff\x0f\x85"
              offset=23
              file="$out/bin/resolve"
              matches=$(LANG=C grep -obUaP "$pattern" "$file")
              matchcount=$(echo "$matches" | wc -l)
              if [[ -z $matches ]]; then echo "pattern not found";
                elif [[ $matchcount -ne 1 ]]; then echo "pattern returned $matchcount matches instead of 1";
              else
                patternOffset=$(echo $matches | cut -d: -f1)
                instructionOffset=$(($patternOffset + $offset))
                echo "patching byte '0x$(${hexdump}/bin/hexdump -s $instructionOffset -n 1 -e '/1 "%02x"' "$file")' at offset $instructionOffset"
                echo -en "\x85" | dd conv=notrunc of="$file" bs=1 seek=$instructionOffset count=1;
              fi
            '';
          }
        );
      in
      replaceDependencies {
        drv = davinci-resolve-studio;
        replacements = [
          {
            oldDependency = nonFhsOriginalDavici;
            newDependency = davinciPatched;
          }
        ];
      };
  };

  skylendar = {
    src = null;
    lambda =
      { stdenv, fetchurl }:
      let
        pname = "skylendar";
        version = "5.1.1pn";
      in
      stdenv.mkDerivation {
        inherit pname version;
        src = fetchurl {
          url = "mirror://sourceforge/skylendar/${pname}-${version}.tar.xz";
          sha256 = "sha256-m7LvZsEbTz5n2wiO7WPuASQLRbj3eEPFuvkPs9AOE7U=";
        };
      };
  };

  tree-sitter-capnp = {
    mods = [ "pkgs" ];
    src = hob.tree-sitter-capnp;

    lambda =
      {
        src,
        stdenv,
        tree-sitter,
      }:

      stdenv.mkDerivation {
        pname = "tree-sitter-capnp";
        inherit src;
        version = src.shortRev;

        nativeBuildInputs = [ tree-sitter ];

        buildPhase = ''
          runHook preBuild
          $CC -fPIC -c -I. -O2 src/parser.c -o parser.o
          $CC -shared -o libtree-sitter-capnp.so parser.o
          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall
          mkdir -p $out/lib $out/queries
          cp -v libtree-sitter-capnp.so $out/lib/
          cp -rv queries/* $out/queries/
          runHook postInstall
        '';
      };
  };

  tree-sitter-cozo = {
    mods = [ "pkgs" ];
    src = hob.tree-sitter-cozo;

    lambda =
      {
        src,
        pkgs,
      }:

      src.packages.${pkgs.system}.default;
  };

  videomass.lambda =
    {
      python3,
      ffmpeg-full,
      wrapGAppsHook,
      fetchPypi,
    }:
    python3.pkgs.buildPythonPackage rec {
      pname = "videomass";
      version = "6.1.12";
      pyproject = true;

      src = fetchPypi {
        inherit pname version;
        hash = "sha256-gbJcnUilDcTgOVq/6t5wJw+l8b8IsMoSgePrcUu1PMo=";
      };

      build-system = with python3.pkgs; [
        babel
        hatchling
        wheel
        setuptools
      ];

      dependencies = with python3.pkgs; [
        ffmpeg-full
        pypubsub
        wxpython
        requests
      ];

      buildInputs = [ wrapGAppsHook ];
    };

  wireguardNetresolved = {
    mods = [
      "pkgs"
      "pkdjz"
    ];
    src = null;
    lambda =
      {
        wireguard-tools,
        makeWrapper,
        netresolve,
      }:
      let
        netresolveLibPath = "${netresolve}/lib";
        netresolvePreloads = "libnetresolve-libc.so.0 libnetresolve-asyncns.so.0";
      in
      wireguard-tools.overrideAttrs (attrs: {
        postInstall = ''
          wrapProgram $out/bin/wg \
            --prefix LD_LIBRARY_PATH : "${netresolveLibPath}" \
            --prefix LD_PRELOAD : "${netresolvePreloads}"
        '';
      });
  };

}
