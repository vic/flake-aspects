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
        value = aspect.resolve { class = transposed.parent; };
      }
    ];
in
{
  transposed = transpose aspects;
}
