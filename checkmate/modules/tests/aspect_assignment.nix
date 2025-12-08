{ lib, targetLib, ... }:
{

  flake.tests."test-assign-aspects-on-scopes" =
    let
      flake-aspects-lib = import targetLib lib;

      first = lib.evalModules {
        modules = [
          (flake-aspects-lib.new-scope "foo")
          (flake-aspects-lib.new-scope "bar")
          (flake-aspects-lib.new-scope "baz")
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
              bar = config.foo;
            }
          )
          (
            { config, ... }:
            {
              baz = config.bar;
            }
          )
        ];
      };

      second = lib.evalModules {
        modules = [
          first.config.baz.aspects.a._.b._.c.modules.nixos
          { options.x = lib.mkOption { type = lib.types.listOf lib.types.str; }; }
        ];
      };

      expr = second.config.x;
      expected = [
        "foo"
        "bar"
        "baz"
      ];
    in
    {
      inherit expected expr;
    };

}
