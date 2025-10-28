{
  outputs = _: {
    __functor = _: import ./nix;
    flakeModule = ./nix/flakeModule.nix;
    lib = import ./nix/lib.nix;
  };
}
