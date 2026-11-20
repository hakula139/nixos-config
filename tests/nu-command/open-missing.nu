#!/usr/bin/env nu

use config-file.nu [open-record]

def main [] {
  open-record "/nonexistent/settings.json" | to json --raw
}
