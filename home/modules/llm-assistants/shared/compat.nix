{ lib }:

{
  mkRenamedOption =
    {
      option,
      oldName,
      newName,
      value,
    }:
    builtins.listToAttrs [
      (lib.nameValuePair (if builtins.hasAttr newName option then newName else oldName) value)
    ];
}
