lib:
let
  resolve = import ./resolve.nix lib;

  aspectsType = lib.types.submodule (
    { config, ... }:
    {
      freeformType = lib.types.attrsOf (lib.types.either aspectSubmoduleAttrs providerType);
      config._module.args.aspects = config;
    }
  );

  # checks the argument names to be those of a provider function:
  #
  # { class, aspect-chain } => aspect-object
  # { class, ... } => aspect-object
  # { aspect-chain, ... } => aspect-object
  functionToAspect = lib.types.addCheck (lib.types.functionTo aspectSubmodule) (
    f:
    let
      args = lib.functionArgs f;
      arity = lib.length (lib.attrNames args);
      hasClass = args ? class;
      hasChain = args ? aspect-chain;
      classOnly = hasClass && arity == 1;
      chainOnly = hasChain && arity == 1;
      both = hasClass && hasChain && arity == 2;
    in
    classOnly || chainOnly || both
  );

  functionProviderType = lib.types.either functionToAspect (lib.types.functionTo providerType);
  providerType = lib.types.either functionProviderType aspectSubmodule;

  aspectSubmoduleAttrs = lib.types.addCheck aspectSubmodule (
    m: (!builtins.isFunction m) || (isAspectSubmoduleFn m)
  );
  isAspectSubmoduleFn =
    m:
    lib.pipe m [
      lib.functionArgs
      lib.attrNames
      (lib.intersectLists [
        "lib"
        "config"
        "options"
        "aspect"
      ])
      (x: lib.length x > 0)
    ];

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
          }
        );
      };
      options.__functor = lib.mkOption {
        internal = true;
        visible = false;
        description = "Functor to default provider";
        type = lib.types.functionTo providerType;
        default =
          aspect:
          # deadnix: skip
          { class, aspect-chain }:
          aspect;
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
          resolve class aspect-chain (aspect {
            inherit class aspect-chain;
          });
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
