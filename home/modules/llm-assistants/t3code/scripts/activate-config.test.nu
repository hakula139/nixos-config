#!/usr/bin/env nu

# ==================================================================================================
# T3 Code Config Activation Tests
# ==================================================================================================

use std/assert

const SCRIPT_DIR = path self "."
const SCRIPT = ($SCRIPT_DIR | path join "activate-config.nu")

def managed-omp [command_path: string]: nothing -> record {
  {
    driver: "acpRegistry"
    displayName: "Oh My Pi"
    enabled: true
    config: {
      source: "local"
      agentId: ""
      commandPath: $command_path
      commandArgs: ["acp"]
    }
  }
}

# Run the script against a fresh scratch directory and return the path of its settings.json.
def activate [base_dir: path, user_settings?: string]: nothing -> path {
  let target = ($base_dir | path join "userdata/settings.json")

  if $user_settings != null {
    mkdir ($target | path dirname)
    $user_settings | save $target
  }

  let config_file = ($base_dir | path dirname | path join "activation.json")
  {
    baseDir: $base_dir
    defaults: {
      defaultRuntimeMode: "auto"
      pullRequestMergeMethod: "squash"
    }
    providerInstances: {
      omp: (managed-omp "omp")
    }
  }
  | to json
  | save --force $config_file

  let run = (
    ^$nu.current-exe --no-config-file
      $SCRIPT --config $config_file
    | complete
  )
  assert equal $run.exit_code 0 $run.stderr

  $target
}

def "test activation creates missing userdata settings from scratch" [] {
  let dir = (mktemp --directory | path expand --strict)
  let target = (activate ($dir | path join "fresh-t3"))

  assert equal (open $target) {
    defaultRuntimeMode: "auto"
    pullRequestMergeMethod: "squash"
    providerInstances: {
      omp: (managed-omp "omp")
    }
  }
  assert equal (ls --long $target | get 0.mode) "rw-------"
}

def "test activation merges defaults and managed providers while keeping user state" [] {
  let dir = (mktemp --directory | path expand --strict)
  let user_settings = (
    {
      defaultRuntimeMode: "approval-required"
      defaultTheme: "catppuccin-mocha"
      providerInstances: {
        omp: {
          driver: "acpRegistry"
          displayName: "Oh My Pi"
          enabled: true
          config: {
            source: "local"
            agentId: ""
            commandPath: "/old/bin/omp"
            commandArgs: ["acp"]
            customModels: ["corp-gateway-anthropic/claude-opus-5-5"]
          }
        }
        customAgent: {
          driver: "claudeAgent"
          displayName: "Custom Claude"
          enabled: true
        }
      }
    }
    | to json
  )
  let target = (activate ($dir | path join "t3") $user_settings)

  assert equal (open $target) {
    defaultRuntimeMode: "approval-required"
    defaultTheme: "catppuccin-mocha"
    pullRequestMergeMethod: "squash"
    providerInstances: {
      omp: {
        driver: "acpRegistry"
        displayName: "Oh My Pi"
        enabled: true
        config: {
          source: "local"
          agentId: ""
          commandPath: "omp"
          commandArgs: ["acp"]
          customModels: ["corp-gateway-anthropic/claude-opus-5-5"]
        }
      }
      customAgent: {
        driver: "claudeAgent"
        displayName: "Custom Claude"
        enabled: true
      }
    }
  }
}

def "test activation replaces empty or non-record settings with the managed ones" [] {
  let expected = {
    defaultRuntimeMode: "auto"
    pullRequestMergeMethod: "squash"
    providerInstances: {
      omp: (managed-omp "omp")
    }
  }

  for user_settings in ["" "[]" "null"] {
    let dir = (mktemp --directory | path expand --strict)
    let target = (activate ($dir | path join "t3") $user_settings)

    assert equal (open $target) $expected $"user settings: ($user_settings)"
  }
}
