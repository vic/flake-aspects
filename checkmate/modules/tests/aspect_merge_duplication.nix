{ lib, targetLib, ... }:
let
  flake-aspects-lib = import targetLib lib;
in
{
  # Test demonstrating duplication issue when merging aspect structures
  # from multiple sources using lib.mkMerge at the module level.
  #
  # The problem: when lib.mkMerge combines pre-evaluated aspect structures,
  # the recursive resolution in resolve.nix processes includes multiple times,
  # causing multiplicative duplication.
  #
  # This reproduces the issue seen in den's namespace.nix where:
  #   config.den.ful.${name} = lib.mkMerge denfuls;
  # causes 64x duplication when merging multiple input flakes.

  flake.tests."test mkMerge aspect duplication" =
    let
      # Create two separate pre-evaluated aspect scopes
      inputA = lib.evalModules {
        modules = [
          (flake-aspects-lib.new-scope "ns")
          { ns.aspects.foo.nixos.vals = [ "A" ]; }
        ];
      };

      inputB = lib.evalModules {
        modules = [
          (flake-aspects-lib.new-scope "ns")
          { ns.aspects.bar.nixos.vals = [ "B" ]; }
        ];
      };

      # Merge using lib.mkMerge - reproduces den namespace.nix pattern
      merged = lib.evalModules {
        modules = [
          (flake-aspects-lib.new-scope "ns")
          {
            ns = lib.mkMerge [
              inputA.config.ns
              inputB.config.ns
            ];
          }
          {
            ns.aspects.combined.nixos.vals = [ "C" ];
            ns.aspects.combined.includes = [
              merged.config.ns.aspects.foo
              merged.config.ns.aspects.bar
            ];
          }
        ];
      };

      # Resolve
      resolved = merged.config.ns.aspects.combined.modules.nixos;
      result = lib.evalModules {
        modules = [
          resolved
          { options.vals = lib.mkOption { type = lib.types.listOf lib.types.str; }; }
        ];
      };

      allVals = result.config.vals;
      sortedVals = lib.sort lib.lessThan allVals;

    in
    {
      expr = sortedVals;
      expected = [
        "A"
        "B"
        "C"
      ];
    };
}
