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
      asp = provider { inherit aspect-chain class; };
      new-chain = aspect-chain ++ [ asp.name ];
    in
    aspectModule new-chain class asp;

  aspectModule = aspect-chain: class: asp: {
    imports = lib.flatten [
      (asp.${class} or { })
      (lib.map (include aspect-chain class) asp.includes)
    ];
  };
in
{
  transposed = transpose aspects;
}
