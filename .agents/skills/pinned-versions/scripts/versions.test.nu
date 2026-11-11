#!/usr/bin/env nu

# ==================================================================================================
# Pinned Version Comparison Tests
# ==================================================================================================

use std/assert

const SCRIPT_DIR = path self "."
const SCRIPT = ($SCRIPT_DIR | path join "versions.nu")

source $SCRIPT

def "test version helpers compare naturally and select the newest valid tag" [] {
  let selections = [
    {
      name: "higher version in original order"
      tags: ["1.2.0" "1.3.0"]
      allow: false
      expected: "1.3.0"
    }
    {
      name: "higher version in reversed order"
      tags: ["1.3.0" "1.2.0"]
      allow: false
      expected: "1.3.0"
    }
    {
      name: "natural core comparison"
      tags: ["1.9.0" "1.10.0"]
      allow: false
      expected: "1.10.0"
    }
    {
      name: "final before same core pre-release"
      tags: ["2.0.0" "2.0.0-rc.1"]
      allow: true
      expected: "2.0.0"
    }
    {
      name: "final after same core pre-release"
      tags: ["2.0.0-rc.1" "2.0.0"]
      allow: true
      expected: "2.0.0"
    }
    {
      name: "pre-release allowed on higher core"
      tags: ["1.4.0" "1.5.0-beta.1"]
      allow: true
      expected: "1.5.0-beta.1"
    }
    {
      name: "later higher beta wins"
      tags: ["2.2.0-beta.2" "3.0.0-beta.6"]
      allow: true
      expected: "3.0.0-beta.6"
    }
    {
      name: "multi digit pre-release comparison"
      tags: ["1.0.0-alpha.9" "1.0.0-alpha.10"]
      allow: true
      expected: "1.0.0-alpha.10"
    }
    {
      name: "bare tags exclude pre-releases"
      tags: ["1.9.0" "2.0.0-rc.1"]
      allow: false
      expected: "1.9.0"
    }
    {
      name: "empty tags"
      tags: []
      allow: false
      expected: ""
    }
    {
      name: "only non-version tags"
      tags: ["release-notes" "macos-27-preview.5"]
      allow: false
      expected: ""
    }
  ]

  for case in $selections {
    let actual = if $case.allow {
      newest-version $case.tags --allow-pre-release
    } else {
      newest-version $case.tags
    }

    assert equal $actual $case.expected $case.name
  }

  let comparisons = [
    {
      name: "compare numeric core components"
      older: "1.9.0"
      newer: "1.10.0"
    }
    {
      name: "compare final with same core pre-release"
      older: "2.0.0-rc.1"
      newer: "2.0.0"
    }
  ]

  for case in $comparisons {
    assert (version-at-least $case.newer $case.older) $case.name
    assert (version-older $case.older $case.newer) $case.name
  }
}
