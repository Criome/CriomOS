with builtins;

rec {

  callWith =
    lambda: closure:
    let
      requiredInputs = functionArgs lambda;
      inputs = intersectAttrs requiredInputs closure;
    in
    lambda inputs;

  highestOf = list: tail (sort lessThan list);

  importJSON = path: fromJSON (readFile path);

  lowestOf = list: head (sort lessThan list);

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
