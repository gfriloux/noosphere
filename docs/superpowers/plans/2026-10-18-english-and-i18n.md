# English everywhere, and EN/FR in the cockpit — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: use **superpowers:executing-plans** — native execution is this repository's default (`PROCEDURE_PLANS.md` §1). Steps use checkbox (`- [ ]`) syntax; both execution skills keep the same ledger.

**Goal:** Ship **v0.5.0**: nothing French left in the repository except deliberate exceptions, the cockpit's source strings English and wrapped for translation, a French table DMS loads by itself, and the DMS floor declared. Closes #13.

**Architecture:** Four movements. Comments and the manifest description go English first — mechanical, no behaviour. Then the user-facing prose is lifted out of the three `model/` modules into the view, which is the only structural change and the only place goldens move. Then every UI string is wrapped in `I18n.trFor("noosphere", …)` with an English source literal — a shippable state on its own. Then the French table, the packaging that carries it, and the gate that keeps it honest.

**Tech Stack:** QML / Qt Quick 6.11, Quickshell 0.3, DankMaterialShell ≥ 1.6.0 (`qs.Common/I18n`), `.pragma library` JavaScript, `jq`, Nix dev shell, git-cliff.

**Spec:** [`docs/superpowers/specs/2026-10-18-english-and-i18n-design.md`](../specs/2026-10-18-english-and-i18n-design.md)

**Execution method:** native — the repository default.

## Global Constraints

- **The plugin writes no registration code.** DMS's `PluginService` discovers
  `translations/<locale>.json` next to `plugin.json`, loads it, and reloads on locale change.
- **`translations/fr.json` at the repository root** — the path is fixed by DMS, not a choice.
- **`I18n.trFor("noosphere", …)` with the id as a literal**, matching `plugin.json`'s `id`.
- **No compatibility guard.** On DMS < 1.6.0 `trFor` does not exist and every call raises a
  `TypeError`. v0.5.0 **raises the floor**, and `README.md` and the changelog say so in those
  words — `requires_dms` does not gate home-manager installs, only the plugin browser.
- **`requires_dms: ">=1.6.0"`** — established against upstream tags, not guessed.
- **Every wrapped string has an entry in `fr.json`**, and `fr.json` carries no orphan entry.
  No exemption list, even for strings DMS's own catalog would cover.
- **Host-tool output (`nix`, `nvd`) stays verbatim**; only the sentence around it is wrapped.
- **Geometry may move** where a language does not fit, and each change is recorded in
  `DESIGN.md` in the same commit. Incidental drift is not allowed.
- **Deliberate French that stays:** published `CHANGELOG.md` sections, `.claude/plans/`,
  `translations/fr.json`, and `DESIGN.md`'s Adeptus vocabulary terms.
- `just lint` at zero, `just ci` green, Nix for every command, atomic signed commits
  announced as a series, `--no-ff` integration, `Co-Authored-By` trailer.
- **Branch:** `feat/v0.5.0-english-and-i18n`.

## Review Focus

Failure modes the spec implies that no task's main assertions would catch. Every one of this
mechanism's failures is silent, which is why four of the five are here.

1. **`translations/fr.json` not installed.** `nix/hm-module.nix` copies only `plugin.json`
   and `src/`; `scripts/noosphere-dev` symlinks only `src/`. Without both carrying
   `translations/`, French never appears and nothing says why. → Task 5, Steps 6–7.
2. **A mistyped plugin id in `trFor`.** DMS keys the table by the id it discovered; a typo
   degrades to English, which looks like success. → Task 5, Step 3 (the gate checks it).
3. **DMS < 1.6.0 after this release.** Not a graceful fallback — a broken widget, and
   `requires_dms` will not stop a home-manager install. → Task 6, Steps 2–3.
4. **A French string that does not fit its slot.** The gate compares strings, not pixels; an
   elided label passes every automated check. → Task 6, Step 6 (manual, both languages).
5. **A golden moving for a reason other than the prose lift.** Task 3 moves goldens on
   purpose, which is exactly the noise a real behaviour change could hide in. → Task 3,
   Step 6 reviews each moved golden line by line against the lift.

---

### Task 1: Workspace and phase-0 audit

**Files:** carries the spec and this plan into the worktree.

**Interfaces:**
- Consumes: nothing.
- Produces: branch `feat/v0.5.0-english-and-i18n` and the worktree every later task runs in.

- [ ] **Step 1: Record the phase-0 audit**

On an up-to-date `main`: `git status --porcelain`, then `nix develop --command just ci`.
Record exit code and test count as a one-line `**Phase 0 (YYYY-MM-DD):**` entry under
`## Phase 0` at the end of this plan.

- [ ] **Step 2: Create the worktree**

`superpowers:using-git-worktrees`, branch `feat/v0.5.0-english-and-i18n` off `main`. The
native tool mangles the name (`/` → `+`, `worktree-` prefix); `git branch -m` to the name
above.

- [ ] **Step 3: Carry the spec and plan in, commit**

Copy both from the main checkout, delete them there, then:

```bash
git add docs/superpowers/
git commit -m "docs: plan the English and i18n pass"
```

---

### Task 2: Everything that is not UI copy goes English

**Files:**
- Modify: `src/view/*.qml`, `src/query/queries.js`, `src/model/*.js` (comments only)
- Modify: `Justfile` (recipe comments), `scripts/noosphere-dev` (remaining French comments)
- Modify: `plugin.json` (`description`)

**Interfaces:**
- Consumes: Task 1's worktree.
- Produces: a repository whose only French is in UI strings and the deliberate exceptions.

- [ ] **Step 1: Translate the code comments**

Every file under `src/`. These files are already mixed — v0.4.0 added English comments per
the language rule — so this finishes rather than starts the job. **Comments only: do not
touch a string literal in this task.**

- [ ] **Step 2: Translate the `Justfile`'s and `scripts/noosphere-dev`'s remaining comments.**

- [ ] **Step 3: Translate `plugin.json`'s `description`**

It is user-visible in DMS's plugin browser. Currently
« Suivi de dérive de flake NixOS — badge d'état et cockpit des inputs en retard ».

- [ ] **Step 4: Verify no behaviour moved**

Run: `nix develop --command just ci`
Expected: exit 0, tests unchanged, `git diff --stat tests/` empty.

- [ ] **Step 5: Verify the scope held**

Run: `git diff -U0 | grep '^[+-]' | grep -vE '^[+-]{3}' | grep -cE '^[+-]\s*(//|#)'` against
the total changed lines.
Expected: the changed lines are comments, `description`, and nothing else. A changed string
literal here means Task 3's work leaked into Task 2.

- [ ] **Step 6: Commit**

```bash
git add src/ Justfile scripts/noosphere-dev plugin.json
git commit -m "docs: translate the remaining code comments and the manifest description"
```

---

### Task 3: User-facing prose leaves the model layer

**Files:**
- Modify: `src/model/format.js`, `src/model/closure.js`, `src/model/poll.js`
- Modify: `src/view/Cockpit.qml`, `src/view/ClosureCard.qml` (compose what the model no longer does)
- Modify: `tests/tst_model.qml`, `tests/tst_poll.qml`, `tests/golden/*.json`
- Modify: `DESIGN.md` (invariant 7's wording, for `commitStatus`)

**Interfaces:**
- Consumes: nothing from Task 2 beyond the worktree.
- Produces: model functions that return **state, not sentences**. The view composes every
  user-visible string. Exact contracts are the builder's to choose (an enum-like string, a
  count plus a flag, a cause code) as long as they stay pure and golden-testable.

- [ ] **Step 1: Write the failing tests**

Change `tests/tst_model.qml` and `tests/tst_poll.qml` to assert the **new** contracts before
the implementation exists — a state or cause value, not a French sentence. For
`poll.js`'s `commitStatus`, assert a cause code rather than
`"aucun input n'a pu être vérifié (amont GitHub injoignable)"`.

- [ ] **Step 2: Run them to verify they fail**

Run: `nix develop --command just test`
Expected: FAIL on the changed assertions.

- [ ] **Step 3: Change the three modules**

`format.js` stops returning lag labels and relative-age prose; `closure.js` stops returning
summary wording; `poll.js`'s `commitStatus` returns a cause code. None of the three may
contain a user-facing sentence afterwards.

- [ ] **Step 4: Compose in the view**

`Cockpit.qml` and `ClosureCard.qml` build the sentences the model no longer returns. Plain
French literals for now — Task 4 wraps them. Keeping the two steps apart is what makes the
golden movement reviewable without the `trFor` churn on top.

- [ ] **Step 5: Render the cause that nothing rendered** *(this is the one behaviour change)*

`Cockpit.qml`'s status row shows a static « échec du check · réessayer ». It now shows the
composed cause from `commitStatus`, so the reason v0.4.0 computes finally reaches the user.
`DESIGN.md` invariant 7's wording follows, in this commit.

- [ ] **Step 6: Review every moved golden** *(Review Focus 5)*

Run: `nix develop --command just test`, then `git diff tests/golden/`.
Expected: every changed line is a string that moved to the view, and nothing else. A changed
number, a changed field name, a changed array length is a **hard stop** — this is the one
commit where golden movement is expected, so it is the one commit where a real regression
could hide.

- [ ] **Step 7: Verify the UI still renders**

`just mock scenario=drift` and `just dev-bar` from this worktree. The cockpit must look
exactly as before — the strings are still French at this point.

- [ ] **Step 8: Commit**

```bash
git add src/ tests/ DESIGN.md
git commit -m "refactor(model): return state instead of prose, and render the poll's cause"
```

---

### Task 4: The UI speaks English, wrapped for translation

**Files:**
- Modify: `src/view/Cockpit.qml`, `ClosureCard.qml`, `Closure.qml`, `Settings.qml`, `NoosphereWidget.qml`
- Modify: `DESIGN.md` (its quoted literals, and the language note)

**Interfaces:**
- Consumes: Task 3's view-composed strings.
- Produces: every user-facing string as `I18n.trFor("noosphere", "<English>")`, the id a
  literal. Task 5's gate greps exactly this shape.

- [ ] **Step 1: Wrap and translate every UI string**

Roughly fifty across the five files (45 carry an accent; a few do not — `"INPUTS"`,
`"DIFF DE CLOSURE"`, `"lock "`). English becomes the source. `qs.Common` is already imported
by all five.

Sentences assembled by concatenation (`"lock " + age`, `count + " commits en retard"`) become
**one wrapped string with a placeholder** rather than translated fragments: fragments
translate badly and cannot be reordered, which French frequently needs.

- [ ] **Step 2: Verify nothing French remains in the view**

Run: `grep -rnE '"[^"]*[éèêàçùôûœ][^"]*"' src/`
Expected: no output.

- [ ] **Step 3: Verify every wrapped call uses the literal id**

Run: `grep -rn 'trFor(' src/ | grep -v 'trFor("noosphere"'`
Expected: no output.

- [ ] **Step 4: Update `DESIGN.md`**

Its quoted French literals become the new English source strings, and the blockquote saying
they are French pending this plan is removed. The Adeptus vocabulary sentence keeps its three
French terms and gains a line saying the UI now renders English with French available.

- [ ] **Step 5: Verify the gates**

Run: `nix develop --command just ci`
Expected: exit 0. `git diff --stat tests/golden/` empty — Task 3 moved the goldens; this task
must not.

- [ ] **Step 6: Verify the UI, in English**

`just dev-bar`. The cockpit reads English throughout, no mixed-language card, nothing elided
that was not elided before.

- [ ] **Step 7: Commit**

```bash
git add src/ DESIGN.md
git commit -m "feat(view): English source strings, wrapped for translation"
```

**This is a shippable state.** If the French table turns out to be more work than expected,
the chantier can stop here as English-only with the mechanism in place.

---

### Task 5: The French table, its packaging, and the gate that keeps it honest

**Files:**
- Create: `translations/fr.json`
- Create: `scripts/check-translations`
- Modify: `Justfile` (new recipe, wired into `ci-hermetic`), `.pre-commit-config.yaml`
- Modify: `nix/hm-module.nix`, `scripts/noosphere-dev`

**Interfaces:**
- Consumes: Task 4's `trFor("noosphere", "…")` call sites.
- Produces: `just check-translations`, called by `ci-hermetic`. The table's shape is
  `{ "<context>": { "<term>": "<translation>" } }`; a single context bucket is enough, since
  `I18n._termIndex` flattens across contexts on lookup.

- [ ] **Step 1: Write the failing gate**

`scripts/check-translations` collects source strings by grepping `trFor("noosphere", "…")`
over `src/`, loads `translations/fr.json`, and reports **both** directions: a source string
with no entry, and an entry no source string uses. It also fails on any `trFor(` whose id is
not the literal `"noosphere"` *(Review Focus 2)*. `jq` only — it must run without DMS or
Quickshell, since this is the one i18n gate CI can run.

- [ ] **Step 2: Run it to verify it fails**

Run: `nix develop --command scripts/check-translations`
Expected: non-zero, listing every source string as missing — `translations/fr.json` does not
exist yet.

- [ ] **Step 3: Write `translations/fr.json`**

One entry per source string. The pre-Task-4 French is the obvious source, but a few will read
differently now that English is the original.

- [ ] **Step 4: Run it to verify it passes**

Run: `nix develop --command scripts/check-translations`
Expected: exit 0.

- [ ] **Step 5: Verify it catches both directions**

Add a wrapped string with no entry → fails naming it. Add an orphan entry → fails naming it.
Change one call site's id to `"nosphere"` → fails. Revert each.

- [ ] **Step 6: Package the table — home-manager** *(Review Focus 1)*

`nix/hm-module.nix` copies only `plugin.json` and `src/`. It must carry `translations/` too,
or the installed plugin has no French and nothing says why.

- [ ] **Step 7: Package the table — dev instance** *(Review Focus 1)*

`scripts/noosphere-dev` assembles the dev plugin directory from `plugin.json` plus a `src/`
symlink. Add `translations/`, symlinked like `src/` so edits are live.

- [ ] **Step 8: Wire the gate in**

A `check-translations` recipe in the `Justfile`, added to `ci-hermetic` beside
`check-manifest`. A `pre-commit` hook keyed on `^src/|^translations/`.

- [ ] **Step 9: Verify**

Run: `nix develop --command just ci`
Expected: exit 0, with the translation check visible.

- [ ] **Step 10: Commit**

```bash
git add translations/ scripts/check-translations Justfile .pre-commit-config.yaml nix/hm-module.nix scripts/noosphere-dev
git commit -m "feat(i18n): add the French translation table, its packaging and its gate"
```

---

### Task 6: Declare the floor, release v0.5.0, integrate

**Files:**
- Modify: `plugin.json` (`requires_dms`, `requires` → `dependencies`, `version`)
- Modify: `README.md`, `CHANGELOG.md`

**Interfaces:**
- Consumes: every earlier task.
- Produces: a merged, tagged, pushed `main`; #13 closed.

- [ ] **Step 1: Declare the floor and fix the deprecated field**

`requires_dms: ">=1.6.0"`. `"requires": [...]` becomes `"dependencies": [...]` — the
non-deprecated spelling, and the one DMS's plugin browser actually displays. That is #13.

- [ ] **Step 2: Say that the floor moved, in words** *(Review Focus 3)*

`README.md` states that v0.5.0 requires DMS ≥ 1.6.0 and that **an older DMS breaks the widget
rather than degrading** — `I18n.trFor` does not exist there. It also states that
`requires_dms` does not gate a home-manager install, so this is the only warning such a user
gets.

- [ ] **Step 3: Verify the manifest gate**

Run: `nix develop --command just check-manifest`, then with `requires_dms` set to `1.6.0`
(no comparator, which the schema's pattern rejects).
Expected: passes, then fails naming the field.

- [ ] **Step 4: Bump and generate**

`version` → `0.5.0`; `nix develop --command just changelog`; read the diff. The published
sections stay byte-identical.

- [ ] **Step 5: Verify the whole gate, the diff's shape, and that no French is left**

Run: `nix develop --command just ci` and `git diff --stat main...HEAD`.
Expected: exit 0; goldens changed **only** in Task 3's commit.

Then the repository-wide check the goal actually states — not just `src/`:

```bash
grep -rnE '[éèêàçùôûœ]' --include='*.qml' --include='*.js' --include='*.nix' \
  --include='*.json' --include='*.md' --include='*.toml' --include='*.yaml' \
  --include='Justfile' . \
  | grep -vE '^\./(CHANGELOG\.md|\.claude/plans/|translations/|docs/superpowers/)'
```

Expected: only `DESIGN.md`'s three Adeptus vocabulary terms. Anything else is French that
this chantier was supposed to remove and did not.

- [ ] **Step 6: Verify both languages on a fresh dev instance** *(Review Focus 4)*

With the DMS locale French, the cockpit reads French; set it to English and it reads English.
Neither shows a mixed-language card, and **no label is elided or overflowing in either** —
the gate compares strings, not pixels. Any geometry that has to move is recorded in
`DESIGN.md` in this commit.

- [ ] **Step 7: Commit, review, integrate**

```bash
git add plugin.json README.md CHANGELOG.md DESIGN.md
git commit -m "chore(release): v0.5.0"
```

Then an independent whole-branch review per `superpowers:requesting-code-review`, then
`superpowers:finishing-a-development-branch`: `--no-ff` merge, push, signed tag `v0.5.0`,
push. Close #13 with a comment naming the commit.

- [ ] **Step 8: Record the manual validation**

Append a `## Manual validation` section to this plan: the date, which boxes were exercised,
which were not and why.

---

## Phase 0

**Phase 0 (2026-10-18, `main` @ `1558acb`):** `nix develop --command just ci` → **exit 0**,
70 passed / 0 failed, `lint: 0 findings over 7 file(s), 47 import path(s)`. Working tree
clean apart from the untracked spec and plan for this work.
