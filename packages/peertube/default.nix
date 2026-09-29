# ==============================================================================
# PeerTube
# ==============================================================================

{
  pkgs,
}:

pkgs.unstable.peertube.overrideAttrs (old: {
  version = "8.3.1";
  src = old.src.override {
    hash = "sha256-9Arq6gvMZV+0WcHWGwFnMjtnZzW+hWPPsHkJDwMFZCM=";
  };
  pnpmDeps = old.pnpmDeps.override {
    hash = "sha256-HbscF8sjgFCICJnpWopW5VWcD67XdzKOONWn+RHZThI=";
  };
  patches = (old.patches or [ ]) ++ [
    ./cdn-redirect-runner.patch
    ./hq-transcode.patch
    ./runner-download-timeout.patch
  ];
  meta = old.meta // {
    platforms = old.meta.platforms ++ [ "aarch64-darwin" ];
  };
})
