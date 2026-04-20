# Agent Bootstrap

Before making changes in this repository, read:

- `docs/AGENTS.md`
- `docs/GUIDELINES.md`
- `docs/NIX_GUIDELINES.md`
- `/home/li/.claude/projects/-home-li-git-CriomOS/memory/MEMORY.md`

Then read any memory files referenced by `MEMORY.md` that match the task.

## Hard Rules

- Use `jj` for all VCS operations. Never use the `git` CLI directly.
- After completing and verifying edits, push automatically:
  `jj describe -m '<three-tuple>' && jj bookmark set main -r @ && jj git push -b main`
- Use the Mentci three-tuple commit format described in `docs/AGENTS.md`.
- Do not print Nix store paths into the conversation unless debugging a specific path issue.
- Push before real builds and deployments; build from origin with `--refresh`.
- Never use `<nixpkgs>` or `NIX_PATH`; use flake attrs or registry references such as `nix shell nixpkgs#jq`.
- For node or network truth, update Maisiliym `datom.nix` / `NodeProposal.nodes.*` first.

