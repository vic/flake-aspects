lib: aspects:
let
  transpose = import ./. { inherit lib emit; };
  emit = transposed: [
    {
      inherit (transposed) parent child;
      value = aspectModule aspects.${transposed.child} transposed.parent;
    }
  ];

  aspectModule =
    aspect: class:
    let
      require = f: aspectModule (f (aspect // { inherit class; })) class;
      module.imports = lib.flatten [
        (aspect.${class} or { })
        (lib.map require aspect.requires)
      ];
    in
    module;
in
{
  transposed = transpose aspects;
}
