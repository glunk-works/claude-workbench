#!/usr/bin/env python3
"""Credential-injecting reverse proxy for the loop container (issue #345, plan v9 § 7.2).

The session container holds a dummy token and ANTHROPIC_BASE_URL pointing here, over plain HTTP
on the isolated network. This process, in its own container, holds the real credential, replaces
whatever auth header the session sent, and forwards over HTTPS to api.anthropic.com. The session
never holds the credential, so nothing in it (an environment, /proc, a file) can leak one.

The credential is the first line of stdin, read once into memory: never an argument, never an
environment variable. LOOP_CREDENTIAL_ENV says which header it becomes:
  ANTHROPIC_API_KEY        -> x-api-key
  CLAUDE_CODE_OAUTH_TOKEN  -> Authorization: Bearer (the client sets the oauth anthropic-beta
                              header itself, as it does for any OAuth token)

Fixed on purpose: the upstream is api.anthropic.com:443 whatever Host the session sends;
only POST /v1/messages, POST /v1/messages/count_tokens and GET /v1/models are forwarded; the target address is resolved once and must be global (the same
DNS-rebinding refusal as proxy.py), and the TLS connection is made to that checked address with
the name verified.

    inject.py                 serve on :8080
    inject.py --check METHOD P  print "allow" or "deny <reason>" and exit; no network I/O
"""
import http.client
import http.server
import os
import socket
import ssl
import sys
import threading
from urllib.parse import unquote

UPSTREAM = "api.anthropic.com"
LISTEN_PORT = 8080
# The only requests Claude Code's inference needs, as exact (method, path) pairs: the credential
# is usable for nothing else (no Files, Batches or Skills, no other method on these paths).
ALLOWED = {("POST", "/v1/messages"), ("POST", "/v1/messages/count_tokens"), ("GET", "/v1/models")}
MAX_BODY = 32 * 1024 * 1024
IDLE_SECONDS = 600
# Request headers the proxy rebuilds itself or must not pass on.
DROP_REQUEST = {"host", "authorization", "x-api-key", "proxy-authorization", "connection", "keep-alive",
                "transfer-encoding", "te", "upgrade", "content-length", "accept-encoding"}
DROP_RESPONSE = {"connection", "keep-alive", "transfer-encoding", "content-length", "proxy-authenticate", "upgrade"}
MODES = {"ANTHROPIC_API_KEY": "x-api-key", "CLAUDE_CODE_OAUTH_TOKEN": "authorization"}


def path_verdict(method, path):
    """Return None when the request may be forwarded, else a reason. Pure."""
    if (method, path.split("?", 1)[0]) not in ALLOWED:
        return "method and path are not on the allowlist"
    if "\r" in path or "\n" in path or " " in path or "#" in path or "\\" in path:
        return "control character, space, backslash or fragment in the path"
    # A dot segment (also percent-encoded, also double-encoded) could walk out of /v1/ upstream.
    decoded = path.split("?", 1)[0]
    for _ in range(3):
        decoded = unquote(decoded)
    if "\\" in decoded or any(s in (".", "..") for s in decoded.split("/")):
        return "dot segment in the path"
    return None


def upstream_headers(headers, mode, cred):
    """The session's headers, minus auth and hop-by-hop ones, plus the real credential. Pure."""
    out = [(k, v) for k, v in headers if k.lower() not in DROP_REQUEST]
    if MODES[mode] == "x-api-key":
        out.append(("x-api-key", cred))
    else:
        out.append(("Authorization", "Bearer " + cred))
    return out


def resolve_global(host):
    import ipaddress
    try:
        infos = socket.getaddrinfo(host, 443, type=socket.SOCK_STREAM)
    except OSError:
        return None
    if not infos:
        return None
    for _fam, _t, _p, _c, sa in infos:
        if not ipaddress.ip_address(sa[0]).is_global:
            return None
    return infos[0]


def open_upstream():
    info = resolve_global(UPSTREAM)
    if info is None:
        return None
    raw = socket.socket(info[0], socket.SOCK_STREAM)
    raw.settimeout(30)
    raw.connect(info[4])
    tls = ssl.create_default_context().wrap_socket(raw, server_hostname=UPSTREAM)
    tls.settimeout(IDLE_SECONDS)
    conn = http.client.HTTPSConnection(UPSTREAM, 443, timeout=IDLE_SECONDS)
    conn.sock = tls  # connect() is skipped: the checked address, the verified name
    return conn


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.0"  # close-delimited bodies: streams pass through unbuffered
    mode = ""
    cred = ""

    def log_message(self, fmt, *args):  # never log headers or bodies
        print("%s %s" % (getattr(self, "command", "-"), getattr(self, "path", "-").split("?", 1)[0]), flush=True)

    def refuse(self, code, why):
        print("deny %s: %s" % (self.path.split("?", 1)[0], why), flush=True)
        self.send_response(code)
        self.send_header("Connection", "close")
        self.send_header("Content-Length", "0")
        self.end_headers()

    def forward(self):
        why = path_verdict(self.command, self.path)
        if why:
            return self.refuse(403, why)
        if self.headers.get("Transfer-Encoding"):
            return self.refuse(411, "chunked request bodies are not forwarded")
        try:
            n = int(self.headers.get("Content-Length") or 0)
        except ValueError:
            return self.refuse(400, "bad Content-Length")
        if n < 0 or n > MAX_BODY:
            return self.refuse(413, "body too large")
        body = self.rfile.read(n) if n else None
        conn = None
        try:
            conn = open_upstream()
            if conn is None:
                return self.refuse(502, "upstream resolves to a non-global address or not at all")
            conn.putrequest(self.command, self.path, skip_host=True, skip_accept_encoding=True)
            conn.putheader("Host", UPSTREAM)
            for k, v in upstream_headers(self.headers.items(), self.mode, self.cred):
                conn.putheader(k, v)
            if body is not None:
                conn.putheader("Content-Length", str(len(body)))
            conn.endheaders(body)
            resp = conn.getresponse()
            self.send_response(resp.status, resp.reason)
            for k, v in resp.getheaders():
                if k.lower() not in DROP_RESPONSE:
                    self.send_header(k, v)
            self.send_header("Connection", "close")
            self.end_headers()
            while True:
                chunk = resp.read1(65536) if hasattr(resp, "read1") else resp.read(65536)
                if not chunk:
                    break
                self.wfile.write(chunk)
                self.wfile.flush()
        except (OSError, ValueError, http.client.HTTPException) as e:
            print("upstream error: %s" % type(e).__name__, flush=True)
            try:
                self.refuse(502, "upstream error")
            except OSError:
                pass
        finally:
            if conn is not None:
                conn.close()

    do_GET = do_POST = do_PUT = do_DELETE = do_PATCH = do_HEAD = do_OPTIONS = forward


def serve():
    mode = os.environ.get("LOOP_CREDENTIAL_ENV", "")
    if mode not in MODES:
        print("inject: LOOP_CREDENTIAL_ENV must be CLAUDE_CODE_OAUTH_TOKEN or ANTHROPIC_API_KEY", file=sys.stderr)
        sys.exit(64)
    cred = sys.stdin.readline().strip()  # strips a CRLF too
    if not cred:
        print("inject: no credential on stdin", file=sys.stderr)
        sys.exit(64)
    Handler.mode, Handler.cred = mode, cred
    srv = http.server.ThreadingHTTPServer(("0.0.0.0", LISTEN_PORT), Handler)
    srv.daemon_threads = True
    print("inject up; upstream %s; mode %s" % (UPSTREAM, MODES[mode]), flush=True)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    threading.Event().wait()


if __name__ == "__main__":
    if len(sys.argv) == 4 and sys.argv[1] == "--check":
        why = path_verdict(sys.argv[2], sys.argv[3])
        print("allow" if why is None else "deny " + why)
    else:
        serve()
