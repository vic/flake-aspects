{ inputs, lib, ... }:
let
  targetNix = "${inputs.target}/nix";
  targetLib = "${inputs.target}/nix/lib.nix";
  targetMod = "${inputs.target}/nix/flakeModule.nix";

  transpose = import targetNix { inherit lib; };

  mkFlake =
    mod:
    inputs.flake-parts.lib.mkFlake
      {
        inputs.self = [ ];
      }
      {
        systems = [ ];
        imports = [
          targetMod
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
  _module.args = {
    inherit
      transpose
      targetLib
      targetMod
      targetNix
      ;
    inherit mkFlake evalMod fooOpt;
  };
}
