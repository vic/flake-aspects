{ lib, targetLib, ... }:
{

  flake.tests."test usage without flakes" =
    let
      flake-aspects-lib = import targetLib lib;
      # first eval is like evaling the flake.
      first = lib.evalModules {
        modules = [
          (flake-aspects-lib.new-scope "hello")
          {
            hello.aspects =
              { aspects, ... }:
              {
                a.b.c = [ "world" ];
                a.includes = [ aspects.x ];
                x.b =
                  { lib, ... }:
                  {
                    c = lib.splitString " " "mundo cruel";
                  };
              };
          }
        ];
      };
      # second eval is like evaling its nixosConfiguration
      second = lib.evalModules {
        modules = [
          { options.c = lib.mkOption { type = lib.types.listOf lib.types.str; }; }
          first.config.hello.modules.b.a
        ];
      };
      expr = lib.sort (a: b: a < b) second.config.c;
      expected = [
        "cruel"
        "mundo"
        "world"
      ];
    in
    {
      inherit expr expected;
    };

}
