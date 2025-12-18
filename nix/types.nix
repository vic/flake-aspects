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
            config._module.args.aspects = config;
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
          { class, aspect-chain }:
          # silence nixf-diagnose :/
          if true || (class aspect-chain) then aspect else aspect;
      };
      options.modules = lib.mkOption {
        internal = true;
        visible = false;
        description = "resolved modules from this aspect";
        # Use a custom type that always takes the last value (no merging)
        type = lib.types.mkOptionType {
          name = "aspectModules";
          description = "resolved modules from aspect";
          merge = _loc: _defs: lib.mapAttrs (class: _: config.resolve { inherit class; }) config;
          check = _: true;
        };
        default = lib.mapAttrs (class: _: config.resolve { inherit class; }) config;
      };
      options.resolve = lib.mkOption {
        internal = true;
        visible = false;
        description = "function to resolve a module from this aspect";
        # Use a custom type that always takes the last value (no merging)
        type = lib.types.mkOptionType {
          name = "aspectResolve";
          description = "resolve function for aspect";
          merge =
            _loc: _defs:
            {
              class,
              aspect-chain ? [ ],
            }:
            resolve class aspect-chain (config {
              inherit class aspect-chain;
            });
          check = _: true;
        };
        default =
          {
            class,
            aspect-chain ? [ ],
          }:
          resolve class aspect-chain (config {
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
