@0xd95d15084e671c33;

using Cxx = import "/capnp/c++.capnp";
$Cxx.namespace("criom");

# Schema derived from nix/mkCrioSphere and nix/mkCrioZones.

struct OptionalText {
  union {
    none @0 :Void;
    value @1 :Text;
  }
}

enum Magnitude {
  min @0; # 0
  low @1; # 1
  med @2; # 2
  max @3; # 3
}

enum NodeSpecies {
  center @0;
  hybrid @1;
  edge @2;
  edgeTesting @3;
  mediaBroadcast @4;
  router @5;
  routerTesting @6;
  largeAI @7;
}

enum UserSpecies {
  code @0;
  multimedia @1;
  unlimited @2;
}

enum UserStyle {
  vim @0;
  emacs @1;
}

enum Keyboard {
  qwerty @0;
  colemak @1;
}

enum Bootloader {
  uefi @0;
  mbr @1;
  uboot @2;
}

enum MachineSpecies {
  metal @0;
  pod @1;
}

enum DomainSpecies {
  cloudflare @0;
}

struct CrioSphereProposal {
  clusters @0 :List(ClusterProposal);
}

struct ClusterProposal {
  name @0 :Text;
  nodes @1 :List(NodeProposal);
  users @2 :List(UserProposal);
  domains @3 :List(Domain);
  trust @4 :TrustProposal;
}

struct TrustProposal {
  cluster @0 :Magnitude;
  clusters @1 :List(TrustEntry);
  nodes @2 :List(TrustEntry);
  users @3 :List(TrustEntry);
}

struct TrustEntry {
  name @0 :Text;
  level @1 :Magnitude;
}

struct Domain {
  name @0 :Text;
  species @1 :DomainSpecies;
}

struct NodeProposal {
  name @0 :Text;
  species @1 :NodeSpecies;
  size @2 :Magnitude;
  trust @3 :Magnitude;
  machine @4 :Machine;
  io @5 :Io;
  preCriomes @6 :NodePreCriomes;
  linkLocalIps @7 :List(LinkLocalIp);
  nodeIp @8 :OptionalText;
  wireguardPreCriome @9 :OptionalText;
}

struct NodePreCriomes {
  ssh @0 :OptionalText;
  nixPreCriome @1 :OptionalText;
  yggdrasil @2 :YggPreCriome;
}

struct YggPreCriome {
  preCriome @0 :OptionalText;
  address @1 :OptionalText;
  subnet @2 :OptionalText;
}

struct LinkLocalIp {
  species @0 :Text; # e.g. ethernet, wifi
  suffix @1 :Text;
}

struct Machine {
  species @0 :MachineSpecies;
  arch @1 :OptionalText;
  cores @2 :UInt16;
  model @3 :OptionalText;
  motherBoard @4 :OptionalText;
  superNode @5 :OptionalText;
  superUser @6 :OptionalText;
}

struct Io {
  keyboard @0 :Keyboard;
  bootloader @1 :Bootloader;
  disks @2 :List(DiskMount);
  swapDevices @3 :List(SwapDevice);
}

struct DiskMount {
  mountPoint @0 :Text;
  device @1 :Text;
  fsType @2 :Text;
  options @3 :List(Text);
}

struct SwapDevice {
  device @0 :Text;
}

struct UserProposal {
  name @0 :Text;
  size @1 :Magnitude;
  species @2 :UserSpecies;
  style @3 :UserStyle;
  keyboard @4 :Keyboard;
  githubId @5 :OptionalText;
  preCriomes @6 :List(UserPreCriomeEntry);
}

struct UserPreCriomeEntry {
  nodeName @0 :Text;
  ssh @1 :Text;
  keygrip @2 :Text;
}

# mkCrioZones output
struct CrioZones {
  clusters @0 :List(ClusterCrioZones);
}

struct ClusterCrioZones {
  name @0 :Text;
  zones @1 :List(NodeCrioZone);
}

struct NodeCrioZone {
  nodeName @0 :Text;
  horizon @1 :Horizon;
}

struct Horizon {
  cluster @0 :HorizonCluster;
  node @1 :HorizonNode;
  exNodes @2 :List(HorizonNode);
  users @3 :List(HorizonUser);
}

struct HorizonCluster {
  name @0 :Text;
  methods @1 :HorizonClusterMethods;
}

struct HorizonClusterMethods {
  trustedBuildPreCriomes @0 :List(OptionalText);
}

struct HorizonNode {
  name @0 :Text;
  species @1 :NodeSpecies;
  size @2 :Magnitude;
  trust @3 :Magnitude;
  machine @4 :Machine;
  io @5 :Io;
  ssh @6 :OptionalText;
  yggPreCriome @7 :OptionalText;
  yggAddress @8 :OptionalText;
  yggSubnet @9 :OptionalText;
  nixPreCriome @10 :OptionalText;
  linkLocalIps @11 :List(Text);
  nodeIp @12 :OptionalText;
  wireguardPreCriome @13 :OptionalText;
  criomeDomainName @14 :Text;
  system @15 :Text;
  nbOfBuildCores @16 :UInt16;
  typeIs @17 :NodeTypeFlags;
  methods @18 :HorizonNodeMethods;
}

struct NodeTypeFlags {
  center @0 :Bool;
  hybrid @1 :Bool;
  edge @2 :Bool;
  edgeTesting @3 :Bool;
  mediaBroadcast @4 :Bool;
  router @5 :Bool;
  routerTesting @6 :Bool;
  largeAI @7 :Bool;
}

struct HorizonNodeMethods {
  isFullyTrusted @0 :Bool;
  sizedAtLeast @1 :SizedAtLeast;
  isBuilder @2 :Bool;
  isDispatcher @3 :Bool;
  isNixCache @4 :Bool;
  hasNixPreCriad @5 :Bool;
  hasYggPrecriad @6 :Bool;
  hasSshPrecriad @7 :Bool;
  hasWireguardPrecriad @8 :Bool;
  hasBasePrecriads @9 :Bool;
  sshPrecriome @10 :OptionalText;
  nixPreCriome @11 :OptionalText;
  nixCacheDomain @12 :OptionalText;
  nixUrl @13 :OptionalText;
  behavesAs @14 :BehavesAs;

  builderConfigs @15 :List(BuilderConfig);
  cacheURLs @16 :List(OptionalText);
  exNodesSshPreCriomes @17 :List(OptionalText);
  dispatchersSshPreCriomes @18 :List(OptionalText);
  adminSshPreCriomes @19 :List(OptionalText);
  chipIsIntel @20 :Bool;
  modelIsThinkpad @21 :Bool;
  useColemak @22 :Bool;
  computerIs @23 :List(ModelFlag);
  wireguardUntrustedProxies @24 :List(WireguardProxy);
}

struct SizedAtLeast {
  min @0 :Bool;
  med @1 :Bool;
  max @2 :Bool;
}

struct BehavesAs {
  router @0 :Bool;
  edge @1 :Bool;
  nextGen @2 :Bool;
  lowPower @3 :Bool;
  bareMetal @4 :Bool;
  virtualMachine @5 :Bool;
  iso @6 :Bool;
}

struct BuilderConfig {
  hostName @0 :Text;
  sshUser @1 :Text;
  sshKey @2 :Text;
  supportedFeatures @3 :List(Text);
  system @4 :Text;
  systems @5 :List(Text);
  maxJobs @6 :UInt16;
}

struct ModelFlag {
  name @0 :Text;
  value @1 :Bool;
}

struct WireguardProxy {
  name @0 :Text;
  address @1 :OptionalText;
}

struct HorizonUser {
  name @0 :Text;
  species @1 :UserSpecies;
  style @2 :UserStyle;
  keyboard @3 :Keyboard;
  size @4 :Magnitude;
  trust @5 :Magnitude;
  preCriomes @6 :List(UserPreCriomeEntry);
  githubId @7 :Text;
  methods @8 :HorizonUserMethods;
}

struct HorizonUserMethods {
  hasPreCriome @0 :Bool;
  sizedAtLeast @1 :SizedAtLeast;
  emailAddress @2 :Text;
  matrixID @3 :Text;
  gitSigningKey @4 :OptionalText;
  useColemak @5 :Bool;
  isMultimediaDev @6 :Bool;
  isCodeDev @7 :Bool;
  sshCriomes @8 :List(Text);
  ssh @9 :OptionalText;
}
