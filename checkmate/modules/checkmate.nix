{ inputs, lib, ... }:
{
  imports = [
    inputs.nix-unit.modules.flake.default
    inputs.treefmt-nix.flakeModule
  ];
  systems = import inputs.systems;

  perSystem =
    { self', ... }:
    {
      packages.fmt = self'.formatter;
      treefmt.projectRoot = inputs.target;
      nix-unit = {
        allowNetwork = true;
        inputs = inputs;
      };
      treefmt.programs = {
        nixfmt.enable = true;
      };
      treefmt.settings.global.excludes = [
        "LICENSE"
      ];
    };
}
