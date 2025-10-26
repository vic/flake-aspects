<!-- Badges -->

<p align="right">
  <a href="https://nixos.org/"> <img src="https://img.shields.io/badge/Nix-Flake-informational?logo=nixos&logoColor=white" alt="Nix Flake"/> </a>
  <a href="https://github.com/vic/flake-aspects/actions">
  <img src="https://github.com/vic/flake-aspects/actions/workflows/test.yml/badge.svg" alt="CI Status"/> </a>
  <a href="LICENSE"> <img src="https://img.shields.io/github/license/vic/flake-aspects" alt="License"/> </a>
</p>

# `<aspect>.<class>` Transposition for Dendritic Nix

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

## Usage

### As a Dependency-Free Library (`./nix/default.nix`)

The [`transpose`](nix/default.nix) library accepts an optional `emit` function that can be used to ignore items, modify them, or generate multiple items from a single input.

```nix
let transpose = import ./nix/default.nix { lib = pkgs.lib; }; in
transpose { a.b.c = 1; } # => { b.a.c = 1; }
```

This `emit` function is utilized by the [`aspects`](nix/aspects.nix) library (both libraries are independent of flakes) to manage cross-aspect, same-class module dependencies.

### As a Dendritic Flake-Parts Module (`flake.aspects` option)

The `flake.aspects` option is transposed into `flake.modules`.

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

`flake.aspects` also allows aspects to declare dependencies among themselves.

Each module can have its own `imports`, but aspect dependencies are defined at the aspect level, not the module level. Dependencies are eventually resolved to modules and are imported only if they exist.

In the example below, the `development-server` aspect can be applied to both Linux and macOS hosts. Note that `alice` uses `nixos` + `homeManager`, while `bob` uses `darwin` + `hjem`.

The `development-server` aspect addresses a usability concern by configuring the same development environment on different operating systems. When applied to a NixOS machine, the `alice.nixos` module will likely configure the `alice` user; there is no corresponding NixOS user for `bob`.

```nix
{
  flake.aspects = { aspects, ... }: {
    development-server = {
      includes = with aspects; [ alice bob ];

      # Without flake-aspects, you would normally do:
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

Creating OS configurations is outside the scope of this library - for that, see [`vic/den`](https://github.com/vic/den) -. Exposing os configurations might look like this:

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

#### Advanced Aspect Dependencies

An aspect can declare a `includes` list:

```nix
# A 'foo' aspect that depends on 'bar' and 'baz' aspects.
flake.aspects = { aspects, ... }: {
  foo.includes = [ aspects.bar aspects.baz ];
}
```

Cross-aspect dependencies work as follows:

When a module like `flake.modules.nixos.foo` is requested (for example, included in a `nixosConfiguration`), a corresponding module is computed from `flake.aspects.foo.nixos`.

`flake.aspects.foo.includes` is a list of functions (providers). A **provider** is either a constant `<aspect-object>` or a function `{ class, aspect-chain } => <aspect-object>`. They are called with `{ aspect-chain = [ aspects.foo ]; class = "nixos" }`, functions can inspect the chain of aspects that have led to the call. These providers return an aspect object that contains a module of the same `class` (in this case, `nixos`). Providers allow us to have a tree of aspects where each provided aspect can be either static or parametric.

Providers answer the question: given we have `nixos` modules from `[foo]` aspects, what other aspects can provide `nixos` modules that need to be imported?

This means that the included aspect determines which configuration its caller should use.

By default, all aspects have an `<aspect>.provides.itself` provider function that always returns the `<aspect>` itself. This is why `with aspects; [ bar baz ]` works: it is shorthand for `[ aspects.bar.provides.itself aspects.baz.provides.itself ]`. It is possible to override the default provider, by setting `__functor`, see how [test](https://github.com/vic/flake-aspects/blob/4f88b4ecefbe46ccfa5d9cfa11451a88be169a70/checkmate.nix#L270) or [vic/den](https://github.com/vic/den/blob/def1c396e7ce884578d6589391cca8a4c6a650d3/nix/aspects-config.nix#L55) do it.

##### Dynamic modules using provider function's `{ aspect-chain, class }` argument.

You can also define custom providers that inspect the `aspect-chain` and `class` values and return a set of modules accordingly. This allows providers to act as conditional proxies or routers for dependencies.

```nix
flake.aspects.kde-desktop.provides.karousel = { aspect-chain, class }:
  if someCondition aspect-chain && class == "nixos" then { nixos = { ... }; } else { };
```

The `karousel` provider can then be included in another aspect:

```nix
flake.aspects = { aspects, ... }: {
  home-server.includes = [ aspects.kde-desktop.provides.karousel ];
}
```

##### Parametrized modules from providers.

Providers can be curried (but *must* use explicit argument names). This lets you have
modules parametrized by some values, outside the aspect scope. For a real-world
usage of this feature, see how `vic/den` [defines](https://github.com/vic/den/blob/def1c396e7ce884578d6589391cca8a4c6a650d3/nix/aspects-config.nix#L40) `flake.aspects.default.host` and their [use](https://github.com/vic/den/blob/def1c396e7ce884578d6589391cca8a4c6a650d3/templates/default/modules/_example/aspects.nix#L32).

```nix
flake.aspects = { aspects, ... }: {
  system = {
    nixos.system.stateVersion = "25.11";
    provides.user = { userName }: { aspect-chain, class }: {
      darwin.system.primaryUser = userName;
      nixos.users.${userName}.isNormalUser = true;
    }
  };

  home-server.includes = [
    aspects.system
    (aspects.system.provides.user { userName = "bob"; })
  ];
}
```

See `aspects."test provides"` [checkmate tests](checkmate.nix) for more examples on chained providers.

## Testing

```shell
nix run ./checkmate#fmt --override-input target .
nix flake check ./checkmate --override-input target . -L
```
