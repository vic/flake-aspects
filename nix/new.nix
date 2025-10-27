# creates a new aspects option.
# See flakeModule for usage.
lib: cb: cfg:
let
  aspects = import ./aspects.nix lib cfg;
  types = import ./types.nix lib;
  option = lib.mkOption {
    default = { };
    description = ''
      Attribute set of `<aspect>.<class>` modules.

      Convenience transposition of `flake.modules.<class>.<aspect>`.
    '';
    type = types.aspectsType;
  };
in
cb option aspects.transposed
