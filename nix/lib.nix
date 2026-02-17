# Public API entry point for flake-aspects library
# Exports: types, transpose, aspects, new, new-scope
lib:
let
  # Type system: aspectsType, aspectSubmodule, providerType
  types = import ./types.nix lib;

  # Generic transposition utility: parameterized by emit function
  transpose =
    {
      emit ? lib.singleton,
    }:
    import ./default.nix { inherit lib emit; };

  # Aspect transposition with resolution
  aspects = import ./aspects.nix lib;

  # Dynamic class forwarding into submodules
  forward = import ./forward.nix lib;

  # Low-level scope factory: parameterized by callback
  new = import ./new.nix lib;

  # High-level named scope factory
  new-scope = import ./new-scope.nix new;
in
{
  inherit
    types
    transpose
    aspects
    new
    new-scope
    forward
    ;
}
