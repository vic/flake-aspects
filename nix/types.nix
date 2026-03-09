lib:
let
  resolve = import ./resolve.nix lib;

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

  functorType = lib.types.mkOptionType {
    name = "aspectFunctor";
    description = "aspect functor function";
    check = lib.isFunction;
    merge =
      _loc: defs:
      let
        lastDef = lib.last defs;
      in
      {
        __functionArgs = lib.functionArgs lastDef.value;
        __functor =
          _: callerArgs:
          let
            result = lastDef.value callerArgs;
          in
          if builtins.isFunction result then result else _: result;
      };
  };

  isSubmoduleFn =
    m:
    let
      args = lib.functionArgs m;
    in
    args ? lib || args ? config || args ? options || args ? aspect;

  # Check if function accepts { class } and/or { aspect-chain }
  isProviderFn =
    f:
    let
      args = lib.functionArgs f;
      n = builtins.length (builtins.attrNames args);
    in
    (args ? class && n == 1)
    || (args ? aspect-chain && n == 1)
    || (args ? class && args ? aspect-chain && n == 2);

  # Direct provider function: ({ class, aspect-chain }) → aspect
  directProviderFn =
    cnf: lib.types.addCheck (lib.types.functionTo (aspectSubmodule cnf)) isProviderFn;

  # Curried provider function: (params) → provider (enables parametrization)
  curriedProviderFn =
    cnf:
    lib.types.addCheck (lib.types.functionTo (providerType cnf)) (
      f:
      builtins.isFunction f
      || lib.isAttrs f && lib.subtractLists [ "__functor" "__functionArgs" ] (lib.attrNames f) == [ ]
    );

  # Any provider function: direct or curried
  providerFn = cnf: lib.types.either (directProviderFn cnf) (curriedProviderFn cnf);

  # Provider type: function or aspect that can provide configurations
  providerType = cnf: lib.types.either (providerFn cnf) (aspectSubmodule cnf);

  # Core aspect submodule with all aspect properties
  aspectSubmodule =
    cnf:
    lib.types.submodule (
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
            type = lib.types.listOf (providerType cnf);
            default = [ ];
          };

          provides = lib.mkOption {
            description = "Providers of aspect for other aspects";
            default = { };
            type = lib.types.submodule (
              { config, ... }:
              {
                freeformType = lib.types.lazyAttrsOf (providerType cnf);
                config._module.args.aspects = config;
              }
            );
          };

          __functor = lib.mkOption {
            internal = true;
            visible = false;
            description = "Functor to default provider";
            type = functorType; # (providerType cnf);
            default =
              let
                defaultFunctor = aspect: { class, aspect-chain }: if true then aspect else class aspect-chain;
              in
              cnf.defaultFunctor or defaultFunctor;
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

  # Top-level aspects container with fixpoint semantics
  aspectsType =
    cnf:
    lib.types.submodule (
      { config, ... }:
      {
        freeformType = lib.types.lazyAttrsOf (
          lib.types.either (lib.types.addCheck (aspectSubmodule cnf) (
            m: (!builtins.isFunction m) || isSubmoduleFn m
          )) (providerType cnf)
        );
        config._module.args.aspects = config;
      }
    );

in
{
  inherit aspectsType aspectSubmodule providerType;
}
