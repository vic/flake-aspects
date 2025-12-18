{
  mkFlake,
  evalMod,
  lib,
  ...
}:
{

  flake.tests."test dependencies on aspects" =
    let
      flake = mkFlake {
        flake.aspects =
          { aspects, ... }:
          {
            aspectOne = {
              description = "os config";
              includes = with aspects; [ aspectTwo ];
              classOne.bar = [ "os" ];
            };

            aspectTwo = {
              description = "user config at os level";
              classOne.bar = [ "user" ];
            };
          };
      };
      expr = lib.sort (a: b: a < b) (evalMod "classOne" flake.modules.classOne.aspectOne).bar;
      expected = [
        "os"
        "user"
      ];
    in
    {
      inherit expr expected;
    };

}
