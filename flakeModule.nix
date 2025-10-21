{ lib, config, ... }:
let
  flakeModules =
    let
      aspects = config.flake.aspects;
      transpose = import ./. { inherit lib emit; };
      require =
        fromAspect: class: f:
        (f fromAspect).${class} or { };
      emit =
        transposed:
        let
          class = transposed.parent;
          aspect = transposed.child;
          required.imports = lib.map (require aspect class) aspects.${aspect}.require;
          item = {
            inherit (transposed) parent child;
            value.imports = [
              transposed.value
              required
            ];
          };
        in
        [
          item
        ];
    in
    transpose aspects;

  aspectSubmoduleType = lib.types.submodule (
    { name, config, ... }:
    {
      freeformType = lib.types.lazyAttrsOf lib.types.deferredModule;
      options.description = lib.mkOption {
        description = "Aspect description";
        default = "Aspect ${name}";
        type = lib.types.str;
      };
      options.require = lib.mkOption {
        description = "Providers to ask aspects from";
        type = lib.types.listOf providerType;
        default = [ ];
      };
      options.provide = lib.mkOption {
        description = "Providers for ${name} aspect";
        default = { };
        type = lib.types.submodule {
          freeformType = lib.types.lazyAttrsOf providerType;
          options.default = lib.mkOption {
            description = "Provider of ${name} aspect";
            type = providerType;
            default = _: config;
          };
        };
      };
    }
  );

  providerType = lib.types.functionTo aspectSubmoduleType;
in
{
  options.flake.aspects = lib.mkOption {
    default = { };
    description = ''
      Attribute set of `<aspect>.<class>` modules.

      Convenience transposition of `flake.modules.<class>.<aspect>`.
    '';
    type = lib.types.submodule {
      freeformType = lib.types.lazyAttrsOf aspectSubmoduleType;
    };
  };
  config.flake.modules = flakeModules;
}
