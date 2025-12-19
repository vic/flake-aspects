{ lib, targetLib, ... }:
{
  flake.tests.test-aspects-merged-provides =
    let
      flake-aspects-lib = import targetLib lib;

      first = lib.evalModules {
        modules = [
          (flake-aspects-lib.new-scope "foo")
          (flake-aspects-lib.new-scope "bar")
          (flake-aspects-lib.new-scope "baz")
          {
            foo.aspects.a.provides.b.nixos.x = [ "b" ];
          }
          {
            bar.aspects.a.provides.c.nixos.x = [ "c" ];
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
              baz.aspects.all.nixos = { };
              baz.aspects.all.includes = [
                config.bar.aspects.a._.b
                config.bar.aspects.a._.c
              ];
            }
          )
        ];
      };

      second = lib.evalModules {
        modules = [
          first.config.baz.aspects.all.modules.nixos
          { options.x = lib.mkOption { type = lib.types.listOf lib.types.str; }; }
        ];
      };

      expr = lib.sort (a: b: a < b) (lib.unique second.config.x);
      expected = [
        "b"
        "c"
      ];
    in
    {
      inherit expr expected;
    };
}
