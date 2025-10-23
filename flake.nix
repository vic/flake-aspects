{
  outputs = _: {
    __functor = _: import ./nix;
    flakeModule = ./nix/flakeModule.nix;
  };
}
