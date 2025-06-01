{
  lib,
  systemd,
  cryptsetup,
  llvmPackages,
  pkg-config,
  utillinux,
  cmake,
  python2,
  fontconfig,
  bzip2,
  freetype,
  expat,
}:
let
  inherit (lib) concatMapStringsSep;

  inherit (llvmPackages) libclang;

  cryptsetupDev = cryptsetup.dev;

  clang = llvmPackages.clang-unwrapped;

  mkClangIncludes = list: concatMapStringsSep " " (x: "--include-directory=${x}") list;

in
{
  pkg-config = attrs: {
    buildInputs = [ pkg-config ];
  };

  libudev-sys = attrs: {
    PKG_CONFIG_PATH = "${systemd.dev}/lib/pkg-config";
    buildInputs = [
      pkg-config
      systemd.dev
    ];
  };

  libcryptsetup-rs-sys = attrs: {
    PKG_CONFIG_PATH = "${cryptsetupDev}/lib/pkg-config";
    LIBCLANG_PATH = "${libclang}/lib";
    BINDGEN_EXTRA_CLANG_ARGS = mkClangIncludes [
      "${cryptsetupDev}/include"
      "${clang}/lib/clang/${clang.version}/include/"
    ];
    buildInputs = [
      pkg-config
      cryptsetupDev
      libclang
    ];
  };

  libcryptsetup-rs = attrs: {
    buildInputs = [
      pkg-config
      cryptsetupDev
    ];
  };

  libstratis = attrs: {
    buildInputs = [
      pkg-config
      cryptsetupDev
      utillinux
    ];
  };

  expat-sys = attrs: {
    buildInputs = [
      pkg-config
      expat
      cmake
    ];
  };

  skia-bindings = attrs: {
    buildInputs = [ python2 ];
  };

  servo-fontconfig-sys = attrs: {
    buildInputs = [
      pkg-config
      fontconfig
    ];
  };

  bzip2-sys = attrs: {
    buildInputs = [
      pkg-config
      bzip2
    ];
  };

  freetype-sys = attrs: {
    buildInputs = [
      pkg-config
      freetype
      cmake
    ];
  };

}
