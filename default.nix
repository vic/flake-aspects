{
  lib,
  emit ? lib.singleton,
}:
let
  transposeItem =
    child: parent: value:
    emit { inherit child parent value; };
  accTransposed =
    acc: item:
    acc
    // {
      ${item.parent} = (acc.${item.parent} or { }) // {
        ${item.child} = item.value;
      };
    };
  transposeItems = parent: lib.mapAttrsToList (transposeItem parent);
  deconstruct = lib.mapAttrsToList transposeItems;
  reconstruct = lib.foldl accTransposed { };
  transpose =
    attrs:
    lib.pipe attrs [
      deconstruct
      lib.flatten
      reconstruct
    ];
in
transpose
