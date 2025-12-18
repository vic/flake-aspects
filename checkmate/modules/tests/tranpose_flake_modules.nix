{
  mkFlake,
  evalMod,
  ...
}:
{

  flake.tests."test transposes to flake.modules" =
    let
      flake = mkFlake {
        flake.aspects.aspectOne = {
          classOne.foo = "niri";
          classTwo.foo = "paper.spoon";
        };
      };
      expr = {
        classOne = (evalMod "classOne" flake.modules.classOne.aspectOne).foo;
        classTwo = (evalMod "classTwo" flake.modules.classTwo.aspectOne).foo;
      };
      expected = {
        classOne = "niri";
        classTwo = "paper.spoon";
      };
    in
    {
      inherit expr expected;
    };
}
