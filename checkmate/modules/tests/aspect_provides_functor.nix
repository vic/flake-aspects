{
  mkFlake,
  evalMod,
  ...
}:
{

  flake.tests."test provides with functors" =
    let
      flake = mkFlake {
        flake.aspects =
          { aspects, ... }:
          {
            aspectOne = {
              includes = [ aspects.aspectTwo._.aspectThree._.aspectFour ];
              classOne = { };
            };
            aspectTwo.provides.aspectThree = {
              provides.aspectFour.classOne.bar = [ "hello" ];
              __functor = self: _: self;
            };
          };
      };

      expr = (evalMod "classOne" flake.modules.classOne.aspectOne).bar;
      expected = [
        "hello"
      ];
    in
    builtins.trace expr {
      inherit expr expected;
    };
}
