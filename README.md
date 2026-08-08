# noosphere

A **NixOS flake drift tracker** widget for the **Quickshell / DankMaterialShell** desktop
bar. A status badge in the bar (drift state + count of inputs behind) and a *cockpit*
popup listing the flake's inputs and how far each one lags behind upstream.

noosphere compares the local `flake.lock` (`nix flake metadata --json`) against the
upstream branch on **GitHub** (compare API) — **read-only**, by polling. **Nothing to
install server-side**, and **no mutation** of the system: noosphere *watches* drift.

> The widget's UI and the project documentation are in **French**. This README is the
> English entry point; the labels quoted below are the literal French strings you will see
> on screen.

Spirit and invariants: [`DESIGN.md`](./DESIGN.md). Working method:
[`PROCEDURE_PLANS.md`](./PROCEDURE_PLANS.md) and [`CLAUDE.md`](./CLAUDE.md).

## Stack

- **View**: QML / Qt Quick (Quickshell), Material 3, Catppuccin Mocha.
- **Data**: `query` (argv for `nix flake metadata` + GitHub compare URLs, pure) →
  `Noosphere.qml` service (Process `nix`, GitHub queried in-process via `XMLHttpRequest`,
  `Authorization: Bearer` header when a token is set) → `model` (drift, pure/testable) →
  `view` (QML).
- **Auth**: GitHub token **optional** (lifts the 60 req/h limit), public scope only. It
  lives in the config and the service, never in the data layers nor in the tests.

## Status

**v0.2.0 — drift + closure diff.** noosphere is **installable and usable**. The **bar
badge** encodes the drift state (blue = up to date, amber + dot = N inputs behind, grey =
failed check), rosette glyph. The **cockpit popout** provides:
- an **EN-TÊTE** card (header: flake identity, branch, current system generation, last check);
- an **INPUTS** card (one row per direct input: state dot, channel, lock age, drift against
  upstream, **changelog** link when hovering a row that is behind);
- a **DIFF DE CLOSURE** card (closure diff, v0.2.0): on the *prévisualiser la mise à jour*
  button, noosphere **builds the toplevel on demand** (`nix build`, **without activating
  it**) and shows the `nvd diff` against the current generation — a summary
  (updated/added/removed/Δ size) plus a console of the changes, with a ▲ marker and a
  **REBOOT** badge on kernel and firmware packages.

noosphere stays **read-only as far as the system is concerned**: it observes (and builds on
demand), it never activates. Still to come (mutations require an explicit DESIGN decision
and a dedicated plan): *update* / *update all* buttons (`nix flake update`), and a
**rebuild** card (timeline + rollback). Foundations, invariants and visual direction:
`DESIGN.md`.

## Development

Always enter the Nix dev shell first (it provides quickshell, qmllint/qmlformat/
qmltestrunner, just):

```bash
nix develop
just ci        # full gate: fmt-check + lint + test
```

Other targets: `just test` (golden + Qt Quick Test), `just fmt` (formats the QML),
`just bless` (regenerates the goldens — read the diff), `just changelog` (regenerates
`CHANGELOG.md` through git-cliff). To try it visually without network or server:

```bash
just mock       # mock of the GitHub compare API (drift | uptodate | ratelimit | error)
just dev-bar    # isolated DMS instance loading the worktree as “Noosphere (dev)”
```

The `Justfile` is the **only** definition of the quality gates; pre-commit and **GitHub
Actions CI** (`.github/workflows/ci.yml`) both call it.

## Code structure

```
src/query/queries.js         ← builders: nix flake metadata, GitHub compare/repo, nix build, nvd diff
src/model/inputs.js          ← parses metadata/compare, behind, barState (pure, golden-tested)
src/model/closure.js         ← parses nvd diff + severity heuristic (pure, golden-tested)
src/model/format.js          ← presentation helpers (relativeAge, stateColor, compareWebUrl)
src/view/Noosphere.qml       ← service: polls nix + GitHub compare → drift model
src/view/Closure.qml         ← service: builds toplevel + nvd diff on demand → closure model
src/view/NoosphereWidget.qml ← bar badge (PluginComponent) + cockpit mounting
src/view/NoosphereGlyph.qml  ← rosette/gear glyph (Canvas)
src/view/Cockpit.qml         ← popout: EN-TÊTE + INPUTS + DIFF DE CLOSURE cards, footer
src/view/ClosureCard.qml     ← closure diff card (button, spinner, summary, console)
src/view/Settings.qml        ← settings (flake path, hostname, repo/branch, token, poll interval)
tests/                       ← frozen fixtures + goldens (expected model)
.claude/plans/               ← per-version plans (plan.md, manual_tests.md, phase0_results.md)
```

## Installation

Through home-manager, as a DankMaterialShell plugin:

```nix
# flake.nix (inputs)
inputs.noosphere.url = "github:gfriloux/noosphere";

# home-manager config
imports = [inputs.noosphere.homeModules.default];
programs.noosphere.enable = true;
```

Then, in DMS: **Settings → Plugins → Noosphere** to enable the widget, and its settings
panel to fill in the flake path, the repo/branch to display and (optionally) a GitHub
token.

## Configuration

1. **Flake path**: the local directory holding `flake.nix` / `flake.lock`
   (e.g. `/etc/nixos`).
2. **Repo / branch** (display): the flake identity shown in the header (e.g.
   `gfriloux/nixos`, `main`). Input drift itself is measured against *their* own upstream
   branches.
3. **GitHub token** (optional): a public-scope token lifts the 60 requests/h limit of the
   compare API. The service sends it in an `Authorization: Bearer` header, from within its
   own process — it never appears in a command line.
4. **Poll interval**: how often upstream is queried (minutes).
5. **Hostname** (optional, closure diff card): the `nixosConfigurations` key to build for
   the preview. Empty → the current host (`hostname`).

noosphere is **read-only as far as the system is concerned**: the token needs no write
access, nothing is ever written to the flake, and no build is ever **activated**. The only
possible side effect is an **on-demand** `nix build` (the *prévisualiser la mise à jour*
button) that builds/downloads derivations without ever switching the system. Runtime
dependencies declared by the module: `nix`, `nvd`, `xdg-utils`.

## Release

**SemVer** versioning, changelog derived from **Conventional Commits** (git-cliff). The tag
is created by the **maintainer** (hybrid git policy) and triggers publication.

1. Bump `plugin.json` (`version`) to the new version.
2. Run `just changelog` to refresh `CHANGELOG.md`, read the diff, commit.
3. Merge onto `main`, then:

   ```bash
   git tag -a vX.Y.Z -m "vX.Y.Z — <title>"
   git push origin vX.Y.Z
   ```

Pushing the tag triggers `.github/workflows/release.yml`: git-cliff generates the release
notes and a **GitHub release** is created. Dependencies (flake inputs, actions) are kept up
to date by **Renovate**.

## License

See [`LICENSE`](./LICENSE).
