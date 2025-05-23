let
  inherit (builtins)
    catAttrs
    attrNames
    hasAttr
    getAttr
    mapAttrs
    listToAttrs
    concatStringsSep
    foldl'
    elem
    length
    elemAt
    head
    tail
    filter
    concatMap
    sort
    lessThan
    fromJSON
    toJSON
    readFile
    toFile
    intersectAttrs
    functionArgs
    typeOf
    isAttrs
    deepSeq
    trace
    getFlake
    isList
    isFunction
    ;

in
rec {

  nameValuePair = name: value: { inherit name value; };

  getAttrs = names: attrs: genAttrs names (name: attrs.${name});

  genAttrs = names: f: listToAttrs (map (n: nameValuePair n (f n)) names);

  genNamedAttrs = names: f: listToAttrs (map (n: f n) names);

  zipAttrsWithNames =
    names: f: sets:
    listToAttrs (
      map (name: {
        inherit name;
        value = f name (catAttrs name sets);
      }) names
    );

  zipAttrsWith = f: sets: zipAttrsWithNames (concatMap attrNames sets) f sets;

  zipAttrs = zipAttrsWith (name: values: values);

  optional = cond: elem: if cond then [ elem ] else [ ];
  optionals = cond: elems: if cond then elems else [ ];

  foldl = foldl';

  optionalString = cond: string: if cond then string else "";

  concatMapStringsSep =
    sep: f: list:
    concatStringsSep sep (map f list);

  optionalAttrs = cond: set: if cond then set else { };

  hasAttrByPath =
    attrPath: e:
    let
      attr = head attrPath;
    in
    if attrPath == [ ] then
      true
    else if e ? ${attr} then
      hasAttrByPath (tail attrPath) e.${attr}
    else
      false;

  attrByPath =
    attrPath: default: e:
    let
      attr = head attrPath;
    in
    if attrPath == [ ] then
      e
    else if e ? ${attr} then
      attrByPath (tail attrPath) default e.${attr}
    else
      default;

  mapAttrs' = f: set: listToAttrs (map (attr: f attr set.${attr}) (attrNames set));

  concatMapAttrs = f: set: listToAttrs (concatMap (attr: f attr set.${attr}) (attrNames set));

  invertValueName = set: mapAttrs' (n: v: nameValuePair "${v}" n) set;

  filterAttrs =
    pred: set:
    listToAttrs (
      concatMap (
        name:
        let
          v = set.${name};
        in
        if pred name v then [ (nameValuePair name v) ] else [ ]
      ) (attrNames set)
    );

  remove = e: filter (x: x != e);

  intersectLists = e: filter (x: elem x e);

  subtractLists = e: filter (x: !(elem x e));

  unique =
    list:
    if list == [ ] then
      [ ]
    else
      let
        x = head list;
      in
      [ x ] ++ unique (remove x list);

  flatten = x: if isList x then concatMap (y: flatten y) x else [ x ];

  flattenNV = list: map (x: x.value) list;

  mapAttrsToList = f: attrs: map (name: f name attrs.${name}) (attrNames attrs);

  attrsToList = attrs: map (a: attrs.${a}) (attrNames attrs);

  attrToNamedList = attrs: mapAttrsToList (name: value: value // { inherit name; }) attrs;

  makeSearchPath =
    subDir: paths: concatStringsSep ":" (map (path: path + "/" + subDir) (filter (x: x != null) paths));

  getSpecies =
    datom:
    assert mesydj (isAttrs datom) "Species-Datom is not Attrs";
    let
      names = attrNames datom;
    in
    assert mesydj ((length names) == 1) "Species-Datom has more than one Attr";
    let
      name = head names;
    in
    {
      inherit name;
      value = datom.${name};
    };

  matc =
    matcSet: datom:
    let
      species = getSpecies datom;
      inherit (species) name value;
      matcValiu = matcSet.${name};
    in
    if isFunction matcValiu then matcValiu value else value;

  indeksSpecies =
    species:
    let
      aylSpecies = map getSpecies species;
      names = unique (map (s: s.name) aylSpecies);
      meikNamedYrei = name: map (s: s.value) (filter (s: s.name == name) aylSpecies);
    in
    genAttrs names meikNamedYrei;

  matchEnum = enum: match: genAttrs enum (name: name == match);

  louestOf = yrei: head (sort lessThan yrei);

  haiystOf = yrei: tail (sort lessThan yrei);

  importJSON = path: fromJSON (readFile path);

  eksportJSON = name: datom: toFile name (toJSON datom);

  getFleik =
    fleik:
    let
      url = concatStringsSep "" [
        (optionalString (fleik.type == "git") "git+")
        fleik.url
        "?"
        (optionalString (fleik ? ref) "ref=${fleik.ref}")
        (optionalString (fleik ? rev) "${optionalString (fleik ? ref) "&"}rev=${fleik.rev}")
      ];
      noFlakeNix = fleik ? flake && (!fleik.flake);
      kol = if noFlakeNix then fetchTree else getFlake;
    in
    kol url;

  kopiNiks = path: toFile (baseNameOf path) (readFile path);

  mkIf = condition: content: {
    _type = "if";
    inherit condition content;
  };

  mesydj = pred: msj: if pred then true else trace msj false;

  traceSeq = x: y: trace (builtins.deepSeq x x) y;

  mkStoreHashPrefix = object: builtins.substring 11 7 object.outPath;

  mkImplicitVersion =
    src:
    assert mesydj (
      (hasAttr "shortRev" src) || (hasAttr "narHash" src)
    ) "Missing implicit version hints";
    let
      shortHash = cortHacString src.narHash;
    in
    src.shortRev or shortHash;

  hazSingylAttr = attrs: (length (attrNames attrs)) == 1;

  cortHacPath = path: builtins.hashFile "sha256" path;

  mkStringHash = String: builtins.hashString "sha256" String;

  cortHacString = string: builtins.substring 0 7 (mkStringHash string);

  cortHacFile = file: builtins.substring 0 7 (builtins.hashFile "sha256" file);

  arkSistymMap = {
    x86-64 = "x86_64-linux";
    amd64 = "x86_64-linux";
    i686 = "i686-linux";
    x86 = "i686-linux";
    aarch64 = "aarch64-linux";
    arm64 = "aarch64-linux";
    armv8 = "aarch64-linux";
    armv7l = "armv7l-linux";
    armv = "armv7l-linux";
    avr = "avr-none";
  };

  mkSaizAtList = saiz: {
    min = saiz >= 1;
    med = saiz >= 2;
    max = saiz == 3;
  };

  matcSaiz =
    saiz: ifNon: ifMin: ifMed: ifMax:
    let
      sizedAtLeast = mkSaizAtList saiz;
    in
    if sizedAtLeast.max then
      ifMax
    else if sizedAtLeast.med then
      ifMed
    else if sizedAtLeast.min then
      ifMin
    else
      ifNon;

  mkLamdy =
    { klozyr, lamdy }:
    let
      rykuestydDatomz = functionArgs lamdy;
      rytyrndDatomz = intersectAttrs rykuestydDatomz klozyr;
    in
    lamdy rytyrndDatomz;

  mkLamdyz =
    { lamdyz, klozyr }:
    mapAttrs (
      n: v:
      mkLamdy {
        inherit klozyr;
        lamdy = v;
      }
    ) lamdyz;

  # TODO(desc: "remove", tags: [ "mkHorizon" ])
  speciesDatum =
    { datum, spek }:
    let
      inherit (datum) species;
      allSpeksNames = concatMap (n: getAttr n spek) (attrNames spek);
      wantedAttrsNames = spek.${species};
      izyntWanted = n: !(elem n wantedAttrsNames);
      unwantedAttrs = filter izyntWanted allSpeksNames;
    in
    removeAttrs datum unwantedAttrs;

  rem = a: b: a - (b * (a / b));

  isOdd =
    number:
    let
      remainder = rem number 2;
    in
    remainder == 1;

}
