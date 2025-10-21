{
  lib,
  config,
  ...
}:
let
  aspects = config.flake.aspects;

  transpose = import ./. { inherit lib emit; };
  emit = transposed: [
    {
      inherit (transposed) parent child;
      value = aspectModule aspects.${transposed.child} transposed.parent;
    }
  ];

  aspectModule =
    aspect: class:
    let
      require = f: aspectModule (f (aspect // { inherit class; })) class;
      module.imports = lib.flatten [
        (aspect.${class} or { })
        (lib.map require aspect.requires)
      ];
    in
    module;

  providerType = lib.types.functionTo aspectSubmoduleType;

  aspectSubmoduleType = lib.types.submodule (
    { name, config, ... }:
    {
      freeformType = lib.types.lazyAttrsOf lib.types.deferredModule;
      options.name = lib.mkOption {
        readOnly = true;
        description = "Aspect name";
        default = name;
        type = lib.types.str;
      };
      options.description = lib.mkOption {
        description = "Aspect description";
        default = "Aspect ${name}";
        type = lib.types.str;
      };
      options.requires = lib.mkOption {
        description = "Providers to ask aspects from";
        type = lib.types.listOf providerType;
        default = [ ];
      };
      options.provides = lib.mkOption {
        description = "Providers of aspect for other aspects";
        default = { };
        type = lib.types.submodule {
          freeformType = lib.types.lazyAttrsOf providerType;
          options.itself = lib.mkOption {
            readOnly = true;
            description = "Provides itself";
            type = providerType;
            default = _: config;
          };
        };
      };
      options.__functor = lib.mkOption {
        internal = true;
        readOnly = true;
        visible = false;
        description = "Functor to default provider";
        type = lib.types.unspecified;
        default = _: config.provides.itself;
      };
    }
  );

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
  config.flake.modules = transpose aspects;
}
