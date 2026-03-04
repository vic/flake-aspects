{
  pkgs ? import <nixpkgs> { },
  ...
}:
import ./nix/lib.nix pkgs.lib
