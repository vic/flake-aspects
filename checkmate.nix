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

        aspects."test providers" =
          let
            flake = mkFlake ({
              flake.aspects =
                { config, ... }:
                {
                  aspectOne = {
                    description = "os config";
                    require = with config; [ aspectTwo.provide.default ];
                    classOne.foo = lib.mkDefault "os";
                  };

                  aspectTwo = {
                    description = "user config at os level";
                    classOne.foo = "user";
                  };
                };
            });
            expr = (evalMod "classOne" flake.modules.classOne.aspectOne).foo;
            expected = "user";
          in
          {
            inherit expr expected;
          };
      };

    };
}
