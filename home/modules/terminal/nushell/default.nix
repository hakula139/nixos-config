# ==============================================================================
# Nushell (Structured-data shell)
# ==============================================================================

{
  programs.nushell = {
    enable = true;

    # Nushell announces each config file it creates on stdout, which corrupts
    # `nu --lsp`'s JSON-RPC stream. Both files must exist to keep it quiet.
    settings.show_banner = false;
    extraEnv = "# Managed by Home Manager.\n";
  };
}
