# test that an aspect tree can be used in a consumer flake
{ lib, targetLib, ... }:
{

  flake.tests."test aspects can be assigned across flakes" =
    let
      flake-aspects-lib = import targetLib lib;

      # first eval is like evaling the source flake
      first = lib.evalModules {
        modules = [
          (flake-aspects-lib.new-scope "ns") # namespace
          {
            ns.aspects.a._.b._.c.nixos.x = [ "first" ];
          }
        ];
      };

      # second eval is like evaling flake consuming source
      second = lib.evalModules {
        modules = [
          (flake-aspects-lib.new-scope "ns") # same namespace
          {
            ns = first.config.ns;
          }
        ];
      };

      third = lib.evalModules {
        modules = [
          (flake-aspects-lib.new-scope "ns") # same namespace
          {
            ns = second.config.ns;
          }
        ];
      };

      expr = third.config.ns;
      expected = first.config.ns;
    in
    builtins.break
    {
      inherit expected expr;
    };

}
