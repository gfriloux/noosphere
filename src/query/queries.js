.pragma library

// Command (argv) and API URL builders. PURE, testable functions: they build the command or
// the URL and nothing else — no network, no authentication.
//
// GitHub auth (optional) lives in the `Authorization: Bearer <token>` HTTP header, injected
// by the service (src/view/Noosphere.qml): the token NEVER appears here. Corollary: no
// secret in these builders, so the fixtures and goldens derived from them are committable
// without risk (see DESIGN.md).

// nix flake metadata --json [<path>] → the flake's metadata (inputs + locks) as JSON.
// We return an argument array — never a shell line: the path, which may contain spaces,
// stays ONE element, with no splitting and no injection.
// No `path` → nix resolves the flake of the current directory.
function flakeMetadata(path) {
    var args = ["flake", "metadata", "--json"];
    if (path)
        args.push(path);
    return args;
}

// Default GitHub API base. Overridable (`apiBase`) to point at a local mock during
// development (`just mock`) with no network at all — see scripts/github-mock.py.
var GITHUB_API = "https://api.github.com";

// GitHub compare API URL: GET <apiBase>/repos/<owner>/<repo>/compare/<base>...<head>.
// The response carries `ahead_by` = the number of commits by which `head` (the upstream
// branch) is ahead of `base` (the locked revision) = the input's **lag**.
function compareApiUrl(apiBase, owner, repo, base, head) {
    return (apiBase || GITHUB_API) + "/repos/" + owner + "/" + repo + "/compare/" + base + "..." + head;
}

// GitHub repo API URL: GET <apiBase>/repos/<owner>/<repo>. Used to resolve the
// `default_branch` of an input that follows no explicit `ref` (see the model layer).
function repoApiUrl(apiBase, owner, repo) {
    return (apiBase || GITHUB_API) + "/repos/" + owner + "/" + repo;
}

// --- Closure diff (v0.2.0, built on demand — see DESIGN.md) ---

// Flake reference of a github input pinned to its upstream: github:<owner>/<repo>/<ref>.
// `ref` = the tracked branch (channel, or the default branch). It resolves to that branch's
// latest commit at evaluation time → the target of an --override-input previewing an update.
function githubFlakeRef(owner, repo, ref) {
    return "github:" + owner + "/" + repo + "/" + ref;
}

// nix build of the toplevel of flake <path>'s NixOS configuration <host>, WITHOUT
// activating it. `--no-link`: no `result` symlink; `--print-out-paths`: print the toplevel's
// store path (the nvd diff's target). `overrides` (optional): a list of { name, ref } inputs
// to point at their upstream through `--override-input` — evaluating *as if updated*
// **without writing flake.lock and without activating** (see DESIGN.md: update preview,
// read-only). Argv: path, host and refs stay distinct elements, with no shell splitting.
function buildToplevel(flakePath, host, overrides) {
    var args = ["build", flakePath + "#nixosConfigurations." + host + ".config.system.build.toplevel", "--no-link", "--print-out-paths"];
    var list = overrides || [];
    // Update preview: force upstream to be re-resolved. Without this, github:owner/repo/branch
    // refs are cached under tarball-ttl, so a recent upstream fix would stay invisible to a
    // retry.
    if (list.length > 0)
        args.push("--refresh");
    for (var i = 0; i < list.length; i++)
        args.push("--override-input", list[i].name, list[i].ref);
    return args;
}

// nvd diff <current> <target> → a text preview of the closure's changes. `current` defaults
// to `/run/current-system`, the active generation. Argv for the `nvd` command.
function nvdDiff(current, target) {
    return ["diff", current || "/run/current-system", target];
}

// hostname → resolves the current host when none is configured (a nixosConfigurations key).
function hostnameArgv() {
    return ["hostname"];
}
