{ lib, targetLib, ... }:
{
  # This test verifies that we can define aspects inside
  # an scope and then merge them in another scope.
  #
  # This is important for Den social aspects, since people will
  # try to merge aspects from different sources, local, and remote flakes.
  flake.tests."test-assign-aspects-on-scopes" =
    let
      flake-aspects-lib = import targetLib lib;

      first = lib.evalModules {
        modules = [
          # each scope creates a new <name>.aspects tree.
          (flake-aspects-lib.new-scope "foo")
          (flake-aspects-lib.new-scope "bar")
          (flake-aspects-lib.new-scope "baz")
          # create a._.b._.c aspect on each namespace
          # we will be trying to merge them for this test.
          {
            foo.aspects.a._.b._.c.nixos.x = [ "foo" ];
          }
          {
            bar.aspects.a._.b._.c.nixos.x = [ "bar" ];
          }
          {
            baz.aspects.a._.b._.c.nixos.x = [ "baz" ];
          }
          (
            { config, ... }:
            {
              bar = config.foo; # bar merges all of foo
            }
          )
          (
            { config, ... }:
            {
              baz = config.bar; # baz merges all of baz
            }
          )
        ];
      };

      second = lib.evalModules {
        modules = [
          # We evaluate the abc nixos module from baz
          first.config.baz.aspects.a._.b._.c.modules.nixos
          # create the options to merge all different values
          { options.x = lib.mkOption { type = lib.types.listOf lib.types.str; }; }
        ];
      };

      # Sort and dedupe for deterministic comparison - merged modules may
      # produce duplicates and order is not guaranteed across merges.
      expr = lib.sort (a: b: a < b) (lib.unique second.config.x);
      expected = [
        "bar"
        "baz"
        "foo"
      ];
    in
    {
      inherit expected expr;
    };

}
