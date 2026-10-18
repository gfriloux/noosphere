#!/usr/bin/env python3
"""Mock of the GitHub API (compare + repo), for developing noosphere.

Serves the endpoints the service uses on http://127.0.0.1:<port>, with no network and no
real token:
    GET /repos/<owner>/<repo>/compare/<base>...<head>  → { "ahead_by": N, "base_commit", ... }
    GET /repos/<owner>/<repo>                           → { "full_name", "default_branch" }

Responses carry `base_commit.sha` and `full_name` because the service **checks** that a
response names what it asked for (`compareBelongsTo` / `repoBelongsTo`, see v0.2.1). Without
those fields the mock is silently rejected and every input stays indeterminate.

Usage:
    python3 scripts/github-mock.py [port] [scenario]
    port     : defaults to 8385
    scenario : drift (default) | uptodate | ratelimit | error
               (also read from $NOOSPHERE_MOCK_SCENARIO)

Set the plugin's "GitHub API base (dev)" setting to http://127.0.0.1:<port>.
"""
import json
import os
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

# Simulated lag per repository (scenario=drift). A repository absent from the table → 5.
AHEAD_BY = {
    "nixpkgs": 214,
    "home-manager": 31,
    "flake-parts": 0,
    "auspex": 3,
    "astropath": 0,
}

# Simulated default branch per repository, resolving inputs with no explicit ref.
DEFAULT_BRANCH = {
    "home-manager": "master",
    "flake-parts": "main",
}


def make_handler(scenario):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, fmt, *args):
            sys.stderr.write("github-mock: " + (fmt % args) + "\n")

        def _send(self, obj, code=200):
            body = json.dumps(obj).encode()
            self.send_response(code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self):
            path = urlparse(self.path).path
            sys.stderr.write("github-mock: <- %s (scenario=%s)\n" % (path, scenario))

            if scenario == "ratelimit":
                self._send({"message": "API rate limit exceeded for 127.0.0.1.",
                            "documentation_url": "https://docs.github.com/rest#rate-limiting"}, code=403)
                return
            if scenario == "error":
                self._send({"message": "Server Error"}, code=500)
                return

            parts = [p for p in path.split("/") if p]
            # /repos/<owner>/<repo>/compare/<base>...<head>
            if len(parts) >= 5 and parts[0] == "repos" and parts[3] == "compare":
                repo = parts[2]
                # `base` is the locked revision that was asked about; returning it as
                # `base_commit.sha` is what attaches the response to the input that asked.
                base = parts[4].split("...")[0]
                ahead = 0 if scenario == "uptodate" else AHEAD_BY.get(repo, 5)
                self._send({"status": "ahead" if ahead else "identical",
                            "ahead_by": ahead, "behind_by": 0,
                            "base_commit": {"sha": base}})
                return
            # /repos/<owner>/<repo>
            if len(parts) == 3 and parts[0] == "repos":
                owner, repo = parts[1], parts[2]
                self._send({"full_name": owner + "/" + repo,
                            "default_branch": DEFAULT_BRANCH.get(repo, "main")})
                return

            self._send({"message": "Not Found"}, code=404)

    return Handler


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8385
    scenario = sys.argv[2] if len(sys.argv) > 2 else os.environ.get("NOOSPHERE_MOCK_SCENARIO", "drift")
    server = ThreadingHTTPServer(("127.0.0.1", port), make_handler(scenario))
    print("github-mock : http://127.0.0.1:%d  (scenario=%s)" % (port, scenario))
    print("  → set the plugin's \"GitHub API base (dev)\" to this address. Ctrl-C to stop.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\ngithub-mock: stopped.")


if __name__ == "__main__":
    main()
