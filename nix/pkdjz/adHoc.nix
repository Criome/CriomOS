hob:
let
  inherit (builtins) mapAttrs;

in
{
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

        meta = with lib; {
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

  hyprland-relative-workspace = {
    src = null;
    lambda =
      {
        lib,
        rustPlatform,
        fetchFromGitHub,
      }:

      rustPlatform.buildRustPackage rec {
        pname = "hyprland-relative-workspace";
        version = "1.1.8-unstable-2023-04-25";

        src = fetchFromGitHub {
          owner = "CheesyPhoenix";
          repo = pname;
          rev = "708e9bf22f100a33948d7ab10bee390b2a454ff8";
          sha256 = "sha256-PN3t3sVIFz1dKVtBEFLmPO9YAhXpbWcT5uurkNqtFqc=";
        };

        cargoHash = "sha256-Jh8eXkj7109z9Sdk97Dy0Hsh5ulSgTrQVRYBvKq/P+I=";

        meta = with lib; {
          description = "GNOME-like workspace switching in Hyprland";
          homepage = "https://github.com/CheesyPhoenix/hyprland-relative-workspace";
          license = licenses.mit;
          maintainers = with maintainers; [ donovanglover ];
        };
      };
  };

  skylendar = {
    src = null;
    lambda =
      { stdenv, fetchurl }:
      let
        pname = "skylendar";
        version = "5.0nn";
      in
      stdenv.mkDerivation {
        inherit pname version;
        src = fetchurl {
          url = "mirror://sourceforge/skylendar/${pname}-${version}.tar.xz";
          sha256 = "sha256-j7iCCzHXwffHdhQcyzxPBvQK+RXaY3QSjXUtHu463fI=";
        };
      };
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
