lib:
let
  include =
    class: aspect-chain: provider:
    let
      provided = if lib.isFunction provider then provider { inherit aspect-chain class; } else provider;
    in
    inner class aspect-chain provided;

  inner = class: aspect-chain: provided: {
    imports =
      let
        config = provided.${class} or { };
        includes = provided.includes or [ ];
      in
      lib.flatten [
        config
        (lib.map (include class (aspect-chain ++ [ provided ])) includes)
      ];
  };

  resolve =
    class: aspect-chain: aspect:
    let
      provided =
        if lib.isFunction aspect then
          aspect {
            inherit class;
            aspect-chain = aspect-chain;
          }
        else
          aspect;
    in
    inner class aspect-chain provided;
in
resolve
