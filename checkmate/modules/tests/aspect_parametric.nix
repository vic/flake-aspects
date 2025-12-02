{
  mkFlake,
  evalMod,
  lib,
  ...
}:
{

  flake.tests."test provides parametrized modules" =
    let
      flake = mkFlake {
        flake.aspects =
          { aspects, ... }:
          {
            aspectOne.includes = [ (aspects.aspectTwo.provides.hello "mundo") ];
            aspectOne.classOne.bar = [ "1" ];

            aspectTwo.provides.hello = world: {
              classOne.bar = [ world ];
            };
          };
      };

      expr = lib.sort (a: b: a < b) (evalMod "classOne" flake.modules.classOne.aspectOne).bar;
      expected = [
        "1"
        "mundo"
      ];
    in
    {
      inherit expr expected;
    };

}
