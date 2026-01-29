# Transpose aspects.<aspect>.<class> to modules.<class>.<aspect>
# Resolves aspect dependencies and applies transformations during transposition

lib: aspects:
let
  # Import transpose utility with custom emit function for aspect resolution
  transpose = import ./. { inherit lib emit; };

  # Emit function: resolves each aspect for its target class
  # Returns: [{ parent = class, child = aspect, value = resolved-module }]
  emit = transposed: [
    {
      inherit (transposed) parent child;
      value = aspects.${transposed.child}.resolve { class = transposed.parent; };
    }
  ];
in
{
  # Exports: transposed.<class>.<aspect> = resolved-module
  transposed = transpose aspects;
}
