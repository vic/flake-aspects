# Core type system for aspect-oriented configuration

lib:
let
  resolve = import ./resolve.nix lib;

  # Type for computed values that only exist during evaluation
  ignoredType = lib.types.mkOptionType {
    name = "ignored type";
    description = "ignored values";
    merge = _loc: _defs: null;
    check = _: true;
  };

  # Create internal read-only option with custom apply function
  mkInternal =
    desc: type: fn:
    lib.mkOption {
      internal = true;
      visible = false;
      readOnly = true;
      description = desc;
      inherit type;
      apply = fn;
    };

  # Check if function has submodule-style arguments
  isSubmoduleFn =
    m:
    lib.length (
      lib.intersectLists [ "lib" "config" "options" "aspect" ] (lib.attrNames (lib.functionArgs m))
    ) > 0;

  # Check if function accepts { class } and/or { aspect-chain }
  isProviderFn =
    f:
    let
      args = lib.functionArgs f;
      n = lib.length (lib.attrNames args);
    in
    (args ? class && n == 1)
    || (args ? aspect-chain && n == 1)
    || (args ? class && args ? aspect-chain && n == 2);

  # Direct provider function: ({ class, aspect-chain }) → aspect
  directProviderFn = lib.types.addCheck (lib.types.functionTo aspectSubmodule) isProviderFn;

  # Curried provider function: (params) → provider (enables parametrization)
  curriedProviderFn = lib.types.functionTo providerType;

  # Any provider function: direct or curried
  providerFn = lib.types.either directProviderFn curriedProviderFn;

  # Provider type: function or aspect that can provide configurations
  providerType = lib.types.either providerFn aspectSubmodule;

  # Core aspect submodule with all aspect properties
  aspectSubmodule = lib.types.submodule (
    { name, config, ... }:
    {
      freeformType = lib.types.lazyAttrsOf lib.types.deferredModule;
      config._module.args.aspect = config;
      imports = [ (lib.mkAliasOptionModule [ "_" ] [ "provides" ]) ];

      options = {
        name = lib.mkOption {
          description = "Aspect name";
          default = name;
          type = lib.types.str;
        };

        description = lib.mkOption {
          description = "Aspect description";
          default = "Aspect ${name}";
          type = lib.types.str;
        };

        includes = lib.mkOption {
          description = "Providers to ask aspects from";
          type = lib.types.listOf providerType;
          default = [ ];
        };

        provides = lib.mkOption {
          description = "Providers of aspect for other aspects";
          default = { };
          type = lib.types.submodule (
            { config, ... }:
            {
              freeformType = lib.types.lazyAttrsOf providerType;
              config._module.args.aspects = config;
            }
          );
        };

        __functor = lib.mkOption {
          internal = true;
          visible = false;
          description = "Functor to default provider";
          type = lib.types.functionTo providerType;
          default = aspect: { class, aspect-chain }: if true || (class aspect-chain) then aspect else aspect;
        };

        modules = mkInternal "resolved modules from this aspect" ignoredType (
          _: lib.mapAttrs (class: _: config.resolve { inherit class; }) config
        );

        resolve = mkInternal "function to resolve a module from this aspect" ignoredType (
          _:
          {
            class,
            aspect-chain ? [ ],
          }:
          resolve class aspect-chain (config {
            inherit class aspect-chain;
          })
        );
      };
    }
  );

in
{
  # Top-level aspects container with fixpoint semantics
  aspectsType = lib.types.submodule (
    { config, ... }:
    {
      freeformType = lib.types.lazyAttrsOf (
        lib.types.either (lib.types.addCheck aspectSubmodule (
          m: (!builtins.isFunction m) || isSubmoduleFn m
        )) providerType
      );
      config._module.args.aspects = config;
    }
  );

  inherit aspectSubmodule providerType;
}
