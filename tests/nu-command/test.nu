#!/usr/bin/env nu

# ==================================================================================================
# Nushell Command Test
# ==================================================================================================
# Asserts the adapter's translation of `config`, `flags`, and `libDirs`, which devkit's tests do
# not cover.
# ==================================================================================================

use std/assert

def main [configured: path, plain: path, with_lib: path, bundled: path] {
  assert equal (^$configured | from json) {
    config: { name: "adapter", nested: { value: 2 } }
    mode: "fast"
    count: 3
  }

  assert equal (^$plain | from json) {
    config: null
    mode: null
    count: null
  }

  assert equal (^$with_lib | str trim) "hello adapter"
  assert equal (^$bundled | from json) {}
}
