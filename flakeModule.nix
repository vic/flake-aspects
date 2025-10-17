{ lib, config, ... }:
{
  options.flake.aspects = lib.mkOption {
    description = ''
      Attribute set of `<aspect>.<class>` modules.

      Convenience transposition of `flake.modules.<class>.<aspect>`.
    '';
    default = { };
    type = lib.types.lazyAttrsOf (lib.types.lazyAttrsOf lib.types.deferredModule);
  };
  config.flake.modules = import ./. lib config.flake.aspects;
}
