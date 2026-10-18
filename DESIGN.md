# DESIGN.md — noosphere

> This document defines noosphere's spirit, structure and **invariants**.
> Before adding anything, check that it fits here. If it does not, the
> answer is no.

---

## What noosphere is

noosphere is a **NixOS flake drift tracker widget** for the **Quickshell /
DankMaterialShell** desktop bar (Material 3, Catppuccin Mocha theme). An icon in the bar
shows a **status badge** (drift state + count of inputs behind); on click, a **cockpit
popup** anchored under the icon answers at a glance: *how many inputs are drifting, and by
how much.*

It compares the **local flake's inputs** (revisions locked in `flake.lock`, read through
`nix flake metadata --json`) against **upstream** (the branch tracked on GitHub) and shows
how far **behind** (number of commits) each input is.

The source of truth is twofold and **local as far as reading goes**: the **flake on disk**
(for the locked state) and **GitHub's compare API** (for upstream). **Nothing is to be
installed server-side.** Refreshing happens by periodic **polling**. In v1, noosphere is
**read-only**: it observes drift, it does not mutate the system.

noosphere is an **observation surface** on top of a flake. What one does next with a drift
(read the upstream changelog, decide on a `nix flake update`, launch a `nixos-rebuild`) is
**delegation** or an **explicit future capability**, not v1's scope: this document does not
detail how mutations would be rendered.

It is **not**:

- An update manager. noosphere does **not** run `nix flake update`,
  `nixos-rebuild switch/boot` or `rollback` (see the *read-only* invariant). It **shows**
  the gap, and **previews** a build's closure — without ever activating.
- An automatic builder. Since v0.2.0, noosphere can **build a toplevel on demand** (a
  button) for a preview `nvd diff`, but never in the background, and without activation.
  The rebuild timeline (activate/test) and rollback remain **future caps** (handoff).
- A mirror of `nix flake update --commit-lock-file`. It reads the lock, it does not write it.

Today a single flake is configured, but nothing in the model assumes that: see the
*flake-agnostic* invariant below.

---

## The pipeline — three stages

noosphere is a three-stage transformation. Each stage has a clear contract and is
**independently testable**. Nothing crosses a stage that should not: raw `nix`/GitHub output
does not enter the view, and the QML never builds a command or a URL itself.

```
  local flake + GitHub                                 popup Quickshell
      │                                                        ▲
      ▼                                                        │
  ┌────────┐        ┌─────────────┐        ┌──────────────────┐
  │ query  │  ───▶  │ model       │  ───▶  │ view             │
  │ (argv/ │        │ (inputs /   │        │ (QML / Material) │
  │  URL)  │        │  drift)     │        │                  │
  └────────┘        └─────────────┘        └──────────────────┘
```

### 1. `query` — building commands & URLs

Builds the **argv** for `nix flake metadata --json` and the **URL** for GitHub's compare
API — **pure** functions, **with no secret whatsoever**. We return an **argument array**
(never a shell line: no injection, the request stays one element), and a URL built from
`owner/repo/base/head`. It knows neither the network nor the presentation. Execution
(`Process` running `nix`, the HTTP `GET` issued by the process itself) is the **service**'s
job (`Noosphere.qml`), not this layer's.

> **Auth lives in a header, not in the URL.** The GitHub token (optional, to lift the
> 60 req/h limit) travels in the `Authorization: Bearer <token>` HTTP header, injected by
> the service. Direct consequence: the URLs built by `query` (and therefore the **golden
> fixtures**) never contain a token — committable without risk.

### 2. `model` — the domain model

Turns `nix flake metadata`'s output and GitHub's compare responses into a **drift model**:
the list of **direct inputs** (name, channel, locked revision, lock date, owner/repo), each
annotated with how far **behind** it is (`behind` = commits of gap against upstream). It
holds the application state: `inputs`, `behindCount`, `barState` (`uptodate | drift`),
`connectionStatus`, `lastCheck`. **Pure and testable**: same inputs → same model (see the
golden tests, PROCEDURE_PLANS.md).

The **presentation** helpers (relative time « il y a 9 j », state colour, the web
compare URL for the changelog link) live in `format.js`, **outside the golden model**
(derivable / dependent on *now*).

### 3. `view` — Quickshell rendering

QML / Qt Quick. Consumes the model; never builds or runs a command directly. It carries the
visual system below, reusing DankMaterialShell's Material 3 components.

### Implementation

noosphere is a **DankMaterialShell plugin** (`plugin.json` at the root + `src/`), installed
into `~/.config/DankMaterialShell/plugins/Noosphere/`. It inherits DMS's theme (Catppuccin
Mocha) and Material 3 components.

- `query` → `src/query/queries.js`: `flakeMetadata()` / `compareApiUrl()` / `repoApiUrl()`
  (drift), `buildToplevel()` / `nvdDiff()` / `hostnameArgv()` (closure diff), pure
  functions. Run by the services (`Process` for `nix` and `nvd`; GitHub URLs are queried by
  `XMLHttpRequest`, with no external process).
- `model` → `src/model/inputs.js` (drift: `parseMetadata`, `parseCompare`, `mergeBehind`,
  `behindCount`, `barState`, attributing responses: `compareBelongsTo`, `repoBelongsTo`,
  the cause of a failed call: `githubError`)
  + `src/model/closure.js` (`parseNvdDiff`, `closureSeverity`,
  `cardSeverity`) + `format.js` (presentation helpers, **outside** the golden model). Pure,
  tested by goldens + inline (`tests/`, `just test` / `just bless`).
- `view` → `src/view/`: the `Noosphere` (drift poll) and `Closure` (on-demand build+diff)
  services; `NoosphereWidget` (bar + badge), `NoosphereGlyph` (glyph), `Cockpit` (popout:
  header + INPUTS + DIFF DE CLOSURE cards), `ClosureCard` (diff card), `Settings` (config).
  Theme = DMS.

#### HTTP transport stays inside the process

Calls to GitHub's API are issued by the service through `XMLHttpRequest`, **never** by an
external client. The reason is the secret: handed to a process, the token would travel in
its argv, hence in `/proc/<pid>/cmdline`, readable by any local process. A header set from
within the process never leaves its memory. This is the execution corollary of the *auth
lives in a header* rule stated above.

What this transport brings incidentally: the **HTTP status** is readable (so the cause of a
failure can be named — `githubError`), **redirects** are followed (a renamed repository
stops breaking silently), and since each request is a distinct object, a response is
attributed to its input through its closure rather than through shared state.

What it does not bring by itself, and which remains a **future cap** (a dedicated decision
and plan; tracked in GitHub Issues):

| Track | Gain | Cost |
|---|---|---|
| Conditional requests `If-None-Match` / `ETag` | quota savings, decisive **without** a token (60 req/h against ~15 requests per poll) | an in-memory ETag cache, to invalidate — and not to persist (inv. 1) |
| Compares in parallel | the latency of a sequential poll | concurrency control, one timer per in-flight request, rate-limit conduct to rethink |

**Sequential remains the default choice**: a controlled request budget, and a single
in-flight request at a time is reasoned about effortlessly.

---

## Domain invariants

1. **The local flake + GitHub are authoritative; nothing server-side.** Every displayed
   datum comes from `nix flake metadata --json` (locked state) and GitHub's compare API
   (upstream). No parallel persistent cache, no server-side configuration.
2. **Read-only — observe, do not activate.** noosphere reads the system state and may, **at
   the user's explicit request**, **build** a toplevel (`nix build …#…toplevel`, since
   v0.2.0) to preview its closure: a build constructs derivations and downloads, but
   **activates nothing** — no `switch`/`boot`, no new generation, no profile switch. These
   stay **out of scope** (a DESIGN decision + a dedicated plan each time):
   `nix flake update` (writing `flake.lock`), `nixos-rebuild switch/boot`, `rollback`. The build is
   **never automatic** (never triggered by a poll): too heavy, and a system action is only
   triggered on explicit intent.
3. **The input is the unit.** The model reasons in the flake's **direct inputs** (those
   declared at the root: `.locks.nodes[root].inputs`), not in transitive nodes. One input =
   a name, a channel, a locked revision, a lock date, a number of commits behind. The full
   lock graph is a detail of the `query` layer, not of the domain.
4. **How far behind is measured against GitHub upstream.** An input's `behind` = `ahead_by` of the
   compare `<lockRev>...<upstream branch>` (the number of commits by which upstream is ahead
   of the lock). Only inputs of `type == "github"` are compared; other types are
   **displayed, never compared** (behind indeterminate, never counted as drift).
5. **GitHub token optional, and secret.** Without a token, the public API is enough (60
   req/h limit). With a token (`Authorization: Bearer` header), the limit rises. The token is
   a secret: it lives in the config / the service, **never** in the `query`/`model` layers
   nor in the fixtures/goldens.
6. **Flake-agnostic.** noosphere does not model flakes as first-class entities: a flake is
   only a **facet** (path + owner/repo + branch + token). Single- or multi-flake are modelled
   with no special handling — a future multi-flake view will be a plan if the need emerges.
7. **Best-effort on the connection.** The state (`live | polling | error`) is *observed*. A
   flake that cannot be found, a slow `nix`, GitHub unreachable or rate-limited **degrades
   the display** (last known state + error status, grey badge), and **never** crashes the
   widget.
8. **Determinism of the data layer.** `query` + `model` are deterministic for a frozen set
   of inputs (`nix flake metadata` output + compare responses + `nvd diff` output) — that is
   what makes the golden tests possible. `behind`/`behindCount`/`barState` and
   `parseNvdDiff`/`closureSeverity`/`cardSeverity` are pure functions.
9. **The closure previews an update, without mutating (v0.2.0).** The closure diff compares
   `/run/current-system` (the current generation) against a **toplevel built on demand**
   with the inputs that are **behind pointed at their upstream** through `--override-input`
   (`github:<owner>/<repo>/<ref>`): we evaluate *as if updated* **without writing
   `flake.lock`** and **without activating**. No input behind → nothing to preview. The
   build is never automatic. `nvd` is a **declared dependency** (devShell + home-manager
   module + `plugin.json`). A change's severity is a **local heuristic**:
   kernel/firmware/driver → `reboot` (REBOOT badge); **CVE** badges are **deferred** (no
   reliable local source of security advisories). The edge takes the maximum severity.
10. **A response belongs to the input that asked for it (v0.2.1).** The poll queries GitHub
    **sequentially**, one step at a time. Contract: **one step = one request = one
    advance**. The input is captured at emission time — never re-read from a cursor on
    return — and each response is **attributed** to it (`compareBelongsTo` on
    `base_commit.sha`, `repoBelongsTo` on `full_name`) before being used. An orphan response
    is **discarded**, never guessed: attributing how far behind one input is to its neighbour is worse
    than displaying nothing. A watchdog bounds each step, so that a poll always hands control
    back: without it, a manual re-check would stay without effect.
11. **The display never contradicts itself.** Two cards describing the same state cannot
    state it differently. An input that is behind but not previewable (upstream unresolved) is
    **named as such** by the closure card; « aucun input en retard » is reserved
    for the case where there really is none. A corollary of invariant 7: degrading the
    display is allowed, lying is not.

---

## Visual system

Inherited from DankMaterialShell (Material 3, Catppuccin Mocha) and defined to the pixel by
the design handoff (`tmp/design_handoff_noosphere/Noosphere.dc.html`, not committed). The
**durable values** are copied below so they survive.

> **Fidelity: high (hifi).** Colours, sizes, spacings and states are final. The only
> freedom: the **font** — the shell's system font for text, the shell's mono (JetBrains Mono
> / Fira Code) for everything marked mono.

> **On the French strings this document quotes.** The UI copy is French **today**. Every
> French literal in guillemets — in this section and in §2 `model` above — is a string `src/`
> renders now, shown with `<placeholders>` and with `N`/`M`/`A`/`R` standing where the code
> interpolates: the code holds `"lock "`, `" commits en retard"`, `"· Δ "` and so on, not the
> whole phrase. They are quoted, not translated, so this document keeps describing the
> interface that actually exists.
>
> **One exception, below:** the Adeptus Mechanicus section's « dérive », « amont », « verrou »
> are named as the project's **vocabulary**, not as rendered copy. Of the three only « amont »
> reaches the screen; the other two live in code comments, which are themselves bound for
> English. The rule, stated once: a French string stays French here when it is a **rendered**
> UI literal — a word appearing only in a comment is not one.
>
> English is noosphere's default language and the UI will follow, with EN/FR
> internationalisation, under its own plan — see `PROCEDURE_PLANS.md`. Until then, a French
> literal here is deliberate, not a missed translation.

### Palette — Catppuccin Mocha

| Role | Hex |
|---|---|
| Base / popup background | `#1e1e2e` |
| Mantle / console background, secondary buttons | `#181825` |
| Surface0 / cards | `#313244` |
| Surface1 / borders | `#45475a` |
| Surface2 / hover border | `#585b70` |
| Overlay0 / tertiary text | `#6c7086` |
| Subtext0 / secondary text | `#a6adc8` |
| Text | `#cdd6f4` |
| **Green — up to date / success** | `#a6e3a1` |
| **Yellow — drift** | `#f9e2af` |
| Peach — attention / reboot / size | `#fab387` |
| Red — error / CVE / danger | `#f38ba8` |
| Mauve — rebuild | `#cba6f7` |
| **Blue — identity / neutral actions / links** | `#89b4fa` |
| Blue hover | `#a6c4fc` / `#b4befe` |

### State colour mapping (imperative)

noosphere's visual pillar. The **bar badge**'s colour encodes the drift state:

| State (`barState`) | Glyph colour | Pill | Meaning |
|---|---|---|---|
| `uptodate` | Blue `#89b4fa` | hidden | every input up to date |
| `drift` | Yellow `#f9e2af` | yellow background, figure = number of inputs behind | at least one input is drifting |
| `rebuilding` *(future cap, not reached in v1)* | Mauve `#cba6f7` | hidden | rebuild in progress |

In the INPUTS card, each row carries a **state dot**: yellow `#f9e2af` if behind, green
`#a6e3a1` if up to date. The behind label is yellow (« N commits en retard ») or grey
`#6c7086` (« à jour »).

### Shapes & depth

- **Bar badge**: height 28px, radius 8, background `#313244`, 1px `#45475a` border.
- **Popup**: width 440px, radius 18, background `#1e1e2e`, 1px `#313244` border, padding 14,
  shadow `0 24px 60px rgba(0,0,0,.55)`, 11 gap between cards.
- **Cards**: background `#313244`, radius 13, padding 13–15, **3px left edge** coloured by
  severity (`inset 3px 0 0 <colour>`). Card titles: mono 11px/600, letter-spacing `.13em`,
  uppercase, coloured like the edge, preceded by a 13px icon.
- Radii: 5 (micro-badges) · 7 (mini-buttons) · 8 (rows, badge, pill) · 9 (buttons, blocks) ·
  13 (cards) · 18 (popup) · 20 (chips) · 50 % (dots, circles).
- Type: **system font** (UI); **the shell's mono** (input names, revisions, behind counts, chips, card
  titles); **Material Symbols** for icons (`sync`, `download`, `fork_right`, `schedule`,
  `settings`, `deployed_code`, `refresh`, `check`, `undo`).

### Animations

- `spin` (rotation, .9s spinner / 3s glyph) and `pulseGlow` (mauve halo, 1.8s) — **reserved
  for the `rebuilding` state**, hence **not triggered in v1**. Row hover and action-reveal
  transitions: 120 ms. No other animation in v1.

### Visual direction — cockpit

A small drift cockpit. Reference layout (the HTML prototype details the pixel-perfect form):

- **440px popup**, a column of cards, gap 11.
- **Header card** (`#89b4fa` edge): 22px glyph + « noosphere » (16px/700
  `#cdd6f4`) and `owner/repo` (mono 12px `#89b4fa`); on the right, a branch chip
  (`fork_right` icon + name, `#1e1e2e` background, `#45475a` border). Row 2: green dot +
  generation (« n°N · activée il y a … »); on the right « check amont · il y a
  … » `#6c7086`.
- **INPUTS card** (`#f9e2af` edge, the heart of the widget): header « INPUTS » +
  « N en retard · M à jour » on the right. One row per input: state dot · name
  (mono 13px/600) · optional channel chip (mono 10.5px `#6c7086`) ·
  « lock <age> »; on the right, the behind label (mono 11px/600, min-width 104,
  right-aligned). **Hover** on a row that is behind: background `rgba(255,255,255,.045)` +
  a 120ms reveal of the **changelog** link (`#89b4fa`, opens GitHub's web compare) —
  **read-only**.

- **DIFF DE CLOSURE card** (peach `#fab387` edge if a `reboot` change, otherwise neutral
  `#45475a`; red `#f38ba8` on error) — **update preview**: `nvd diff` between
  `/run/current-system` and a toplevel **built on demand, with the inputs that are behind
  pointed at upstream** (`--override-input`, without writing the lock). Title:
  `deployed_code` icon + « DIFF DE CLOSURE ».
  - **idle**: a « prévisualiser la mise à jour (N) » button (`#89b4fa`) if N inputs
    are behind; otherwise the note « aucun input en retard ». The card is empty
    until a build has run (never automatic).
  - **building / diffing**: mauve `#cba6f7` spinner + the step's label.
  - **ready**: a summary row (mono 12px, segments separated by `·` `#6c7086`)
    « N màj » `#f9e2af` · « A ajoutés » `#a6e3a1` ·
    « R retirés » `#f38ba8` · « Δ <size> » `#fab387`; then a `#181825`
    console block (radius 9, mono 12px): per entry `name  <from>  →  <to>` (versions
    `#6c7086`, the new one `#cdd6f4`). A `reboot` entry: peach `#fab387` name, ▲ marker, a
    right-hand **REBOOT** badge (mono 9.5px, `#fab387` on `rgba(250,179,135,.14)`).
  - **error**: red edge + a message (an excerpt of `nix`/`nvd` output).

> **Deferred.** **CVE** badges (they need a source of security advisories — no reliable local
> source); an external *view the N changes* viewer (the console already shows everything);
> *update* / *Update all* buttons (`nix flake update`); a **REBUILD** card (an
> update→build→activate→test timeline + rollback). The latter **mutate** and will become
> dedicated plans once settled in DESIGN. The rotating glyph (`rebuilding`) is not triggered.

### Secondary states

- **Up to date (zen)**: blue badge, pill hidden; INPUTS card « 0 en retard · M à
  jour », every dot green.
- **Loading (check in progress)**: the behind columns in grey `#6c7086` placeholder, the list
  **not emptied** (we keep the last known state).
- **Error** (flake not found, GitHub unreachable/rate-limited): the INPUTS card's edge in red
  `#f38ba8`, a status row « échec du check · réessayer », the bar badge in grey
  `#6c7086` keeping its last known value.

---

## Adeptus Mechanicus nod

Subtle, never kitsch. The **noosphere** is the Mechanicus's information network; the plugin's
glyph is a **rosette/gear** (an 8-spoke wheel + hub), a discreet echo of the mechanical cog.
Sober vocabulary: the project says « dérive », « amont », « verrou », not their flashier
synonyms. These are the French terms the project reasons in — *drift*, *upstream*, *lock* —
and they are named here as terms, not prescribed as English copy. It is a seasoning, not a
theme.
