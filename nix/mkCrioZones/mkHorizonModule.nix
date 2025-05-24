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
    lowestOf
    nameValuePair
    filterAttrs
    speciesDatom
    optional
    mapAttrsToList
    optionalAttrs
    optionalString
    archToSystemMap
    unique
    ;
  inherit (config) clusterName nodeName species;
  inherit (clustersSpecies) metnodeNames nodeSpecies;

  inputCluster = Clusters.${clusterName};
  inputNodes = inputCluster.nodes;
  inputNode = inputNodes.${nodeName};

  nodeNames = attrNames inputCluster.nodes;
  userNames = attrNames inputCluster.users;

  nodeCriomOSName = concatStringsSep "." [
    clusterName
    "criome"
  ];

  metaTrust = inputCluster.trust.cluster;

  mkTrust = yrei: lowestOf (yrei ++ [ metaTrust ]);

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
      inherit (inputNode) size species;
      inherit (inputNode.preCriomes) yggdrasil;

      filteredMachine = speciesDatom {
        datom = inputNode.machine;
        spec = {
          metal = [
            "arch"
            "motherBoard"
            "model"
          ];
          pod = [
            "arch"
            "superNode"
            "superUser"
          ];
        };
      };

      archFromMotherboard = mb: abort "Missing motherBoard table";

      checkedArch =
        if (filteredMachine.arch != null) then
          filteredMachine.arch
        else if (filteredMachine.species == "pod") then
          nodes.${filteredMachine.superNode}.machine.arch
        else if (filteredMachine.motherBoard != null) then
          (archFromMotherboard filteredMachine.motherBoard)
        else
          abort "Missing machine arch";

      machine = filteredMachine // {
        arch = checkedArch;
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
        inherit size species;

        name = nodeName;
        inherit machine wireguardPreCriome nodeIp;

        linkLocalIPs =
          if (hasAttr "linkLocalIPs" inputNode) then (map mkLinkLocalIP inputNode.linkLocalIPs) else [ ];

        trust = mkTrust [
          inputNode.trust
          inputCluster.trust.nodes.${nodeName}
        ];

        ssh = mkSshString inputNode.preCriomes.ssh;

        yggPreCriome = yggdrasil.preCriome;
        yggAddress = yggdrasil.address;
        yggSubnet = yggdrasil.subnet;

        inherit (inputNode.preCriomes) nixPreCriome;

        criomOSName = concatStringsSep "." [
          nodeName
          nodeCriomOSName
        ];

        system = archToSystemMap.${machine.arch};

        nbOfBuildCores = 1; # TODO

        typeIs = listToAttrs (map mkTypeIsFromTypeName nodeSpecies);
      };

      methods =
        let
          inherit (node)
            species
            trust
            size
            nixPreCriome
            yggAddress
            criomOSName
            typeIs
            ;

        in
        rec {
          isFullyTrusted = trust == 3;
          sizedAtLeast = kor.mkSizeAtList size;
          isBuilder =
            !typeIs.edj && isFullyTrusted && (sizedAtLeast.med || typeIs.sentyr) && hasBasePrecriads;
          isDispatcher = !typeIs.sentyr && isFullyTrusted && sizedAtLeast.min;
          isNixCache = typeIs.sentyr && sizedAtLeast.min && hasBasePrecriads;
          hasNixPreCriad = node.nixPreCriome != null && node.nixPreCriome != "";
          hasYggPrecriad = yggAddress != null && yggAddress != "";
          hasSshPrecriad = hasAttr "ssh" inputNode.preCriomes;
          hasWireguardPrecriad = wireguardPreCriome != null;

          hasBasePrecriads = hasNixPreCriad && hasYggPrecriad && hasSshPrecriad;

          sshPrecriome = if !hasSshPrecriad then "" else mkSshString inputNode.preCriomes.ssh;

          nixPreCriome = optionalString hasNixPreCriad (
            concatStringsSep ":" [
              criomOSName
              node.nixPreCriome
            ]
          );

          nixCacheDomain = if isNixCache then ("nix." + criomOSName) else null;
          nixUrl = if isNixCache then ("http://" + nixCacheDomain) else null;

        };

    in
    node // { inherit methods; };

  exNodeNames = attrNames exNodes;
  builders = filter (n: nodes.${n}.methods.isBuilder) exNodeNames;
  caches = filter (n: nodes.${n}.methods.isNixCache) exNodeNames;
  dispatchers = filter (n: nodes.${n}.methods.isDispatcher) exNodeNames;

  adminUserNames = filter (n: users.${n}.trust == 3) userNames;

  nodeMethods =
    let
      mkBuilder =
        n:
        let
          node = exNodes.${n};
        in
        {
          hostName = node.criomOSName;
          sshUser = "nixBuilder";
          sshKey = "/etc/ssh/ssh_host_ed25519_key";
          supportedFeatures = optional (!node.typeIs.edj) "big-parallel";
          system = node.system;
          systems = lib.optional (node.system == "x86_64-linux") "i686-linux";
          maxJobs = node.nbOfBuildCores;
        };

      mkAdminUserPreCriomes =
        adminUserName:
        let
          adminUser = users.${adminUserName};
          preCriomeNodeNames = attrNames adminUser.preCriomes;
          isFullyTrustedNode = n: nodes.${n}.methods.isFullyTrusted;
          fullyTrustedPreCriomeNames = filter isFullyTrustedNode preCriomeNodeNames;
          getSshString =
            n:
            if (adminUser.preCriomes.${n}.ssh == null) then "" else (mkSshString adminUser.preCriomes.${n}.ssh);
        in
        map getSshString fullyTrustedPreCriomeNames;

      inherit (node.machine) model;
      thinkpadModels = [
        "ThinkPadX240"
        "ThinkPadX230"
      ];
      imposedHTModels = [ "ThinkPadX240" ];

      computerModels = thinkpadModels ++ [ "rpi3B" ];

      computerIsNotMap = listToAttrs (map (n: nameValuePair n false) computerModels);

    in
    {
      builderConfigs = map mkBuilder builders;

      cacheURLs =
        let
          mkKacURL = n: exNodes.${n}.methods.nixUrl;
        in
        map mkKacURL caches;

      exNodesSshPreCriomes = map (n: exNodes.${n}.ssh) exNodeNames;

      dispatchersSshPreCriomes = map (n: exNodes.${n}.ssh) dispatchers;

      adminSshPreCriomes = unique (concatMap mkAdminUserPreCriomes adminUserNames);

      tcipIzIntel = elem node.machine.arch [
        "x86-64"
        "i686"
      ]; # TODO

      modelIzThinkpad = elem node.machine.model thinkpadModels;

      impozyzHaipyrThreding = elem node.machine.model imposedHTModels;

      useColemak = node.io.keyboard == "colemak";

      computerIs = computerIsNotMap // (optionalAttrs (model != null) { "${model}" = true; });

      wireguardUntrustedProxies = node.wireguardUntrustedProxies or [ ];
    };

  mkUser =
    userName:
    let
      inputUser = inputCluster.users.${userName};

      tcekPreCriome = nodeName: preCriome: hasAttr nodeName nodes;

      user = {
        name = userName;

        inherit (inputUser) style species keyboard;

        size = lowestOf [
          inputUser.size
          node.size
        ];

        trust = inputCluster.trust.users.${userName};

        preCriomes = filterAttrs tcekPreCriome inputUser.preCriomes;

        githubId = if (inputUser.githubId == null) then userName else inputUser.githubId;

      };

      hasPreCriome = hasAttr node.name user.preCriomes;

      methods =
        {
          inherit hasPreCriome;

          sizedAtLeast = kor.mkSizeAtList user.size;

          emailAddress = "${user.name}@${cluster.name}.criome.me";
          matrixID = "@${user.name}:${cluster.name}.criome.me";

          gitSigningKey = if hasPreCriome then ("&" + user.preCriomes.${node.name}.keygrip) else null;

          useColemak = user.keyboard == "colemak";

          isMultimediaDev = elem user.species [
            "Sema"
            "Onlimityd"
          ];
          isCodeDev = elem user.species [
            "Niks"
            "Onlimityd"
          ];

          sshCriomes = mapAttrsToList (n: pk: mkSshString pk.ssh) user.preCriomes;

        }
        // (kor.optionalAttrs hasPreCriome {
          ssh = mkSshString user.preCriomes.${node.name}.ssh;
        });

    in
    user // { inherit methods; };

  nodes = listToAttrs (
    map (y: nameValuePair y.name y) (filter (x: x.trust != 0) (map (n: mkNode n) nodeNames))
  );

  cluster = {
    name = clusterName;

    methods = {
      trustydBildPreCriomes = map (n: nodes.${n}.methods.nixPreCriome) nodeNames;
    };
  };

  exNodes = kor.filterAttrs (n: v: n != nodeName) nodes;

  node =
    let
      node = nodes.${nodeName};
    in
    node
    // {
      inherit (inputNode) io;
      methods = node.methods // nodeMethods;
    };

  users = listToAttrs (
    map (y: nameValuePair y.name y) (filter (x: x.trust != 0) (map (n: mkUser n) userNames))
  );

in
{
  horizon = {
    inherit
      cluster
      node
      exNodes
      users
      ;
  };
}
