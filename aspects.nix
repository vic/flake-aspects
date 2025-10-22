lib: aspects:
let
  transpose = import ./. { inherit lib emit; };
  emit = transposed: [
    {
      inherit (transposed) parent child;
      value = aspectModule transposed.child transposed.parent aspects.${transposed.child};
    }
  ];

  include =
    aspect: class: f:
    let
      asp = f { inherit aspect class; };
    in
    aspectModule asp.name class asp;

  aspectModule =
    aspect: class: asp:
    let
      module.imports = lib.flatten [
        (asp.${class} or { })
        (lib.map (include aspect class) asp.includes)
      ];
    in
    module;
in
{
  transposed = transpose aspects;
}
