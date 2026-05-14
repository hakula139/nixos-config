# ==============================================================================
# PeerTube Runner (slim build)
# ==============================================================================

{ peertube }:

peertube.overrideAttrs (old: {
  pname = "peertube-runner";
  outputs = [ "out" ];

  # Pin to upstream's pnpm fetch; otherwise the `pname` rename re-derives it
  # via `finalAttrs.pname` and triggers an identical-content refetch.
  inherit (peertube) pnpmDeps;

  buildPhase = ''
    runHook preBuild

    export HOME=$PWD

    npm run build:peertube-runner
    patchShebangs apps/peertube-runner/dist/peertube-runner.mjs

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib/peertube-runner
    cp apps/peertube-runner/dist/peertube-runner.mjs \
       $out/lib/peertube-runner/peertube-runner.mjs
    cp apps/peertube-runner/package.json \
       $out/lib/peertube-runner/package.json
    ln -s $out/lib/peertube-runner/peertube-runner.mjs $out/bin/peertube-runner

    runHook postInstall
  '';

  meta = old.meta // {
    description = "PeerTube remote runner (slim build, bundled JS only)";
    mainProgram = "peertube-runner";
  };
})
