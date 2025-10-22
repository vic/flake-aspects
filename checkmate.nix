{ inputs, ... }:
{
  perSystem =
    { lib, ... }:
    let
      transpose = import ./. { inherit lib; };

      mkFlake =
        mod:
        inputs.flake-parts.lib.mkFlake
          {
            inputs.self = [ ];
          }
          {
            systems = [ ];
            imports = [
              ./flakeModule.nix
              inputs.flake-parts.flakeModules.modules
              mod
              (fooMod "aspectOne")
              (fooMod "aspectTwo")
              (fooMod "aspectThree")
            ];
          };

      fooMod = aspect: {
        imports = [
          { flake.modules.classOne.${aspect}.imports = [ fooOpt ]; }
          { flake.modules.classTwo.${aspect}.imports = [ fooOpt ]; }
          { flake.modules.classThree.${aspect}.imports = [ fooOpt ]; }
        ];
      };

      fooOpt = {
        options.foo = lib.mkOption {
          type = lib.types.string;
          default = "<unset>";
        };
        options.bar = lib.mkOption {
          type = lib.types.listOf lib.types.string;
          default = [ ];
        };
        options.baz = lib.mkOption {
          type = lib.types.lazyAttrsOf lib.types.string;
          default = { };
        };
      };

      evalMod =
        class: mod:
        (lib.evalModules {
          inherit class;
          modules = [ mod ];
        }).config;
    in
    {
      nix-unit.tests = {
        transpose."test swaps parent and child attrNames" = {
          expr = transpose { a.b.c = 1; };
          expected = {
            b.a.c = 1;
          };
        };

        transpose."test common childs become one parent" = {
          expr = transpose {
            a.b = 1;
            c.b = 2;
          };
          expected.b = {
            a = 1;
            c = 2;
          };
        };

        aspects."test provides default" =
          let
            flake =
              inputs.flake-parts.lib.mkFlake
                {
                  inputs.self = [ ];
                  moduleLocation = builtins.toString ./.;
                }
                {
                  systems = [ ];
                  imports = [
                    ./flakeModule.nix
                    inputs.flake-parts.flakeModules.modules
                  ];
                };
            expr = flake.modules;
            expected = { };
          in
          {
            inherit expr expected;
          };

        aspects."test transposes to flake.modules" =
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

        aspects."test dependencies on aspects" =
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

        aspects."test provides" =
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
                        includes = [ aspects.aspectThree.provides.moo ];
                        classOne.bar = [ "two:${class}:${lib.concatStringsSep "/" aspect-chain}" ];
                        classTwo.bar = [ "foo class two not included" ];
                      };
                    provides.bar = _: {
                      # classOne is missing on bar
                      classTwo.bar = [ "bar class two not included" ];
                    };
                  };
                  aspectThree.provides.moo =
                    { aspect-chain, class }:
                    {
                      classOne.bar = [ "three:${class}:${lib.concatStringsSep "/" aspect-chain}" ];
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

        aspects."test provides using fixpoints" =
          let
            flake = mkFlake {
              flake.aspects =
                { aspects, ... }:
                {
                  aspectOne = {
                    classOne.bar = [ "1" ];
                    includes = [
                      aspects.aspectTwo
                    ];
                  };

                  aspectTwo =
                    { aspect, ... }:
                    {
                      classOne.bar = [ "2" ];
                      includes = [ aspect.provides.three-and-four-and-five ];
                      provides =
                        { provides, ... }:
                        {
                          three-and-four-and-five = _: {
                            classOne.bar = [ "3" ];
                            includes = [
                              provides.four
                              aspects.five
                            ];
                          };
                          four = _: {
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

        aspects."test provides parametrized modules" =
          let
            flake = mkFlake {
              flake.aspects =
                { aspects, ... }:
                {
                  aspectOne.includes = [ (aspects.aspectTwo.provides.hello "mundo") ];
                  aspectOne.classOne.bar = [ "1" ];

                  aspectTwo.provides.hello =
                    world:
                    # deadnix: skip
                    { aspect-chain, class }:
                    {
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
      };

    };
}
