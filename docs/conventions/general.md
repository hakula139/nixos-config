# General

## Script language

Nushell is the default for new helper scripts. Bash is only for scripts another shell evaluates or sources, as with `makeWrapper --run` snippets, and for `exec` wrappers that only set a variable and hand off.

## Section banners

Every language uses these banners, which end at column 100, including indentation. Use equals signs for the file header (unindented) and dashes for inner subsections (indented to match the surrounding code):

```nix
# ==================================================================================================
# Module Name
# ==================================================================================================

      # --------------------------------------------------------------------------------------------
      # Subsection
      # --------------------------------------------------------------------------------------------
```

Place a file description inside the header banner after the title, and close it with a third line of equals signs.
