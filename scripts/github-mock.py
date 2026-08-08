#!/usr/bin/env python3
"""Mock de l'API GitHub (compare + repo) pour le dev de noosphere.

Sert les endpoints utilisés par le service sur http://127.0.0.1:<port>, sans réseau ni
token réel :
    GET /repos/<owner>/<repo>/compare/<base>...<head>  → { "ahead_by": N, ... }
    GET /repos/<owner>/<repo>                           → { "default_branch": "..." }

Usage :
    python3 scripts/github-mock.py [port] [scenario]
    port     : défaut 8385
    scenario : drift (défaut) | uptodate | ratelimit | error
               (aussi lisible via $NOOSPHERE_MOCK_SCENARIO)

Règle « Base de l'API GitHub (dev) » du plugin sur http://127.0.0.1:<port>.
"""
import json
import os
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

# Retard simulé par repo (scenario=drift). Un repo absent de la table → 5 par défaut.
AHEAD_BY = {
    "nixpkgs": 214,
    "home-manager": 31,
    "flake-parts": 0,
    "auspex": 3,
    "astropath": 0,
}

# Branche par défaut simulée par repo (résolution des inputs sans ref explicite).
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
                ahead = 0 if scenario == "uptodate" else AHEAD_BY.get(repo, 5)
                self._send({"status": "ahead" if ahead else "identical",
                            "ahead_by": ahead, "behind_by": 0})
                return
            # /repos/<owner>/<repo>
            if len(parts) == 3 and parts[0] == "repos":
                repo = parts[2]
                self._send({"default_branch": DEFAULT_BRANCH.get(repo, "main")})
                return

            self._send({"message": "Not Found"}, code=404)

    return Handler


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8385
    scenario = sys.argv[2] if len(sys.argv) > 2 else os.environ.get("NOOSPHERE_MOCK_SCENARIO", "drift")
    server = ThreadingHTTPServer(("127.0.0.1", port), make_handler(scenario))
    print("github-mock : http://127.0.0.1:%d  (scenario=%s)" % (port, scenario))
    print("  → règle « Base de l'API GitHub (dev) » du plugin sur cette adresse. Ctrl-C pour arrêter.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\ngithub-mock : arrêt.")


if __name__ == "__main__":
    main()
