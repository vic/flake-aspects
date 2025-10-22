{
  lib,
  config,
  ...
}:
let
  aspects = import ./aspects.nix lib config.flake.aspects;
  types = import ./types.nix lib;
in
{
  options.flake.aspects = lib.mkOption {
    default = { };
    description = ''
      Attribute set of `<aspect>.<class>` modules.

      Convenience transposition of `flake.modules.<class>.<aspect>`.
    '';
    type = types.aspectsType;
  };
  config.flake.modules = aspects.transposed;
}
