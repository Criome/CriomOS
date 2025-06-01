with builtins;
rec {
  exportJSON = name: datom: toFile name (toJSON datom);

  importJSON = path: fromJSON (readFile path);

  matchSize =
    size: ifNon: ifMin: ifMed: ifMax:
    let
      sizedAtLeast = mkSizeAtLeast size;
    in
    if sizedAtLeast.max then
      ifMax
    else if sizedAtLeast.med then
      ifMed
    else if sizedAtLeast.min then
      ifMin
    else
      ifNon;

  mkSizeAtLeast = size: {
    min = size >= 1;
    med = size >= 2;
    max = size == 3;
  };

}
