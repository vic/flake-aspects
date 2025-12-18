<!-- Badges -->

<p align="right">
  <a href="https://github.com/sponsors/vic"><img src="https://img.shields.io/badge/sponsor-vic-white?logo=githubsponsors&logoColor=white&labelColor=%23FF0000" alt="Sponsor Vic"/>
  </a>
  <a href="https://vic.github.io/dendrix/Dendritic-Ecosystem.html#vics-dendritic-libraries"> <img src="https://img.shields.io/badge/Dendritic-Nix-informational?logo=nixos&logoColor=white" alt="Dendritic Nix"/> </a>
  <a href="https://github.com/vic/flake-aspects/actions">
  <img src="https://github.com/vic/flake-aspects/actions/workflows/test.yml/badge.svg" alt="CI Status"/> </a>
  <a href="LICENSE"> <img src="https://img.shields.io/github/license/vic/flake-aspects" alt="License"/> </a>
</p>

# `<aspect>.<class>` Transposition for Dendritic Nix

> `flake-aspects` and [vic](https://bsky.app/profile/oeiuwq.bsky.social)'s [dendritic libs](https://vic.github.io/dendrix/Dendritic-Ecosystem.html#vics-dendritic-libraries) made for you with Love++ and AI--. If you like my work, consider [sponsoring](https://github.com/sponsors/vic)

In [aspect-oriented](https://vic.github.io/dendrix/Dendritic.html) [Dendritic](https://github.com/mightyiam/dendritic) setups, it is common to expose modules using the structure `flake.modules.<class>.<aspect>`.

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

Unlike `flake.modules.<class>.<aspect>` which is _flat_, aspects can be nested forming a _tree_ by using the `provides` (short alias: `_`) attribute. Each aspect can also specify a list of `includes` of other aspects, forming a _graph_ of dependencies.

```nix
{
  flake.aspects = {
    gaming = {
      nixos  = {};
      darwin = {};

      _.emulation = { aspect, ... }: {
        nixos = {};

        _.nes.nixos = {};
        _.gba.nixos = {};

        includes = with aspect._; [ nes gba ];
      };
    };
  };
}
```

## Usage

The library can be used in two ways: as a flakes-independent dependency-free utility or as a `flake-parts` module.

### As a Dependency-Free Library (`./nix/default.nix`)

The core of this project is the [`transpose`](nix/default.nix) function, which is powerful enough to implement cross-aspect dependencies for any Nix configuration class. It accepts an optional `emit` function that can be used to ignore items, modify them, or generate multiple items from a single input.

```nix
let transpose = import ./nix/default.nix { lib = pkgs.lib; }; in
transpose { a.b.c = 1; } # => { b.a.c = 1; }
```

This `emit` function is utilized by the [`aspects`](nix/aspects.nix) library to manage module dependencies between different aspects of the same class. Both `transpose` and `aspects` are independent of flakes.

#### Use aspects without flakes.

It is possible to use the aspects system as a library, [without flakes](https://github.com/vic/flake-aspects/blob/b94d806/checkmate.nix#L76). This can be used, for example, to avoid poluting flake-parts' `flake.modules` or by libraries that want to create own isolated aspects scope. For examples of this, see our own [flake-parts integration](nix/flakeModule.nix), and how [`den`](https://github.com/vic/den) creates its own [`den.aspects` scope](https://github.com/vic/den/blob/main/nix/scope.nix) independent of `flakes.aspects`/`flake.modules`.

### As a Dendritic Flake-Parts Module (`flake.aspects` option)

When used as a `flake-parts` module, the `flake.aspects` option is automatically transposed into `flake.modules`, making the modules available to consumers of your flake.

```nix
# The code in this example can (and should) be split into different Dendritic modules.
{ inputs, ... }: {
  imports = [ inputs.flake-aspects.flakeModule ];
  flake.aspects = {

    sliding-desktop = {
      description = "Next-generation tiling windowing";
      nixos  = { }; # Configure Niri on Linux
      darwin = { }; # Configure Paneru on macOS
    };

    awesome-cli = {
      description = "Enhances the environment with the best of CLI and TUI";
      nixos  = { };       # OS services
      darwin = { };       # Apps like ghostty, iTerm2
      homeManager = { };  # Fish aliases, TUIs, etc.
      nixvim = { };       # Plugins
    };

    work-network = {
      description = "Work VPN and SSH access";
      nixos = {};    # Enable OpenSSH
      darwin = {};   # Enable macOS SSH server
      terranix = {}; # Provision VPN
      hjem = {};     # Home: link .ssh keys and configs
    };

  };
}
```

#### Declaring Cross-Aspect Dependencies

Aspects can declare dependencies on other aspects using the `includes` attribute. This allows you to compose configurations in a modular way.

Dependencies are defined at the aspect level, not within individual modules. When a module from an aspect is evaluated (e.g., `flake.modules.nixos.development-server`), the library resolves all dependencies for the `nixos` class and imports the corresponding modules if they exist.

In the example below, the `development-server` aspect includes the `alice` and `bob` aspects. This demonstrates how to create a consistent development environment across different operating systems and user configurations.

```nix
{
  flake.aspects = { aspects, ... }: {
    development-server = {
      # This aspect now includes modules from 'alice' and 'bob'.
      includes = with aspects; [ alice bob ];

      # Without flake-aspects, you would have to do this manually for each class.
      # nixos.imports  = [ inputs.self.modules.nixos.alice ];
      # darwin.imports = [ inputs.self.modules.darwin.bob ];
    };

    alice = {
      nixos = {};
      homeManager = {};
    };

    bob = {
      darwin = {};
      hjem = {};
    };
  };
}
```

Creating the final OS configurations is outside the scope of this library—for that, see [`vic/den`](https://github.com/vic/den). However, exposing them would look like this:

```nix
{ inputs, ... }:
{
  flake.nixosConfigurations.fooHost = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [ inputs.self.modules.nixos.development-server ];
  };

  flake.darwinConfigurations.fooHost = inputs.darwin.lib.darwinSystem {
    system = "aarch64-darwin";
    modules = [ inputs.self.modules.darwin.development-server ];
  };
}
```

### Advanced Aspect Dependencies: Providers

Dependencies are managed through a powerful abstraction called **providers**. A provider is a value that returns an aspect object, which can then supply modules to the aspect that includes it.

A provider can be either a static aspect object or a function that dynamically returns one. This mechanism enables sophisticated dependency chains, conditional logic, and parameterization.

#### Default Provider (`__functor`)

Each aspect is itself a provider via its hidden option `__functor` (see `nix/types.nix`). You can include aspects directly.

```nix
# A 'foo' aspect that depends on 'bar' and 'baz' aspects.
flake.aspects = { aspects, ... }: {
  foo.includes = with aspects; [ bar baz ];
}
```

#### Custom Providers

You can define custom providers to implement more complex logic. A provider function receives the current `class` (e.g., `"nixos"`) and the `aspect-chain` (the list of aspects that led to the call). This allows a provider to act as a conditional proxy or router for dependencies.

In this example, the `kde-desktop` aspect defines a custom `karousel` provider that only returns a module if certain conditions are met:

```nix
flake.aspects.kde-desktop._.karousel = { aspect-chain, class }:
  if someCondition aspect-chain && class == "nixos" then { nixos = { ... }; } else { };
```

The `karousel` provider can then be included in another aspect:

```nix
flake.aspects = { aspects, ... }: {
  home-server.includes = [ aspects.kde-desktop._.karousel ];
}
```

This pattern allows an included aspect to determine which configuration its caller should use, enabling a tree of dependencies where each node can be either static or parametric.

#### Parameterized Providers

Providers can be implemented as curried functions, allowing you to create parameterized modules. This is useful for creating reusable configurations that can be customized at the inclusion site.

For real-world examples, see how `vic/den` defines [auto-imports](https://github.com/vic/den/blob/main/modules/aspects/batteries/import-tree.nix) and [home-managed](https://github.com/vic/den/blob/main/modules/aspects/batteries/home-managed.nix) parametric aspects.

```nix
flake.aspects = { aspects, ... }: {
  system = {
    nixos.system.stateVersion = "25.11";
    _.user = userName: {
      darwin.system.primaryUser = userName;
      nixos.users.${userName}.isNormalUser = true;
    };
  };

  home-server.includes = [
    aspects.system
    (aspects.system._.user "bob")
  ];
}
```

See the `aspects."test provides"` and `aspects."test provides using fixpoints"` sections in the [checkmate tests](checkmate.nix) for more examples of chained providers.

#### The `_` Alias for `provides`

For convenience, `_` is an alias for `provides`. This allows for more concise chaining of providers. For example, `foo.provides.bar.provides.baz` can be written as `foo._.bar._.baz`.

## Testing

```shell
nix run github:vic/checkmate#fmt --override-input target .
nix flake check github:vic/checkmate --override-input target . -L
```
