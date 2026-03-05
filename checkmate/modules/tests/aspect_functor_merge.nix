# Test that when multiple modules define the same aspect with a custom
# __functor twice, the functor is not called once per definition (which would
# duplicate the includes). Using lib.types.functionTo merges both functors.
#
# This was a bug where `functionTo` merge would
# invoke all definitions and merge their results, causing duplication
# when the functor uses `self` (the merged aspect) to produce includes.
#
# See https://github.com/vic/den/issues/216
{ lib, new-scope, ... }:
{

  flake.tests."test functor merge does not duplicate includes" =
    let
      first = lib.evalModules {
        modules = [
          (new-scope "kit")
          # Two separate modules defining the same aspect with same __functor.
          {
            kit.aspects.groups = {
              myclass.names = [ "alice" ];
              __functor = self: {
                inherit (self) myclass;
              };
            };
          }
          {
            kit.aspects.groups = {
              myclass.names = [ "bob" ];
              __functor = self: {
                inherit (self) myclass;
              };
            };
          }
          (
            { config, ... }:
            {
              kit.aspects.main = {
                myclass.names = [ "main" ];
                includes = [ config.kit.aspects.groups ];
              };
            }
          )
        ];
      };

      second = lib.evalModules {
        modules = [
          { options.names = lib.mkOption { type = lib.types.listOf lib.types.str; }; }
          first.config.kit.modules.myclass.main
        ];
      };

      expr = lib.sort (a: b: a < b) second.config.names;
      expected = [
        "alice"
        "bob"
        "main"
      ];
    in
    {
      inherit expr expected;
    };

}
