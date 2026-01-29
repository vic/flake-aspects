# Flake-parts integration for aspect-oriented configuration
# Provides flake.aspects (input) and flake.modules (output)

{
  lib,
  config,
  ...
}:
# Invoke new() factory to create flake.aspects and flake.modules
import ./new.nix lib (option: transposed: {
  # User-facing aspects input
  options.flake.aspects = option;

  # Computed modules output organized by class
  config.flake.modules = transposed;
}) config.flake.aspects
