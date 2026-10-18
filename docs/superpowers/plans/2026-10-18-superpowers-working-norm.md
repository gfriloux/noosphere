# noosphere's working norm moves to superpowers — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace noosphere's house process with the superpowers norm, delegate git to the
agent, make GitHub Issues the only backlog, and ship `DESIGN.md`, `PROCEDURE_PLANS.md` and
`CLAUDE.md` in English. No version is released by this work.

**Architecture:** A documentation change in six steps. The document tree and the
`.gitignore` leak land first, because every later task executes inside the worktree they
describe. `DESIGN.md`'s translation is isolated in its own task and its own commit, because
it is the one deliverable with a human gate on it. The backlog migration is ordered so that
nothing is deleted before its content exists elsewhere. Memories are corrected last, since
they are outside git and cannot be verified by the repo diff.

**Tech Stack:** Markdown, `git`, `gh` (GitHub CLI), `just` + Nix dev shell for the gates.
No QML, no JavaScript, no Nix expression is touched.

**Spec:** [`docs/superpowers/specs/2026-10-18-superpowers-working-norm-design.md`](../specs/2026-10-18-superpowers-working-norm-design.md)

**Execution method:** native — the spec fixes this as the repository default (the
announce-a-commit-series rule needs commits arriving from one context in one burst).

## Global Constraints

- **Language.** Repository documents, code comments and commit messages in **English**. UI
  copy is French today and stays French until the English/i18n plan; it is quoted as a
  literal, never silently translated.
- **No `src/` or `tests/` change.** A `git diff --stat` touching either is a hard stop. The
  goldens cannot move.
- **Nix.** Non-interactive commands run as `nix develop --command …`.
- **Gates.** `just ci` = `fmt-check` + `lint` + `test`. The `Justfile` is their single
  definition; no document redefines them. The `lint` leg is known-blind (issue #6) — that is
  recorded, not relied on.
- **Signing.** Every commit is GPG-signed via the global config (`guillaume@friloux.me`,
  key `52381C92A5071464F3160D257D4216D8BDDA9A09`). **No local `user.email` override.**
  Announce a commit series before running it so the passphrase is typed once.
- **Commit trailer.** Keep `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`.
- **Merge form.** `git merge --no-ff` into `main`, by the agent, under
  `superpowers:finishing-a-development-branch`.
- **`.claude/plans/` is frozen.** v0.1.0 … v0.3.0 stay exactly as they are, in French. They
  are never edited, renamed or translated.
- **`CHANGELOG.md` and `cliff.toml` are out of scope.** `cliff.toml` belongs to chantier 2.
- **Branch:** `docs/superpowers-working-norm`.

## Review Focus

Failure modes the spec implies that no mechanical check in the tasks below would catch on
its own. Each one has a check attached to the task that owns it.

1. **Two active process documents.** `PROCEDURE_PLANS.md` keeps describing a planning
   workflow, so a future session follows whichever norm it read last. → Task 3, Step 5.
2. **A faithful-looking mistranslation that narrows a `DESIGN.md` invariant.** The grep and
   the count both pass; the meaning moved. The mechanical checks in Task 2 Steps 4–6 cannot
   see this, which is the whole reason the next two exist. → Task 2, Step 7 (two independent
   fidelity reviews), and the owner's gate in Task 6, Step 6.
3. **`TODO.md` content surviving only in git history**, because the file was deleted before
   the issues and comments existed. → Task 5 orders the deletion last and checks it.
4. **A fresh worktree starting with unignored agent scratch.** `.gitignore` is right in the
   main checkout but the rule is never exercised where it leaks. → Task 1, Step 5 runs the
   check *from the new worktree*.
5. **A stale memory slug steering a future session.** `MEMORY.md`'s index is read before any
   body, so correcting a body under a misleading slug changes nothing. → Task 6, Step 4
   checks slugs, not only content.

---

### Task 1: Workspace, document tree, and the scratch leak

**Files:**
- Modify: `.gitignore`
- Create (by moving from the main checkout): `docs/superpowers/specs/2026-10-18-superpowers-working-norm-design.md`, `docs/superpowers/plans/2026-10-18-superpowers-working-norm.md`

**Interfaces:**
- Consumes: nothing.
- Produces: the branch `docs/superpowers-working-norm` and the worktree every later task
  runs in; the committed spec and plan at the paths the spec fixes.

- [ ] **Step 1: Record the phase-0 audit**

Run on an up-to-date `main`, before branching:

```bash
git -C /home/kuri/Apps/github/gfriloux/noosphere status --porcelain
nix develop --command just ci
```

Write the result into this plan as a one-line `**Phase 0 (YYYY-MM-DD):**` entry directly
below this step — exit code, and for `lint` the fact that it is blind per #6. Never assume
the tree is clean.

- [ ] **Step 2: Create the isolated worktree**

Use `superpowers:using-git-worktrees` to get a worktree on a new branch
`docs/superpowers-working-norm` off `main`.

- [ ] **Step 3: Carry the spec and the plan into the worktree**

The design and this plan were written in the main checkout as untracked files. Copy both
into the worktree at the same paths, then delete them from the main checkout so only one
copy exists.

Expected: `ls docs/superpowers/specs docs/superpowers/plans` in the worktree lists both
files; `git -C <main checkout> status --porcelain` no longer shows them.

- [ ] **Step 4: Add `.superpowers/` to `.gitignore`**

Insert next to the existing `tmp/` block. The comment must say why the rule lives at the
repository root: `.superpowers/sdd/.gitignore` is created by the tooling, covers only
`sdd/`, and does not exist before the tooling's first run — so a fresh worktree would start
with unignored scratch. Update the `.claude/` comment in the same file: "les plans, eux,
sont versionnés" becomes a statement that `.claude/plans/` is a frozen archive. Both
comments in English.

- [ ] **Step 5: Verify the leak is closed where it would leak**

Run **from the worktree**, not the main checkout:

```bash
git check-ignore -v .superpowers/sdd/x
```

Expected: the matching rule reported is the root `.gitignore`'s `.superpowers/` line.
A report naming `.superpowers/sdd/.gitignore`, or no output at all, is a failure.

- [ ] **Step 6: Commit**

```bash
git add .gitignore docs/superpowers/
git commit -m "docs: adopt the superpowers document tree and ignore agent scratch"
```

---

### Task 2: `DESIGN.md` to English

**Files:**
- Modify: `DESIGN.md` (whole file)
- Create: `tmp/design-fr-en.md` (git-ignored, expires on approval)

**Interfaces:**
- Consumes: Task 1's worktree.
- Produces: an English `DESIGN.md` with its eleven invariants, its numbering, its colour
  table and its section structure preserved; `tmp/design-fr-en.md` as the artifact the owner
  reads in Task 6.

- [ ] **Step 1: Inventory the French strings that must survive untranslated**

```bash
grep -oE '«[^»]*»' DESIGN.md | sort -u
```

For each result, run `grep -rF '<string>' src/`. A hit means the string is a live UI literal
and **stays French**. No hit means it is prose or copy for UI that does not exist, and it
**translates**. Record the two lists in `tmp/design-fr-en.md`.

Known from the spec, verified: stays French — «&nbsp;N commits en retard&nbsp;»,
«&nbsp;INPUTS&nbsp;», «&nbsp;DIFF DE CLOSURE&nbsp;», «&nbsp;prévisualiser la mise à
jour&nbsp;», «&nbsp;aucun input en retard&nbsp;», «&nbsp;échec du check ·
réessayer&nbsp;». Translates — «&nbsp;Tout mettre à jour&nbsp;», «&nbsp;voir les N
changements&nbsp;», «&nbsp;update&nbsp;». `EN-TÊTE` is **not** a UI literal: it exists only
in `src/view/Cockpit.qml` comments and one `src/view/Settings.qml` description, so the card
is called the *header* card in English.

- [ ] **Step 2: Translate `DESIGN.md`**

A translation, not a revision. Preserve: the eleven numbered invariants and their order, the
three-stage pipeline diagram, the colour table's hex values, the bar-state mapping table,
the future-caps table, every section and its order. Domain vocabulary: *dérive* → drift,
*amont* → upstream, *retard* → behind, *verrou* → lock, *input en retard* → input behind;
*noosphère* stays noosphere. Add one short note in the visual-system section recording that
the remaining French literals are French *pending* the English/i18n plan, so a reader does
not read them as a missed translation.

- [ ] **Step 3: Build the clause-by-clause correspondence table**

Append to `tmp/design-fr-en.md`: each invariant, each normative visual-system rule and each
imperative sentence, old beside new, sourced from `git show HEAD:DESIGN.md`. This is what
the owner reads in Task 6 instead of diffing two documents in parallel. It stays in `tmp/`
and is never committed.

- [ ] **Step 4: Run the half-translation check**

```bash
grep -rniE 'jamais|toujours|le token|la couche|dérive|plan validé' DESIGN.md
```

Expected: no output.

- [ ] **Step 5: Run the quoted-literal check**

For every `«…»` string remaining in `DESIGN.md`, `grep -rF '<string>' src/` must hit.

Expected: every string hits. A quoted French string with no hit means either an
untranslated fragment or a document describing copy that does not exist — both defects,
and the check cannot tell them apart, so it fails rather than warns.

- [ ] **Step 6: Run the structure checks**

```bash
grep -cE '^[0-9]+\. \*\*' DESIGN.md                      # expected: 11
git show HEAD:DESIGN.md | grep -oE '#[0-9a-f]{6}' | sort | uniq -c > /tmp/hex-before
grep -oE '#[0-9a-f]{6}' DESIGN.md | sort | uniq -c > /tmp/hex-after
diff /tmp/hex-before /tmp/hex-after                      # expected: no difference
```

- [ ] **Step 7: Dispatch two independent fidelity reviews**

Two fresh subagents, each given `git show HEAD:DESIGN.md` and the new `DESIGN.md`, each
asked to report **only** places where the English narrows, widens or changes an invariant,
a normative rule or a measured value. Fix what they find. They run before the owner's gate
so that what reaches the owner has had its obvious slips removed; they do not replace it.

- [ ] **Step 8: Commit**

```bash
git add DESIGN.md
git commit -m "docs: translate DESIGN.md to English"
```

---

### Task 3: `PROCEDURE_PLANS.md` and `CLAUDE.md`

**Files:**
- Modify: `PROCEDURE_PLANS.md` (whole file)
- Modify: `CLAUDE.md` (whole file)

**Interfaces:**
- Consumes: Task 2's English `DESIGN.md` (both documents point at it).
- Produces: the written norm every future session reads. One commit, because `CLAUDE.md`'s
  header and guardrails describe what `PROCEDURE_PLANS.md` says; shipping them apart leaves
  the repository momentarily self-contradicting.

- [ ] **Step 1: Rewrite `PROCEDURE_PLANS.md` in English, holding only what superpowers cannot know**

Required content, per the spec: the step→skill→artifact table; when the agent stops
(decisions, not steps) and which superpowers gates survive; git (branch, atomic commits,
signing, announce-a-series, `--no-ff`, delegation including `tag`, the `Co-Authored-By`
trailer); the gates with the `Justfile` as single definition; the golden discipline on
`query`/`model`, `just bless`, and the change-type table; TDD and the narrow `view`
exception; what is not automatable and therefore lands as manual verification inside the
plan; the worktree / dev-bar / mock constraints (one dev bar and one mock at a time); Nix as
the entry point; the language rule in noosphere's form **with the divergence from astropath
named**; the backlog rule; one line declaring `.claude/plans/` a frozen archive of
v0.1.0 … v0.3.0 that binds nothing now; a pointer to superpowers naming the skills.

Two further rules the spec fixes and this file must carry, or they survive nowhere:

- **`manual_tests.md` and `phase0_results.md` no longer exist as files.** The phase-0 audit
  is the plan's first step, recorded on one line; manual tests are verification steps
  attached to the task they validate, with a `- [ ]` checkbox; the closing run gets a
  `## Manual validation` section in the plan. The copies inside the frozen
  `.claude/plans/v0.x/` directories are history and are not deleted.
- **Execution method: native by default**, because the announce-a-commit-series rule needs
  commits arriving from one context in one burst. A plan whose tasks are genuinely
  independent may opt into subagent-driven execution — a decision taken at the plan review,
  with the passphrase cost named out loud.

Everything the file currently says about writing plans, phases, plan templates and the plan
directory is removed.

The language rule, verbatim from the spec:

> English is noosphere's default language — documents, code comments, commit messages, and
> the software's own copy. The UI is French today and stays French until the English/i18n
> plan lands; French then becomes one locale of two, if EN/FR internationalisation proves
> workable in a hot-loaded DMS plugin.

Plus: the rule binds GitHub Issues (titles, bodies, comments, PR descriptions), with the
carve-out that carried measurements are reproduced as verbatim quoted French blocks.

- [ ] **Step 2: Rewrite `CLAUDE.md` in English**

Its header becomes: read `DESIGN.md` — it outranks every skill; the process is superpowers
(brainstorm → design → plan → execute → review → integrate); `PROCEDURE_PLANS.md` holds
this project's specifics. Correct the guardrails section for the git decision (delegated,
`--no-ff`, `tag` included) and the language rule. Update the structure block to the new
tree, naming `.claude/plans/` the frozen archive and `tmp/`, `.superpowers/` as uncommitted
scratch.

- [ ] **Step 3: Check the gates are not redefined**

The gate list in `CLAUDE.md` and `PROCEDURE_PLANS.md` must match the `Justfile`'s recipes
and be presented as a convenience copy, not a second source.

Run: `grep -nE 'just (ci|fmt-check|lint|test|bless)' CLAUDE.md PROCEDURE_PLANS.md README.md`
Expected: every recipe named exists in the `Justfile`, and no document states a gate the
`Justfile` does not define.

- [ ] **Step 4: Run the half-translation check**

```bash
grep -rniE 'jamais|toujours|le token|la couche|dérive|plan validé' PROCEDURE_PLANS.md CLAUDE.md
```

Expected: no output.

- [ ] **Step 5: Check there is exactly one active process description** *(Review Focus 1)*

Read `PROCEDURE_PLANS.md` as a fresh session would. It must describe **no** planning
workflow of its own — no phases, no plan template, no plan directory convention beyond
pointing at `docs/superpowers/`. A reader must be able to tell that `.claude/plans/` is
historical from the line that says so.

Expected: the only active process description in the repository is superpowers, reached
from `CLAUDE.md`.

- [ ] **Step 6: Commit**

```bash
git add PROCEDURE_PLANS.md CLAUDE.md
git commit -m "docs: replace the house process with the superpowers norm"
```

---

### Task 4: `README.md` corrections

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: Task 3's norm (the README points readers at it).
- Produces: a README whose four stated facts are true.

- [ ] **Step 1: Fix the four facts**

1. The note "The widget's UI and the project documentation are in **French**" → state the
   rule: documentation and the project's default language are English; UI copy is French
   pending the i18n plan, and the labels quoted below are those literal French strings.
2. The code-structure block's `.claude/plans/` line → the superpowers tree, with
   `.claude/plans/` named as the frozen archive.
3. §Release's "created by the **maintainer** (hybrid git policy)" → the sequence is the
   agent's; the passphrase prompt on the signed tag is the owner's stop.
4. §Status says **v0.2.0** while `plugin.json` is `0.3.0` and the changelog has a v0.3.0
   section → v0.3.0, mentioning the XHR transport. Fix the version line only; this is not a
   rewrite of the section.

- [ ] **Step 2: Verify**

```bash
grep -nE 'v0\.2\.0|hybrid git|in \*\*French\*\*|\.claude/plans/' README.md
```

Expected: no line claims v0.2.0 as the current version, no line claims a hybrid git policy,
no line claims the documentation is French, and the only `.claude/plans/` mention describes
it as a frozen archive.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: correct the README's language, git and version statements"
```

---

### Task 5: The backlog moves to GitHub Issues

**Files:**
- Delete: `.claude/plans/TODO.md`
- GitHub: comments on issues #6 and #7; three new issues

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: a repository with no second backlog. **Order is the deliverable here**: the
  deletion is last, so the content never has a window where git history is its only home.

- [ ] **Step 1: Carry the `lint` measurements into issue #6**

`gh issue comment 6` with an English framing and the French measurements as a **verbatim
quoted block**: `just lint` exits 0 while emitting **745** warnings on `main` @ `2f3a707`;
the per-file split (`Cockpit.qml` 304, `ClosureCard.qml` 230, `Noosphere.qml` 74,
`NoosphereWidget.qml` 66, `Closure.qml` 41, `Settings.qml` 15, `NoosphereGlyph.qml` 9); the
root cause (no `-I` toward Quickshell's and Qt6's `qml/` directories, so it fails at
`import QtQuick` and cascades into `Process was not found` / `unresolved-type` /
`unqualified`, and still returns 0). State that the ordering matters: without the `-I`
flags, measuring the real backlog is impossible.

- [ ] **Step 2: Carry the mock measurement into issue #7**

`gh issue comment 7`, same form: measured with the dev mock, `scenario=error` (500 on every
call) → `status=live`, `behind=0 uptodate=0 bar=uptodate`, both inputs at `behind=null`.
Add that this predates the v0.3.0 XHR work (same behaviour under `curl`), so it is not a
regression — it is now measured.

- [ ] **Step 3: Create the three new issues**

English titles and bodies.

1. **`cliff.toml` to English** — scheduled in chantier 2, to be done immediately before
   that version is tagged. The body must carry the subtlety: `just changelog` regenerates
   `CHANGELOG.md` entirely, so the already-published French sections have to be preserved
   rather than re-emitted under English headers; the changelog is bilingual by
   construction, cut at the first version after the switch.
2. **Conditional requests (`If-None-Match` / `ETag`)** — links to `DESIGN.md`'s future-caps
   table for the rationale rather than restating it. Verified working under Qt 6.11.1 (304
   received, empty body). Gain: a poll on a stable flake consumes almost no quota, decisive
   **without** a token (60 req/h against ~15 requests per poll). Cost: an in-memory ETag
   cache, which is extra state to invalidate and must not be persisted (invariant 1).
3. **Parallelise the GitHub compares** — same arrangement. Gain: the latency of a
   sequential poll (~15 requests in series). Cost: concurrency control, one timer per
   in-flight request, and rate-limit conduct to rethink (several requests already sent when
   the 403 arrives). Note that sequential remains the default choice.

- [ ] **Step 4: Verify the content exists before deleting its source** *(Review Focus 3)*

```bash
gh issue view 6 --comments | tail -40
gh issue view 7 --comments | tail -40
gh issue list --state open
```

Expected: both comments present and carrying the numbers; the three new issues listed. Only
then proceed.

- [ ] **Step 5: Delete `TODO.md` and commit**

```bash
git rm .claude/plans/TODO.md
git commit -m "docs: make GitHub Issues the only backlog"
```

---

### Task 6: Memories, review, and integration

**Files:**
- Outside the repository: `~/.claude/projects/-home-kuri-Apps-github-gfriloux-noosphere/memory/`

**Interfaces:**
- Consumes: every earlier task.
- Produces: a merged `main`, and a memory directory that cannot reapply the old norm.

- [ ] **Step 1: Replace the two stale memories**

Delete `git-hybrid-noosphere.md` and `commits-en-anglais.md`, and their `MEMORY.md` index
lines. The slug is the stale signal — `MEMORY.md`'s index is what a future session reads
first — so editing their bodies in place is not enough.

Write in their place:
- `git-delegated-announce-series.md` — git is delegated (`merge`, `push`, `tag`), a commit
  series is announced so the passphrase is typed once, merge form `--no-ff`, the agent stops
  for decisions rather than for steps.
- `anglais-par-defaut.md` — English is the default for documents, code comments, commit
  messages and the software's own copy; the UI is French pending the i18n plan; the
  published changelog stays French; GitHub Issues are English with carried measurements
  quoted verbatim.
- `noosphere-astropath-norme-partagee.md` — the two repositories share the superpowers norm
  **but diverge on the language rule**, so a future session does not copy astropath's
  "French UI" rule into noosphere.

Bodies stay in French, like every other file in that directory.

- [ ] **Step 2: Correct `noosphere-status.md` in place**

v0.3.0 is merged (`c276038`), not "finie sur branche, à merger". Add: the new document
tree, GitHub Issues as the only backlog, the three open issues with #6's blind `lint` gate
still true, and the three-chantier order (norm → issues + `cliff.toml` → English/i18n).

- [ ] **Step 3: Run the full gate and the confinement check**

```bash
nix develop --command just ci
git diff --stat main...HEAD
```

Expected: `just ci` green. The diff touches only `CLAUDE.md`, `PROCEDURE_PLANS.md`,
`DESIGN.md`, `README.md`, `.gitignore`, `docs/superpowers/`, and the deletion of
`.claude/plans/TODO.md`. **Any `src/` or `tests/` path in that diff is a hard stop.**

- [ ] **Step 4: Check the memory directory by slug, not only by content** *(Review Focus 5)*

```bash
ls ~/.claude/projects/-home-kuri-Apps-github-gfriloux-noosphere/memory/
grep -c '^- \[' ~/.claude/projects/-home-kuri-Apps-github-gfriloux-noosphere/memory/MEMORY.md
```

Expected: no file whose name or index line suggests hybrid git or a French repository; every
`MEMORY.md` index line resolves to a file present, and every file present has an index line.

- [ ] **Step 5: Request an independent review of the whole branch**

Use `superpowers:requesting-code-review`.

- [ ] **Step 6: GATE — the owner reads the translated `DESIGN.md`**

Hand over `tmp/design-fr-en.md` and the new `DESIGN.md`. **Stop here.** Nothing merges to
`main` until the owner says the translation is faithful. This is the one stop the spec
grants autonomy no exception to: `DESIGN.md` outranks every skill, and no mechanical check
catches a plausible mistranslation that narrows an invariant.

- [ ] **Step 7: Integrate**

Use `superpowers:finishing-a-development-branch`. Announce the integration, then
`git merge --no-ff` into `main` and push. No tag: this work ships no version.

- [ ] **Step 8: Record the manual validation**

Append a `## Manual validation` section to this plan: the date, which boxes were exercised,
and which were not and why.

---

## Phase 0

**Phase 0 (2026-10-18, `main` @ `900c54b`):** `nix develop --command just ci` → **exit 0**,
`just test` 49 passed / 0 failed. Working tree clean apart from the untracked `docs/` holding
this spec and plan. `just lint` is blind as issue #6 describes: the same run emits **721
warning lines**, including 6 `Failed to import`, and still returns 0. The gate is therefore
green on this work but proves nothing about QML — which is harmless here, since no QML is
touched.
