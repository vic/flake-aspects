lib:
let

  aspectsType = lib.types.submodule {
    freeformType = lib.types.lazyAttrsOf aspectSubmoduleType;
  };

  providerType = lib.types.functionTo aspectSubmoduleType;

  aspectSubmoduleType = lib.types.submodule (
    { name, config, ... }:
    {
      freeformType = lib.types.lazyAttrsOf lib.types.deferredModule;
      options.name = lib.mkOption {
        description = "Aspect name";
        default = name;
        type = lib.types.str;
      };
      options.description = lib.mkOption {
        description = "Aspect description";
        default = "Aspect ${name}";
        type = lib.types.str;
      };
      options.includes = lib.mkOption {
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
        visible = false;
        description = "Functor to default provider";
        type = lib.types.functionTo lib.types.unspecified;
        default = _: config.provides.itself;
      };
    }
  );

in
{
  inherit aspectsType;
}
