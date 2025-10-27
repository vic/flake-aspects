{
  lib,
  config,
  ...
}:
let
  newAspects = import ./new.nix lib;
  mod = newAspects (option: transposed: {
    options.flake.aspects = option;
    config.flake.modules = transposed;
  }) config.flake.aspects;
in
{
  imports = [ mod ];
}
