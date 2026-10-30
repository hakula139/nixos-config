# ==================================================================================================
# PeerTube
# ==================================================================================================

{
  pkgs,
}:

pkgs.unstable.peertube.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [
    ./cdn-redirect-runner.patch
    ./hq-transcode.patch
    ./runner-download-timeout.patch
  ];

  meta = old.meta // {
    platforms = old.meta.platforms ++ [ "aarch64-darwin" ];
  };
})
