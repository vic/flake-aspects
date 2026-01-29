# Low-level aspect scope factory
# Creates aspect integration via callback pattern for maximum flexibility
lib: cb: cfg:
let
  # Import aspects transposer: validates and transposes aspect config
  aspects = import ./aspects.nix lib cfg;

  # Import type system for aspect validation
  types = import ./types.nix lib;

  # Create aspects input option
  option = lib.mkOption {
    default = { };
    description = "Aspect definitions organized as <aspect>.<class>";
    type = types.aspectsType;
  };
in
# Invoke callback with option and transposed results
cb option aspects.transposed
