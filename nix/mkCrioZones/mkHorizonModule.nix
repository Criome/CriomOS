{
  lib,
  config,
  kor,
  clustersSpecies,
  Clusters,
  ...
}:
let
  inherit (builtins)
    filter
    concatStringsSep
    listToAttrs
    hasAttr
    attrNames
    concatMap
    elem
    ;
  inherit (kor)
    louestOf
    nameValuePair
    filterAttrs
    speciesDatum
    optional
    mapAttrsToList
    optionalAttrs
    optionalString
    arkSistymMap
    unique
    ;
  inherit (config) clusterName astraName species;
  inherit (clustersSpecies) metnodeNames nodeSpecies;

  inputCluster = Clusters.${clusterName};
  inputNodes = inputCluster.nodes;
  inputAstra = inputNodes.${astraName};

  nodeNames = attrNames inputCluster.nodes;
  userNames = attrNames inputCluster.users;

  nodeCriomOSName = concatStringsSep "." [
    clusterName
    "criome"
  ];

  metaTrost = inputCluster.trost.cluster;

  mkTrost = yrei: louestOf (yrei ++ [ metaTrost ]);

  mkSshString =
    preCriome:
    if (preCriome == null) then
      ""
    else
      concatStringsSep " " [
        "ssh-ed25519"
        preCriome
      ];

  mkNode =
    nodeName:
    let
      # (TODO typecheck)
      inputNode = inputNodes.${nodeName};
      inherit (inputNode) saiz species;
      inherit (inputNode.preCriomes) yggdrasil;

      filteredMachine = speciesDatum {
        datum = inputNode.machine;
        spek = {
          metyl = [
            "ark"
            "mothyrBord"
            "modyl"
          ];
          pod = [
            "ark"
            "ubyrNode"
            "ubyrUser"
          ];
        };
      };

      rytyrnArkFromMothyrBord = mb: abort "Missing mothyrBord table";

      tcekdArk =
        if (filteredMachine.ark != null) then
          filteredMachine.ark
        else if (filteredMachine.species == "pod") then
          nodes.${filteredMachine.ubyrNode}.machine.ark
        else if (filteredMachine.mothyrBord != null) then
          (rytyrnArkFromMothyrBord filteredMachine.mothyrBord)
        else
          abort "Missing machine ark";

      machine = filteredMachine // {
        ark = tcekdArk;
      };

      mkLinkLocalIP =
        linkLocalIP:
        with linkLocalIP;
        let
          interface = if (species == "ethernet") then "enp0s25" else "wlp3s0";
        in
        "fe80::${suffix}%${interface}";

      nodeIp = inputNode.nodeIp or null;
      wireguardPreCriome = inputNode.wireguardPreCriome or null;

      mkTypeIsFromTypeName =
        name:
        let
          isOfThisType = name == species;
        in
        nameValuePair name isOfThisType;

      node = {
        inherit saiz species;

        name = nodeName;
        inherit machine wireguardPreCriome nodeIp;

        linkLocalIPs =
          if (hasAttr "linkLocalIPs" inputNode) then (map mkLinkLocalIP inputNode.linkLocalIPs) else [ ];

        trost = mkTrost [
          inputNode.trost
          inputCluster.trost.nodes.${nodeName}
        ];

        ssh = mkSshString inputNode.preCriomes.ssh;

        yggPreCriome = yggdrasil.preCriome;
        yggAddress = yggdrasil.address;
        yggSubnet = yggdrasil.subnet;

        inherit (inputNode.preCriomes) niksPreCriome;

        criomOSName = concatStringsSep "." [
          nodeName
          nodeCriomOSName
        ];

        sistym = arkSistymMap.${machine.ark};

        nbOfBildKorz = 1; # TODO

        typeIs = listToAttrs (map mkTypeIsFromTypeName nodeSpecies);
      };

      methods =
        let
          inherit (node)
            species
            trost
            saiz
            niksPreCriome
            yggAddress
            criomOSName
            typeIs
            ;

        in
        rec {
          isFullyTrusted = trost == 3;
          sizedAtLeast = kor.mkSaizAtList saiz;
          isBuilder =
            !typeIs.edj && isFullyTrusted && (sizedAtLeast.med || typeIs.sentyr) && hasBasePrecriads;
          isDispatcher = !typeIs.sentyr && isFullyTrusted && sizedAtLeast.min;
          isNixCache = typeIs.sentyr && sizedAtLeast.min && hasBasePrecriads;
          izNiksCriodaizd = niksPreCriome != null && niksPreCriome != "";
          hasYggPrecriad = yggAddress != null && yggAddress != "";
          hasSshPrecriad = hasAttr "ssh" inputNode.preCriomes;
          hasWireguardPrecriad = wireguardPreCriome != null;

          hasBasePrecriads = izNiksCriodaizd && hasYggPrecriad && hasSshPrecriad;

          sshPrecriome = if !hasSshPrecriad then "" else mkSshString inputNode.preCriomes.ssh;

          nixPreCriome = optionalString izNiksCriodaizd (
            concatStringsSep ":" [
              criomOSName
              niksPreCriome
            ]
          );

          nixCacheDomain = if isNixCache then ("nix." + criomOSName) else null;
          nixUrl = if isNixCache then ("http://" + nixCacheDomain) else null;

        };

    in
    node // { inherit methods; };

  exNodeNames = attrNames exNodes;
  bildyrz = filter (n: nodes.${n}.methods.isBuilder) exNodeNames;
  kacyz = filter (n: nodes.${n}.methods.isNixCache) exNodeNames;
  dispatcyrz = filter (n: nodes.${n}.methods.isDispatcher) exNodeNames;

  adminUserNames = filter (n: users.${n}.trost == 3) userNames;

  astraMethods =
    let
      mkBildyr =
        n:
        let
          node = exNodes.${n};
        in
        {
          hostName = node.criomOSName;
          sshUser = "nixBuilder";
          sshKey = "/etc/ssh/ssh_host_ed25519_key";
          supportedFeatures = optional (!node.typeIs.edj) "big-parallel";
          system = node.sistym;
          systems = lib.optional (node.sistym == "x86_64-linux") "i686-linux";
          maxJobs = node.nbOfBildKorz;
        };

      mkAdminUserPreCriomes =
        adminUserName:
        let
          adminUser = users.${adminUserName};
          preCriomeNodeNames = attrNames adminUser.preCriomes;
          izNodeFulyTrostyd = n: nodes.${n}.methods.isFullyTrusted;
          fulyTrostydPreCriomeNames = filter izNodeFulyTrostyd preCriomeNodeNames;
          getSshString =
            n:
            if (adminUser.preCriomes.${n}.ssh == null) then
              ""
            else
              (mkSshString adminUser.preCriomes.${n}.ssh);
        in
        map getSshString fulyTrostydPreCriomeNames;

      inherit (astra.machine) modyl;
      thinkpadModylz = [
        "ThinkPadX240"
        "ThinkPadX230"
      ];
      impozdHTModylz = [ "ThinkPadX240" ];

      computerModylz = thinkpadModylz ++ [ "rpi3B" ];

      computerIsNotMap = listToAttrs (map (n: nameValuePair n false) computerModylz);

    in
    {
      bildyrKonfigz = map mkBildyr bildyrz;

      kacURLz =
        let
          mkKacURL = n: exNodes.${n}.methods.nixUrl;
        in
        map mkKacURL kacyz;

      exNodesSshPreCriomes = map (n: exNodes.${n}.ssh) exNodeNames;

      dispatcyrzSshKiz = map (n: exNodes.${n}.ssh) dispatcyrz;

      adminSshPreCriomes = unique (concatMap mkAdminUserPreCriomes adminUserNames);

      tcipIzIntel = elem astra.machine.ark [
        "x86-64"
        "i686"
      ]; # TODO

      modylIzThinkpad = elem astra.machine.modyl thinkpadModylz;

      impozyzHaipyrThreding = elem astra.machine.modyl impozdHTModylz;

      useColemak = astra.io.kibord == "colemak";

      computerIs = computerIsNotMap // (optionalAttrs (modyl != null) { "${modyl}" = true; });

      wireguardUntrustedProxies = astra.wireguardUntrustedProxies or [ ];
    };

  mkUser =
    userName:
    let
      inputUser = inputCluster.users.${userName};

      tcekPreCriome = nodeName: preCriome: hasAttr nodeName nodes;

      user = {
        name = userName;

        inherit (inputUser) stail species kibord;

        saiz = louestOf [
          inputUser.saiz
          astra.saiz
        ];

        trost = inputCluster.trost.users.${userName};

        preCriomes = filterAttrs tcekPreCriome inputUser.preCriomes;

        githubId = if (inputUser.githubId == null) then userName else inputUser.githubId;

      };

      hazPreCriome = hasAttr astra.name user.preCriomes;

      methods =
        {
          inherit hazPreCriome;

          sizedAtLeast = kor.mkSaizAtList user.saiz;

          emailAddress = "${user.name}@${cluster.name}.criome.me";
          matrixID = "@${user.name}:${cluster.name}.criome.me";

          gitSigningKey = if hazPreCriome then ("&" + user.preCriomes.${astra.name}.keygrip) else null;

          useColemak = user.kibord == "colemak";

          izSemaDev = elem user.species [
            "Sema"
            "Onlimityd"
          ];
          izNiksDev = elem user.species [
            "Niks"
            "Onlimityd"
          ];

          sshyz = mapAttrsToList (n: pk: mkSshString pk.ssh) user.preCriomes;

        }
        // (kor.optionalAttrs hazPreCriome {
          ssh = mkSshString user.preCriomes.${astra.name}.ssh;
        });

    in
    user // { inherit methods; };

  nodes = listToAttrs (
    map (y: nameValuePair y.name y) (filter (x: x.trost != 0) (map (n: mkNode n) nodeNames))
  );

  cluster = {
    name = clusterName;

    methods = {
      trostydBildPreCriomes = map (n: nodes.${n}.methods.nixPreCriome) nodeNames;
    };
  };

  exNodes = kor.filterAttrs (n: v: n != astraName) nodes;

  astra =
    let
      node = nodes.${astraName};
    in
    node
    // {
      inherit (inputAstra) io;
      methods = node.methods // astraMethods;
    };

  users = listToAttrs (
    map (y: nameValuePair y.name y) (filter (x: x.trost != 0) (map (n: mkUser n) userNames))
  );

in
{
  horizon = {
    inherit
      cluster
      astra
      exNodes
      users
      ;
  };
}
