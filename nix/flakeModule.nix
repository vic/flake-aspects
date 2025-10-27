{
  lib,
  config,
  ...
}:
import ./new.nix lib (option: transposed: {
  options.flake.aspects = option;
  config.flake.modules = transposed;
}) config.flake.aspects
