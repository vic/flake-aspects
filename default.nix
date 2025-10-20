lib:
let
  transposeChild = child: parent: value: { inherit child parent value; };

  accTransposed =
    acc:
    {
      parent,
      child,
      value,
    }:
    acc
    // {
      ${parent} = (acc.${parent} or { }) // {
        ${child} = value;
      };
    };

  eachChildAttrs = parent: lib.mapAttrsToList (transposeChild parent);
  deconstruct = lib.mapAttrsToList eachChildAttrs;
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
