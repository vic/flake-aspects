<!-- Badges -->

<p align="right">
  <a href="https://nixos.org/"> <img src="https://img.shields.io/badge/Nix-Flake-informational?logo=nixos&logoColor=white" alt="Nix Flake"/> </a>
  <a href="https://github.com/vic/flake-aspects/actions">
  <img src="https://github.com/vic/flake-aspects/actions/workflows/test.yml/badge.svg" alt="CI Status"/> </a>
  <a href="LICENSE"> <img src="https://img.shields.io/github/license/vic/flake-aspects" alt="License"/> </a>
</p>

# `<aspect>.<class>` transposition for Dendritic Nix

<table>
<tr>
<td>
<b><code>flake.aspects</code></b>

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

</td>
<td>
<img width="400" height="400" alt="image" src="https://github.com/user-attachments/assets/dd28ce8d-f727-4e31-a192-d3002ee8984e" />
</td>
<td>
<code>flake.modules</code>

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

</td>
</tr>
</table>

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
