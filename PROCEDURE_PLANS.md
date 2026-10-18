# PROCEDURE_PLANS.md — noosphere project specifics

> **The process is superpowers** (the agent skill set; `superpowers:<skill>` below).
> This document holds only what superpowers cannot know about this repository: its gates,
> its test discipline, its toolchain, its language rules, its git identity, its backlog.
>
> Read [`DESIGN.md`](DESIGN.md) first. **It outranks every skill.** If an idea does not fit
> its invariants, the answer is no — that is not a process question.

---

## 1. Where the process lives

| Step | Skill | Artifact |
|---|---|---|
| Work out what we want | `superpowers:brainstorming` | `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md` |
| Turn it into tasks | `superpowers:writing-plans` | `docs/superpowers/plans/YYYY-MM-DD-<feature>.md` |
| Isolate the workspace | `superpowers:using-git-worktrees` | a worktree on a dedicated branch |
| Implement | `superpowers:executing-plans` | atomic commits + a ledger |
| Prove each change | `superpowers:test-driven-development` | a test watched failing, then passing (§6 narrows this for `view`) |
| Independent review | `superpowers:requesting-code-review` | findings, re-graded by effect |
| Integrate | `superpowers:finishing-a-development-branch` | a `--no-ff` merge into `main` |

Both document directories are committed. Nothing new lands under `.claude/plans/` (see §8).
An obsolete spec or plan is **deleted**, never kept alongside its replacement: the dated
filenames make a stale document look like history rather than the duplicate it is.

The version a plan ships (`v0.4.0`, …) belongs in the plan's **Goal** line, not in its
filename — a release is a property of the work, not of the document tree.

**`manual_tests.md` and `phase0_results.md` no longer exist as files.** Both fold into the
plan, which is where superpowers puts verification:

- the **phase-0 audit** is the plan's first step — run `nix develop --command just ci` on an
  up-to-date `main` and record the result on one line. Never assume the tree is clean;
- **manual tests** are verification steps attached to the task they validate, in superpowers'
  step style: the command to run, the result that means it passed, a `- [ ]` checkbox;
- the **closing run** gets a final `## Manual validation` section in the plan: the date,
  which boxes were exercised, and which were not and why.

**Execution method: native by default.** `superpowers:writing-plans` offers subagent-driven
or native execution; this repository defaults to **native**, because the commit-series rule
in §3 needs commits arriving from one context in one burst. A plan whose tasks are genuinely
independent can opt into subagent-driven execution — that is a decision taken at the plan
review, with the extra signing prompts named out loud.

## 2. When the agent stops

The agent runs a plan end to end without asking permission per step. It stops when there is
something to **decide**: a design choice that changes what gets built, an ambiguity in the
spec, friction against a `DESIGN.md` invariant, a surprise that invalidates the plan.

Superpowers' own gates are kept, because each is a decision and not a step approval: the
brainstorming gate (nothing is built before the design is approved), the plan review, and
the choice of execution method.

Subagents — independent review, builder check, research, parallel exploration — are
dispatched without asking.

## 3. Git

- Dedicated branch (`feat/`, `fix/`, `chore/`, `refactor/`, `docs/`), never directly on
  `main`.
- Atomic commits: one logical change, one commit, each passing the gates on its own.
- **Commits and tags are GPG-signed.** The global git config already resolves to
  `guillaume@friloux.me` with `commit.gpgsign` and `tag.gpgsign` true — noosphere needs **no
  local `user.email` override**. (Note for whoever compares: astropath carries one.)
- Every commit ends with the trailer
  `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`.
- The agent **announces a commit series before running it**, so the passphrase is typed once
  (`gpg-agent` caches it a few minutes) and the burst goes through.
- The agent may `merge`, `push` and `tag` — **including the release tag** (see `README.md`
  §Release). **Merge form: `git merge --no-ff`**, always a merge commit, so a plan's branch
  stays legible and its closure is one point in the log. The signed merge commit asks for the
  passphrase; that prompt is the stop.
- A finished branch is never left unmerged: every plan starts from an up-to-date `main`.

A PR merged through GitHub's web UI produces a commit signed by GitHub's key, which reports
as unverifiable locally (`%G?` = `E`). That is not a defect, but it is a further reason for
integrations to run locally under `--no-ff`.

### Commit convention

```
type(scope): short imperative message
```

- **type**: `feat`, `fix`, `refactor`, `perf`, `test`, `docs`, `chore`, `ci`.
- **scope**: `query`, `model`, `view`, `nix`, `ui`, or the module touched.

Docs are updated **in the same commit** as the code they describe. A structural change
committed without updating `DESIGN.md`/`README.md` leaves the docs stale — that is a defect,
not a follow-up.

## 4. Quality gates

**One single definition: the `Justfile`.** pre-commit and CI both call it, and no other
document **redefines** the gates — a list elsewhere (here, `CLAUDE.md`, `README.md`) is a
convenience copy of the `Justfile`, never a second source.

```bash
just fmt-check          # qmlformat — no unformatted file
just check-manifest     # plugin.json against DMS's published schema (vendored)
just check-translations # translations/ against src/'s wrapped strings, both directions
just test               # goldens (frozen inputs → model) + Qt Quick Test
just lint               # qmllint — blocks at zero; needs DMS installed
just ci                 # all five
just ci-hermetic        # all but lint: the subset CI can run (no DMS on a runner)
```

> **`lint` needs DankMaterialShell installed, and blocks at zero.** `qmllint` cannot resolve
> DMS's `qs.*` modules from an `-I` flag — DMS ships no `qmldir`, and Quickshell synthesises
> the module metadata as it starts. So `scripts/qml-import-paths` has Quickshell generate it
> (an empty `.qmlls.ini` in a cached copy of the DMS shell root, populated by a short `qs`
> run) and feeds the result in. Consequences:
>
> - **Without DMS on `PATH`, `just lint` fails** rather than linting a subset quietly.
> - **`qmllint` exits 0 whatever it finds**, so the recipe judges its *output*: any
>   `Warning:`/`Error:`/`Info:` line that is not one of two known-bogus classes fails the
>   gate. Those two filters are commented at the call site with what would let them go.
> - **CI does not run this leg** — it has no DMS — and says so in its own output. A green CI
>   run proves `fmt-check`, `test` and the manifest check, and nothing about QML. The QML gate
>   lives on the developer's machine and in `pre-commit`.

## 5. Determinism — goldens on the data layer

The `query` + `model` layer is deterministic: a frozen input set (`nix flake metadata
--json` output + GitHub compare responses + `nvd diff` output) produces an exact model,
stored as a reference file.

```
tests/fixtures/<case>.json     ← frozen input (nix metadata / GitHub compare / states to join)
tests/golden/<case>.json       ← expected domain model
```

- A behaviour change shows up in the **golden diff**.
- A golden that changes by accident = **hard stop**.
- To regenerate one on purpose: `just bless`, then **review the diff**.
- **No secret in the fixtures.** The GitHub token lives in a header injected by the service;
  the frozen inputs (public compares) never contain one (see `DESIGN.md`, invariant 5).

| Change | Stage | Order |
|---|---|---|
| New command / model field | `query` `model` | fixture+golden → impl → docs |
| New computation (behind, state) | `model` | fixture+golden → impl → `DESIGN.md` if an invariant moves |
| View / component change | `view` | impl → manual verification → visual review |
| Bug fix | affected | failing regression test → fix |
| Refactor | affected | no golden moves. If a golden moves, it was not a refactor. |

## 6. Test-driven development, and the `view` exception

`superpowers:test-driven-development` applies wherever a test can express the change:

- **`query` / `model` — fully.** Fixture + golden first (RED), then implementation (GREEN).
  That is §5, and it already satisfies TDD.
- **`view` (QML) — partially.** Logic extracted out of QML is testable and gets its test
  first. Rendering, live settings and a real DMS instance are not. There, the "failing test"
  step is replaced by a **manual verification step written before the implementation**: the
  plan states what to look at and what the right outcome is, before the code exists. TDD's
  intent is kept — the expected result is decided before the implementation — only the
  automation is unavailable.

This exception is narrow and decided. It is **not** a licence to skip tests anywhere a test
could have been written. Note where it bites: the `Noosphere` and `Closure` service drivers
are the layer with no automated coverage at all, and the layer where this project's live bugs
surfaced. Pushing that boundary back is work the backlog tracks, not a standing permission.

## 7. What is automated, and what is not

**Automated**: parsing `nix flake metadata` → direct inputs, parsing a compare → `behind`,
joining input↔`behind`, `behindCount`, `barState`, `parseNvdDiff`, severity, URL and argv
construction. That is the whole `query` + `model` layer, and §5 is how it is tested. A change
there with no fixture and no golden is incomplete, not merely untested.

**Not automated**: pixel-perfect QML rendering, a real `nix` and a real GitHub, launching
Quickshell on Wayland, live settings, the actual closure build.

These become **verification steps inside the plan**, attached to the task they validate, as
described in §1.

**Worktrees, the dev bar and the mock.** A plan executes in an isolated worktree.
`just dev-bar` takes the repository root as an argument (`justfile_directory()`) and
symlinks `src/` live, so it works from any worktree — but its isolated state root
(`$XDG_STATE_HOME/noosphere-dev`) is single, so **one dev bar at a time**. `just mock` serves
the GitHub compare API with no network (`drift | uptodate | ratelimit | error`) and binds a
port, 8385 by default, so likewise **one mock at a time** unless the port is overridden.

## 8. Toolchain, language, backlog, scratch

- **Nix.** Always `nix develop`, or `nix develop --command …` for non-interactive commands.
- **Language.**

  > English is noosphere's default language — documents, code comments, commit messages, and
  > the software's own copy. The UI is French today and stays French until the English/i18n
  > plan lands; French then becomes one locale of two, if EN/FR internationalisation proves
  > workable in a hot-loaded DMS plugin.

  Consequences:
  - A French UI string is **quoted** when a document describes it, never silently translated
    as a side effect of another change. `DESIGN.md`'s visual system says so on the spot.
  - The rule **binds GitHub Issues** too, now that Issues is the only backlog and therefore
    part of the project's written record: titles, bodies, comments, PR descriptions in
    English. One carve-out: a **measurement carried from elsewhere is reproduced as a
    verbatim quoted block**, not translated — a wording slip in a measured finding rewrites
    the record rather than the prose around it.
  - `CHANGELOG.md`'s already-published sections **stay French**: they describe French
    commits, and rewriting them would be a retroactive lie. The file is bilingual by
    construction, cut at the first version after the switch.

  **This rule differs from astropath's**, which is "English docs, French UI". Do not copy
  astropath's version into this repository.
- **GitHub Issues is the only backlog.** There is no `TODO.md` and no second list in the
  repository. A future cap documented in `DESIGN.md` keeps its rationale there and gets an
  issue as its tracking entry.
- **`.claude/plans/` is a frozen archive** of the v0.1.0 … v0.3.0 plans. It records the house
  process that was in force then; none of it binds anything now, and nothing new is added to
  it.
- **Scratch, never committed.** `tmp/` (design handoffs, notes, working output) and
  `.superpowers/` (agent ledgers, briefs, review packages).
- **Release tooling** (Renovate, git-cliff, CI + the release workflow) has been in place
  since v0.1.0. The sequence lives in `README.md` §Release.

---

**Last updated:** 2026-10-18
**Status:** Active
