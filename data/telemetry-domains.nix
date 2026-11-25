# ==================================================================================================
# Telemetry Domains
# ==================================================================================================

{
  exact = [
    # T3 Code
    "ingest.t3.codes"

    # Anthropic
    "a-api.anthropic.com"
    "a-cdn.anthropic.com"

    # OpenAI / Codex
    "ab.chatgpt.com"

    # Cursor / VS Code
    "metrics.cursor.sh"
    "telemetry.vscode.dev"
    "dc.services.visualstudio.com"
    "vortex.data.microsoft.com"

    # Zed
    "telemetry.zed.dev"

    # GitLab
    "telemetry.gitlab.com"

    # PostHog
    "app.posthog.com"
    "us.i.posthog.com"
    "eu.i.posthog.com"

    # Axiom
    "api.axiom.co"

    # SiftScience
    "api3.siftscience.com"
  ];

  suffix = [
    # PostHog
    "posthog.com"

    # Datadog
    "browser-intake-datadoghq.com"
    "browser-intake-us3-datadoghq.com"
    "browser-intake-us5-datadoghq.com"
    "browser-intake-datadoghq.eu"
    "browser-intake-ap1-datadoghq.com"
    "logs.datadoghq.com"
    "logs.us3.datadoghq.com"
    "logs.us5.datadoghq.com"
    "logs.datadoghq.eu"
    "logs.ap1.datadoghq.com"

    # Sentry
    "ingest.sentry.io"
    "ingest.us.sentry.io"
    "ingest.de.sentry.io"
  ];
}
