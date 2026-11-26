# ==================================================================================================
# Clash Subscription Generator
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  repoLib,
  servers,
}:

let
  # ------------------------------------------------------------------------------------------------
  # Settings
  # ------------------------------------------------------------------------------------------------
  levels = [
    "user"
    "admin"
  ];

  regionOrder = [
    "us"
    "sg"
  ];

  regionFlags = {
    us = "🇺🇸";
    sg = "🇸🇬";
  };

  sniHost = config.hakula.network.realitySniHost;

  chromeMajor = lib.versions.major pkgs.chromium.version;
  wsUserAgent = lib.concatStringsSep " " [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
    "AppleWebKit/537.36 (KHTML, like Gecko)"
    "Chrome/${chromeMajor}.0.0.0"
    "Safari/537.36"
  ];

  # ------------------------------------------------------------------------------------------------
  # Server helpers
  # ------------------------------------------------------------------------------------------------
  regionOf =
    id:
    let
      parts = lib.splitString "-" id;
    in
    if lib.length parts > 1 then lib.concatStringsSep "-" (lib.init parts) else id;

  regionRank = region: lib.lists.findFirstIndex (r: r == region) (lib.length regionOrder) regionOrder;

  compareServer =
    a: b:
    let
      rankA = regionRank (regionOf a.name);
      rankB = regionRank (regionOf b.name);
    in
    if rankA != rankB then rankA < rankB else a.name < b.name;

  sortedServers = lib.sort compareServer (lib.attrValues servers);

  # ------------------------------------------------------------------------------------------------
  # Proxy & level builders
  # ------------------------------------------------------------------------------------------------
  levelRank =
    level: lib.lists.findFirstIndex (l: l == level) (throw "Unknown proxy level: ${level}") levels;

  mkServerProxies =
    server:
    let
      flag = regionFlags.${regionOf server.name} or "🏳️";
      displayName = "${flag} ${lib.toUpper server.name}";
    in
    [
      {
        name = "${displayName} (REALITY)";
        type = "vless";
        server = "${server.name}.hakula.xyz";
        port = 443;
        network = "tcp";
        tls = true;
        udp = true;
        flow = "xtls-rprx-vision";
        servername = sniHost;
        reality-opts = {
          public-key = "bHzc9AjLZiUGoZBGvDmo7XBcewkh9Vqukvzb8CTBnVQ";
        };
        client-fingerprint = "chrome";
      }

      {
        name = "${displayName} (WS + CDN)";
        type = "vless";
        server = "${server.name}-cdn.hakula.xyz";
        port = 443;
        network = "ws";
        tls = true;
        udp = true;
        ws-opts = {
          path = "/ws";
          headers = {
            User-Agent = wsUserAgent;
          };
        };
        client-fingerprint = "chrome";
      }
    ];

  mkLevelConfig =
    level:
    let
      rank = levelRank level;
      admitted = builtins.filter (server: rank >= levelRank server.proxyLevel) sortedServers;
      levelProxies = lib.concatMap mkServerProxies admitted;
    in
    {
      proxies = levelProxies;
      proxy-groups = [
        {
          name = "PROXY";
          type = "select";
          proxies = map (proxy: proxy.name) levelProxies;
        }
      ];
    };

  # ------------------------------------------------------------------------------------------------
  # Rule helpers
  # ------------------------------------------------------------------------------------------------
  ipToCidr =
    ip:
    if lib.hasInfix "/" ip then
      ip
    else if lib.hasInfix ":" ip then
      "${ip}/128"
    else
      "${ip}/32";

  fleetRules = map (server: "IP-CIDR,${ipToCidr server.ip}") sortedServers;

  mkHttpRuleProvider =
    {
      behavior,
      url,
      path,
    }:
    {
      type = "http";
      inherit behavior url path;
      interval = 86400;
    };

  mkClashRulesProvider =
    behavior: name:
    mkHttpRuleProvider {
      inherit behavior;
      url = "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/${name}.txt";
      path = "./ruleset/${name}.yaml";
    };

  # ------------------------------------------------------------------------------------------------
  # Render config
  # ------------------------------------------------------------------------------------------------
  renderConfig = {
    usersFile = config.sops.secrets.clash-users.path;
    outputDir = "/var/lib/clash-generator";

    levels = lib.genAttrs levels mkLevelConfig;

    rule-providers = {
      Hakula = {
        type = "inline";
        behavior = "classical";
        payload = [
          "DOMAIN-SUFFIX,hakula.xyz"
        ]
        ++ fleetRules;
      };

      Telemetry = mkHttpRuleProvider {
        behavior = "domain";
        url = "https://clash.hakula.xyz/rules/telemetry.yaml";
        path = "./ruleset/telemetry.yaml";
      };

      Reject = mkClashRulesProvider "domain" "reject";
      iCloud = mkClashRulesProvider "domain" "icloud";
      Apple = mkClashRulesProvider "domain" "apple";
      Google = mkClashRulesProvider "domain" "google";
      GFW = mkClashRulesProvider "domain" "gfw";
      Proxy = mkClashRulesProvider "domain" "proxy";
      Direct = mkClashRulesProvider "domain" "direct";
      LAN = mkClashRulesProvider "ipcidr" "lancidr";
      Telegram = mkClashRulesProvider "ipcidr" "telegramcidr";
    };

    rules = [
      "RULE-SET,Hakula,DIRECT,no-resolve"
      "RULE-SET,Telemetry,REJECT"
      "RULE-SET,Reject,REJECT"
      "RULE-SET,iCloud,DIRECT"
      "RULE-SET,Apple,DIRECT"
      "RULE-SET,Google,PROXY"
      "RULE-SET,GFW,PROXY"
      "RULE-SET,Proxy,PROXY"
      "RULE-SET,Direct,DIRECT"
      "RULE-SET,LAN,DIRECT,no-resolve"
      "RULE-SET,Telegram,PROXY,no-resolve"
      "GEOIP,CN,DIRECT"
      "MATCH,PROXY"
    ];
  };
in
repoLib.mkNuCommand {
  inherit pkgs;
  name = "clash-generator";
  script = ./render-config.nu;
  runtimeInputs = [ pkgs.coreutils ];
  config = renderConfig;
}
