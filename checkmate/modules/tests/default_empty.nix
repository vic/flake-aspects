{
  inputs,
  targetMod,
  ...
}:
{

  flake.tests."test provides default" =
    let
      flake =
        inputs.flake-parts.lib.mkFlake
          {
            inputs.self = [ ];
            moduleLocation = builtins.toString ./.;
          }
          {
            systems = [ ];
            imports = [
              targetMod
              inputs.flake-parts.flakeModules.modules
            ];
          };
      expr = flake.modules;
      expected = { };
    in
    {
      inherit expr expected;
    };
}
