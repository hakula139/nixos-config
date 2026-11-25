# ==================================================================================================
# Telemetry Blocking Helpers
# ==================================================================================================

{
  lib,
}:

let
  isCoveredBySuffix =
    suffixes: domain: lib.any (suffix: domain == suffix || lib.hasSuffix ".${suffix}" domain) suffixes;
in
{
  clashDomains =
    domains:
    let
      exact = builtins.filter (domain: !(isCoveredBySuffix domains.suffix domain)) domains.exact;
    in
    lib.sort builtins.lessThan (exact ++ map (d: "+.${d}") domains.suffix);

  hostsEntries =
    domains:
    lib.concatMap (domain: [
      "0.0.0.0 ${domain}"
      ":: ${domain}"
    ]) domains.exact;
}
