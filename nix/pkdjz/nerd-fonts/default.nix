{
  lib,
  stdenv,
  fetchzip,
  fd,
}:
let
  version = "2.1.0";

  mkNerdFont =
    {
      fontName,
      regexMatch ? "",
      sha256,
      globExcludes ? [ ],
    }:
    stdenv.mkDerivation {
      name = "${fontName}-nerdfont-${version}";

      src = fetchzip {
        url = "https://github.com/ryanoasis/nerd-fonts/releases/download/v${version}/${fontName}.zip";
        inherit sha256;
        stripRoot = false;
      };

      nativeBuildInputs = [ fd ];

      installPhase =
        let
          regex = if (regexMatch == "") then ".*" else regexMatch;
          excludes = lib.optionalString (globExcludes != [ ]) (
            lib.concatMapStringsSep " " (x: "--exclude '${x}'") globExcludes
          );
        in
        ''
          IFS="
          "
          installDir=$out/share/fonts/${fontName}-nerdfont
          mkdir --parents $installDir
          wantedFonts=`fd --extension otf --exclude '*Windows*' ${excludes} '${regex}' $src`
          for font in $wantedFonts
          do
            cp $font $installDir/
          done
        '';
    };

in
{
  firaCode = mkNerdFont {
    fontName = "FiraCode";
    regexMatch = "Fira Code";
    globExcludes = [ "*Mono*" ];
    sha256 = "0k064h89ynbbqq5gvisng2s0h65ydnhr6wzx7hgaw8wfbc3qayvp";
  };

  firaCodeMono = mkNerdFont {
    fontName = "FiraMono";
    sha256 = "0f2daidakhmbbd5ph6985rghjmr87k7xzmmmf9n851dxvfyndsgl";
  };

}
