# CLAUDE.md

Guidance for Claude Code (claude.ai/code) in this repository.

> **Before any work on the code, read [`DESIGN.md`](./DESIGN.md) — it outranks every
> skill.** The process is **superpowers**: brainstorm → design → plan → execute → review →
> integrate. **Then read [`PROCEDURE_PLANS.md`](./PROCEDURE_PLANS.md)** — it holds this
> project's specifics (gates, goldens, toolchain, language, git identity, backlog), and
> nothing else.
> **No code without an approved plan.**

## What noosphere is

A **NixOS flake drift tracker** widget for **Quickshell / DankMaterialShell**: a status
badge in the bar (drift state + count of inputs behind) + a cockpit popup listing the inputs
and how far each lags behind upstream. It compares the local `flake.lock` (through
`nix flake metadata --json`) against the upstream branch on **GitHub** (compare API),
**read-only** (v1), by polling. No server-side configuration. Details and invariants:
`DESIGN.md`.

## Stack & structure

- **View**: QML / Qt Quick (Quickshell), Material 3, Catppuccin Mocha.
- **Data**: the `query` layer (argv for `nix flake metadata` + GitHub compare URLs, pure) →
  the `Noosphere.qml` service (runs `nix` through `Process`, queries GitHub through
  `XMLHttpRequest`, `Authorization: Bearer` header when a token is set) → `model` (the drift
  model, pure/testable) → `view` (QML). The QML **never** builds a command or a URL itself.

```
src/                     ← Quickshell QML + query/model layers
tests/                   ← frozen fixtures (nix metadata + GitHub compare) + goldens
docs/superpowers/specs/  ← designs (brainstorming output)
docs/superpowers/plans/  ← plans, verification included (writing-plans output)
.claude/plans/           ← frozen archive of the v0.1.0 … v0.3.0 plans
tmp/, .superpowers/      ← uncommitted scratch (notes; agent ledgers and briefs)
```

## Language

English is the project's default language — documents, code comments, commit messages, and
the software's own copy. **The UI copy is French today** and stays French until the
English/i18n plan lands; a French UI string is quoted when a document describes it, never
silently translated as a side effect of another change. This rule **differs from
astropath's** ("English docs, French UI") — do not copy astropath's version here. Details,
including the published changelog and GitHub Issues: `PROCEDURE_PLANS.md` §8.

## Dev environment

Always enter the Nix dev shell before building/testing:

```bash
nix develop
```

For non-interactive commands: `nix develop --command just ci`.

## Commands

```bash
just ci          # full gate: fmt-check + lint + test
just fmt         # qmlformat -i (formats in place)
just fmt-check   # checks formatting, fails if non-conforming
just lint        # qmllint, no warning tolerated — currently blind, see issue #6
just test        # goldens (frozen inputs → model) + Qt Quick Test
just bless       # regenerates the goldens (review the diff)
just mock        # GitHub compare mock (scenario: drift | uptodate | ratelimit | error)
just dev-bar     # isolated DMS instance loading the worktree
just changelog   # regenerates CHANGELOG.md through git-cliff
```

The `Justfile` is the **only** definition of the gates; pre-commit and CI call it.

## Guardrails (what does not change)

- **DESIGN.md is authoritative.** Outside the invariants → no. Local flake + GitHub as the
  source of truth, **read-only (v1)**, **the input is the unit**, how far **behind** measured
  against GitHub upstream (`ahead_by`), **flake-agnostic** (path + owner/repo + branch +
  token): hard
  invariants. Moving to writes (`nix flake update`, `nixos-rebuild`, `rollback`) = an
  explicit DESIGN decision + a dedicated plan, never a quiet addition.
- **The GitHub token is a secret.** It lives in the config / the `Noosphere.qml` service,
  **never** in the `query`/`model` layers, **never** in a fixture or a golden.
- **Git: delegated.** Claude works on a **dedicated branch**, commits **atomically**
  (Conventional Commits, see PROCEDURE_PLANS.md §3), **announces a commit series before
  running it** — the commits are signed, so one passphrase covers the burst — and may run
  `merge`/`push`/`tag`. Integration is a `--no-ff` merge into `main` under
  `superpowers:finishing-a-development-branch`. Claude stops for **decisions**, not for
  steps.
- **Docs in the same commit** as the code they describe.
- **`tmp/` and `.superpowers/`**: never committed.
- **Deterministic data layer**: any change to `query`/`model` goes through a fixture + a
  golden (see PROCEDURE_PLANS.md §5).
- **GitHub Issues is the only backlog.** No `TODO.md`, no second list in the repository.
- **Release tooling** (Renovate, git-cliff, CI + the release workflow) has been in place
  since v0.1.0. The sequence is in `README.md` §Release; the tag is signed, and the
  passphrase prompt is the owner's stop.
