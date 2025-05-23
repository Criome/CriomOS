{
  lib,
  stdenvNoCC,
  pijul,
  cacert,
}:

{
  name ? "",
  url,
  sha256,
  ancestor ? null,
}@arguments:

let
  caCertFile = "${cacert}/etc/ssl/certs/ca-bundle.crt";

in
stdenvNoCC.mkDerivation {
  inherit name url;

  outputHashAlgo = "sha256";
  outputHashMode = "recursive";
  outputHash = sha256;

  phases = [
    "buildPhase"
    "installPhase"
  ];

  nativeBuildInputs = [ pijul ];

  SSL_CERT_FILE = caCertFile;

  buildPhase = ''
    pijul clone -k $url
  '';

  installPhase = ''
    mkdir $out
    cp -R ./ $out
  '';
}
