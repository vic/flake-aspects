{
  mkFlake,
  evalMod,
  lib,
  forward,
  ...
}:
{
  flake.tests.test-forward =
    let
      forwarded =
        # deadnix: skip
        { class, aspect-chain }:
        forward {
          each = [ "source" ];
          fromClass = item: "${item}Class";
          intoClass = _item: "targetClass";
          intoPath = _item: [ "targetMod" ];
          fromAspect = _item: lib.head aspect-chain;
        };

      targetSubmodule = {
        options.targetMod = lib.mkOption {
          type = lib.types.submoduleWith {
            modules = [
              {
                options.names = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                };
              }
            ];
          };
        };
      };

      flake = mkFlake {
        flake.aspects = {
          fwd-self-target = {
            targetClass = {
              imports = [ targetSubmodule ];
              targetMod.names = [ "from-target" ];
            };

            sourceClass.names = [ "from-source" ];

            includes = [ forwarded ];
          };
        };
      };

      expr =
        lib.sort (a: b: a < b)
          (evalMod "targetClass" flake.modules.targetClass.fwd-self-target).targetMod.names;

      expected = [
        "from-source"
        "from-target"
      ];
    in
    {
      inherit expr expected;
    };

}
