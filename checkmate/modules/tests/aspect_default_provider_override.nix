{
  mkFlake,
  evalMod,
  ...
}:
{

  flake.tests."test override default provider includes" =
    let
      flake = mkFlake {
        flake.aspects =
          { aspects, ... }:
          {
            aspectOne = {
              classOne.bar = [ "should-not-be-present" ];
              includes = [ aspects.aspectTwo ];
              __functor = aspect: {
                includes = [
                  { classOne.bar = [ "from-functor" ]; }
                ]
                ++ map (f: f { message = "hello"; }) aspect.includes;
              };
            };
            aspectTwo.__functor =
              _aspect:
              { message }:
              {
                classOne.bar = [ message ];
              };
          };
      };

      expr = (evalMod "classOne" flake.modules.classOne.aspectOne).bar;
      expected = [
        "hello"
        "from-functor"
      ];
    in
    {
      inherit expr expected;
    };
}
