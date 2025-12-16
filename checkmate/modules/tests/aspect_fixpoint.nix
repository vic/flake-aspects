{
  lib,
  mkFlake,
  evalMod,
  ...
}:
{

  flake.tests."test provides using fixpoints" =
    let
      flake = mkFlake {
        flake.aspects =
          { aspects, ... }@top:
          {
            aspectOne = {
              classOne.bar = [ "1" ];
              includes = [
                aspects.aspectTwo
              ];
            };

            aspectTwo = {
              classOne.bar = [ "2" ];
              includes = [ aspects.aspectTwo.provides.three-and-four-and-five ];
              provides =
                { aspects, ... }:
                {
                  three-and-four-and-five = {
                    classOne.bar = [ "3" ];
                    includes = [
                      aspects.four
                      top.aspects.five
                    ];
                  };
                  four = {
                    classOne.bar = [ "4" ];
                  };
                };
            };

            five.classOne.bar = [ "5" ];
          };
      };

      expr = lib.sort (a: b: a < b) (evalMod "classOne" flake.modules.classOne.aspectOne).bar;
      expected = [
        "1"
        "2"
        "3"
        "4"
        "5"
      ];
    in
    {
      inherit expr expected;
    };

}
