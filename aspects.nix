lib: aspects:
let
  transpose = import ./. { inherit lib emit; };
  emit = transposed: [
    {
      inherit (transposed) parent child;
      value = aspectModule [ transposed.child ] transposed.parent aspects.${transposed.child};
    }
  ];

  include =
    aspect-chain: class: provider:
    let
      provided = provider { inherit aspect-chain class; };
      new-chain = aspect-chain ++ [ provided.name ];
    in
    aspectModule new-chain class provided;

  aspectModule = aspect-chain: class: provided: {
    imports = lib.flatten [
      (provided.${class} or { })
      (lib.map (include aspect-chain class) provided.includes)
    ];
  };
in
{
  transposed = transpose aspects;
}
