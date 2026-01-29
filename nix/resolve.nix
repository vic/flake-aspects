# Core aspect resolution algorithm
# Resolves aspect definitions into nixpkgs modules with dependency resolution

lib:
let
  # Process a single provider: invoke with context and resolve
  include =
    class: aspect-chain: provider:
    let
      provided = provider { inherit aspect-chain class; };
    in
    resolve class aspect-chain provided;

  # Main resolution: extract class config and recursively resolve includes
  resolve = class: aspect-chain: provided: {
    imports = lib.flatten [
      (provided.${class} or { })
      (lib.map (include class (aspect-chain ++ [ provided ])) provided.includes)
    ];
  };

in
resolve
