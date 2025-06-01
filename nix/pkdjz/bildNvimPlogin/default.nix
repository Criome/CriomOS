{
  lib,
  stdenv,
  neovim,
}:
let
  inherit (builtins) elem all;

  allowedComponents = [
    "bin"
    "lua"
    "filetype.vim"
    "scripts.vim"
    "autoload"
    "colors"
    "doc"
    "ftplugin"
    "indent"
    "keymap"
    "plugin"
    "queries"
    "rplugin"
    "syntax"
  ];

in
arguments@{
  pname,
  version,
  src,
  namePrefix ? "nvimPlogin",
  unpackPhase ? "",
  configurePhase ? ":",
  buildPhase ? ":",
  installPhase ? "",
  preInstall ? "",
  postInstall ? "",
  components ? [ ],
  ...
}:
assert lib.assertMsg (all (
  c: elem c allowedComponents
) components) "Component not allowed in: ${toString components}";
let
  srcDirs = builtins.readDir src;
  checkSrcComponent = dirName: fileType: lib.optionalString (fileType == "directory") dirName;
  srcComponents = lib.mapAttrsToList checkSrcComponent srcDirs;
  components = lib.intersectLists srcComponents (arguments.components or allowedComponents);

in
stdenv.mkDerivation (
  arguments
  // {
    name = builtins.concatStringsSep "-" [
      namePrefix
      pname
      version
    ];

    inherit
      unpackPhase
      configurePhase
      buildPhase
      preInstall
      postInstall
      components
      ;

    installPhase =
      ''
        runHook preInstall
      ''
      + (
        if ((arguments.installPhase or "") != "") then
          arguments.installPhase
        else
          ''
            mkdir -p $out
            for dir in ''${components[@]}; do
            cp -r $dir $out
            done
          ''
      )
      # build help tags
      + ''
        if [ -d "$out/doc" ]; then
        echo "Building help tags"
        if ! ${neovim}/bin/nvim -N -u NONE -i NONE -n -E -s -V1 -c "helptags $out/doc" +quit!; then
        echo "Failed to build help tags!"
        exit 1
        fi
        else
        echo "No docs available"
        fi

        runHook postInstall
      '';
  }
)
