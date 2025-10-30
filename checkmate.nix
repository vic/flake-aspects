{ inputs, ... }:
{
  perSystem =
    { lib, ... }:
    let
      transpose = import ./nix { inherit lib; };

      mkFlake =
        mod:
        inputs.flake-parts.lib.mkFlake
          {
            inputs.self = [ ];
          }
          {
            systems = [ ];
            imports = [
              ./nix/flakeModule.nix
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
          type = lib.types.str;
          default = "<unset>";
        };
        options.bar = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
        };
        options.baz = lib.mkOption {
          type = lib.types.lazyAttrsOf lib.types.str;
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

        new-scope."test usage without flakes" =
          let
            flake-aspects-lib = import ./nix/lib.nix lib;
            # first eval is like evaling the flake.
            first = lib.evalModules {
              modules = [
                (flake-aspects-lib.new-scope "hello")
                {
                  hello.aspects =
                    { aspects, ... }:
                    {
                      a.b.c = [ "world" ];
                      a.includes = [ aspects.x ];
                      x.b =
                        { lib, ... }:
                        {
                          c = lib.splitString " " "mundo cruel";
                        };
                    };
                }
              ];
            };
            # second eval is like evaling its nixosConfiguration
            second = lib.evalModules {
              modules = [
                { options.c = lib.mkOption { type = lib.types.listOf lib.types.str; }; }
                first.config.hello.modules.b.a
              ];
            };
            expr = lib.sort (a: b: a < b) second.config.c;
            expected = [
              "cruel"
              "mundo"
              "world"
            ];
          in
          {
            inherit expr expected;
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
                    ./nix/flakeModule.nix
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

        aspects."test resolve aspect-chain" =
          let
            flake = mkFlake {
              flake.aspects = {
                aspectOne =
                  { aspect, ... }:
                  {
                    name = "one";
                    includes = [ aspect.provides.dos ];
                    classOne.bar = [ "zzz" ];
                    provides.dos =
                      { aspect-chain, ... }:
                      {
                        name = "dos";
                        includes = [ aspect.provides.tres ];
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
                          three-and-four-and-five = {
                            classOne.bar = [ "3" ];
                            includes = [
                              provides.four
                              aspects.five
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

        aspects."test provides parametrized modules" =
          let
            flake = mkFlake {
              flake.aspects =
                { aspects, ... }:
                {
                  aspectOne.includes = [ (aspects.aspectTwo.provides.hello "mundo") ];
                  aspectOne.classOne.bar = [ "1" ];

                  aspectTwo.provides.hello = world: {
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

        aspects."test override default provider" =
          let
            flake = mkFlake {
              flake.aspects =
                { aspects, ... }:
                {
                  aspectOne.includes = [ (aspects.aspectTwo { message = "hello"; }) ];
                  aspectOne.classOne = { }; # required for propagation

                  aspectTwo.__functor =
                    _:
                    { message }: # args must be always named
                    { class, aspect-chain }:
                    { aspect, ... }:
                    {
                      classOne.bar = [
                        aspect.name
                        message
                        class
                      ] ++ (lib.map (x: x.name) aspect-chain);
                    };
                  aspectTwo.classOne.bar = [ "itself not included" ];
                };
            };

            expr = (evalMod "classOne" flake.modules.classOne.aspectOne).bar;
            expected = [
              "<function body>"
              "hello"
              "classOne"
              "aspectOne"
            ];
          in
          {
            inherit expr expected;
          };

        aspects."test override default provider includes" =
          let
            flake = mkFlake {
              flake.aspects =
                { aspects, ... }:
                {
                  aspectOne =
                    { aspect, ... }:
                    {
                      classOne.bar = [ "should-not-be-present" ];
                      includes = [ aspects.aspectTwo ];
                      __functor = _: {
                        includes = [
                          { classOne.bar = [ "from-functor" ]; }
                        ] ++ map (f: f { message = "hello"; }) aspect.includes;
                      };
                    };
                  aspectTwo.__functor =
                    _:
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
      };

    };
}
