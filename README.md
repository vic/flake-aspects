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

---

## Usage

### As a `flake-parts` Module

```nix
{ inputs, ... }: {
  imports = [ inputs.flake-aspects.flakeModule ];
  flake.aspects = {
    sliding-desktop = {
      nixos  = { };  # Niri on Linux
      darwin = { };  # Paneru on macOS
    };
    awesome-cli = {
      nixos = { }; darwin = { }; homeManager = { }; nixvim = { };
    };
  };
  flake.nixosConfigurations.my-host = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      inputs.self.modules.nixos.sliding-desktop # read resolved module
    ];
  };
}
```

### Without Flakes ([test](checkmate/modules/tests/without_flakes.nix))

```nix
let

  myModules = (lib.evalModules {
    modules = [
      (new-scope "my") # creates my.aspects and my.modules.
      { my.aspects.laptop.nixos = ...; }
    ];
  }).config.my.modules;

in lib.nixosSystem { modules = [ myModules.nixos.laptop ]; };
```

Useful for libraries that want isolated aspect scopes or flake-parts independence (see [`den`'s scope](https://github.com/vic/den/blob/main/nix/scope.nix)).

---

## API ([nix/lib.nix](nix/lib.nix))

| Export                | Description                                                 |
| --------------------- | ----------------------------------------------------------- |
| `transpose { emit? }` | Generic 2-level transposition                               |
| `types`               | Nix type system for aspects and providers                   |
| `aspects`             | Aspect-aware transposition with resolution                  |
| `new`                 | Low-level scope factory (callback-based)                    |
| `new-scope`           | Named scope factory (`${name}.aspects` / `${name}.modules`) |
| `forward`             | Cross-class module forwarding                               |

### Core: `transpose` ([nix/default.nix](nix/default.nix))

Generic 2-level attribute set transposition parameterized by an `emit` function.

```nix
transpose { a.b.c = 1; } # ⇒ { b.a.c = 1; }
```

`emit` receives `{ child, parent, value }` and returns a list of `{ parent, child, value }` items. Default: `lib.singleton` (identity). This allows users to filter, modify or multiply items being transposed. This is exploited by [nix/aspects.nix](nix/aspects.nix) to intercept each transposition and inject [resolution](nix/resolve.nix).

Tests: [transpose_swap](checkmate/modules/tests/transpose_swap.nix), [transpose_common](checkmate/modules/tests/transpose_common.nix), [tranpose_flake_modules](checkmate/modules/tests/tranpose_flake_modules.nix).

### Resolution: `resolve` ([nix/resolve.nix](nix/resolve.nix))

Recursive dependency resolver. Given a `class` and an `aspect-chain` (the call stack of aspects that led here -- most recent last), it extracts the class-specific config and recursively resolves all `includes`.

The `aspect-chain` lets providers know who is including them and make decisions based on call context. Tests: [aspect_chain](checkmate/modules/tests/aspect_chain.nix), [aspect_modules_resolved](checkmate/modules/tests/aspect_modules_resolved.nix).

### Scope Factories ([nix/new.nix](nix/new.nix), [nix/new-scope.nix](nix/new-scope.nix))

`new` is a callback-based factory: `new (option: transposed: moduleDefinition) aspectsConfig`. The [flakeModule](nix/flakeModule.nix) uses it to wire `flake.aspects → flake.modules`.

`new-scope` wraps `new` to create named scopes: `new-scope "foo"` produces `foo.aspects` (input) and `foo.modules` (output). Multiple independent namespaces can coexist. Tests: [without_flakes](checkmate/modules/tests/without_flakes.nix), [aspect_assignment](checkmate/modules/tests/aspect_assignment.nix).

### Forward ([nix/forward.nix](nix/forward.nix))

Cross-class configuration forwarding. Routes resolved modules from one class into a submodule path of another class. Used by [`den`](https://github.com/vic/den) to forward `homeManager` modules into `nixos.home-manager.users.<name>`. Test: [forward](checkmate/modules/tests/forward.nix).

---

## Dependency Resolution

### `includes` — Cross-Aspect Dependencies ([test](checkmate/modules/tests/aspect_dependencies.nix))

```nix
flake.aspects = { aspects, ... }: {
  server = {
    includes = with aspects; [ networking monitoring ];
    nixos = { };
  };
  networking.nixos = { };
  monitoring.nixos = { };
};
```

When `flake.modules.nixos.server` is evaluated, it resolves to `{ imports = [ server.nixos, networking.nixos, monitoring.nixos ] }`. Only classes that exist on the included aspect are imported.

### Providers — `provides` / `_` ([test](checkmate/modules/tests/aspect_provides.nix))

Aspects can expose sub-aspects as providers. `_` is an alias for `provides`.

```nix
flake.aspects = { aspects, ... }: {
  gaming = {
    nixos = { };
    _.emulation = {
      nixos = { };
      _.nes.nixos = { };
    };
  };
  my-host.includes = [ aspects.gaming._.emulation._.nes ];
};
```

Providers receive `{ class, aspect-chain }` and can use them for conditional logic or context-aware configuration. The `aspect-chain` tracks the full inclusion path.

### Fixpoint Semantics ([test](checkmate/modules/tests/aspect_fixpoint.nix))

The top-level `aspects` argument is a fixpoint: providers at any depth can reference siblings or top-level aspects.

```nix
flake.aspects = { aspects, ... }: {
  two.provides = { aspects, ... }: {
    sub = { includes = [ aspects.sibling ]; classOne = { }; };
    sibling.classOne = { };
  };
  one.includes = [ aspects.two._.sub ];
};
```

### Parametric Providers ([test](checkmate/modules/tests/aspect_parametric.nix))

Curried functions act as parametric providers:

```nix
flake.aspects = { aspects, ... }: {
  base._.user = userName: {
    nixos.users.${userName}.isNormalUser = true;
  };
  server.includes = [ (aspects.base._.user "bob") ];
};
```

### Top-Level Parametric Aspects ([test](checkmate/modules/tests/aspect_toplevel_parametric.nix))

Top-level aspects can also be curried providers:

```nix
flake.aspects = { aspects, ... }: {
  greeter = { message }: { nixos.greeting = message; };
  host.includes = [ (aspects.greeter { message = "hello"; }) ];
};
```

### `__functor` Override ([test](checkmate/modules/tests/aspect_default_provider_functor.nix), [test](checkmate/modules/tests/aspect_default_provider_override.nix))

The default `__functor` just returns the aspect itself. However, you can override the `__functor` to allow an aspect to intercept when it is being included and provide different config depending on who is including it.

```nix
flake.aspects = { aspects, ... }: {
  foo = {
    nixos = { ... };
    __functor = self:
      { class, aspect-chain }:
      if class == "nixos" then self else { darwin = ...; includes = [ ... ]; };
  };
};
```

### Forward ([nix/forward.nix](nix/forward.nix)) ([test](checkmate/modules/tests/forward.nix))

Route modules from one class into a submodule path of another:

```nix
forward {
  each = host.users;
  fromClass = _user: "homeManager";
  intoClass = _user: "nixos";
  intoPath = user: [ "home-manager" "users" user.name ];
  fromAspect = user: den.aspects.${user.name};
}
```

---

## Testing

```shell
nix run github:vic/checkmate#fmt --override-input target .
nix flake check github:vic/checkmate --override-input target . -L
```
