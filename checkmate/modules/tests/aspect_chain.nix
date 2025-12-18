{
  lib,
  mkFlake,
  evalMod,
  fooOpt,
  ...
}:
{

  flake.tests."test resolve aspect-chain" =
    let
      flake = mkFlake {
        flake.aspects =
          { aspects, ... }:
          {
            aspectOne = {
              name = "one";
              includes = [ aspects.aspectOne.provides.dos ];
              classOne.bar = [ "zzz" ];
              provides.dos =
                { aspect-chain, ... }:
                {
                  name = "dos";
                  includes = [ aspects.aspectOne.provides.tres ];
                  classOne.bar = map (x: x.name) aspect-chain;
                };

              provides.tres =
                { aspect-chain, ... }:
                {
                  name = "tres";
                  classOne.bar = [ (lib.last aspect-chain).name ];
                };
            };
          };
      };
      mod = {
        imports = [
          fooOpt
          (flake.aspects.aspectOne.resolve { class = "classOne"; })
        ];
      };
      expr = lib.sort (a: b: a < b) (evalMod "classOne" mod).bar;
      expected = [
        "dos"
        "one"
        "zzz"
      ];
    in
    {
      inherit expr expected;
    };
}
