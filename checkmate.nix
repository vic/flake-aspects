{ inputs, ... }:
{
  perSystem =
    { lib, ... }:
    let
      transpose = import ./. lib;

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
              { flake.modules.nixos.tooling.imports = [ toolOpt ]; }
              { flake.modules.darwin.tooling.imports = [ toolOpt ]; }
            ];
          };

      toolOpt = {
        options.tool = lib.mkOption {
          type = lib.types.string;
          default = "<unset>";
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
              flake.aspects.tooling = {
                nixos.tool = "niri";
                darwin.tool = "paper.spoon";
              };
            };
            expr = {
              nixos = (evalMod "nixos" flake.modules.nixos.tooling);
              darwin = (evalMod "darwin" flake.modules.darwin.tooling);
            };
            expected = {
              nixos.tool = "niri";
              darwin.tool = "paper.spoon";
            };
          in
          {
            inherit expr expected;
          };
      };
    };
}
