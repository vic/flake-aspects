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
    aspect-chain: class: f:
    let
      asp = f { inherit aspect-chain class; };
      new-chain = aspect-chain ++ [ asp.name ];
    in
    aspectModule new-chain class asp;

  aspectModule =
    aspect-chain: class: asp:
    let
      module.imports = lib.flatten [
        (asp.${class} or { })
        (lib.map (include aspect-chain class) asp.includes)
      ];
    in
    module;
in
{
  transposed = transpose aspects;
}
