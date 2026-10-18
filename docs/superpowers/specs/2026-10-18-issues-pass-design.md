# Design — the issues pass: make the gates guard something

Covers issues #6, #7, #8, #9 and half of #12.

**Date:** 2026-10-18
**Status:** approved by the owner, 2026-10-18

## Intent and why

Nothing here is hurting daily use. All three of the original issues carry the
`weekly-audit` label and were filed by an agent, not by the owner — he had not noticed any
of them, and said so. This is a deliberate quality pass, and the investigation that preceded
it reframed every one of them.

The thread running through it: **noosphere's quality gates announce more than they guard.**
`just lint` claims "no warning tolerated" and exits 0 on 721 of them. `just test` covers the
pure layers thoroughly and the two stateful service objects not at all — and those services
are where both live bugs surfaced. The job is to make each gate guard what it claims, and —
where it genuinely cannot — to say so in the gate itself rather than let a green run imply
otherwise.

## What the investigation found

### #6: the 745-warning backlog does not exist

The issue, and the `TODO.md` entry behind it, assume a large real debt waiting behind the
unresolved imports ("burn down the real backlog this uncovers, file-by-file if needed").
Measured, it decomposes into three layers and the bottom one is small:

| Measurement | Warnings |
|---|---|
| `just lint` as it stands today | **721** (exit 0) |
| with `-I` for Qt's and Quickshell's `qml/` dirs | **353** |
| with DankMaterialShell's `qs.*` modules also resolving | **18** |

So 368 warnings are Qt and Quickshell not being on the import path, another 335 are DMS
types being unknown, and **18 are real**. Per file, once everything resolves:

> **On the 721.** Measured three consecutive times on `main` @ `14ee1a6` with
> `nix develop --command just lint 2>&1 | grep -c Warning`, identical each run: 721 warning
> lines, **6** `Failed to import` (`QtQuick`, `Quickshell.Io`, `QtQuick.Layouts`, `qs.Common`,
> `qs.Widgets`, `qs.Modules.Plugins` — every external import, as one would expect with no
> `-I`), 2414 output lines, exit 0. An earlier draft of this document said 717 and 4, taken
> from the chantier-1 branch review; those figures do not reproduce, and the "4" was the count
> from a run that already had `-I` for Qt and Quickshell. Corrected, and recorded with its
> command so the next reader does not have to trust it.

| File | Before | After |
|---|---|---|
| `ClosureCard.qml` | 141 | **0** warnings (1 `Info`, see below) |
| `Cockpit.qml` | 135 | 7 |
| `NoosphereWidget.qml` | 53 | 7 |
| `Settings.qml` | 20 | **0** |
| `Closure.qml` | 3 | 3 |
| `Noosphere.qml` | 1 | 1 |
| `NoosphereGlyph.qml` | 0 | **0** |

The 18, in full, because the plan should burn down a known list rather than discover one:

- **8 × `[unqualified]`** — unqualified access to outer-scope properties:
  `NoosphereWidget.qml` lines 69, 75, 86 (×2), 97, 98, 99 and `Cockpit.qml` line 335.
- **6 × `[Quick.layout-positioning]`** — `width`/`height` set on layout-managed items in
  `Cockpit.qml` (lines 300, 301, 316, 317, 345, 346). Qt calls this *undefined behaviour*;
  the fix is `implicitWidth`/`implicitHeight` or `Layout.preferredWidth/Height`. These are
  real defects, not style.
- **4 × `[signal-handler-parameters]`** — `QProcess::ExitStatus` not found for the
  `exitStatus` parameter of `onExited` in `Closure.qml` (77, 93, 132) and `Noosphere.qml`
  (189). This one is about a Quickshell type qmllint cannot see, not about our code.

There is also a **19th line**, at `Info:` level rather than `Warning:` —
`Info: src/view/ClosureCard.qml:7:1: Unused import [unused-imports]` — plus one
`Info: Set "pragma ComponentBehavior: Bound" …` hint attached to each of the 8 `unqualified`
warnings. The first draft of this table omitted them.

**The gate blocks on zero *lines*, not zero warnings.** *(My call.)* Caelestia's
`! test -s $lint_out` idiom fails on any surviving output, and that is the right bar: the
unused import is a real (if trivial) finding, and the pragma hints disappear on their own
once the warnings they annotate are fixed. "Zero warnings but some Infos tolerated" would
reintroduce, in miniature, exactly the judgement call this work exists to remove.

A gate that blocks at zero is therefore reachable. "Blocking with a list of tolerated
exceptions" is not the shape of this work.

### #6: DMS cannot be put on the import path with `-I` alone

`qmllint` resolves a module by finding a `qmldir`. **DankMaterialShell ships none** —
verified: no `qmldir` anywhere under its `share/quickshell/dms/`. Its `qs.Common`,
`qs.Widgets` and `qs.Modules.Plugins` are plain directories of `.qml` files that Quickshell
resolves at runtime through its own mechanism, synthesising the module metadata as it starts.
A plain `-I` at the DMS root does nothing, which is what the first measurement above shows.

A throwaway spike confirmed the diagnosis by generating `qmldir` files by hand (one line per
type, `singleton` where the file carries `pragma Singleton`) into a shim tree: every import
resolved and the count fell from 353 to 18. **That spike is not the proposed implementation**
— it reimplements, badly, something that exists upstream.

### #6: the upstream mechanism is Quickshell generating `.qmlls.ini`

Quickshell populates a `.qmlls.ini` placed in a shell root with the import paths it would
itself use. DMS's own `AGENTS.md` names this as the prerequisite for its `make lint-qml`
target ("requires the generated `.qmlls.ini` VFS from `qs -p .`").

`caelestia-dots/shell` does exactly this in CI, and its recipe is worth copying rather than
inventing around:

1. `touch .qmlls.ini`
2. `QT_QPA_PLATFORM=offscreen QML2_IMPORT_PATH=… timeout 2 qs -p .` — run Quickshell for two
   seconds so it fills the file in
3. parse `buildDir` and `importPaths` out of the ini, turn each into a `-I`
4. run `qmllint` with those arguments
5. delete two known-bogus warning classes with `sed` (`… not declared as singleton in qmldir
   but using pragma Singleton [import]`, `PostReloadHook was not found …`)
6. `! test -s $lint_out` — **zero tolerance**; any surviving line fails the job

Caelestia also uses inline `// qmllint disable <category>` / `// qmllint enable <category>`
pairs around individual lines, rather than disabling a category globally. That is the right
tool for the four `signal-handler-parameters` warnings if they prove unfixable.

**The route was verified to work for a plugin, not only for a shell.** Copying DMS's shell
root (~25 MB) into a writable directory, `touch .qmlls.ini`, then
`QT_QPA_PLATFORM=offscreen qs -p <copy>` populates `buildDir` and `importPaths`. Quickshell
writes a VFS under `/run/user/<uid>/quickshell/vfs/<hash>` containing the synthesized
`qs/Common/qmldir`, `qs/Widgets/qmldir` and so on, and **that VFS survives `qs` exiting**.
Feeding `buildDir` plus the `importPaths` to `qmllint` as `-I` reproduces the 18 findings
exactly. Three gotchas the recipe must handle, all measured:

- **`qmllint` exits 0 even with all 18 findings.** The recipe forces the failure itself —
  caelestia's `! test -s` on captured output, or an explicit count. Relying on `qmllint`'s
  exit code is precisely today's bug.
- **`qs -p` exits 255** while still writing a complete VFS. The recipe must not gate on its
  exit code, only on the ini being populated.
- **`buildDir` lives on tmpfs.** Caching `.qmlls.ini` alone will not survive a reboot, so
  either regenerate each run or validate the cached paths still exist.

### #6: a plugin is not a shell, and the ecosystem's answer for plugins is "don't"

Caelestia can run `qs -p .` because it **is** a shell — it owns a shell root. noosphere is a
plugin loaded into DMS's shell root, which lives read-only in the Nix store. There is no
`shell.qml` at the repository root to point `qs` at.

More decisive: the peers that are actually plugins do not lint QML at all.
[`alcxyz/DankDiskUsage`](https://github.com/alcxyz/DankDiskUsage), a third-party DMS
`dankbar-widget` plugin with a Nix flavour much like noosphere's, has a CI that validates
`plugin.json` (required fields, semver, that `component` and `settings` resolve to real local
files), validates `CHANGELOG.md`'s structure against the manifest's version, runs tests if
present, then auto-tags and releases from the manifest's version. **No `qmllint`, no
`qmlformat`, no Quickshell, no DMS dependency.** It guards what is checkable without the
host and leaves the QML to runtime.

A Quickshell configuration guide in the caelestia discussions goes further and states flatly
that qmllint is not usable because Quickshell synthesises `qmldir` at startup.

And noosphere's own sibling `astropath` carries the identical blind gate — `xargs qmllint`
with no `-I`, no DMS input — so there is no in-house precedent either. It did build
`scripts/check-manifest`, which is the manifest-validation idea already present in the house.

**Nobody adds their host as a flake input in order to lint.** Doing it would make noosphere
pin a DMS version for a tooling reason, and `nix flake update` would start moving the host
under the plugin.

### #7 is narrower than written, and needs no DESIGN decision

The issue proposes settling a design question — a new `barState`, or keeping
`connectionStatus === "error"` — and the earlier brainstorm repeated that framing. Reading
`DESIGN.md` closely, the question is already settled there. Its *Secondary states* section
prescribes, for the error case:

> the INPUTS card's edge in red `#f38ba8`, a status row « échec du check · réessayer », the
> bar badge in grey `#6c7086` keeping its last known value.

That is precisely the right rendering for "nothing could be verified": a grey badge holding
the last known number, not a blue all-clear with a fresh timestamp. **No fourth bar state is
needed and the imperative colour-mapping table does not move.** The defect is narrower than
the issue suggests: a poll where every comparable input ended indeterminate still reaches
`_commit()` and flips `connectionStatus` to `"live"`. Making it stay `"error"` is making the
code match `DESIGN.md`, not changing `DESIGN.md`.

Exposure is low and that is relevant to effort, not to whether it is a defect: the owner runs
a GitHub token on both machines (so the 60 req/h rate limit, and the 403 that would trip
this, never occur) and reports no network trouble. Reaching the bug takes every one of a
poll's ~15 requests failing non-fatally.

### #8: there is no seam — and worse, there is no runner

Two problems, and the second is the one that decides the shape of this work. Both measured.

**No seam.** `src/view/Noosphere.qml`'s `_ghGet` calls `new XMLHttpRequest()` inline, so the
poll driver cannot be exercised without real HTTP. That is why every invariant its own
comments assert — one request in flight at a time, a response attributed to the input that
asked for it, an aborted request's callback never firing, the watchdog recovering a stuck
step — is verified only by hand today.

**No runner.** An earlier draft of this design assumed that injecting a transport factory
would be enough and that a `tst_*.qml` could then drive the service. It cannot:

- **`qmltestrunner` cannot load `Noosphere.qml` at all.** Quickshell's QML modules ship only
  `qmldir`, `.qmltypes` and `.qml` — no plugin library. Its `qmldir` carries
  `linktarget quickshell-ioplugin`, i.e. the types are linked into the `quickshell` binary
  itself. A probe importing `Quickshell.Io` under `qmltestrunner` fails at compile:
  `module "Quickshell.Io" plugin "quickshell-ioplugin" not found`. `Noosphere.qml` imports
  `Quickshell.Io` and declares `property Process metaProc`, so no test under today's
  `just test` can instantiate it.
- **Under the `quickshell` binary, QtTest assertions are inert.** `TestCase` loads and its
  functions run, but a failing `compare(1, 2)` printed nothing and the process exited **0**.
  `Qt.exit(3)` does propagate, so a runner is buildable by hand — but `TestCase` itself
  fails nothing without `qmltestrunner` driving it.

So a transport factory alone buys a seam with nothing on the other side of it. This is the
finding that moved #8 from a side commit to the centre of the work.

**`Closure.qml` is a different shape** and stays out: its orchestration drives declarative
Quickshell `Process` objects, which cannot be substituted the same cheap way, and its
parsing is already pure and golden-tested in `src/model/closure.js`.

### #12 splits in two, and half of it belongs here

Its `connectionStatus` half is the same sentence #7 edits: `DESIGN.md` invariant 7 enumerates
`live | polling | error` while `src/view/Noosphere.qml` also uses `idle`. Whoever fixes #7 is
editing that enumeration anyway. Its other half — five exported functions missing from the
Implementation listing — is unrelated and stays in #12.

## Goals

1. **`just lint` guards the QML it claims to guard, and blocks at zero warnings**, with every
   import resolved through the mechanism Quickshell provides rather than a hand-rolled one.
2. **The 18 real warnings are gone**, by fixing the code — not by tolerating categories.
3. **Where a gate cannot guard, the gate says so.** Specifically: CI has no DMS, so CI cannot
   lint QML; it must report that rather than pass quietly.
4. **CI gains the check it can actually run**: `plugin.json` validated, so a manifest that
   drifts out of shape fails before a user installs it.
5. **The poll driver is a pure module with scenario tests under the existing runner**,
   covering at minimum a full poll per scenario, a late or aborted response never mutating
   the next input's `behind`, and the watchdog advancing past a stuck step. What stays in
   `Noosphere.qml` is I/O, and the `view` TDD exception shrinks accordingly.
6. **A poll where nothing could be verified no longer reports `uptodate`** — it holds the
   last known state behind an error status, as `DESIGN.md` already prescribes.
7. **The released changelog is coherent**: `cliff.toml` is English before the tag.

## Non-goals

- **Adding DankMaterialShell as a flake input.** Decided against, with the ecosystem
  evidence above: no peer does it, and it would make `nix flake update` move the host under
  the plugin.
- **Any new `barState`, and any change to the imperative colour-mapping table.** #7 does not
  need one. A fourth state would be a DESIGN decision and this plan is not it.
- **Writing to the system.** `nix flake update`, `nixos-rebuild`, `rollback` stay out, per
  invariant 2. Nothing here goes near them.
- **Testing `Closure.qml` end to end.** Its seam is a different and larger problem (fake
  `Process` objects); #8 itself says a handful of scenario-level tests is enough. The
  `Closure` half stays in #8 when the rest closes, or becomes its own issue. *(My call.)*
- **The `qmlformat` vs `qmlfmt` question.** DMS's `AGENTS.md` says "don't use qmlformat"; this
  project's `fmt` gate uses it. Worth an issue, not worth this plan.
- **Declaring `requires_dms` in `plugin.json`.** Adjacent to goal 4 and tempting once a
  manifest check exists, but it is a host-compatibility decision of its own. Out. *(My
  call.)*
- **#12's second half** (five functions missing from `DESIGN.md`'s Implementation listing).
- **i18n and the remaining English pass** — code comments, `Justfile` comments,
  `plugin.json`'s description, UI copy. That is chantier 3.

## Anti-goals

What would make this a failure even if every test passed:

- **A gate that still announces more than it guards.** Replacing "exits 0 on 721 warnings"
  with "blocks, but with `unqualified` and `unresolved-type` suppressed" is the same lie in a
  new costume — and it would suppress exactly the 8 real findings.
- **A second blind gate in CI.** If CI runs a lint step that silently covers less than the
  local one, the project is back where it started, one layer up. CI must either not claim to
  lint QML, or fail.
- **A hand-rolled reimplementation of Quickshell's import-path resolution** surviving into
  the repository. The spike proved the diagnosis; using Quickshell's own mechanism is the
  fix. A bespoke `qmldir` generator would rot the first time DMS reorganises.
- **Making the local gate depend on DMS being installed at a hard-coded store path.** It must
  discover DMS, and degrade with a clear message when it is absent, not fail obscurely.
- **A driver test that needs the network, or that flakes on timing.** A test spawning the
  Python mock and racing a real socket would be worse than no test: a gate that fails at
  random teaches people to ignore it.
- **Trading `uptodate` for a silent `error`.** #7's fix must leave the user able to tell
  "nothing is behind" from "nothing could be checked" — that is invariant 11.

## Constraints

- `DESIGN.md` invariants hold. Invariant 7 (best-effort connection, degrade and never crash)
  and invariant 11 (the display never contradicts itself) are the two #7 answers to.
- Any change to the `query`/`model` **transformations** goes through a fixture and a golden; a
  golden that moves by accident is a hard stop (PROCEDURE_PLANS.md §5). The extracted driver
  is a state machine, not a transformation, and is covered by inline assertions instead — see
  the #8 decision for why, and note that `model/format.js` already sits outside the golden
  discipline on the same grounds. **Every existing golden must stay byte-identical**: the
  extraction moves code, it does not change what `parseMetadata`, `parseCompare`,
  `mergeBehind`, `behindCount` or `barState` compute.
- The `Justfile` stays the only definition of the gates. No second source.
- `just test` must stay hermetic: no network, no spawned server, runnable offscreen.
- English: documents, code comments, commit messages. UI copy stays French in this pass.
- Git delegated, atomic signed commits announced as a series, `--no-ff` integration.
- The GitHub token stays a secret: never in `query`/`model`, never in a fixture or golden.
  **A driver test must not need one** — the fake transport sees the header, not a real token.

## The decisions taken

### The lint gate becomes two gates, both honest

**Local `just lint`** — resolves every import and blocks at zero:

- Discover Quickshell's import path, Qt's, and DMS's shell root; generate the import-path
  configuration by the upstream route (`.qmlls.ini` populated by a short `qs` run), not by
  hand-written `qmldir` files.
- Pass each resulting path as `-I`.
- Filter only the known-bogus classes caelestia filters, and only those; each filter carries
  a comment saying why it exists and what would let it be removed.
- Any surviving warning fails the recipe.
- **If DMS cannot be found, the recipe says so and exits non-zero** rather than silently
  linting less. A developer without DMS installed is not a case this project needs to
  support quietly — the plugin cannot be run there either.

**CI** — does what it can, and says what it cannot:

- Validates `plugin.json`: required fields present, `version` matching semver and matching
  the tag when there is one, `component` and `settings` resolving to files that exist.
  Modelled on `DankDiskUsage`'s check and on astropath's `scripts/check-manifest`.
- Runs `fmt-check` and `test` as today.
- **Does not run the QML lint**, and prints one line stating that DMS is absent so QML is not
  linted here, with a pointer to the local gate. The point is that a green CI run never
  implies the QML was checked.

*(My call on the split, from the evidence: the lint gate's value is at commit time, on a
machine that has DMS — which is also where `pre-commit` runs. Buying CI coverage would cost
a flake input pinning the host, which no peer pays and which `nix flake update` would then
move.)*

### `#7`: the poll keeps its error status when nothing could be verified

A poll in which **every comparable input** ended indeterminate is a failed poll:
`connectionStatus` stays `"error"` with a cause in `errorMessage`, the badge greys and keeps
its last known value, and the INPUTS card shows the error edge and status row — all of which
`DESIGN.md` already specifies and the view already implements for the error case.

"Comparable" is load-bearing: inputs that are not `type == "github"` are never compared
(invariant 4), so a flake made only of non-GitHub inputs must **not** be reported as an
error. The condition is "at least one comparable input existed, and none of them resolved
either way".

**The freshly-read input list is published anyway.** *(My call, answering the builder check —
the first draft said only "holds the last known state", which does not say what becomes of
data that *did* arrive.)* On such a poll `nix flake metadata` **succeeded**: only the GitHub
half failed, so the driver holds new names, locked revisions, channels and lock dates. Those
are published, with `behind` indeterminate, under `connectionStatus === "error"`. Withholding
them would throw away local truth that was actually verified, and `DESIGN.md`'s loading state
already establishes the principle — "the list **not emptied** (we keep the last known
state)".

This also settles the case the "last known value" wording does not cover: **the first poll
after startup**, where there is no last known value. Publishing the list means a first-run
failure shows the real inputs with an unknown lag, an error edge and the retry row — rather
than a grey glyph over an empty INPUTS card, which is what skipping the commit would render.

`barState` is not what greys the badge here — `connectionStatus` is, as `DESIGN.md`'s
*Secondary states* prescribes. With `behind` indeterminate everywhere, `behindCount` is 0 and
`barState` still reads `uptodate`; the error status is what must win in the view. A builder
must check that path actually holds, because it is the difference between the fix working and
the badge going blue again.

`lastCheck` must not advertise a verification that did not happen. *(My call: `lastCheck`
keeps the timestamp of the last **successful** poll. The alternative — refreshing it and
relying on the error status to qualify it — makes two parts of the display disagree, which
invariant 11 forbids.)*

`DESIGN.md` gains the `idle` state in invariant 7's enumeration, closing #12's first half in
the same commit.

**#7's stated acceptance criterion still binds, and the extraction is what makes it
satisfiable.** The issue asks for "`tst_model.qml` gains a case for all-indeterminate inputs
asserting the new (non-`uptodate`) state". Read literally against today's code that is
impossible — `barState([], false)` returns `"uptodate"` by definition and no new bar state is
being added. But once the driver is a pure module (#8), the predicate *is* model-level: the
"at least one comparable input existed and none resolved" condition becomes an exported,
unit-tested function, and the assertion lands in the test file for the driver rather than in
`tst_model.qml` specifically. *(My call: the file name in the AC is not the point; a
unit-tested pure predicate is. #7 closes on that.)*

### `#8`: the poll driver moves out of QML into a pure module

**Owner's decision, 2026-10-18**, chosen over a hand-rolled runner and over narrowing the
issue. The driver's logic — the queue, the cursor, response attribution, the watchdog, the
state transitions — becomes a pure module under `src/model/`. `src/view/Noosphere.qml` keeps
only the I/O it cannot shed: the `Process` objects, the `XMLHttpRequest` calls, the `Timer`.
Scenario tests then run under **`qmltestrunner`**, which already works and already fails
builds, because the module they exercise imports nothing from Quickshell.

```
src/model/poll.js       ← pure driver: queue, cursor, attribution, watchdog, states
src/view/Noosphere.qml  ← I/O only: Process, XMLHttpRequest, Timer
tests/tst_poll.qml      ← scenarios, via the existing runner
```

Two things make this the principled route rather than the expedient one. `PROCEDURE_PLANS.md`
§6 already points at it — "Logic extracted out of QML is testable and gets its test first" —
so the `view` TDD exception shrinks rather than being invoked. And **astropath solved this
exact shape of problem the same way**: its dispatch logic lives in `src/model/service.js`,
pure and unit-tested by `tests/tst_service.qml`, with its own design stating the requirement
as "a pure, unit-tested function in `src/model/service.js`, not new `Process` wiring".

What it costs, named plainly: a **stateful** driver arrives in `model/`, a layer whose
discipline (PROCEDURE_PLANS §5) is fixture-plus-golden. Goldens suit a transformation, not a
state machine. *(My call: the driver's tests are **inline assertions** in
`tests/tst_poll.qml`, not goldens — the same treatment `model/format.js` already gets, and
the same astropath gives `tst_service.qml`. A golden per scenario would freeze an execution
trace, and a trace that changes legitimately on every refactor is the opposite of a hard
stop that means something. §5's golden rule covers the transformations; this is not one.)*

**The transport factory stays**, as the seam for the I/O that remains in QML, and the fake
implements the slice `_ghGet` uses (`open`, `setRequestHeader`, `send`, `abort`,
`onreadystatechange`, `readyState`, `status`, `responseText`). The token keeps travelling in
a header and never reaches an argv.

**Where a scenario starts.** The pure driver is fed `nix flake metadata`'s output as text, so
a test enters where `_onMeta` enters today — with a fixture. That is a complete poll from the
driver's point of view, and `Process` needs no seam of its own. *(My call, answering the
builder check: faking `Process` would buy coverage of Quickshell's process plumbing, which is
not ours to test.)*

Scenarios: a poll ending `drift`, one ending `uptodate`, one rate-limited, one where every
comparable input failed; a late response arriving after its request was aborted and mutating
nothing; a response whose `base_commit.sha` belongs to another input being discarded; the
watchdog firing on a request that never settles.

The `#7` fix is verified through this harness — the all-indeterminate poll is one of these
scenarios. That ordering is why #8 comes before #7.

### The 18 findings are fixed the semantics-neutral way

qmllint attaches `Info: Set "pragma ComponentBehavior: Bound" in order to use IDs from outer
components in nested components` to each of the 8 `unqualified` warnings. That is its
suggested fix, and it is **not** the one to take: the pragma changes delegate ID-binding
semantics at runtime, inside a widget hosted by someone else's shell, and the blast radius
can only be observed on a live DMS instance.

*(My call: plumb `required property` into the delegates instead. More code, mechanical, and
semantically neutral. The anti-goals of this design forbid buying a tidy lint run with a
runtime risk, and that is exactly the trade the pragma offers.)*

The 6 `Quick.layout-positioning` findings take `implicitWidth`/`implicitHeight` or
`Layout.preferredWidth`/`Layout.preferredHeight`, per qmllint's own message. The unused
import goes. For the 4 `signal-handler-parameters`, prefer a real fix; if none exists, an
inline `// qmllint disable signal-handler-parameters` pair around the single handler, with a
comment naming what would let it be removed — never a global category disable.

### `#9`: `cliff.toml` to English, immediately before the tag

Last substantive step before the release commit, so the generated changelog is coherent. The
already-published French sections stay French; the route chosen to preserve them is recorded
in the plan.

### Ordering, and the version

**#6 → #8 → #7 → #9.** #6 first because until the gate guards, nothing added afterwards is
protected from a QML regression. #8 next because it builds the harness that proves #7. #7 on
top of it. #9 last, against the tag.

**Target release: v0.4.0.** One branch, one `--no-ff` merge, one signed tag.
`plugin.json`'s `version` moves with it. *(My call.)*

## What is left to the builder

- **How the local recipe discovers DMS and gets `.qmlls.ini` populated.** The shell root is
  read-only in the Nix store, so the `touch .qmlls.ini` + `qs -p .` recipe needs a writable
  root — `scripts/noosphere-dev` already builds exactly such a tree (a writable config dir
  with `src/` symlinked in as a plugin), so reusing or factoring out that construction is the
  obvious route. Whether the generated configuration is cached between runs or regenerated
  each time is also the builder's call; regenerating is simpler and `qs` costs two seconds.
- **Whether the 4 `signal-handler-parameters` warnings are fixable** by an import, or need
  inline `// qmllint disable signal-handler-parameters` pairs. Prefer a fix; if suppression
  is the answer, it is inline and per-line, never global, and carries a comment.
- **Exactly where the extraction boundary falls.** The driver's logic goes to
  `src/model/poll.js` (name is the builder's too); what remains in `Noosphere.qml` is the
  `Process` objects, the `XMLHttpRequest` calls and the `Timer`. The judgement call is how the
  pure module asks for I/O — a callback interface it is handed, a list of intents the QML
  layer executes, or a step function the QML layer pumps. Any is fine; what matters is that
  `poll.js` imports nothing from Quickshell, holds the whole state machine, and that
  `Noosphere.qml` keeps no decision of its own.
- **The shape of the transport factory** — a `property var` returning a new object, a
  `QtObject` component, or a function property. Any is fine; what matters is that production
  behaviour is unchanged and the test can substitute.
- **Where the fake transport lives** (`tests/` beside `tst_poll.qml`, most likely) and how
  far its API faithfulness goes.
- **Whether `src/model/` is the right home for a stateful module**, or whether it deserves a
  sibling directory. `model/` is what `PROCEDURE_PLANS.md` and astropath's precedent point
  at; a builder who finds the layering misleading may argue otherwise in review, as long as
  the module stays pure and `qmltestrunner`-loadable.
- **The manifest check's implementation** — a Python script like `DankDiskUsage`'s, a port of
  astropath's `scripts/check-manifest`, or a small shell script. The requirement is that a
  drifted `plugin.json` fails `just ci`.
- **The route for preserving the published French changelog sections** when `cliff.toml`
  turns English: freezing the published history at the top of the file, or generating only
  what is new. Both were sketched in #9; pick one and say why.
- **The commit split**, within the rule that docs ship with the code they describe.

## Verification

- `just lint` fails on a deliberately introduced QML warning, and passes at zero otherwise.
  This is the acceptance criterion #6 asks for and the one that proves the gate is no longer
  decorative.
- `just ci` fails on a deliberately broken `plugin.json` (missing field, bad semver,
  `component` pointing nowhere).
- The 18 warnings are gone, measured by the same command that found them.
- New `tst_poll.qml` exercising the extracted driver **under `qmltestrunner`** — the runner
  that already works and already fails builds: a poll per scenario, the abort and attribution
  cases, the watchdog. No network, no spawned server, nothing imported from Quickshell.
- A probe confirming the inverse of the finding that shaped this work: a test importing
  `Quickshell.Io` must still fail under `qmltestrunner`, and `tst_poll.qml` must not import
  it. If the driver module ever acquires such an import, the suite silently stops running —
  so the test file's imports are themselves worth an assertion in review.
- A regression test for #7 that fails before the fix: every comparable input indeterminate →
  the all-indeterminate predicate true, `connectionStatus === "error"`, `lastCheck`
  unchanged, and the freshly-parsed input list still published with `behind` indeterminate.
- Existing drift / uptodate / rebuilding golden cases unaffected; any golden movement is a
  hard stop.
- `just changelog` after `cliff.toml` turns English leaves the published French sections
  intact; the diff is read.
- Manual, in the plan's verification steps: the badge actually grey with the network cut
  mid-poll, and a re-check afterwards recovering; the cockpit's INPUTS card showing the error
  edge and status row in that state; the `Cockpit.qml` layout fixes not shifting anything
  visually.
