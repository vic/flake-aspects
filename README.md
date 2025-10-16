# flake-aspects

Tiny nix function and flake-parts-module that transposes an attribute set like:

```nix
{
  nixos = {
    foo = ...;
    bar = ...;
  };
  darwin = {
    bar = ...;
    baz = ...;
  };
}
```

Into

```nix
{
  foo = {
    nixos = ...;
  };
  bar = {
    nixos = ...;
    darwin = ...;
  };
  baz = {
    darwin = ...;
  };
}
```

## Motivation

On [Dendritic](https://github.com/mightyiam/dendritic) setups it is common to expose modules using `flake.modules.<class>.<aspect>` - see [aspect-oriented nix configurations](https://vic.github.io/dendrix/Dendritic.html).

However, for humans, it might be more intuitive to use a transposed attrset `<aspect>.<class>`. Because it feels more natural to nest classes on aspects than the other way around.

## Usage

As a deps-free library from `./default.nix`:

```nix
let transpose = import ./default.nix lib; in
transpose { a.b.c = 1; } # => { b.a.c = 1; }
```

As a *Dendritic* flake-parts module that provides the `flake.aspects` option:

> `flake.aspects` transposes into `flake.modules`.

```nix
{ inputs, ... }: {
  imports = [ inputs.flake-aspects.flakeModule ];
  flake.aspects.sliding-desktop = {
    nixos = { ... }; # configure Niri
    darwin = { ... }; # configure Paneru
  };
}
```

## Testing

```shell
nix run ./checkmate#fmt --override-input target .
nix flake check ./checkmate --override-input target . -L
```
