# ==================================================================================================
# Curl Helper Library
# ==================================================================================================

{
  # Arguments for an unattended transfer, with both bounds in seconds.
  mkArgs =
    {
      connectTimeout,
      maxTime,
    }:
    [
      "--fail"
      "--silent"
      "--show-error"

      "--connect-timeout"
      (toString connectTimeout)

      "--max-time"
      (toString maxTime)
    ];
}
