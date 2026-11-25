# Deployment

These commands update hosts after initial [Bootstrap](bootstrap.md). Run them from the repository root in the managed Zsh environment.

## Local workstation

Run `nixsw` to apply the local configuration.

## NixOS servers

`nixdp` aliases `colmena apply` and accepts its flags: `nixdp` deploys every server, and `nixdp --on us-4` or `nixdp --on @cloudcone` selects hosts by name or provider tag.

The servers build on target and substitute what GitHub CI pushes to Cachix, so wait for the CI run on the synced commit to finish before running `nixdp`.

Every proxy node in `data/servers.nix` is a deploy target. Switch the workstation's proxy client to another node before deploying a node, because activation can restart its nginx or Xray and cut off a session routed through it. When proxy credentials rotate, deploy the subscription host `us-4` first through an undeployed node, then refresh the client's subscription before deploying the rest.
