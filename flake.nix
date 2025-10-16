{
  outputs = _: {
    __functor = _: import ./.;
    flakeModule = ./flakeModule.nix;
  };
}
