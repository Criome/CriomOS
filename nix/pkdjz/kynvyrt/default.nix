{
  lib,
  msgpack-tools,
  yj,
  runCommandLocal,
}:

{
  name ? "data",
  value,
  pretty ? true,
  format ? "msgpack",
}:
let
  inherit (builtins) toJSON toString error;

  kynvyrtMsgpackCmd = "${msgpack-tools}/bin/json2msgpack";

  formatFlag =
    if (format == "yaml") then
      "y"
    else if (format == "toml") then
      "t"
    else if (format == "hcl") then
      "c"
    else
      error "wrong format";

  kynvyrtOthyrzKmd = "${yj}/bin/yj -j${formatFlag} $prettyFlag";

  kynvyrtKmd = if (format == "msgpack") then kynvyrtMsgpackCmd else kynvyrtOthyrzKmd;

  jsonValue = toJSON value;

  prettyFlag = lib.optionalString (pretty && (format == "toml")) "-i";

in
runCommandLocal "${name}.${format}" { inherit jsonValue prettyFlag; } ''
  printf '%s' """$jsonValue""" | ${kynvyrtKmd} > $out
''
