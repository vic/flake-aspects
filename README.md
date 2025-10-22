<!-- Badges -->

<p align="right">
  <a href="https://nixos.org/"> <img src="https://img.shields.io/badge/Nix-Flake-informational?logo=nixos&logoColor=white" alt="Nix Flake"/> </a>
  <a href="https://github.com/vic/flake-aspects/actions">
  <img src="https://github.com/vic/flake-aspects/actions/workflows/test.yml/badge.svg" alt="CI Status"/> </a>
  <a href="LICENSE"> <img src="https://img.shields.io/github/license/vic/flake-aspects" alt="License"/> </a>
</p>

# `<aspect>.<class>` transposition for Dendritic Nix

On [aspect oriented](https://vic.github.io/dendrix/Dendritic.html) [Dendritic](https://github.com/mightyiam/dendritic) setups, it is common to expose modules using `flake.modules.<class>.<aspect>`.
However, for humans, it might be more intuitive to use a transposed attrset `<aspect>.<class>`. Because it feels more natural to nest classes inside aspects than the other way around.

This project provides a [`transpose`](tree/main/default.nix) primitive, small and powerful enough to implement [cross-aspect dependencies](tree/main/aspects.nix) for *any* nix configuration class, and a [flake-parts module](./tree/main/flakeModule.nix) for turning `flake.aspects` into `flake.modules`.

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

## Usage

### As a deps-free library from `./default.nix`:

Our [`transpose`](tree/main/default.nix) library takes an optional `emit` function that
can be used to ignore some items, modify them or produce many other items on its place.

```nix
let transpose = import ./default.nix { lib = pkgs.lib; }; in
transpose { a.b.c = 1; } # => { b.a.c = 1; }
```

This `emit` function is used by our [`aspects`](tree/main/aspects.nix) library
(both libs are flakes-independent) to provide cross-aspects same-class module dependencies.

### As a *Dendritic* flake-parts module that provides the `flake.aspects` option:

> `flake.aspects` transposes into `flake.modules`.

```nix
# code in this example can (and should) be split into different dendritic modules.
{ inputs, ... }: {
  imports = [ inputs.flake-aspects.flakeModule ];
  flake.aspects = {

    sliding-desktop = {
      description = "nextgen tiling windowing";
      nixos  = { }; # configure Niri on Linux
      darwin = { }; # configure Paneru on MacOS
    };


    awesome-cli = {
      description = "enhances environment with best of cli an tui";
      nixos  = { }; # os services
      darwin = { }; # apps like ghostty, iterm2
      homeManager = { }; # fish aliases, tuis, etc.
      nixvim = { }; # plugins
    };

    work-network = {
      description = "work vpn and ssh access.";
      nixos = {};  # enable openssh
      darwin = {}; # enable MacOS ssh server
      terranix = {}; # provision vpn
      hjem = {}; # home link .ssh keys and configs.
    }

  };
}
```

#### Declaring cross-aspect dependencies

`flake.aspects` also allow to dependencies between aspects.

Of course each module can have its own `imports`, however aspect requirements
are aspect-level instead of module-level. Dependencies will ultimately resolve to
modules and get imported only when they exist.

In the following example, our `development-server` aspect can be applied into
linux and macos hosts.
Note that `alice` prefers to use `nixos`+`homeManager`, while `bob` likes `darwin`+`hjem`.

The `development-server` is a "usability concern", that configures the exact same
development tools on two different OS.
When it is applied to a NixOS machine, the `alice.nixos` module will likely
configure the alice user, but there is no nixos user for `bob`.

```nix
{
  flake.aspects = {config, ...}: {
    development-server = {
      requires = with config; [ alice bob ];

      # without flake-aspects, you'd normally do:
      # nixos.imports  = [ inputs.self.modules.nixos.alice ];
      # darwin.imports = [ inputs.self.modules.darwin.bob ];
    };

    alice = { 
      nixos = {};
    };

    bob = {
      darwin = {};
    };
  };
}
```

It is out of scope for this library to create OS configurations.
As you might have guessed, exposing configurations would look like this:

```nix
{ inputs, ... }:
{
  flake.nixosConfigurations.fooHost = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [ inputs.self.modules.nixos.development-server ];
  };

  flake.darwinConfigurations.fooHost = inputs.darwin.lib.darwinSystem {
    system = "aarm64-darwin";
    modules = [ inputs.self.modules.darwin.development-server ];
  };
}
```

#### Advanced aspect dependencies.

You have already seen that an `aspect` can have a `requires` list:

```nix
# A foo aspect that depends on aspects bar and baz.
flake.aspects = { config, ... }: {
  foo.requires = [ config.bar config.baz ];
}
```

cross-aspect requirements work like this:

When a module `flake.modules.nixos.foo` is requested (eg, included in a nixosConfiguration),
a corresponding module will be computed from `flake.aspects.foo.nixos`.

`flake.aspects.foo.requires` is a list of functions (named **providers**)
that will be called with `{name = "foo"; class = "nixos"}` to obtain another aspect
providing a module having the same `class` (`nixos` in our example).

_providers_ are a way of asking: if I have a (`foo`, `nixos`) module what other
aspects can you provide that have `nixos` modules to be imported in `foo`.

> This way, it is aspects *being included* who decide what configuration must
> be used by its caller aspect.

by default, all aspects have a `<aspect>.provides.itself` function that ignores its argument
and always returns the `<aspect>` itself.
This is why you can use the `with config; [ bar baz ]` syntax.
They are actually `[ config.bar.provides.itself  config.baz.provides.itself ]`.

but you can also define custom providers that can inspect the argument's `name` and `class`
and return some another aspect accordingly.

```nix
flake.aspects.alice.provides.os-user = { name, class, ... }: {
  # perhaps regexp matching on name or class. eg, match all "hosts" aspects.
  nixos = { };
}
```

the `os-user` provider can be now included in a `requires` list:

```nix
flake.aspects = {config, ...}: {
  home-server.requires = [ config.alice.provides.os-user ];
}
```

## Testing

```shell
nix run ./checkmate#fmt --override-input target .
nix flake check ./checkmate --override-input target . -L
```
