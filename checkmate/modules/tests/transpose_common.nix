{ transpose, ... }:
{

  flake.tests."test transpose common childs become one parent" = {
    expr = transpose {
      a.b = 1;
      c.b = 2;
    };
    expected.b = {
      a = 1;
      c = 2;
    };
  };

}
