{
  config,
  pkgs,
  lib,
}:

let
  inherit (pkgs.stdenv) isDarwin;

  # PowerShell reads tmux's UTF-8 pipe explicitly. clip.exe guesses the encoding
  # and treats NUL-free UTF-16LE prefixes as single-byte text.
  wslClipboard = pkgs.writeShellScript "tmux-copy-to-windows-clipboard" ''
    exec powershell.exe -STA -NoProfile -NonInteractive -Command \
      '[Console]::InputEncoding = [Text.UTF8Encoding]::new($false); Set-Clipboard -Value ([Console]::In.ReadToEnd())'
  '';

  # Cursor's OSC 52 decoder corrupts multibyte UTF-8, so prefer local clipboard
  # sinks when the platform exposes one.
  localClipboard =
    if isDarwin then
      "pbcopy"
    else if config.hakula.wsl.enable then
      "${wslClipboard}"
    else
      null;
in

# A local sink and tmux OSC 52 can race to update the clipboard. Disable OSC 52
# locally, but retain it as the only copy path on headless hosts.
if localClipboard != null then
  ''
    set -s set-clipboard off
    bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel ${lib.escapeShellArg localClipboard}
  ''
else
  ''
    set -s set-clipboard on
    bind -T copy-mode-vi y send-keys -X copy-selection-and-cancel
  ''
