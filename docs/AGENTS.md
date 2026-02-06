# Repository Guidelines

## Project Structure & Module Organization
- Root Nix entrypoints live in `flake.nix` and `default.nix`.
- Core system modules are under `nix/mkCriomOS/`; zone and sphere builders live in `nix/mkCrioZones/` and `nix/mkCrioSphere/`.
- Home Manager modules are in `nix/homeModule/` (with `min/`, `med/`, `max/` profiles).
- Package and tooling overlays are in `nix/pkdjz/` and `nix/mkPkgs/`.
- Schema definitions are in `capnp/`; website templates live in `mkWebpage/`.
- Inputs are pinned in `npins/` and `flake.lock`.

## Build, Test, and Development Commands
- `nix flake show` to discover available outputs for this flake.
- `nix build .#<output>` to build a specific output (for example, a system or package).
- `nix flake check` to run flake checks and Nix-based tests.
- `nix develop` to enter a dev shell, if one is defined for the output you are working on.

## Coding Style & Naming Conventions
- Adhere to the Nix-specific Sema object style defined in `NIX_GUIDELINES.md`. The universal principles, with their original Rust examples, are in `GUIDELINES.md` for context.
- Nix files use 2-space indentation and prefer the existing formatting in the file.
- Formatting tools seen in this repo include `nixpkgs-fmt` and `nixfmt-rfc-style`; use the one already used in the area you touch.

## Testing Guidelines
- Nix evaluation tests live in `nix/tests/`.
- Prefer adding or updating tests alongside module changes, then validate with `nix flake check`.

## Commit & Pull Request Guidelines
- Commit messages follow a lowercase verb + scoped parentheses style, often nested (example: `fix(emacs(errors(copilot)))`).
- PRs should include a short intent summary, affected outputs (e.g., `nix/mkCriomOS`), and the exact test commands run.
- Include screenshots when changing `mkWebpage/` templates.

## Agent-Specific Instructions
- Follow `AGENT_RULES.md`: ALL CAPS paths are immutable; PascalCase paths are stable contracts; lowercase paths are mutable.
