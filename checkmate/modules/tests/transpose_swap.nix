{ transpose, ... }:
{

  flake.tests."test transpose swaps parent and child attrNames" = {
    expr = transpose { a.b.c = 1; };
    expected = {
      b.a.c = 1;
    };
  };
}
