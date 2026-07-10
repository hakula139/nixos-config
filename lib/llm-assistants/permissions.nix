# ==============================================================================
# LLM Assistant Permissions
# ==============================================================================

{ lib }:

let
  # ----------------------------------------------------------------------------
  # Gates
  # ----------------------------------------------------------------------------
  gates = [
    # --------------------------------------------------------------------------
    # Local / system state
    # --------------------------------------------------------------------------
    {
      argv = [ "rm" ];
      reason = "Irreversible local deletion.";
    }
    {
      argv = [ "sudo" ];
      reason = "Privilege escalation.";
    }
    {
      argv = [ "agenix" ];
      reason = "Rewrites encrypted secrets.";
    }
    {
      argv = [ "darwin-rebuild" ];
      reason = "Switches system configuration.";
    }
    {
      argv = [ "nixos-rebuild" ];
      reason = "Switches system configuration.";
    }

    # --------------------------------------------------------------------------
    # Shared remote
    # --------------------------------------------------------------------------
    {
      argv = [
        "git"
        "push"
      ];
      reason = "Publishes commits to a remote.";
    }
    {
      argv = [
        "gh"
        "issue"
        "create"
      ];
      reason = "Opens an issue under our identity.";
    }
    {
      argv = [
        "gh"
        "pr"
        "create"
      ];
      reason = "Opens a pull request under our identity.";
    }
    {
      argv = [
        "gh"
        "pr"
        "merge"
      ];
      reason = "Integrates a pull request into a shared branch.";
    }
    {
      argv = [
        "gh"
        "pr"
        "review"
      ];
      reason = "Records a review verdict under our identity.";
    }
    {
      argv = [
        "gh"
        "repo"
        "create"
      ];
      reason = "Creates a repository under our identity.";
    }
    {
      argv = [
        "gh"
        "repo"
        "fork"
      ];
      reason = "Forks a repository under our identity.";
    }
    {
      argv = [
        "glab"
        "issue"
        "create"
      ];
      reason = "Opens an issue under our identity.";
    }
    {
      argv = [
        "glab"
        "mr"
        "create"
      ];
      reason = "Opens a merge request under our identity.";
    }
    {
      argv = [
        "glab"
        "mr"
        "merge"
      ];
      reason = "Integrates a merge request into a shared branch.";
    }
    {
      argv = [
        "glab"
        "mr"
        "approve"
      ];
      reason = "Records an approval under our identity.";
    }
    {
      argv = [
        "glab"
        "repo"
        "create"
      ];
      reason = "Creates a repository under our identity.";
    }
    {
      argv = [
        "glab"
        "repo"
        "fork"
      ];
      reason = "Forks a repository under our identity.";
    }
  ];

  denies = [
    {
      argv = [
        "agenix"
        "-r"
      ];
      reason = "agenix -r empties every secret when stdin is not a TTY.";
    }
    {
      argv = [
        "agenix"
        "--rekey"
      ];
      reason = "agenix --rekey empties every secret when stdin is not a TTY.";
    }
  ];

  # ----------------------------------------------------------------------------
  # Renderers
  # ----------------------------------------------------------------------------
  joined = entry: lib.concatStringsSep " " entry.argv;

  toClaude = entries: map (e: "Bash(${joined e} *)") entries;

  toCodexRule =
    decision: entry:
    let
      pattern = lib.concatStringsSep ", " (map (a: ''"${a}"'') entry.argv);
    in
    ''
      prefix_rule(
          pattern = [${pattern}],
          decision = "${decision}",
          justification = "${entry.reason}",
      )'';

  # Each command gets a bare and a prefixed key so `rm` never matches `rmdir`.
  toOpencodeBash =
    action: entries:
    lib.listToAttrs (
      lib.concatMap (e: [
        (lib.nameValuePair (joined e) action)
        (lib.nameValuePair "${joined e} *" action)
      ]) entries
    );
in
{
  inherit gates denies;

  claudeAsk = toClaude gates;
  claudeDeny = toClaude denies;

  codexRules = lib.concatStringsSep "\n\n" (
    map (toCodexRule "forbidden") denies ++ map (toCodexRule "prompt") gates
  );

  # OpenCode resolves permission.bash last-match-wins with no deny precedence,
  # and Nix serializes keys alphabetically (attrsets are unordered:
  # nix-community/home-manager#2519). Denies win today only because each is more
  # specific than its ask, so it sorts later (`agenix -r` after `agenix *`). A
  # broad deny with a narrower ask carve-out would silently degrade to a prompt.
  opencodeBash = {
    "*" = "allow";
  }
  // toOpencodeBash "ask" gates
  // toOpencodeBash "deny" denies;
}
