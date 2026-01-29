lib:
let
  # Import the resolve function which handles aspect resolution and dependency injection
  resolve = import ./resolve.nix lib;

  # Top-level aspects container type
  # This is the entry point for defining all aspects in a flake
  # Structure: aspects.<aspectName> = { ... }
  # Makes the entire aspects config available as 'aspects' in module args
  # allowing cross-referencing between aspects
  aspectsType = lib.types.submodule (
    { config, ... }:
    {
      # Allow arbitrary aspect definitions as attributes
      # Each aspect can be either:
      # - An aspect submodule (aspectSubmoduleAttrs)
      # - A provider function (providerType)
      freeformType = lib.types.lazyAttrsOf (lib.types.either aspectSubmoduleAttrs providerType);
      # Inject the aspects config into _module.args for cross-referencing
      config._module.args.aspects = config;
    }
  );

  # Type checker for provider functions with specific argument patterns
  # Valid provider function signatures:
  # 1. { class } => aspect-object
  # 2. { aspect-chain } => aspect-object
  # 3. { class, aspect-chain } => aspect-object
  # 4. { class, ... } => aspect-object (with other ignored args)
  # 5. { aspect-chain, ... } => aspect-object (with other ignored args)
  #
  # This ensures that provider functions receive the proper context when invoked
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

  # Provider functions can be:
  # 1. A function taking { class, aspect-chain } and returning an aspect (functionToAspect)
  # 2. A function taking parameters and returning another provider (curried)
  # This allows for parametric aspects and lazy evaluation
  functionProviderType = lib.types.either functionToAspect (lib.types.functionTo providerType);

  # Provider type allows three forms:
  # 1. A function provider (functionProviderType)
  # 2. An aspect configuration (aspectSubmodule)
  # This enables both immediate aspect definitions and deferred/parametric ones
  providerType = lib.types.either functionProviderType aspectSubmodule;

  # Additional validation for aspect submodules to ensure they're not mistyped functions
  # An aspectSubmoduleAttrs is either:
  # - Not a function at all (plain attribute set)
  # - A function with submodule-style arguments (lib, config, options, aspect)
  # This prevents accidentally treating provider functions as aspect configs
  aspectSubmoduleAttrs = lib.types.addCheck aspectSubmodule (
    m: (!builtins.isFunction m) || (isAspectSubmoduleFn m)
  );

  # Helper to identify if a function is a submodule-style function
  # Submodule functions take args like { lib, config, options, aspect, ... }
  # Returns true if the function accepts at least one of these special args
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

  # Special type that accepts any value but always merges to null
  # Used for internal computed values that shouldn't be serialized
  # This prevents type errors when values don't have proper types
  ignoredType = lib.types.mkOptionType {
    name = "ignored type";
    description = "ignored values";
    merge = _loc: _defs: null;
    check = _: true;
  };

  # Core aspect definition type
  # Each aspect represents a reusable configuration module that can:
  # - Define configuration for multiple "classes" (e.g., nixos, home-manager, darwin)
  # - Include other aspects as dependencies
  # - Provide sub-aspects for selective composition
  # - Be parametrized via __functor
  aspectSubmodule = lib.types.submodule (
    {
      name,
      config,
      ...
    }:
    {
      # Allow arbitrary class configurations (e.g., nixos, home-manager, etc.)
      # Each class maps to a deferred module that will be resolved later
      freeformType = lib.types.attrsOf lib.types.deferredModule;

      # Make the aspect config available as 'aspect' in module args
      # This allows modules within the aspect to reference their own aspect
      config._module.args.aspect = config;

      # Create "_" as a shorthand alias for "provides"
      # Allows writing: aspect._.foo instead of aspect.provides.foo
      # This improves ergonomics for the common case of defining sub-aspects
      imports = [ (lib.mkAliasOptionModule [ "_" ] [ "provides" ]) ];

      # Human-readable aspect name, defaults to the attribute name
      # Used in aspect-chain tracking and for display purposes
      options.name = lib.mkOption {
        description = "Aspect name";
        default = name;
        type = lib.types.str;
      };

      # Optional description for documentation purposes
      # Defaults to a generic description using the aspect name
      options.description = lib.mkOption {
        description = "Aspect description";
        default = "Aspect ${name}";
        type = lib.types.str;
      };

      # Dependencies: list of other providers this aspect includes
      # During resolution, included aspects are merged with this aspect
      # Includes can be:
      # - Direct aspect references: aspects.otherAspect
      # - Parametrized providers: aspects.other.provides.foo "param"
      # - Functorized aspects: aspects.otherAspect { param = value; }
      # The resolution order matters for module merging semantics
      options.includes = lib.mkOption {
        description = "Providers to ask aspects from";
        type = lib.types.listOf providerType;
        default = [ ];
      };

      # Sub-aspects that can be selectively included by other aspects
      # This allows aspects to expose multiple named variants or components
      # Creates a fixpoint where provides can reference the aspects in their scope
      # The provides scope gets its own 'aspects' arg for internal cross-referencing
      options.provides = lib.mkOption {
        description = "Providers of aspect for other aspects";
        default = { };
        type = lib.types.submodule (
          { config, ... }:
          {
            # Allow arbitrary sub-aspect definitions
            freeformType = lib.types.attrsOf providerType;
            # Make the provides scope available as 'aspects' for fixpoint references
            # This enables provides.foo to reference provides.bar via aspects.bar
            config._module.args.aspects = config;
          }
        );
      };

      # Functor enables aspects to be callable like functions
      # When defined, calling aspect { param = value; } invokes the functor
      # The functor receives:
      # 1. The aspect config itself
      # 2. The parameters passed by the caller (which must include class and aspect-chain)
      # This allows aspects to be parametrized and context-aware
      #
      # The default functor:
      # - Takes the aspect config
      # - Takes { class, aspect-chain } parameters
      # - Returns the aspect unchanged (identity function with parameter access)
      # - The weird `if true || (class aspect-chain) then` is to silence nixf-diagnose
      #   about unused variables while ensuring they're in scope
      options.__functor = lib.mkOption {
        internal = true;
        visible = false;
        description = "Functor to default provider";
        type = lib.types.functionTo providerType;
        default =
          aspect:
          { class, aspect-chain }:
          # silence nixf-diagnose about unused variables
          if true || (class aspect-chain) then aspect else aspect;
      };

      # Convenience accessor: aspect.modules.<class> automatically resolves
      # This is equivalent to calling aspect.resolve { class = "<class>"; }
      # Returns a map of all classes with their resolved modules
      #
      # For example: aspect.modules.nixos == aspect.resolve { class = "nixos"; }
      #
      # This is computed lazily and uses ignoredType to avoid serialization issues
      options.modules = lib.mkOption {
        internal = true;
        visible = false;
        readOnly = true;
        description = "resolved modules from this aspect";
        type = ignoredType;
        # For each class in the aspect, resolve it with empty aspect-chain
        apply = _: lib.mapAttrs (class: _: config.resolve { inherit class; }) config;
      };

      # Main resolution function that converts an aspect into a nixpkgs module
      # Takes { class, aspect-chain } and returns a resolved module
      # - class: The target configuration class (e.g., "nixos", "home-manager")
      # - aspect-chain: List of aspects traversed so far (for tracking dependencies)
      #
      # The resolution process:
      # 1. Invokes the aspect config with class and aspect-chain parameters
      #    This triggers the __functor if defined, allowing parametrization
      # 2. Calls resolve.nix to recursively resolve includes
      # 3. Returns a module with imports from the aspect and its dependencies
      #
      # The aspect-chain parameter allows aspects to introspect their dependency tree
      # This is useful for debugging and for aspects that need to know their context
      options.resolve = lib.mkOption {
        internal = true;
        visible = false;
        readOnly = true;
        description = "function to resolve a module from this aspect";
        type = ignoredType;
        apply =
          _:
          {
            class,
            aspect-chain ? [ ],
          }:
          # Invoke config (the aspect) with class and aspect-chain parameters
          # This works because config is wrapped with __functor via the submodule system
          # Then pass the result to resolve for dependency resolution
          resolve class aspect-chain (config {
            inherit class aspect-chain;
          });
      };
    }
  );

in
{
  inherit
    aspectsType # Main entry point for flake.aspects
    aspectSubmodule # Individual aspect definition type
    providerType # Type for provider expressions
    ;
}
