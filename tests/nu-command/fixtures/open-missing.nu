#!/usr/bin/env nu

# ==================================================================================================
# Nushell Shared-Library Fixture
# ==================================================================================================

use config-file.nu [open-record]

def main [] {
  open-record "/nonexistent/settings.json" | to json --raw
}
