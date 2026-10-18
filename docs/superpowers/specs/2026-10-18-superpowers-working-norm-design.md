# Design — noosphere's working norm moves to superpowers, and the project goes English

**Date:** 2026-10-18
**Status:** approved by the owner, 2026-10-18

## Intent and why

noosphere has been built under a house process written for this repository alone:
`PROCEDURE_PLANS.md` (plan first, phase-0 audit, atomic commits, goldens, a plan template)
plus a git policy that forbade the agent from running `merge`, `push` or `tag`, and a
document tree under `.claude/plans/v{X.Y.Z}/`.

That process shipped four versions (v0.1.0 → v0.3.0). Two things changed. The agent is
more capable than when the rules were written, so a policy built around withholding git
from it now costs more than it catches. And the project would rather conform to a
**shared, published standard** — the superpowers skill set — than keep maintaining a
bespoke one. The bar goes up, and it goes up by adopting someone else's bar instead of
inventing more local rules.

The sibling project **astropath** made exactly this move on 2026-10-17
(`../astropath/docs/superpowers/specs/2026-10-17-superpowers-working-norm-design.md`).
This design follows it deliberately, so the two repositories are worked the same way — and
it names the one place where noosphere diverges on purpose: **the language rule**.

Second, independent decision taken in the same conversation: **English becomes
noosphere's default language, for the software and not only for its documentation.**
French is not dropped; it becomes one locale of two, if internationalisation turns out to
be workable in a hot-loaded DMS plugin. That is a larger piece of work and it is *not*
this one — but the documents being rewritten here ship in English immediately, `DESIGN.md`
included, because it is the document that outranks everything and every reader reaches it
first.

## Goals

1. **Superpowers is the process of record.** Brainstorm → written design → plan →
   execution → review → integration, with its skills invoked as they prescribe and its
   document layout adopted as-is.
2. **Autonomy by default, the owner as arbiter.** The agent runs a plan end to end without
   asking permission per step. It stops when there is something to *decide*: a design
   choice that changes what gets built, an ambiguity in the spec, friction against a
   `DESIGN.md` invariant, a surprise that invalidates the plan.

   Superpowers' own mandatory human waits are kept, because each is a decision and not a
   step approval: the brainstorming gate (nothing is built before the design is approved),
   the plan review at the end of `writing-plans`, and the choice of execution method. What
   goes away is the old per-task approval stop.
3. **Git is delegated.** The agent may run every git command, `merge`, `push` and `tag`
   included.
4. **Subagents are free.** Independent code review, the brainstorming builder check,
   research, parallel exploration: dispatched without asking.
5. **One document per piece of work.** The plan carries its own verification, including the
   manual verification `just ci` cannot cover.
6. **English is the project's default language**, stated as a rule in
   `PROCEDURE_PLANS.md`, with the UI switch and EN/FR internationalisation named as their
   own future plan rather than left implicit.
7. **`DESIGN.md`, `PROCEDURE_PLANS.md` and `CLAUDE.md` are in English** at the end of this
   work.
8. **GitHub Issues is noosphere's only backlog.** No second list in the repository.
9. **The project's invariants keep the last word.** `DESIGN.md` outranks any skill.

## Non-goals

- **Rewriting or renaming the four existing `.claude/plans/v0.x/` directories.** They
  describe shipped versions and are frozen as read-only history. Several restate the
  superseded process ("Claude ne fait jamais `merge`/`push`/`tag`"); that text stays as it
  is, in French, and `PROCEDURE_PLANS.md` carries the one line declaring the directory
  historical. They are **not** translated.
- **Translating `CHANGELOG.md`.** Its published sections describe French commits;
  rewriting them would be a retroactive lie. This was already decided in
  `.claude/plans/TODO.md` and the decision survives the file that recorded it. The
  changelog is bilingual by construction, cut at the first version following the switch.
- **Translating `cliff.toml`, the code comments, the `Justfile` comments, the
  `plugin.json` description, or any UI string.** None of it belongs to this work.
  `cliff.toml` goes to the issues pass (chantier 2, owner's decision — see below); the rest
  goes to the English/i18n pass.
- **Any `src/` or `tests/` change.** The goldens cannot move; this work ships documents,
  `.gitignore` and memory files.
- **Changing `DESIGN.md`'s invariants, the `Justfile` gates, the golden discipline, the
  Nix workflow or the Conventional Commits convention.** `DESIGN.md` changes language, not
  content.
- **Adding release tooling.** `git-cliff`, Renovate, the CI and release workflows already
  exist and are untouched — except for the one `README.md` sentence that describes the tag
  as the maintainer's job under the hybrid policy, which is now false.
- **Changing the owner's machine configuration.** `gpg-agent`'s cache TTL is left at its
  default, and `git merge` / `git push` are deliberately **not** added to
  `.claude/settings.local.json`'s allowlist — the permission prompt *is* the announce step,
  so suppressing it would remove the one place the owner sees an integration coming.

## Anti-goals

What would make this a failure even if every file lands correctly:

- **Two parallel process documents.** If `PROCEDURE_PLANS.md` still describes a planning
  workflow after this change, the repository has two norms and the agent follows whichever
  it read last. It must end up strictly complementary to superpowers, never overlapping it.
- **Two parallel document trees.** Nothing new lands under `.claude/plans/`.
- **Two parallel backlogs.** `TODO.md` disappearing while part of its content survives
  nowhere is as bad as keeping it: the repository would look like it has no backlog while
  decisions quietly live in a deleted file's git history.
- **Autonomy read as "do not consult".** Fewer stops is not fewer questions. An unasked
  question that becomes a wrong guess is the exact failure this change must not buy.
- **Stale memories steering the agent.** Two stored memories encode the superseded rules
  (hybrid git; "the rest of the repository stays in French"). If they survive, a future
  session reapplies the old norm — and the language memory would directly contradict the
  new rule.
- **A half-translated `DESIGN.md`.** A document that mixes English prose with untranslated
  French sections is worse than the French original: the reader cannot tell what is a
  deliberate French literal from what nobody got round to.
- **Translating the French UI strings that `DESIGN.md` quotes.** They are literals of code
  that still exists. `DESIGN.md` must keep describing the UI that is actually there.

## Constraints

- **Language, from this work onward.** Repository documents, code comments and commit
  messages in **English**. UI copy is *currently* French and stays French until the
  English/i18n plan lands; it is quoted as a literal, never silently translated as a side
  effect of another change.
- **Nix.** Non-interactive commands run as `nix develop --command …`.
- **Gates.** `just ci` (`fmt-check` + `lint` + `test`) is the single definition, called by
  pre-commit and CI. It is never duplicated as a second source — a list in `CLAUDE.md`,
  `README.md` or `PROCEDURE_PLANS.md` is a convenience copy of the `Justfile`.
- **Signing.** Commits and tags are GPG-signed. The global git config already resolves to
  `guillaume@friloux.me` with `commit.gpgsign` and `tag.gpgsign` true and
  `user.signingkey=52381C92A5071464F3160D257D4216D8BDDA9A09`; every local commit in recent
  history verifies (`%G?` = `G`). **No local `user.email` override is needed** — unlike
  astropath, which carries one. The passphrase is the owner's to type.

  One caveat for whoever reads `git log --show-signature` later: `900c54b` reports `E`
  (unverifiable) because it is GitHub's own web merge of a Renovate PR, signed by a key
  absent from the local keyring. That is not a project defect, and this norm does not make
  it one — but a PR merged through GitHub's UI will keep producing such commits, which is a
  further reason for integrations to run locally under `--no-ff`.
- **The `lint` gate is currently blind** (issue #6: `qmllint` with no `-I`, exits 0 on 745
  warnings). A green `just ci` on this work therefore proves little about QML — which is
  irrelevant here, since no QML is touched, and is the first thing the next chantier fixes.
- **Live testing cannot be automated.** QML rendering, Wayland, a real DMS instance, real
  `nix`/GitHub timing. `just dev-bar` takes `justfile_directory()` and symlinks `src/`
  live, so it works from a git worktree; `just mock` serves the GitHub compare API with no
  network.
- **Determinism.** Any change to `query`/`model` goes through a fixture and a golden. A
  golden that moves by accident is a hard stop.

## The decisions taken

### Document layout

Canonical superpowers paths, committed:

```
docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md    ← designs (brainstorming output)
docs/superpowers/plans/YYYY-MM-DD-<feature>.md         ← plans (writing-plans output)
.claude/plans/                                         ← frozen archive, v0.1.0 … v0.3.0
.superpowers/                                          ← agent scratch, git-ignored (fixed below)
tmp/                                                   ← scratch, git-ignored
```

Spec and plan filenames are dated, per superpowers. The version a plan ships (`v0.4.0`, …)
belongs in the plan's **Goal** line, not in its filename: a release is a property of the
work, not of the document tree.

An obsolete spec or plan is **deleted**, never kept beside its replacement — the dated
filename makes a stale document look like history instead of the duplicate it is. This
carries over the existing rule ("un plan obsolète est supprimé, pas dupliqué en `_v2`").

### `manual_tests.md` and `phase0_results.md` disappear as files

Both fold into the plan document, which is where superpowers puts verification:

- **The phase-0 audit** becomes the plan's first step: run `nix develop --command just ci`
  on an up-to-date `main`, record the result on one line in the plan. Its purpose — never
  assume the tree is clean — is preserved; its separate file is not.
- **Manual tests** become verification steps inside the task they validate, in superpowers'
  step style: the command to run, the result that means it passed, a `- [ ]` checkbox.
- **The closing run** gets a final `## Manual validation` section in the plan: the date,
  which boxes were exercised, and which were not and why. The v0.3.0 plan already recorded
  exactly this, and that record is worth keeping.

### Git policy

Replaces `PROCEDURE_PLANS.md` §3's "Claude ne fait **jamais** `merge`/`push`/`tag`".

- Work happens on a dedicated branch (`feat/`, `fix/`, `chore/`, `refactor/`, `docs/`),
  never directly on `main`.
- Atomic commits, Conventional Commits form, each passing the gates on its own, docs in the
  same commit as the code they describe.
- The agent **announces a commit series before running it** ("I'm about to commit steps
  1–6"), so the passphrase is typed once and `gpg-agent`'s cache carries the burst.
- The agent may `merge`, `push` and `tag`. Integration follows
  `superpowers:finishing-a-development-branch`: the agent names the integration it is about
  to perform, then performs it. The signed merge commit asks for the passphrase, and that
  prompt is the natural stop — the owner sees every integration arrive without the agent
  having to hold a menu open.
- **Merge form: `git merge --no-ff`.** Always a merge commit, so a plan's branch stays
  legible and its closure is one point in the log. This matches noosphere's existing history
  (`Merge branch 'refactor/v0.3.0-xhr-transport'`).
- A finished branch is never left unmerged: every plan starts from an up-to-date `main`.
- **The `Co-Authored-By: Claude …` trailer stays, and the rewritten `PROCEDURE_PLANS.md`
  says so.** It is present in 13 of the last 20 commits, but it is recorded as a live
  convention *only* in the two memories this work deletes — so it would vanish from the
  norm by omission, which is not the same as being dropped on purpose. astropath's
  rewritten equivalent does not mention it; that is a gap there, not a precedent to copy.
  *(My call: keep it. The history is unambiguous and attribution in a public repository is
  worth being explicit about. Trivially reversible if the owner would rather drop it.)*
- **Release tagging moves to the agent too.** `README.md` §Release currently says the tag
  is created by the maintainer "(hybrid git policy)". That parenthesis is removed and the
  sequence becomes the agent's, the passphrase prompt being the owner's stop. *(My call,
  derived from goal 3 — the alternative, delegating `merge` and `push` but withholding
  `tag`, is a distinction with no rationale behind it.)*

### Execution method: native by default

`superpowers:writing-plans` offers subagent-driven or native execution. This repository
defaults to **native** (the session implements the plan itself), because the
announce-a-series-then-one-passphrase rule depends on commits arriving from one context in
one burst; under subagent-driven development they arrive from several contexts at
unpredictable times and each stops on a passphrase prompt. Subagents stay free for what
does not commit: independent review, the builder check, research, parallel exploration. A
plan whose tasks are genuinely independent can still opt into subagent-driven execution —
a decision taken at the plan review, with the passphrase cost named out loud.

### Worktrees

A plan executes in an isolated worktree, per `superpowers:using-git-worktrees`. Compatible
with live testing: `just dev-bar` loads whichever worktree it is invoked from. Its isolated
state root is single, so **one dev bar at a time** across worktrees; `just mock` binds a
port (8385 by default), so likewise **one mock at a time** unless the port is overridden.
No change to `scripts/noosphere-dev`.

### Test-driven development, and the `view` exception

`superpowers:test-driven-development` applies wherever a test can express the change:

- **`query` / `model` — fully.** Fixture + golden first (RED), then implementation (GREEN).
  This is the existing discipline and it already satisfies TDD.
- **`view` (QML) — partially.** Logic extracted out of QML is testable and gets its test
  first. Rendering, live settings and a real DMS instance are not. There, the "failing
  test" step is replaced by a **manual verification step written before the
  implementation**: the plan states what to look at and what the right outcome is, before
  the code exists. TDD's intent — the expected result is decided before the implementation
  — is kept; only the automation is unavailable.

This exception is narrow and decided. It is not a licence to skip tests anywhere a test
could have been written. Note that noosphere's `view` layer is where its two live bugs sit
(#7, #8), so the exception is also the thing the next chantier pushes back against.

### The language rule — where noosphere diverges from astropath

astropath's rule is "English docs, French UI". **noosphere's rule is different and must not
be copied from it:**

> English is noosphere's default language — documents, code comments, commit messages, and
> the software's own copy. The UI is French today and stays French until the English/i18n
> plan lands; French then becomes one locale of two, if EN/FR internationalisation proves
> workable in a hot-loaded DMS plugin.

The rule is written in `PROCEDURE_PLANS.md`, in that form, with the future plan named. A
builder reading astropath's `PROCEDURE_PLANS.md` for guidance will find the opposite rule;
the divergence is therefore stated explicitly rather than left to be inferred.

**The rule binds GitHub Issues too**, now that Issues is the only backlog and therefore part
of the project's written record: issue titles, bodies, comments and PR descriptions are
English. The three existing issues already are. *(My call, with one carve-out below.)*

**Carve-out: a measurement is evidence, not prose.** The French measurements carried out of
`TODO.md` into #6 and #7 are reproduced as **verbatim quoted French blocks** under English
framing, not translated. Translating a measured finding is the one place where a wording
slip rewrites the record instead of the prose around it, and the numbers are the reason the
comment is worth writing at all.

### What this work translates, and what it does not

**Translated now:** `DESIGN.md`, `PROCEDURE_PLANS.md`, `CLAUDE.md`. `README.md` is
*already* English and only needs its facts corrected (below).

**Not translated now:** `CHANGELOG.md` (never), `cliff.toml`, code and `Justfile` comments,
`plugin.json`'s description, UI strings, and the frozen `.claude/plans/` archive.

`DESIGN.md` is a **translation, not a revision.** Its invariants, its numbering, its colour
table, its visual system and its structure are preserved; only the language changes. Two
consequences the builder must honour:

- **The classification rule is mechanical: a quoted string that appears verbatim in `src/`
  stays a French literal; everything else is prose and translates.** *(My call. It is the
  only rule that can be checked rather than judged, and it follows from why the exception
  exists at all — `DESIGN.md` must describe the UI that is actually there.)*

  Stays French, verified present in `src/`: «&nbsp;N commits en retard&nbsp;»
  (`src/model/format.js`), «&nbsp;INPUTS&nbsp;» (`src/view/Cockpit.qml`),
  «&nbsp;DIFF DE CLOSURE&nbsp;», «&nbsp;prévisualiser la mise à jour&nbsp;»,
  «&nbsp;aucun input en retard&nbsp;» (`src/view/ClosureCard.qml`), «&nbsp;échec du check ·
  réessayer&nbsp;» (`src/view/Cockpit.qml`).

  **Translates, because the copy does not exist yet:** «&nbsp;Tout mettre à jour&nbsp;»,
  «&nbsp;voir les N changements&nbsp;», «&nbsp;update&nbsp;» — the update/rebuild roadmap's
  prescribed labels, absent from `src/` (verified). *(My call. The preservation rule exists
  to stop `DESIGN.md` describing a UI that is not there; it has nothing to preserve where
  there is no code. The owner's rule is that English is the software's default language, so
  copy specified for UI that does not exist yet is specified in English. This does not
  pre-empt chantier 3: that plan decides what happens to strings that **exist**, and
  whether EN/FR becomes a translation layer. If the owner would rather `DESIGN.md` reserve
  no language at all for unbuilt copy, the fix is one sentence.)*

- **`EN-TÊTE` is not a UI literal and must not be treated as one.** It appears only in two
  `src/view/Cockpit.qml` code comments and inside one `src/view/Settings.qml` description
  string — the cockpit's first card renders no such title. An earlier draft of this design
  listed it beside `INPUTS`; that was wrong. The card is referred to in English (the
  *header* card), and the day its title is actually rendered is chantier 3's business.
- **A short note in the visual-system section** records that the remaining French literals
  are French *pending* the English/i18n plan, so a reader does not take them for a
  translation that was missed.

The domain vocabulary translates: *dérive* → **drift**, *amont* → **upstream**, *retard* →
**behind**, *verrou* → **lock**, *input en retard* → **input behind**. The Adeptus
Mechanicus section translates as prose; *noosphère* stays **noosphere**.

### The owner reads the translated `DESIGN.md` before it is merged

**Owner's decision, 2026-10-18.** `DESIGN.md` outranks every skill, and the verification
this design otherwise specifies for it is entirely mechanical — a French-word grep, "still
eleven invariants in the same order", "the same hex values". None of that catches a
faithful-looking mistranslation that quietly narrows an invariant. So the autonomy granted
in goal 2 **stops here**: this is a decision point, not a step approval.

Consequences for the plan:

- The plan **ends on a stop** for the owner's reading of `DESIGN.md`. The rest of the work
  may be committed before it, but nothing is merged to `main` until the reading is done.
- The plan produces, as a reviewable artifact, a **clause-by-clause FR↔EN correspondence
  table** — each invariant, each visual-system rule, each normative sentence, old beside
  new — built against `git show HEAD:DESIGN.md`. The point is that the owner checks one
  document instead of diffing two in parallel.
- That table is **scratch, not a deliverable**: it lands in `tmp/` (git-ignored), because
  its whole purpose expires the moment the translation is approved. A correspondence table
  committed next to `DESIGN.md` would become a second, rotting description of the
  invariants — precisely the anti-goal this design opens with. *(My call.)*
- An independent fidelity review by subagents runs **in addition**, before the owner's
  reading, so that what reaches the owner has already had its obvious slips removed. The
  owner's reading is the gate; the subagents are there to make it cheap.

### The backlog

**GitHub Issues becomes noosphere's only backlog, and `.claude/plans/TODO.md` is deleted.**

What the file currently holds, and where each item goes:

| Entry | Destination |
|---|---|
| "Réparer la porte `lint`" | Already issue **#6**. Its measurements (745 warnings, the per-file split, the root cause) are richer than the issue's and must be **carried into #6 as a comment** before the file dies. |
| "Un poll où *tout* échoue finit quand même en vert" | Already issue **#7**. Same: the mock measurement (`scenario=error` → `status=live`, `bar=uptodate`) goes into #7 as a comment. |
| "Passer `cliff.toml` en anglais" | Its own issue, scheduled in the **issues pass** (chantier 2), to be done just before that version is tagged — **owner's decision, 2026-10-18**. Its subtlety must survive into the issue body: `just changelog` regenerates the whole file, so the already-published French sections have to be preserved rather than re-emitted under English headers. |
| "Requêtes conditionnelles `If-None-Match` / `ETag`" | New issue. `DESIGN.md`'s future-caps table keeps the reasoning; the issue is the tracking entry. |
| "Paralléliser les compare GitHub" | New issue, same arrangement. |

*(My call: the last two become issues even though `DESIGN.md` already documents them. Goal
8 says one backlog, and a cap recorded only inside a design document is not on a backlog —
it is a footnote in a specification. `DESIGN.md` stays their rationale; the issue is their
tracking entry, and the issue links to the table rather than restating it.)*

**Deleting `TODO.md` is the last step of the sequence, not the first.** Three issue
comments and three new issues exist before the file goes, so the content never has a window
where its only home is git history.

### `README.md` corrections

The file is already English. Three facts in it become false with this change, plus one
pre-existing staleness worth fixing while the file is open:

- The note "The widget's UI and the project documentation are in **French**" — now wrong
  about the documentation. Rewritten to state the rule: documentation and the project's
  default language are English; the UI copy is French pending the i18n plan.
- The code-structure block's `.claude/plans/` line — replaced by the superpowers tree, with
  `.claude/plans/` named as the frozen archive.
- §Release's "created by the **maintainer** (hybrid git policy)" — now wrong per the git
  decision above.
- §Status says **v0.2.0** while `plugin.json` is at `0.3.0` and the changelog has a v0.3.0
  section. *(My call: fixed in passing — it is a factual error in a section this work
  already rewrites, and leaving a known-false version in the README to respect a scope
  boundary serves nobody. The fix is the version line and the XHR transport, not a rewrite
  of the section.)*

### Agent scratch must actually be ignored

`.superpowers/` is **not** in noosphere's `.gitignore` (verified: the file ignores
`/result*`, `.direnv`, `.envrc`, `tmp/`, `.claude/settings.local.json`,
`.claude/worktrees/`, `*.qmlc`, `*.jsc` — and nothing else). The directory does not exist
yet, so nothing leaks today; but this norm makes worktree execution the default, and the
first worktree would start with unignored agent scratch.

Fix: add `.superpowers/` to the root `.gitignore`, next to `tmp/`, with a comment
explaining that the rule lives at the root rather than only in `.superpowers/sdd/.gitignore`
— the latter is created by the tooling, covers only `sdd/`, and does not exist before the
tooling's first run (which is precisely what bit astropath). The `.claude/` comment is
updated too: it currently says "les plans, eux, sont versionnés", which stays true but now
means "frozen archive".

### Stored memories

Two memories encode the superseded norm and must be corrected as part of this work, or the
next session reapplies the old rules. They live outside the repository
(`~/.claude/projects/-home-kuri-Apps-github-gfriloux-noosphere/memory/`) and are not in git,
so the repo diff cannot verify them — see Verification.

- **`git-hybrid-noosphere.md`** — "Claude commite sur branche dédiée ; l'utilisateur
  merge/tag/push". The **slug itself is the stale signal**, since `MEMORY.md`'s index is
  what a future session reads first. So: delete the file and its index line, and write a
  new memory under a name that states the live rule (e.g. `git-delegated-announce-series`)
  saying git is delegated, a commit series is announced so the passphrase is typed once,
  the merge form is `--no-ff`, and the agent stops for decisions rather than for steps.
- **`commits-en-anglais.md`** — "les messages de commit s'écrivent en anglais, le reste du
  dépôt reste en français". The second half is now false and directly contradicts the new
  rule. Same treatment as above: the slug misleads, so the file is replaced by one naming
  the live rule (e.g. `anglais-par-defaut`), covering English as the default for docs, code
  comments, commit messages and the software's own copy, the UI being French pending the
  i18n plan, and the published changelog staying French.
- **`noosphere-status.md`** — edited in place. It says v0.3.0 is "finie sur branche, à
  merger" (it is merged, `c276038`), calls the lint gate blind (still true, now issue #6)
  and carries a roadmap. It also needs the new document tree and the fact that GitHub
  Issues is the backlog.
- **A new memory** records that noosphere and astropath are worked under the same
  superpowers norm **but diverge on the language rule**, so a future session does not copy
  astropath's "French UI" rule into noosphere.
- `annonce-avancement-investigations.md` and `observer-quickshell-en-vol.md` stay as they
  are.

Memory bodies **stay in French**, like every other memory in that directory. The
English-only rule covers repository documents, code comments and commit messages; these
files are not in the repository. *(My call, consistent with astropath's.)*

### `CLAUDE.md` and `PROCEDURE_PLANS.md` after the change

`PROCEDURE_PLANS.md` stays — `CLAUDE.md` points at it and the pointer is worth keeping —
but it is rewritten in English to hold only what superpowers cannot know:

- a table mapping each process step to its skill and its artifact;
- when the agent stops (decisions, not steps), and which superpowers gates survive;
- git: branch, atomic commits, signing, announce-a-series, `--no-ff`, delegation;
- the gates, with the `Justfile` as their single definition;
- the golden discipline on `query`/`model`, `just bless`, and the change-type table;
- TDD and the narrow `view` exception;
- what is not automatable and therefore lands as manual verification in the plan;
- the worktree / dev-bar / mock constraints (one at a time);
- Nix as the entry point for every command;
- the language rule, in noosphere's form, with the divergence from astropath named;
- one line declaring `.claude/plans/` a frozen archive of v0.1.0 … v0.3.0 whose contents
  describe the process then in force and bind nothing now;
- one line declaring GitHub Issues the only backlog;
- a pointer to superpowers for everything else, naming the skills by name.

Everything it currently says about writing plans, phases, plan templates and the plan
directory goes away, replaced by that pointer.

`CLAUDE.md` is updated in the same commit: its "read `DESIGN.md` then
`PROCEDURE_PLANS.md`, on ne code pas sans plan validé" header becomes "read `DESIGN.md` —
it outranks every skill; the process is superpowers; `PROCEDURE_PLANS.md` holds this
project's specifics", in English, with the guardrails section corrected for the git and
language decisions and the structure block showing the new tree.

### Bootstrap: this change ships under the new norm

This work executes the way it describes: isolated worktree, dated plan under
`docs/superpowers/plans/`, atomic signed commits announced as a series, then the agent
merges `--no-ff` and pushes `main`. **Approving this design is what authorises that first
integration.** *(My call, following astropath's precedent; the alternative — shipping the
new norm under the old one — would leave the norm untested at the moment it takes effect.)*

The three chantiers agreed with the owner, in order:

1. **This one** — the norm migration, plus `DESIGN.md`/`PROCEDURE_PLANS.md`/`CLAUDE.md` in
   English.
2. **The issues pass** — #6 (blind `lint` gate), #7 (all-indeterminate poll reports
   `uptodate`; needs a `DESIGN.md` decision, since the bar-state colour mapping is
   normative), #8 (no automated coverage of the `Noosphere`/`Closure` service drivers),
   **plus `cliff.toml` to English** just before that version is tagged. Its own brainstorm
   and design.
3. **English + EN/FR i18n** — code comments, `Justfile` comments, `plugin.json`'s
   description, and the cockpit's copy. Its own brainstorm and design, and it must first
   establish whether `qsTr` / Qt Linguist are usable in a hot-loaded DMS plugin, because the
   answer decides whether EN/FR is a translation layer or a hard switch to English.

**Why `cliff.toml` moved to chantier 2 (owner's decision, 2026-10-18):** chantier 2 ships a
version, and `just changelog` regenerates `CHANGELOG.md` entirely from `cliff.toml`. Left
until chantier 3, that release would emit French group headers (`Fonctionnalités`,
`Corrections`) over English commit titles. Translating `cliff.toml` inside chantier 2,
immediately before the tag, is what keeps the released changelog coherent. The already
published French sections still stay French — the cut is at the first version following the
switch, exactly as `TODO.md` had reserved it.

## What is left to the builder

- **The exact wording and section order of the rewritten `PROCEDURE_PLANS.md`**, as long as
  it covers the list above and describes no planning process of its own.
- **The English wording of `DESIGN.md`**, within the translation-not-revision constraint.
  Where the French is ambiguous, the builder picks the reading that matches the code and
  says so in the commit message.
- **The commit split**, within the rule that docs ship with what they describe. A
  reasonable shape is: the document tree and `.gitignore`; `DESIGN.md`'s translation;
  `PROCEDURE_PLANS.md` + `CLAUDE.md`; `README.md`'s corrections; the backlog migration;
  the memories. The builder may merge or split these.
- **The exact issue titles and bodies** for the three new issues, and the wording of the
  two comments carried into #6 and #7.
- **Whether the new memories are two files or three**, and their slugs.

## Verification

This work ships documents, `.gitignore`, GitHub issues and memory files. No `src/` or
`tests/` file is touched, so the goldens cannot move.

- `nix develop --command just ci` green before (phase 0) and after. It does not read these
  documents, but a green run is the proof nothing leaked into the code. Its `lint` leg is
  known-blind (#6); that is recorded, not relied on.
- `git diff --stat` shows changes confined to `CLAUDE.md`, `PROCEDURE_PLANS.md`,
  `DESIGN.md`, `README.md`, `.gitignore`, `docs/superpowers/`, and the deletion of
  `.claude/plans/TODO.md`. **A diff touching `src/` or `tests/` is a hard stop.**
- `git check-ignore -v .superpowers/sdd/x`, run from a **freshly created worktree**, reports
  the root `.gitignore` as the matching rule. This is the check that proves the scratch leak
  is closed where it would actually leak.
- `grep -rniE 'jamais|toujours|le token|la couche|dérive|plan validé' DESIGN.md
  PROCEDURE_PLANS.md CLAUDE.md` returns nothing. This is the mechanical check against a
  half-translated document, and the classification rule above is what makes its expected
  output empty rather than a judgement call.
- Every French string still quoted in `DESIGN.md` is verified present in `src/`: for each
  one, `grep -rF '<string>' src/` must hit. A quoted French string with no hit in `src/`
  means either an untranslated fragment or a `DESIGN.md` that describes copy which does not
  exist — both are defects, and this check cannot tell them apart, which is why it fails
  rather than warns.
- `DESIGN.md`'s invariants are still eleven, still in the same order, and the colour table
  still holds the same hex values. A translation that renumbers or drops an invariant is a
  revision, and a revision was a non-goal.
- **The owner has read the translated `DESIGN.md` and said so.** This is a gate, not a
  check: no merge to `main` before it. The subagent fidelity review and the correspondence
  table in `tmp/` are inputs to that reading, never substitutes for it.
- A fresh reader of `CLAUDE.md` reaches the superpowers workflow and finds no second,
  **active** process description in the repository. The frozen `.claude/plans/` archive is
  exempt by construction, and the line declaring it historical is what lets a reader tell.
- `gh issue list` shows #6 and #7 carrying their comments, and the three new issues present,
  before `TODO.md` is deleted.
- The memory directory holds no file telling a future session that git is hybrid or that the
  repository stays in French, and `MEMORY.md`'s index lines match the files present.
