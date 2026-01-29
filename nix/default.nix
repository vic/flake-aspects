# Generic 2-level attribute set transposition
# Swaps parent/child levels: { a.b = 1; } → { b.a = 1; }
# Parameterized via emit function for custom value handling

{
  lib,
  # emit: Customization function for each item during transpose
  # Signature: { child, parent, value } → [{ parent, child, value }]
  # Default: lib.singleton (identity transformation)
  emit ? lib.singleton,
}:
let
  # Create transposition metadata by calling emit
  transposeItem =
    child: parent: value:
    emit { inherit child parent value; };

  # Fold accumulator: rebuilds transposed structure
  accTransposed =
    acc: item:
    acc
    // {
      ${item.parent} = (acc.${item.parent} or { }) // {
        ${item.child} = item.value;
      };
    };

  # Process all children of a parent
  transposeItems = parent: lib.mapAttrsToList (transposeItem parent);

  # Flatten input into transposition items
  deconstruct = lib.mapAttrsToList transposeItems;

  # Fold items back into swapped structure
  reconstruct = lib.foldl accTransposed { };

  # Main transpose: deconstruct → flatten → reconstruct
  transpose =
    attrs:
    lib.pipe attrs [
      deconstruct
      lib.flatten
      reconstruct
    ];
in
transpose
