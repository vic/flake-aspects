{
  outputs = _: {
    __functor = _: import ./nix;
    flakeModule = ./nix/flakeModule.nix;
    lib.types = import ./nix/types.nix;
  };
}
