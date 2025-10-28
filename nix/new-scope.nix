# usage:
#
# { inputs, ... }: {
#   imports = [ (new-scope "foo") ];
#   foo.aspects.<aspect> = ...;
#   # and use foo.modules.<class>.<aspect>
# }
#
# returns a nix module that defines the ${name} option having:
#
#   options.${name}.aspects # for user
#   options.${name}.modules # read-only resolved modules.
#
# for lower-level usage like using other option names, see new.nix.
new: name:
{ config, lib, ... }:
new (option: transposed: {
  options.${name} = {
    aspects = option;
    modules = lib.mkOption {
      readOnly = true;
      default = transposed;
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.deferredModule);
    };
  };
}) config.${name}.aspects
