{
  lib,
  mkFlake,
  evalMod,
  ...
}:
{

  flake.tests."test provides" =
    let
      flake = mkFlake {
        flake.aspects =
          { aspects, ... }:
          {
            aspectOne.includes = with aspects.aspectTwo.provides; [
              foo
              bar
            ];
            aspectOne.classOne = { }; # must be present for mixing dependencies.
            aspectTwo = {
              classOne.bar = [ "class one not included" ];
              classTwo.bar = [ "class two not included" ];
              provides.foo =
                { class, aspect-chain }:
                {
                  name = "aspectTwo.foo";
                  description = "aspectTwo foo provided";
                  includes = [
                    aspects.aspectThree.provides.moo
                    aspects.aspectTwo.provides.baz
                  ];
                  classOne.bar = [ "two:${class}:${lib.concatStringsSep "/" (lib.map (x: x.name) aspect-chain)}" ];
                  classTwo.bar = [ "foo class two not included" ];
                };
              # a provider can be immediately an aspect object.
              provides.bar = {
                # classOne is missing on bar
                classTwo.bar = [ "bar class two not included" ];
              };
              # _ is an shortcut alias of provides.
              _.baz = {
                # classOne is missing on bar
                classTwo.bar = [ "baz" ];
              };
            };
            aspectThree.provides.moo =
              { aspect-chain, class }:
              {
                classOne.bar = [ "three:${class}:${lib.concatStringsSep "/" (lib.map (x: x.name) aspect-chain)}" ];
              };
          };
      };
      expr = lib.sort (a: b: a < b) (evalMod "classOne" flake.modules.classOne.aspectOne).bar;
      expected = [
        "three:classOne:aspectOne/aspectTwo.foo"
        "two:classOne:aspectOne"
      ];
    in
    {
      inherit expr expected;
    };

}
