---
title: Contributing
description: How to contribute to flake-aspects.
---

All contributions welcome. PRs are checked by CI.

## Run tests

```shell
nix flake check github:vic/checkmate --override-input target . -L
```

## Format code

```shell
nix run github:vic/checkmate#fmt --override-input target .
```

## Bug reports

Create a minimal reproduction as a test case in `checkmate/modules/tests/` and send a PR.

Failing tests are the best way to report bugs — they become the regression test once fixed.

## Documentation

The docs site lives under `./docs/`. Run locally:

```shell
cd docs && pnpm install && pnpm run dev
```

## Community

- [GitHub Issues](https://github.com/vic/flake-aspects/issues) — bugs and features
- [GitHub Discussions](https://github.com/vic/flake-aspects/discussions) — questions and ideas
