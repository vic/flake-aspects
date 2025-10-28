lib:
let
  resolve = import ./resolve.nix lib;

  aspectsType = lib.types.submodule (
    { config, ... }:
    {
      freeformType = lib.types.attrsOf aspectSubmodule;
      config._module.args.aspects = config;
    }
  );

  # checks the argument names to be those of a provider function:
  #
  # { class, aspect-chain } => aspect-object
  # { class, ... } => aspect-object
  # { aspect-chain, ... } => aspect-object
  # name => aspect-object
  functionToAspect = lib.types.addCheck (lib.types.functionTo aspectSubmodule) (
    f:
    let
      args = lib.functionArgs f;
      arity = lib.length (lib.attrNames args);
      isEmpty = arity == 0;
      hasClass = args ? class;
      hasChain = args ? aspect-chain;
      classOnly = hasClass && arity == 1;
      chainOnly = hasChain && arity == 1;
      both = hasClass && hasChain && arity == 2;
    in
    isEmpty || classOnly || chainOnly || both
  );

  functionProviderType = lib.types.either functionToAspect (lib.types.functionTo providerType);
  providerType = lib.types.either functionProviderType aspectSubmodule;

  aspectSubmodule = lib.types.submodule (
    {
      name,
      aspect,
      config,
      ...
    }:
    {
      freeformType = lib.types.attrsOf lib.types.deferredModule;
      config._module.args.aspect = config;
      imports = [ (lib.mkAliasOptionModule [ "_" ] [ "provides" ]) ];
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
        type = lib.types.submodule (
          { config, ... }:
          {
            freeformType = lib.types.attrsOf providerType;
            config._module.args.provides = config;
            options.itself = lib.mkOption {
              readOnly = true;
              description = "Provides itself";
              type = providerType;
              default = _: aspect;
            };
          }
        );
      };
      options.__functor = lib.mkOption {
        internal = true;
        visible = false;
        description = "Functor to default provider";
        type = lib.types.functionTo providerType;
        default = _: aspect.provides.itself;
      };
      options.resolve = lib.mkOption {
        internal = true;
        visible = false;
        readOnly = true;
        description = "function to resolve a module from this aspect";
        type = lib.types.functionTo lib.types.deferredModule;
        default =
          {
            class,
            aspect-chain ? [ ],
          }:
          resolve class aspect-chain aspect;
      };
    }
  );

in
{
  inherit
    aspectsType
    aspectSubmodule
    providerType
    ;
}
