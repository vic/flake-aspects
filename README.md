<!-- Badges -->

<p align="right">
  <a href="https://dendritic.oeiuwq.com/sponsor"><img src="https://img.shields.io/badge/sponsor-vic-white?logo=githubsponsors&logoColor=white&labelColor=%23FF0000" alt="Sponsor Vic"/>
  </a>
  <a href="https://dendritic.oeiuwq.com"> <img src="https://img.shields.io/badge/Dendritic-Nix-informational?logo=nixos&logoColor=white" alt="Dendritic Nix"/> </a>
  <a href="https://github.com/vic/flake-aspects/actions">
  <img src="https://github.com/vic/flake-aspects/actions/workflows/test.yml/badge.svg" alt="CI Status"/> </a>
  <a href="LICENSE"> <img src="https://img.shields.io/github/license/vic/flake-aspects" alt="License"/> </a>
</p>

# `<aspect>.<class>` Transposition for Dendritic Nix

> `flake-aspects` and [vic](https://bsky.app/profile/oeiuwq.bsky.social)'s [dendritic libs](https://dendritic.oeiuwq.com) made for you with Love++ and AI--. If you like my work, consider [sponsoring](https://dendritic.oeiuwq.com/sponsor)

In [aspect-oriented](https://den.oeiuwq.com) [Dendritic](https://github.com/mightyiam/dendritic) setups, it is common to expose modules using the structure `flake.modules.<class>.<aspect>`.

However, for many users, a transposed attribute set, `<aspect>.<class>`, can be more intuitive. It often feels more natural to nest classes within aspects rather than the other way around.

This project provides a small, dependency-free [`transpose`](nix/default.nix) primitive that is powerful enough to implement [cross-aspect dependencies](nix/aspects.nix) for any Nix configuration class. It also includes a [flake-parts module](nix/flakeModule.nix) that transforms `flake.aspects` into `flake.modules`.

<table>
<tr>
<td>
<b><code>flake.aspects</code></b>

```nix
{
  vim-btw = {
    nixos = ...;
    darwin = ...;
    homeManager = ...;
    nixvim = ...;
  };
  tiling-desktop = {
    nixos = ...;
    darwin = ...;
  };
  macos-develop = {
    darwin = ...;
    hjem = ...;
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
    vim-btw = ...;
    tiling-desktop = ...;
  };
  darwin = {
    vim-btw = ...;
    tiling-desktop = ...;
    macos-develop = ...;
  };
  homeManager = {
    vim-btw = ...;
  };
  hjem = {
    macos-develop = ...;
  };
  nixvim = {
    vim-btw = ...;
  };
}
```

</td>
</tr>
</table>

Unlike `flake.modules.<class>.<aspect>` which is _flat_, aspects form a _tree_ via `provides` (alias: `_`) and a _graph_ via `includes`.

---

## Quick Start

```nix
# flake.nix
{
  inputs.flake-aspects.url = "github:vic/flake-aspects";
  outputs = { flake-parts, flake-aspects, nixpkgs, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ flake-aspects.flakeModule ];
      flake.aspects = { aspects, ... }: {
        my-desktop = {
          nixos  = { };
          darwin = { };
          includes = [ aspects.my-tools ];
        };
        my-tools.nixos = { };
      };
    };
}
```

Also works [without flakes](checkmate/modules/tests/without_flakes.nix) via `new-scope` and `lib.evalModules`.

## Documentation

**[Full documentation](https://flake-aspects.oeiuwq.com)**

| Section                                                             | Content                                                             |
| ------------------------------------------------------------------- | ------------------------------------------------------------------- |
| [Concepts](https://vic.github.io/flake-aspects/concepts/transpose/) | Transpose, resolution algorithm, providers & fixpoint               |
| [Guides](https://vic.github.io/flake-aspects/guides/flake-parts/)   | flake-parts, standalone, dependencies, parametric, functor, forward |
| [Reference](https://vic.github.io/flake-aspects/reference/api/)     | API exports, type system, test suite                                |

## Testing

```shell
nix run github:vic/checkmate#fmt --override-input target .
nix flake check github:vic/checkmate --override-input target . -L
```
