{ lib, mkFlake, ... }:
{
  flake.tests."test _file on simple aspect" =
    let
      flake = mkFlake {
        flake.aspects.aspectOne.classOne.bar = [ "x" ];
      };
      mod = flake.aspects.aspectOne.resolve { class = "classOne"; };
    in
    {
      expr = mod._file;
      expected = "flake.aspects:aspectOne.classOne";
    };

  flake.tests."test _file overriden" =
    let
      flake = mkFlake {
        flake.aspects.aspectOne = {
          _file = "foo";
          classOne.bar = [ "x" ];
        };
      };
      mod = flake.aspects.aspectOne.resolve { class = "classOne"; };
    in
    {
      expr = mod._file;
      expected = "foo";
    };

  flake.tests."test _file respects custom aspect name" =
    let
      flake = mkFlake {
        flake.aspects.aspectOne = {
          name = "my-one";
          classOne.bar = [ "x" ];
        };
      };
      mod = flake.aspects.aspectOne.resolve { class = "classOne"; };
    in
    {
      expr = mod._file;
      expected = "flake.aspects:my-one.classOne";
    };

  flake.tests."test _file on named include has index" =
    let
      flake = mkFlake {
        flake.aspects =
          { aspects, ... }:
          {
            aspectOne = {
              classOne.bar = [ "one" ];
              includes = [ aspects.aspectTwo ];
            };
            aspectTwo.classOne.bar = [ "two" ];
          };
      };
      mod = flake.aspects.aspectOne.resolve { class = "classOne"; };
      include0 = lib.elemAt mod.imports 1;
    in
    {
      expr = include0._file;
      expected = "flake.aspects:aspectOne.includes[0].aspectTwo.classOne";
    };

  flake.tests."test _file on second include has index 1" =
    let
      flake = mkFlake {
        flake.aspects =
          { aspects, ... }:
          {
            aspectOne = {
              classOne.bar = [ "one" ];
              includes = [
                aspects.aspectTwo
                aspects.aspectThree
              ];
            };
            aspectTwo.classOne.bar = [ "two" ];
            aspectThree.classOne.bar = [ "three" ];
          };
      };
      mod = flake.aspects.aspectOne.resolve { class = "classOne"; };
      include1 = lib.elemAt mod.imports 2;
    in
    {
      expr = include1._file;
      expected = "flake.aspects:aspectOne.includes[1].aspectThree.classOne";
    };

  flake.tests."test _file on class config wrapper matches root" =
    let
      flake = mkFlake {
        flake.aspects.aspectOne.classOne.bar = [ "x" ];
      };
      mod = flake.aspects.aspectOne.resolve { class = "classOne"; };
      classConfigWrapper = lib.head mod.imports;
    in
    {
      expr = classConfigWrapper._file;
      expected = "flake.aspects:aspectOne.classOne";
    };

  flake.tests."test _file on anonymous function include is not function body" =
    let
      flake = mkFlake {
        flake.aspects.aspectOne = {
          classOne.bar = [ "x" ];
          includes = [
            (
              { ... }:
              {
                classOne.bar = [ "from-fn" ];
              }
            )
          ];
        };
      };
      mod = flake.aspects.aspectOne.resolve { class = "classOne"; };
      include0 = lib.elemAt mod.imports 1;
    in
    {
      expr = lib.hasPrefix "flake.aspects:aspectOne.includes[0]." include0._file;
      expected = true;
    };

  flake.tests."test _file on deeply nested includes" =
    let
      flake = mkFlake {
        flake.aspects =
          { aspects, ... }:
          {
            aspectOne = {
              classOne.bar = [ "one" ];
              includes = [ aspects.aspectTwo ];
            };
            aspectTwo = {
              classOne.bar = [ "two" ];
              includes = [ aspects.aspectThree ];
            };
            aspectThree.classOne.bar = [ "three" ];
          };
      };
      modOne = flake.aspects.aspectOne.resolve { class = "classOne"; };
      modTwo = lib.elemAt modOne.imports 1;
      modThree = lib.elemAt modTwo.imports 1;
    in
    {
      expr = [
        modOne._file
        modTwo._file
        modThree._file
      ];
      expected = [
        "flake.aspects:aspectOne.classOne"
        "flake.aspects:aspectOne.includes[0].aspectTwo.classOne"
        "flake.aspects:aspectOne.includes[0].aspectTwo.includes[0].aspectThree.classOne"
      ];
    };

  flake.tests."test _file on provides include" =
    let
      flake = mkFlake {
        flake.aspects =
          { aspects, ... }:
          {
            aspectOne = {
              classOne.bar = [ "one" ];
              includes = [ aspects.aspectTwo.provides.helper ];
            };
            aspectTwo.provides.helper = {
              name = "helper";
              classOne.bar = [ "help" ];
            };
          };
      };
      mod = flake.aspects.aspectOne.resolve { class = "classOne"; };
      include0 = lib.elemAt mod.imports 1;
    in
    {
      expr = include0._file;
      expected = "flake.aspects:aspectOne.includes[0].helper.classOne";
    };

  flake.tests."test _file on deeply nested provides" =
    let
      flake = mkFlake {
        flake.aspects =
          { aspects, ... }:
          {
            aspectOne = {
              classOne.bar = [ "one" ];
              includes = [ aspects.aspectTwo.provides.helper ];
            };
            aspectTwo.provides.helper = {
              name = "helper";
              classOne.bar = [ "help" ];
              includes = [ aspects.aspectThree.provides.sub ];
            };
            aspectThree.provides.sub = {
              name = "sub";
              classOne.bar = [ "sub" ];
            };
          };
      };
      modOne = flake.aspects.aspectOne.resolve { class = "classOne"; };
      helper = lib.elemAt modOne.imports 1;
      sub = lib.elemAt helper.imports 1;
    in
    {
      expr = [
        helper._file
        sub._file
      ];
      expected = [
        "flake.aspects:aspectOne.includes[0].helper.classOne"
        "flake.aspects:aspectOne.includes[0].helper.includes[0].sub.classOne"
      ];
    };
}
