lib: aspects:
let
  transpose = import ./. { inherit lib emit; };
  emit =
    transposed:
    let
      aspect = aspects.${transposed.child};
    in
    [
      {
        inherit (transposed) parent child;
        value = aspectModule [ aspect ] transposed.parent aspect;
      }
    ];

  include =
    aspect-chain: class: provider:
    let
      provided = provider { inherit aspect-chain class; };
      new-chain = aspect-chain ++ [ provided ];
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
