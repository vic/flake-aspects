{
  mkFlake,
  evalMod,
  lib,
  ...
}:
{

  flake.tests."test override default provider" =
    let
      flake = mkFlake {
        flake.aspects =
          { aspects, ... }:
          {
            aspectOne =
              { aspect, ... }:
              {
                includes = [ (aspects.aspectTwo { message = "hello ${aspect.name}"; }) ];
                classOne = { }; # required for propagation
              };

            aspectTwo.__functor =
              _:
              { message }: # args must be always named
              { class, aspect-chain }:
              { aspect, ... }:
              {
                classOne.bar = [
                  "foo"
                  aspect.name
                  message
                  class
                ]
                ++ (lib.map (x: x.name) aspect-chain);
              };
            aspectTwo.classOne.bar = [ "itself not included" ];
          };
      };

      expr = (evalMod "classOne" flake.modules.classOne.aspectOne).bar;
      expected = [
        "foo"
        "<function body>"
        "hello aspectOne"
        "classOne"
        "aspectOne"
      ];
    in
    {
      inherit expr expected;
    };

}
