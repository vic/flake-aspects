# Creates named aspect scopes: ${name}.aspects and ${name}.modules
# Enables multiple independent aspect namespaces
new: name:
{ config, lib, ... }:
# Invoke new() to create ${name}.aspects and ${name}.modules
new (option: transposed: {
  options.${name} = {
    # User-facing aspects input
    aspects = option;

    # Computed modules output (read-only)
    modules = lib.mkOption {
      readOnly = true;
      default = transposed;
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.deferredModule);
    };
  };
}) config.${name}.aspects
