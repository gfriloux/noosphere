# Design — the rest of the repository goes English, and the UI gains EN/FR

Chantier 3 of the three agreed on 2026-10-18. Closes the language migration started by the
superpowers norm change, and takes up #13's `requires_dms` question as a consequence.

**Date:** 2026-10-18
**Status:** the owner opted out of the brainstorming questions ("saute les questions et go"),
so every decision below is mine unless marked otherwise. They are all overridable.

## Intent and why

The owner's position, in his words: *« les logiciels aussi doivent être en anglais par
défaut, et s'il y a de l'internationalisation possible, on fait EN/FR »*. The norm migration
(v0.4.0's predecessor) moved the documents; v0.4.0 moved nothing further. What is left is the
software itself: code comments, the `Justfile`, `plugin.json`'s description, and the cockpit's
copy.

The gating unknown was whether a hot-loaded DMS plugin can be internationalised at all. It
can, and by a first-class upstream API rather than a workaround — which turns "English only,
i18n someday" into "English source strings with a French table" at almost no extra cost.

## What the investigation found

### DMS ships a plugin translation API, and noosphere already imports the module it lives in

`qs.Common/I18n.qml` is a DMS singleton. Read directly from the installed 1.6.2:

| Function | Meaning |
|---|---|
| `trFor(pluginId, term, context, isRealContext)` | look up the plugin's table, then DMS's own, then **return `term` itself** |
| `registerPluginTranslations(pluginId, table)` | stores a table — **called by DMS, not by the plugin** |
| `localeCandidates()` | the locale tags to try, English excluded |

The table's shape is `{ context: { term: translation } }`, with a flattened term index as a
fallback so a context need not be given at every call site.

**The plugin writes no registration code at all.** An earlier draft of this design had the
plugin call `registerPluginTranslations` itself; that was wrong, and reading
`Services/PluginService.qml` settles it. DMS does the loading:

```
<pluginDirectory>/translations/<localeCandidate>.json
```

`PluginService._loadPluginTranslations` walks `I18n.localeCandidates()` in order — for a
French user `fr_FR.json`, then `fr-FR.json`, then `fr.json` — loads the first that exists
through a `FileView`, and calls `registerPluginTranslations` with the parsed JSON. It
re-runs on locale change, and unregisters when the plugin is disabled. Malformed JSON is
logged and unregistered, degrading to English rather than breaking.

Two consequences worth stating plainly:

- **English needs no file.** `localeCandidates()` filters `en` out, so an English locale
  registers nothing and every `trFor` falls through to its source string.
- **The plugin id in `trFor` must match `plugin.json`'s `id` exactly** — DMS keys the table
  by the id it discovered. `"noosphere"` already has to agree between `plugin.json` and
  `Settings.qml`'s `pluginId`; this is a third place.

Three properties make this cheap:

- **The fallback is the source string.** `trFor` ends with `return tr(term, context)`, and
  `tr` ends with `return term`. So English literals wrapped in `trFor` render as English with
  no table registered at all. Translation is additive; nothing breaks while it is incomplete.
- **Locale resolution is DMS's problem, not ours.** `I18n` reads `SessionData.locale`, falls
  back to `Qt.locale().name`, builds candidates (`fr_FR`, `fr-FR`, `fr`) and falls back to
  English. noosphere follows the shell's language setting automatically and has no locale
  preference of its own to add, store, or expose in Settings.
- **No Qt Linguist, no `.ts`, no `.qm`, no `QTranslator`.** The earlier assumption that this
  chantier hinged on `qsTr` and Qt's tooling was wrong. DMS extracts `qsTr()` calls to JSON
  (POEditor format) with its own `translations/extract_translations.py`, and loads JSON at
  runtime. A plugin does not need that pipeline — it needs a table object.

### It raises noosphere's DMS floor, and that is the real cost

DMS **1.5.3 has `Common/I18n.qml` but not `registerPluginTranslations`** — measured: zero
occurrences in the 1.5.3 store path, present in 1.6.2. So the API landed between the two.

noosphere declares no `requires_dms` at all today. Adopting this API means the plugin stops
working on older DMS, silently, unless the floor is declared.

**Decision: adopt the API and declare `requires_dms`.** *(My call.)* The owner's stated
position when the same question arose for astropath was to adopt DMS's evolutions rather than
hold back out of caution; he runs 1.6.2. `requires_dms` is enforced by DMS since v1.2.0 (a
warning banner and install gating) and ignored by anything older, so declaring it is safe at
any floor. This also makes #13's `requires_dms` half concrete instead of hypothetical.

**The floor is `>=1.6.0`, established rather than guessed.** Checked against the upstream
tags: `quickshell/Common/I18n.qml` contains `registerPluginTranslations` at **v1.6.0** and
does not at **v1.5.4** or **v1.5.3**. The locally installed 1.5.3 agrees — it has the file,
without the function. The owner runs 1.6.2.

Note the failure mode on an older host: `I18n.trFor` would not exist and every call site
would raise a `TypeError`. This is not a graceful degradation to English; it is a broken
widget. That is what makes declaring the floor part of the work rather than a nicety.

### What is actually left to translate

Measured over `src/`, the `Justfile` and `plugin.json`:

- **Code comments** — French throughout `src/view/*.qml`, `src/query/queries.js`,
  `src/model/*.js`. v0.4.0 added English comments in those files per the language rule, so
  they are already mixed; this finishes the job.
- **`Justfile`** — recipe comments, partly English since v0.4.0.
- **`plugin.json`'s `description`** — French, and user-visible in DMS's plugin browser.
- **UI copy** — the cockpit's labels, the closure card's states, `Settings.qml`'s field
  descriptions, and the strings in `src/model/format.js` (`"N commits en retard"`, `"à
  jour"`) and `src/model/closure.js`. Note that **some user-facing copy lives in the model
  layer**, which the i18n call sites must reach.
- **`DESIGN.md`'s quoted French literals** — they exist to describe the UI that exists. When
  the UI turns English they must follow, or the document starts describing a UI that is gone.

## Goals

1. **No French left in the repository** except where it is deliberate: the published
   `CHANGELOG.md` sections, the frozen `.claude/plans/` archive, and the French *translation
   table*.
2. **The UI's source strings are English**, wrapped so they can be translated.
3. **A French table exists and is registered**, so the owner's own bar reads French if his
   DMS locale is French — the EN/FR he asked for, not English-only.
4. **The floor is declared.** `requires_dms` states what this plugin now needs.
5. **`DESIGN.md` describes the UI that exists** after the change, with its quoted literals
   updated and the language note retired.
6. **Nothing regresses**: goldens unchanged except where a golden legitimately contains a
   translated string, and those moves are reviewed deliberately.

## Non-goals

- **Translating the published `CHANGELOG.md` sections.** Settled twice already.
- **Translating the `.claude/plans/` frozen archive.**
- **Any language beyond EN and FR.** The table format accepts more; adding one is then a file.
- **A locale setting of noosphere's own.** DMS already owns locale selection, and a second
  control would be a second source of truth.
- **Adopting DMS's `extract_translations.py` pipeline.** It is built for DMS's own tree. A
  plugin with roughly fifty strings does not need a POEditor workflow. *(My call — revisit if
  the string count grows or more languages appear.)*
- **Changing any behaviour.** This chantier moves words, not logic. A `just ci` failure that
  is not a translated-string golden is a defect, not an expected consequence.
- **`startupCheck`, `dependencies` vs `requires`** — #13's other half. Adjacent, and it will
  be tempting while editing the manifest. Out.

## Anti-goals

- **A half-translated UI.** Mixed-language labels in one cockpit are worse than either
  language alone. The switch is per-release, not per-file.
- **Strings that no longer reach the user.** A mistyped plugin id, a translation file whose
  name matches no locale candidate, or malformed JSON all degrade **silently to English** —
  which looks exactly like success. Every failure mode of this mechanism is invisible, so it
  needs a check that is not "look at it".
- **`DESIGN.md` left describing French copy that no longer exists.** The document's own rule
  is that it describes the UI that is there.
- **A translation table drifting out of sync with the source strings.** Every English string
  without a French entry renders English, silently. Nothing in the repository would say so.
- **Raising the DMS floor without declaring it.** A user on older DMS would get a plugin whose
  labels silently fall back to English — or worse, a load error — with no explanation.

## Constraints

- `DESIGN.md` invariants hold. Nothing here touches the pipeline, the read-only rule, or the
  colour mapping — but the colour mapping's quoted literals change language.
- `query`/`model` changes go through fixture and golden; a golden that moves must be reviewed,
  and here some legitimately will (`format.js` produces user-facing strings).
- The `Justfile` stays the only definition of the gates.
- `just lint` must stay at zero, and `just ci` green.
- Git delegated, atomic signed commits announced as a series, `--no-ff` integration.
- English for documents, code comments, commit messages — and now for source UI strings.

## The decisions taken

### How the UI gets translated

- Source strings are **English literals** at every call site, wrapped in
  `I18n.trFor("noosphere", "…")`, with the id as a literal (DMS's own tooling greps for it,
  and a computed id would not match what DMS registered).
- The French table is **`translations/fr.json` at the repository root**, beside
  `plugin.json`. Nothing loads it: DMS finds it. Adding Spanish later is one more file and no
  code.
- No registration code, no startup ordering to get right, no locale setting of our own.

**Two packaging edits without which none of this ships.** `nix/hm-module.nix` copies only
`plugin.json` and `src/`, and `scripts/noosphere-dev` assembles the dev plugin directory from
`plugin.json` plus a `src/` symlink. Neither carries `translations/`, so the French table
would be absent from both the installed plugin and the dev instance — and the manual check
("the cockpit reads French") would read English with nothing to indicate why. Both must copy
the directory. *(Caught by the builder check; I had missed it twice.)*

**No compatibility guard at the call sites.** On DMS < 1.6.0 `I18n.trFor` does not exist, so
every call raises a `TypeError` — the widget breaks rather than degrading. Worse,
`requires_dms` does **not** gate loading: `checkPluginCompatibility` feeds a warning banner
and the plugin browser's install button, and the home-manager path this project documents
bypasses the browser entirely. So the floor is advisory for exactly the users who install
noosphere.

*(My call: accept it, and say so loudly.* A guard — `typeof I18n.trFor === "function" ? … :
term` — would have to wrap ~50 call sites, costs the literal-id convention upstream's tooling
expects, and buys protection against a narrow window: DMS ≥ 1.6.0 since mid-2026, and this
plugin and its host are installed from the same NixOS configuration, so they move together.
**v0.5.0 is therefore a floor-raising release**, and `README.md` and the changelog must say
that in those words, not bury it in a manifest field.*)
- **Three model modules produce user-facing strings**, and `.pragma library` modules cannot
  import a QML singleton. *(My call: they stop producing prose. They return the data the view
  needs — a count, a state, a cause — and the view composes the sentence through `trFor`. A
  pure model function returning a French sentence was always a smell; it is also what makes
  those strings reachable by i18n at all.)* This is the one place the chantier changes
  structure rather than words, and the goldens move accordingly — deliberately, reviewed in
  the commit that moves them.
  - `src/model/format.js` — the lag labels and relative ages.
  - `src/model/closure.js` — the diff summary wording.
  - `src/model/poll.js` — `commitStatus` returns
    `errorMessage: "aucun input n'a pu être vérifié (amont GitHub injoignable)"`. **Nothing
    renders it today**: the cockpit shows a static « échec du check · réessayer » instead, so
    the cause v0.4.0 went to the trouble of naming never reaches anyone. *(My call: return a
    cause **code**, and have the status row render the composed sentence instead of its
    static string. This is not new UI — it is the same row finally saying something true, and
    leaving a computed cause discarded would be exactly the half-thing this project keeps
    catching itself at. It does change `commitStatus`'s contract, `tests/tst_poll.qml` and
    invariant 7's wording.)*
- **Host-tool output stays verbatim.** `Closure.qml` and `ClosureCard.qml` splice excerpts of
  `nix` and `nvd` output into messages. The surrounding sentence is translated; the excerpt
  is not — it is machine output in whatever language the tool emits, and paraphrasing it
  would destroy its only value.

### Where the table lives, and how it is kept honest

*(My call on both.)*

- The path is **fixed by DMS**: `translations/fr.json` at the repository root. Not a choice.
- **A gate asserts the table covers every source string**, and that it carries no entry no
  call site uses. Every failure mode here is silent, so this is the piece that keeps the
  translation honest — worth more than the translation itself. It needs neither DMS nor
  Quickshell (it compares a grep over `src/` against a JSON file), so unlike the QML lint it
  **can run in CI**, and belongs in `ci-hermetic`.
- The same gate is the natural place to check the id in every `trFor` call matches
  `plugin.json`'s `id` — the mistyped-id failure mode is otherwise invisible.
- **Every wrapped string needs an entry, with no exemption list.** Upstream's model is
  deliberately partial — a string DMS already carries in its own 317 KB catalog ("Settings",
  "Retry") resolves to French for free. Leaning on that would mean a curated list of strings
  we deliberately omit, which is a second artifact that rots silently, and the saving is a
  handful of duplicated words. *(My call: duplicate them. The gate stays a plain
  bidirectional diff with nothing to maintain.)*
- **The gate lands in step 4, with the table.** It must not exist during step 3, or step 3
  would fail `just ci` for having no translations yet — which would destroy the separability
  the ordering below depends on.

### The DMS floor

`requires_dms` is declared in `plugin.json` at the version that introduced
`registerPluginTranslations`. `README.md` states the floor too — `requires_dms` is for the
host, a human installing the plugin reads the README. The vendored schema already validates
the field's format, and `just check-manifest` will enforce it.

### Geometry may move where a language does not fit

`DESIGN.md` declares the visual system final ("Fidelity: high (hifi)") against a handoff
that lives in uncommitted `tmp/`. French runs roughly a fifth longer than English, and
several values were chosen around French copy — the behind label's `min-width: 104`, the
440px popup, the chip paddings.

*(My call: fixed values may change where a language does not fit, and each change is
recorded in `DESIGN.md` in the same commit. The alternative — holding the geometry sacred —
would make the English wording hostage to a layout designed for the French it is replacing,
which is backwards. What is not allowed is incidental drift: a value moves because a string
does not fit, deliberately, or it does not move.)*

Both languages are checked in the manual pass, not just one.

### `#13` is closed by this chantier, not left half-done

The design's non-goals put `requires` → `dependencies` out of scope, but #13's own
acceptance criteria couple it to the `requires_dms` decision this chantier takes — and the
manifest is already being edited for exactly that. *(My call: do the one-line rename too and
close #13. Leaving an issue open that says "settle both together", with one settled, is
worse than a one-line commit.)* `startupCheck`, #13's remaining neighbour, stays out.

### `DESIGN.md`

Its quoted French literals become the new English source strings, and the blockquote note
explaining that they are French pending this plan is removed. The Adeptus Mechanicus
vocabulary sentence — « dérive », « amont », « verrou » — is the one place French stays, as
the project's own terms; it gains a line saying the UI now renders English with a French
translation available.

### Ordering

1. **English everywhere that is not UI copy**: code comments, `Justfile`, `plugin.json`'s
   description. Mechanical, no behaviour, no golden movement.
2. **Lift the user-facing strings out of `model/`** into the view, with the goldens moving in
   that commit and reviewed there.
3. **Wrap the UI in `trFor`**, source strings English. The UI is English at this point and
   fully working, with no translation file anywhere — which is a valid shipping state.
4. **Add `translations/fr.json`, the packaging that carries it** (`nix/hm-module.nix` and
   `scripts/noosphere-dev`), **and the coverage gate.** The gate arrives here, not earlier,
   so step 3 can stand on its own.
5. **Declare `requires_dms: ">=1.6.0"`**, rename `requires` → `dependencies` (#13), and
   update `README.md` and `DESIGN.md` — including that this release raises the DMS floor.

Steps 3 and 4 are separable on purpose: if the French table turns out to be more work than
expected, the chantier can ship after step 3 as English-only with the mechanism in place,
which is exactly the fallback the owner's "si l'i18n est possible" allowed for.

**Target release: v0.5.0.** One branch, one `--no-ff` merge, one signed tag.

## What is left to the builder

- **The shape of the coverage gate**: how source strings are collected (a `grep` over
  `trFor("noosphere", "…")` call sites is adequate, and matches how DMS's own extractor
  works), and whether it is a QML test under `tests/` or a script. Either way it joins
  `ci-hermetic`, since it needs neither DMS nor Quickshell.
- **How multi-line and interpolated strings are handled.** Several labels are built by
  concatenation (`"lock " + age`, `count + " commits en retard"`). Whether those become one
  translatable sentence with a placeholder, or stay concatenations of translated fragments,
  changes both the French wording and what the extractor must recognise. Fragments are the
  easy route and they translate badly; one string per sentence is better French and more
  work.
- **How `format.js` and `closure.js` return state instead of prose** — an enum-like string, a
  structured object, or a count plus a flag. Whatever keeps them pure and their goldens
  meaningful.
- **Whether `Settings.qml`'s field descriptions go through `trFor` too.** They are
  user-facing, so probably yes; they are also long, which makes the table bigger.
- **The French wording.** The existing French strings are the obvious source, but a few will
  read differently once the English is the original.

## Verification

- `nix develop --command just ci` green at every step; `just lint` at zero.
- **No French prose left**: `grep` over `src/`, `Justfile` and `plugin.json` for French
  words finds only the translation table, the Mechanicus terms in `DESIGN.md`, and nothing
  else.
- **The coverage test fails** when a source string is added without a French entry, verified
  by adding one deliberately.
- **Goldens**: only those tied to strings lifted out of `model/` move, each reviewed in the
  commit that moves it. Any other movement is a hard stop.
- `just check-manifest` passes with `requires_dms` declared, and fails if its format is wrong.
- **Manual, and it is the real check**: with the DMS locale set to French the cockpit reads
  French; set to anything else it reads English; neither shows a mixed-language card. On a
  fresh dev instance, so no cached state hides a missing registration.
- The headless probe route from v0.4.0 still works for the service, and `src/model/poll.js`
  must remain free of user-facing strings.
