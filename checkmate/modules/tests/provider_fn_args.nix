{
  mkFlake,
  lib,
  ...
}:
{
  flake.tests."test provider functionArgs preserved through merge" =
    let
      flake = mkFlake {
        flake.aspects.aspectOne.provides.greet =
          { who }:
          {
            classOne.bar = [ "hello ${who}" ];
          };
      };
      provider = flake.aspects.aspectOne.provides.greet;
    in
    {
      expr = lib.functionArgs provider;
      expected = {
        who = false;
      };
    };

  flake.tests."test provider functionArgs preserved in includes" =
    let
      flake = mkFlake {
        flake.aspects =
          { aspects, ... }:
          {
            aspectOne.includes = [
              aspects.aspectTwo.provides.greet
            ];
            aspectOne.classOne = { };
            aspectTwo.provides.greet =
              { who }:
              {
                classOne.bar = [ "hello ${who}" ];
              };
          };
      };
      includes = flake.aspects.aspectOne.includes;
      fn = builtins.head (builtins.filter lib.isFunction includes);
    in
    {
      expr = lib.functionArgs fn;
      expected = {
        who = false;
      };
    };

  flake.tests."test provider functionArgs survives double eval" =
    let
      inner = mkFlake {
        flake.aspects.aspectOne.provides.greet =
          { who }:
          {
            classOne.bar = [ "hello ${who}" ];
          };
      };
      provider1 = inner.aspects.aspectOne.provides.greet;
      outer = mkFlake {
        flake.aspects.aspectOne.provides.greet = provider1;
      };
      provider2 = outer.aspects.aspectOne.provides.greet;
    in
    {
      expr = lib.functionArgs provider2;
      expected = {
        who = false;
      };
    };
}
