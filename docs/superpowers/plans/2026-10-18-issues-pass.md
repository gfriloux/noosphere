# The issues pass — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: use **superpowers:executing-plans** to implement this plan task-by-task — native execution is this repository's default (`PROCEDURE_PLANS.md` §1: the announce-a-commit-series rule needs commits arriving from one context). `superpowers:subagent-driven-development` is the alternative, decided at the plan review with the extra signing prompts named. Steps use checkbox (`- [ ]`) syntax; both skills keep the same ledger.

**Goal:** Ship **v0.4.0**: `just lint` resolves every QML import and blocks at zero lines, the poll driver becomes a pure tested module, a poll that verified nothing stops reporting `uptodate`, CI validates `plugin.json`, and `cliff.toml` turns English before the tag. Closes #6, #7, #8, #9 and #12's first half.

**Architecture:** Four movements. The lint gate is made to *see* (Quickshell generates the import paths), then the 18 real findings are fixed, then the gate is made to *bite*. CI gains the one check it can run without the host. The poll driver's state machine moves out of `src/view/Noosphere.qml` into a pure `src/model/poll.js` that `qmltestrunner` can load — which is what makes both #8's invariants and #7's fix provable. Then the release.

**Tech Stack:** QML / Qt Quick 6.11, Quickshell 0.3, plain `.pragma library` JavaScript, `qmllint`/`qmltestrunner` from qtdeclarative, `just`, Nix dev shell, Python 3 for the manifest check, git-cliff.

**Spec:** [`docs/superpowers/specs/2026-10-18-issues-pass-design.md`](../specs/2026-10-18-issues-pass-design.md)

**Execution method:** native — the repository default.

## Global Constraints

- **The gate blocks on zero *lines*** of `qmllint` output, not zero warnings: the `Info:` unused-import and the pragma hints must go too.
- **The 8 `unqualified` findings are fixed with `required property`, never with `pragma ComponentBehavior: Bound`** — the pragma changes delegate ID-binding semantics at runtime inside someone else's shell.
- **`src/model/poll.js` imports nothing from Quickshell.** If it ever does, `qmltestrunner` cannot load it and the new suite silently stops running.
- **Every existing golden stays byte-identical.** The extraction moves code; it does not change what `parseMetadata`, `parseCompare`, `mergeBehind`, `behindCount` or `barState` compute. A moved golden is a hard stop.
- **The driver's tests are inline assertions, not goldens** (a golden per scenario would freeze an execution trace).
- **No new `barState`**, and no change to `DESIGN.md`'s imperative colour-mapping table.
- **No DankMaterialShell flake input.** CI has no DMS and must say so rather than lint less quietly.
- **`lastCheck` only ever carries the timestamp of a poll that verified something.**
- **The GitHub token never leaves a header.** It must not reach an argv, a fixture, a golden, or `query`/`model`.
- **`just test` stays hermetic**: no network, no spawned server, runs offscreen.
- **Language:** English for documents, code comments and commit messages. UI copy stays French in this pass; a French UI string is quoted, never translated in passing.
- **Nix:** non-interactive commands run as `nix develop --command …`.
- **Git:** branch `feat/v0.4.0-gates-that-guard`, atomic signed commits announced as a series, `--no-ff` integration, `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>` trailer.

## Review Focus

Failure modes the spec implies that no task's main assertions would catch. Each has a step attached to the task that owns it.

1. **The badge greys from `connectionStatus`, not from `barState`.** With every input indeterminate, `behindCount` is 0 and `barState` still reads `uptodate`; if the view's grey path is driven by `barState`, #7 ships invisible — the fix lands and the badge still goes blue. → Task 7, Step 2.
2. **A flake of only non-GitHub inputs reported as a failure.** Invariant 4 says non-GitHub inputs are never compared, so `queue` is empty and nothing resolved — which must read as "nothing to verify", not "verification failed". → Task 6, Step 1 (`nothingVerified` false on an empty queue).
3. **The first poll after startup, failing.** There is no last known value to hold. → Task 7, Step 6 (manual) and Step 1's assertion that the fresh list is published regardless.
4. **DMS absent, or `qs` behaving differently on another machine.** The lint recipe must fail with a message naming what is missing, never lint a subset quietly. → Task 2, Steps 5–6.
5. **`poll.js` or `tst_poll.qml` acquiring a Quickshell import later.** The suite would stop running and `just test` would still pass. → Task 6, Step 9.

---

### Task 1: Workspace and phase-0 audit

**Files:** none modified; carries the spec and this plan into the worktree.

**Interfaces:**
- Consumes: nothing.
- Produces: branch `feat/v0.4.0-gates-that-guard`, the worktree every later task runs in, the committed spec and plan.

- [x] **Step 1: Record the phase-0 audit**

On an up-to-date `main`, before branching:

```bash
git status --porcelain
nix develop --command just ci
```

Record the result as a one-line `**Phase 0 (YYYY-MM-DD):**` entry under `## Phase 0` at the end of this plan: exit code, test count, and the `lint` figure measured with `nix develop --command just lint 2>&1 | grep -c Warning`.

- [x] **Step 2: Create the worktree**

Use `superpowers:using-git-worktrees`, branch `feat/v0.4.0-gates-that-guard` off `main`. The native tool mangles branch names (`/` → `+`, `worktree-` prefix); rename with `git branch -m` to the name above.

- [x] **Step 3: Carry the spec and plan into the worktree**

Both were written in the main checkout as untracked files. Copy to the same paths in the worktree, then delete from the main checkout.

Expected: `find docs/superpowers -type f` in the worktree lists the 2026-10-18 issues-pass spec and plan (plus the already-committed norm-migration pair); `git -C <main checkout> status --porcelain` is clean.

- [x] **Step 4: Commit**

```bash
git add docs/superpowers/
git commit -m "docs: plan the issues pass"
```

---

### Task 2: `just lint` resolves every import

**Files:**
- Create: `scripts/qml-import-paths`
- Modify: `Justfile` (the `lint` recipe)

**Interfaces:**
- Consumes: Task 1's worktree.
- Produces: `scripts/qml-import-paths`, which prints one `-I <path>` argument per line on stdout and exits non-zero with a message on stderr when DMS cannot be found. The `lint` recipe consumes its output. Task 4 makes the recipe blocking.

- [x] **Step 1: Write the import-path script**

`scripts/qml-import-paths` discovers the paths and prints them, one per line. The route, verified in the spec's investigation:

1. Locate DMS's shell root. It is `share/quickshell/dms` inside the `dms-shell` store path; find it without hard-coding a hash (the plugin is installed through home-manager, so `~/.config/quickshell` or the DMS binary on `PATH` are both reasonable anchors). **Hard-coding a store path is a defect** — DMS updates change it.
2. Copy that root into a writable temporary directory (~25 MB), `touch .qmlls.ini` inside the copy.
3. `QT_QPA_PLATFORM=offscreen qs -p <copy>` — with a `timeout`, since `qs` does not exit on its own.
4. Parse `buildDir=` and `importPaths=` out of the populated `.qmlls.ini`; emit `buildDir` and each `:`-separated import path.

Three measured constraints the script must respect:

- **`qs -p` exits 255** while still writing a complete VFS. Do not gate on its exit code; gate on `.qmlls.ini` being populated.
- **The VFS survives `qs` exiting**, so the paths stay usable after it is gone.
- **`buildDir` lives on tmpfs.** Regenerate per run, or validate that a cached path still exists.

- [x] **Step 2: Verify the script's output**

Run: `nix develop --command scripts/qml-import-paths`
Expected: several absolute paths, at least one under `/run/user/<uid>/quickshell/vfs/`, and `echo $?` → 0.

- [x] **Step 3: Rewrite the `lint` recipe to use them**

The recipe builds `-I <path>` arguments from the script's output and runs `qmllint` over `src/**/*.qml`, capturing output. It does **not** yet fail on findings — Task 4 does that, after Task 3 empties the list. Keep today's behaviour of printing what it finds.

- [x] **Step 4: Measure the resolved backlog**

Run: `nix develop --command just lint 2>&1 | grep -cE 'Warning:|Info:'`
Expected: **19** — 18 `Warning:` plus the `Info:` unused import. Any `Failed to import` line means the resolution is incomplete and the task is not done.

- [x] **Step 5: Verify the DMS-absent path** *(Review Focus 4)*

Run the script with the discovery anchor made unavailable (e.g. `PATH` stripped of the DMS binary, or the expected directory temporarily renamed) and confirm it exits non-zero with a message naming DMS.

Expected: non-zero exit, a message a human can act on, and **no** partial list of paths on stdout. A script that prints some paths and exits 0 would make the gate lint a subset in silence — the anti-goal.

- [x] **Step 6: Verify the recipe propagates that failure**

Run: `nix develop --command just lint` with the same anchor unavailable.
Expected: the recipe exits non-zero. It must not fall back to linting without `-I`.

- [x] **Step 7: Commit**

```bash
git add scripts/qml-import-paths Justfile
git commit -m "build(nix): resolve QML imports for qmllint through Quickshell's own VFS"
```

---

### Task 3: Fix the 19 findings

**Files:**
- Modify: `src/view/NoosphereWidget.qml` (7 × `unqualified`: lines 69, 75, 86 ×2, 97, 98, 99)
- Modify: `src/view/Cockpit.qml` (1 × `unqualified` line 335; 6 × `Quick.layout-positioning` lines 300, 301, 316, 317, 345, 346)
- Modify: `src/view/ClosureCard.qml` (1 × `Info: Unused import`, line 7)
- Modify: `src/view/Closure.qml` (3 × `signal-handler-parameters`: lines 77, 93, 132)
- Modify: `src/view/Noosphere.qml` (1 × `signal-handler-parameters`: line 189)

**Interfaces:**
- Consumes: Task 2's resolving `lint` recipe — without it these findings are invisible.
- Produces: a `src/` tree on which `qmllint` emits nothing. Task 4 relies on that.

- [x] **Step 1: Fix the 8 unqualified accesses with `required property`**

Each is an access to an outer-scope property from inside a delegate or nested component. Plumb the value in as a `required property` on the delegate instead. **Do not add `pragma ComponentBehavior: Bound`**, which qmllint suggests in an attached `Info:` — it changes delegate ID-binding semantics at runtime, and this widget runs inside someone else's shell.

- [x] **Step 2: Fix the 6 layout-positioning findings**

`width`/`height` on layout-managed items become `implicitWidth`/`implicitHeight`, or `Layout.preferredWidth`/`Layout.preferredHeight` where the item should negotiate. Qt calls the current form undefined behaviour.

- [x] **Step 3: Remove the unused import** in `src/view/ClosureCard.qml:7`.

- [x] **Step 4: Resolve the 4 `signal-handler-parameters` findings**

`QProcess::ExitStatus` is not visible to qmllint for the `exitStatus` parameter of `onExited`. Prefer a real fix (an import that brings the type into scope, or a handler signature that does not name the parameter). If none exists, wrap the single handler in an inline `// qmllint disable signal-handler-parameters` / `// qmllint enable signal-handler-parameters` pair carrying a comment that names what would let it be removed. **Never disable the category globally.**

- [x] **Step 5: Verify the list is empty**

Run: `nix develop --command just lint 2>&1 | grep -cE 'Warning:|Info:'`
Expected: **0**.

- [x] **Step 6: Verify nothing moved**

Run: `nix develop --command just test`
Expected: 49 passed, 0 failed. No golden changed — `git diff --stat tests/` must be empty.

- [x] **Step 7: Verify the UI still renders**

Run `just dev-bar` (and `just mock` in another terminal). Open the cockpit.
Expected: the INPUTS rows, the closure card and the bar badge look as before — the layout fixes must not shift anything visually, and the `required property` plumbing must not blank a delegate. This is the manual check that the `unqualified` and layout fixes are behaviour-preserving.

- [x] **Step 8: Commit**

```bash
git add src/view/
git commit -m "fix(view): clear the 19 findings qmllint reports once imports resolve"
```

---

### Task 4: The gate bites

**Files:**
- Modify: `Justfile` (the `lint` recipe)

**Interfaces:**
- Consumes: Task 3's empty finding list.
- Produces: a `lint` recipe that exits non-zero on any `qmllint` output line.

- [x] **Step 1: Make the recipe fail on any output**

Capture `qmllint`'s combined output and fail if it is non-empty — `qmllint` itself **exits 0 even with 18 findings**, which is today's bug, so the recipe must force the failure. Filter only the known-bogus classes if they appear (`… not declared as singleton in qmldir but using pragma Singleton`, `PostReloadHook was not found …`), each filter carrying a comment naming why it exists and what would let it go.

- [x] **Step 2: Verify it passes at zero**

Run: `nix develop --command just ci`
Expected: exit 0.

- [x] **Step 3: Verify it fails on a deliberate regression**

Introduce one unqualified access in `src/view/Cockpit.qml`, run `nix develop --command just lint`, then revert it.
Expected: non-zero exit naming the file and line. **This is #6's acceptance criterion** — the gate was decorative until this step.

- [x] **Step 4: Update the documents that describe the gate**

`PROCEDURE_PLANS.md` §4's blind-`lint` warning block is removed — it is no longer true. `CLAUDE.md`'s `just lint` line drops "currently blind, see issue #6". `README.md`'s blind-lint blockquote goes. Same commit as the recipe, per the docs-with-code rule.

- [x] **Step 5: Commit**

```bash
git add Justfile PROCEDURE_PLANS.md CLAUDE.md README.md
git commit -m "build(nix): make the lint gate blocking"
```

---

### Task 5: CI validates the manifest and states what it cannot lint

**Files:**
- Create: `scripts/check-manifest`
- Modify: `Justfile` (new recipe, wired into `ci`)
- Modify: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: a `just check-manifest` recipe, called by `ci`.

- [x] **Step 1: Write the failing check**

`scripts/check-manifest` validates `plugin.json`:
- `id`, `name`, `description`, `version`, `author`, `component` are non-empty strings;
- `version` matches `^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$`;
- `component` and `settings`, when present, resolve to files that exist inside the repository (no scheme, no `..` escape).

Modelled on `alcxyz/DankDiskUsage`'s CI check and on astropath's `scripts/check-manifest`.

- [x] **Step 2: Verify it fails on a broken manifest**

Break `plugin.json` three ways in turn — drop `author`, set `version` to `0.4`, point `component` at a missing file — running the script each time, then restore.
Expected: non-zero exit each time, with a message naming the field.

- [x] **Step 3: Verify it passes on the real manifest**

Run: `nix develop --command scripts/check-manifest`
Expected: exit 0.

- [x] **Step 4: Wire it into `ci`**

A `check-manifest` recipe in the `Justfile`, added to `ci`'s dependency list. The `Justfile` stays the only definition of the gates.

- [x] **Step 5: Make CI say what it does not lint**

`.github/workflows/ci.yml` gains a step that prints one line: DankMaterialShell is not available here, so the QML lint does not run in CI; it runs locally and in `pre-commit`, where DMS is installed. A green CI run must never imply the QML was checked.

*(The QML lint cannot run in CI and is not expected to: see the spec's non-goal on adding DMS as a flake input.)*

- [x] **Step 6: Verify the whole gate**

Run: `nix develop --command just ci`
Expected: exit 0, and the manifest check visible in the output.

- [x] **Step 7: Commit**

```bash
git add scripts/check-manifest Justfile .github/workflows/ci.yml
git commit -m "ci: validate plugin.json, and declare that CI does not lint QML"
```

---

### Task 6: The poll driver becomes a pure tested module

**Files:**
- Create: `src/model/poll.js`
- Create: `tests/tst_poll.qml`
- Create: `tests/fixtures/poll-metadata.json` (a `nix flake metadata` fixture with at least two GitHub inputs — one with a `channel`, one without — and one non-GitHub input)
- Modify: `src/view/Noosphere.qml` (the driver logic leaves; `Process`, `XMLHttpRequest` and `Timer` stay)

**Interfaces:**
- Consumes: Task 1's worktree.
- Produces, in `src/model/poll.js` (`.pragma library`, nothing imported from Quickshell):

  | Function | Returns |
  |---|---|
  | `create(cfg)` | a driver state object `st`; `cfg` is `{ apiBase: string }` |
  | `begin(st, metaJsonText)` | an effect |
  | `onHttpDone(st, token, status, text, timedOut)` | an effect |
  | `onWatchdog(st)` | an effect |
  | `onMetaFailed(st, message)` | an effect |
  | `model(st)` | `{ inputs, behindCount, upToDateCount, barState }` |
  | `nothingVerified(st)` | `bool` |

  An **effect** is a plain object discriminated on `kind`:
  - `{ kind: "get", url: string, token: number }` — the caller issues a GET and later calls `onHttpDone` with that same `token`, restarting its step watchdog
  - `{ kind: "commit", verified: bool }` — the caller publishes `model(st)`; `verified` false is #7's case
  - `{ kind: "fail", message: string }` — the caller keeps the last known state and shows the error
  - `{ kind: "noop" }` — nothing happened and nothing changed; the caller does nothing. This is what a stale `token` returns.

  **The token is the invariant made structural.** `onHttpDone` with a stale token returns `{kind:"noop"}` and mutates nothing: that is "a response belongs to the input that asked for it" and "an aborted request's callback never advances a step", expressed where a unit test can reach them.

- [x] **Step 1: Write the failing tests**

`tests/tst_poll.qml`, a `TestCase` importing only `QtQuick`, `QtTest` and `../src/model/poll.js` — matching `tests/tst_model.qml`'s style (inline `compare()`, no goldens).

```qml
function test_nothingVerified_emptyQueue()      // non-GitHub-only flake → false  (Review Focus 2)
function test_nothingVerified_noneResolved()    // queue non-empty, behind {} → true
function test_nothingVerified_oneResolved()     // one behind === 0 → false
function test_poll_drift()                      // compare responses with ahead_by > 0 → commit verified, barState "drift"
function test_poll_uptodate()                   // ahead_by 0 everywhere → commit verified, barState "uptodate"
function test_poll_allFailed()                  // every response 500 → commit NOT verified, fresh inputs still in model(st)
function test_poll_rateLimited()                // a 403 rate-limit → fail effect, message naming the cause
function test_staleTokenIsIgnored()             // onHttpDone with a previous token → noop, behind unchanged
function test_attributionMismatchDiscarded()    // compare whose base_commit.sha is another input's → behind unchanged
function test_watchdogAdvances()                // onWatchdog mid-request → next get, or commit when the queue is spent
function test_channelSkipsRepoLookup()          // an input with a channel → first effect is the compare URL, not the repo URL
function test_defaultBranchResolved()           // an input without a channel → repo URL first, then compare with the parsed branch
```

Assert on `model(st).barState`, `model(st).inputs`, and the effects' `kind`/`url`. Use `tests/fixtures/poll-metadata.json` for the metadata text and inline JSON strings for the GitHub responses.

- [x] **Step 2: Verify `.import` works between `.pragma library` files**

`poll.js` needs `queries.js` (URL builders) and `inputs.js` (parsers). No existing module imports another, so confirm the mechanism before building on it: add `.import "../query/queries.js" as Queries` to a throwaway library, call one function from a test, and run the suite.

Run: `nix develop --command just test`
Expected: PASS. **If it fails**, the fallback is to pass the two modules in as a dependency object at `create(cfg, deps)` — the test supplies them from its own imports. Either way, record which route was taken in the ledger; the rest of this task is unchanged.

- [x] **Step 3: Run the tests to verify they fail**

Run: `nix develop --command just test`
Expected: FAIL — `poll.js` does not exist, so the import fails to resolve.

- [x] **Step 4: Write `src/model/poll.js`**

The state machine, lifted from `src/view/Noosphere.qml:195-324` (`_onMeta`, `_next`, `_compare`, `_advance`, `_commit`, `_fail`, `_parse`) with the QML removed. `st` holds what the QML properties `_inputs`, `_behind`, `_heads`, `_queue`, `_cursor` hold today, plus the request token. The `_heads` enrichment stays part of `model(st)` — it feeds the view's changelog link.

`model(st)` must produce exactly what `_commit` produces today, by calling the same `Model.*` functions, so the existing goldens cannot move.

No `Date.now()`, no `console`, no QML type.

- [x] **Step 5: Run the tests to verify they pass**

Run: `nix develop --command just test`
Expected: all of `tst_poll.qml` passes, and the pre-existing 49 still pass.

- [x] **Step 6: Rewire `src/view/Noosphere.qml` onto the module**

The service keeps: the four `Process` objects, `_ghGet` and its `XMLHttpRequest`, `httpTimeout`, `stepWatchdog`, `pollTimer`, the published properties, and `reconfigure`. It performs effects:

- `poll()` creates the state and runs `metaProc`; the stdout handler calls `begin(st, text)`.
- `{kind:"get"}` → `_ghGet(url, …)`, `stepWatchdog.restart()`, and the callback passes the effect's `token` back to `onHttpDone`.
- `{kind:"commit", verified}` → publish `model(st)`; see Task 7 for what `verified:false` does. For this task, `verified:false` keeps today's behaviour so the commit is behaviour-preserving.
- `{kind:"fail", message}` → today's `_fail` body.
- `{kind:"noop"}` → nothing.

The transport factory is the seam that stays: `_ghGet` obtains its object from a replaceable property rather than calling `new XMLHttpRequest()` directly, so the remaining I/O is substitutable later.

- [x] **Step 7: Verify behaviour is preserved**

Run: `nix develop --command just ci`
Expected: exit 0, 49 + the new tests passing, `git diff --stat tests/golden/` empty.

- [x] **Step 8: Verify the real thing still polls**

Run `just mock` and `just dev-bar`; exercise `drift`, `uptodate`, `ratelimit` and `error` scenarios.
Expected: each renders as it did before this task — this is the extraction's only end-to-end proof, and `{kind:"commit", verified:false}` still behaving like today is deliberate (Task 7 changes it).

- [x] **Step 9: Verify the suite cannot silently stop running** *(Review Focus 5)*

Run: `grep -nE '^(\.import|import)' src/model/poll.js tests/tst_poll.qml`
Expected: no `Quickshell` anywhere. Then confirm the runner really would notice: add `import Quickshell.Io` to `tests/tst_poll.qml`, run `just test`, see it **fail to load**, and revert. A silent pass there would mean the suite can die unnoticed.

- [x] **Step 10: Commit**

```bash
git add src/model/poll.js src/view/Noosphere.qml tests/tst_poll.qml tests/fixtures/poll-metadata.json
git commit -m "refactor(model): extract the poll driver out of QML and test it"
```

---

### Task 7: A poll that verified nothing stops reporting `uptodate`

**Files:**
- Modify: `src/view/Noosphere.qml` (the `commit` effect handler)
- Modify: `tests/tst_poll.qml` (the regression assertion)
- Modify: `DESIGN.md` (invariant 7's `connectionStatus` enumeration)

**Interfaces:**
- Consumes: Task 6's `nothingVerified(st)` and `{kind:"commit", verified}`.
- Produces: the published state for a poll that verified nothing.

- [x] **Step 1: Write the failing regression assertion**

In `tests/tst_poll.qml`, extend `test_poll_allFailed` to pin all of it:

```qml
compare(Poll.nothingVerified(st), true);
compare(effect.kind, "commit");
compare(effect.verified, false);
compare(Poll.model(st).inputs.length, 3);   // the freshly-parsed list is published anyway
compare(Poll.model(st).inputs[0].behind, null);
```

- [x] **Step 2: Find what drives the badge's colour** *(Review Focus 1)*

Read `src/view/NoosphereWidget.qml` and `src/view/NoosphereGlyph.qml` and establish which property greys the badge. `DESIGN.md`'s *Secondary states* requires grey on error; with everything indeterminate `behindCount` is 0 and `barState` reads `uptodate`, so if the grey path keys off `barState` the fix is invisible and the badge goes blue anyway.

Expected: a named property and line. If it keys off `barState`, this task also changes the view to key off `connectionStatus` — record that as a finding, because it means the error state never greyed correctly for *any* cause, not just this one.

- [x] **Step 3: Implement the commit handler**

On `{kind:"commit", verified:false}`: publish `model(st)` as usual (fresh inputs, `behind` indeterminate), set `connectionStatus = "error"` and an `errorMessage` naming the cause, and **leave `lastCheck` untouched**. On `verified:true`: today's behaviour, including `lastCheck = Date.now() / 1000`.

- [x] **Step 4: Run the tests**

Run: `nix develop --command just test`
Expected: PASS, including the extended `test_poll_allFailed`.

- [x] **Step 5: Add the `idle` state to `DESIGN.md`** — invariant 7 enumerates `live | polling | error` while the code also uses `idle`. This closes #12's first half. Same commit.

- [x] **Step 6: Verify against the mock** *(Review Focus 3)*

Run `just mock scenario=error` and `just dev-bar`.
Expected: the badge **grey**, not blue; the INPUTS card with its red edge, the « échec du check · réessayer » row, and the input rows present with an indeterminate lag. Then, on a **fresh** dev-bar start against the same failing mock — so there is no last known value — the same rendering rather than an empty card. Finally, switch the mock to `drift` and click re-check: the badge recovers.

- [x] **Step 7: Commit**

```bash
git add src/view/Noosphere.qml tests/tst_poll.qml DESIGN.md
git commit -m "fix(view): keep the error status when a poll verified nothing"
```

---

### Task 8: `cliff.toml` to English

**Files:**
- Modify: `cliff.toml`
- Modify: `CHANGELOG.md` (regenerated)

**Interfaces:**
- Consumes: nothing.
- Produces: an English changelog scaffold, with the published French sections intact.

- [x] **Step 1: Translate `cliff.toml`**

`[changelog] header` (and its `keepachangelog.com/fr/`, `semver.org/lang/fr/` links), `## [Non publié]`, the scope separator `- **{{ scope }}** : ` (French spacing before the colon), the `footer`, and the `commit_parsers` group names (Fonctionnalités, Corrections, Performance, Refactorisations, Documentation, Tests, Intégration continue, Divers).

- [x] **Step 2: Decide and apply the preservation route**

`just changelog` regenerates the whole file, so the published French sections would otherwise be re-emitted under English headers. Choose: freeze the published history at the top of the file and generate only what is new, or accept English headers over the old French titles. Record the choice and the reason in the commit message.

- [x] **Step 3: Verify the published sections survived**

Run: `nix develop --command just changelog`, then `git diff CHANGELOG.md`.
Expected: the v0.1.0 … v0.3.0 sections unchanged, read line by line. **Any edit inside a published section is a hard stop** — it would rewrite the description of commits that were written in French.

- [x] **Step 4: Commit**

```bash
git add cliff.toml CHANGELOG.md
git commit -m "docs: translate the changelog scaffolding to English"
```

---

### Task 9: Release v0.4.0 and integrate

**Files:**
- Modify: `plugin.json` (`version`)
- Modify: `CHANGELOG.md`
- Modify: `README.md` (§Status)

**Interfaces:**
- Consumes: every earlier task.
- Produces: a merged, tagged, pushed `main`.

- [x] **Step 1: Bump and regenerate**

`plugin.json` `version` → `0.4.0`; `nix develop --command just changelog`; read the diff.

- [x] **Step 2: Update `README.md` §Status** to v0.4.0, naming what this version adds: a lint gate that guards, a tested poll driver, and a badge that no longer claims to have verified what it could not.

- [x] **Step 3: Run the full gate**

Run: `nix develop --command just ci`
Expected: exit 0.

- [x] **Step 4: Confirm the diff's shape**

Run: `git diff --stat main...HEAD`
Expected: `Justfile`, `scripts/`, `src/model/poll.js`, `src/view/*.qml`, `tests/`, `cliff.toml`, `CHANGELOG.md`, `plugin.json`, `DESIGN.md`, `PROCEDURE_PLANS.md`, `CLAUDE.md`, `README.md`, `.github/workflows/ci.yml`, `docs/superpowers/`. **No golden under `tests/golden/` may appear.**

- [x] **Step 5: Commit**

```bash
git add plugin.json CHANGELOG.md README.md
git commit -m "chore(release): v0.4.0"
```

- [x] **Step 6: Request an independent review** of the whole branch, per `superpowers:requesting-code-review`.

- [ ] **Step 7: Close the issues**

`gh issue close 6 7 8 9` with a comment on each naming the commit that closed it. #12 stays open on its second half; comment there that the `connectionStatus` half is done.

- [ ] **Step 8: Integrate**

`superpowers:finishing-a-development-branch`: announce, `git merge --no-ff` into `main`, push, then the signed tag `v0.4.0` and push it — which triggers `.github/workflows/release.yml`.

- [x] **Step 9: Record the manual validation**

Append a `## Manual validation` section to this plan: the date, which boxes were exercised, which were not and why.

---

## Manual validation

**Run 2026-10-18.** The plan listed two checks as needing a live DMS instance and a human
eye. One of the two turned out to be verifiable **mechanically**, which is a better outcome
than a glance, and it was done that way.

### What a headless probe proved

`src/view/Noosphere.qml` imports only `QtQuick`, `Quickshell.Io` and this repository's own
JS — **no DMS `qs.*` module** — so the real service loads under a bare
`QT_QPA_PLATFORM=offscreen quickshell -p probe.qml`. A throwaway probe instantiated it
against the real flake (`/home/kuri/Apps/github/gfriloux/nixos`) and the dev mock, and
printed the state it actually reached. The probe was deleted afterwards; the mocks it started
were stopped **by pid**, never with a broad `pkill` (which would take the owner's bar with
it).

| Condition | Measured |
|---|---|
| Real GitHub, no mock | `status=live bar=drift behind=7 uptodate=2 inputs=10` — a full poll end to end on the branch's code |
| `scenario=error`, fresh instance | `status=error`, `err="aucun input n'a pu être vérifié (amont GitHub injoignable)"`, **`lastCheck=0`**, **`inputs=10`** |
| then switched to a mock that answers | `status=live bar=drift behind=9 uptodate=1`, `lastCheck` stamped |

That settles three things the plan had down as manual:

- **#7 itself.** A poll that verified nothing reports `error`, names the cause, and does not
  touch `lastCheck`. Before this branch it reported `live` with a refreshed timestamp.
- **Review Focus 3, the first poll after startup.** Each probe run *is* a fresh instance,
  so there is no last known value — and the ten inputs are published anyway, with an
  indeterminate lag. Not an empty card.
- **No latch.** Pointing the service at a working endpoint after the error recovers on the
  next poll. The v0.2.1 defect (a `_busy` that never clears) does not reappear.

`behind=9 uptodate=1` against the drift mock matches the owner's own bar exactly, which is a
useful cross-check that the mock and the live widget agree.

### What still needs eyes, and why

**The cockpit's appearance on this branch.** `pragma ComponentBehavior: Bound` and the
`width`/`height` → `implicitWidth`/`implicitHeight` changes are visual by nature; a probe
reports state, not pixels. The owner sent a screenshot of a healthy cockpit — all three
cards, the input rows with their dots, channel chips and right-aligned lag — but it could not
be confirmed which checkout produced it, so it is recorded as encouraging rather than as the
check.

Run from **this worktree** (not `main`, whose `src/` the dev bar would otherwise symlink):

```bash
just mock scenario=drift   # one terminal
just dev-bar               # another
```

### Not exercised, and why

| Not exercised | Why |
|---|---|
| `just bless` | No fixture or golden touched; running it could only introduce a diff. |
| A real `nix build` through the closure card | Out of this plan's scope; `Closure.qml` is untouched. |
| CI's own run | Verified locally through `just ci-hermetic`; the workflow change is one step name and one notice line. |

### Gates

- `nix develop --command just ci` → exit 0 at every task boundary and at the close.
  **70 tests**, 0 failed (49 pre-existing + 21 new).
- `just lint` → **0 findings**, down from 721 warning lines, and verified to *fail* on a
  deliberately reintroduced one.
- `just check-manifest` → verified against six deliberate breakages.
- `git diff --name-only main...HEAD | grep tests/golden/` → empty. No golden moved.

---

## Phase 0

**Phase 0 (2026-10-18, `main` @ `14ee1a6`):** `nix develop --command just ci` → **exit 0**,
49 passed / 0 failed. Working tree clean apart from the untracked spec and plan for this work.

`just lint` blind as issue #6 describes, measured with
`nix develop --command just lint 2>&1 | grep -c Warning` **three consecutive times, identical
each run**: **721** warning lines, of which **6** are `Failed to import` (`QtQuick`,
`Quickshell.Io`, `QtQuick.Layouts`, `qs.Common`, `qs.Widgets`, `qs.Modules.Plugins` — every
external import), 2414 output lines, exit 0.

> The chantier-1 branch review asserted 717 and 4 here, and I propagated it. It does not
> reproduce: the "4" is the count from a run that already had `-I` for Qt and Quickshell
> applied. Corrected in `PROCEDURE_PLANS.md`, the issues-pass design, issue #6's comment and
> the project memory. Recorded in the ledger's first ruling.
