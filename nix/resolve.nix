lib:
let

  include =
    class: aspect-chain: provider:
    let
      provided = provider { inherit aspect-chain class; };
    in
    resolve class aspect-chain provided;

  resolve = class: aspect-chain: provided: {
    imports = lib.flatten [
      (provided.${class} or { })
      (lib.map (include class (aspect-chain ++ [ provided ])) provided.includes)
    ];
  };

in
resolve
