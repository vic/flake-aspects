lib:
let
  types = import ./types.nix lib;
  transpose =
    {
      emit ? lib.singleton,
    }:
    import ./default.nix { inherit lib emit; };
  aspects = import ./aspects.nix lib;
  new = import ./new.nix lib;
  new-scope = import ./new-scope.nix new;
in
{
  inherit
    types
    transpose
    aspects
    new
    new-scope
    ;
}
