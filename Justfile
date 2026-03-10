help:
  just -l

docs:
  cd docs && pnpm run dev

ci test="":
  nix-unit  --override-input target . --flake github:vic/checkmate#.tests.systems.x86_64-linux.system-agnostic.{{test}}
  
check:
  nix flake check  --override-input target . github:vic/checkmate

fmt:
  nix run github:vic/checkmate#fmt --override-input target .
