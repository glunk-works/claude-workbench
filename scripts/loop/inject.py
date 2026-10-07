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
only POST /v1/messages, POST /v1/messages/count_tokens and GET /v1/models are forwarded, and a POST body that names mcp_servers, a container, a server-side tool, a content block of another type or a url or file source is refused (#318); the target address is resolved once and must be global (the same
DNS-rebinding refusal as proxy.py), and the TLS connection is made to that checked address with
the name verified.

    inject.py                 serve on :8080
    inject.py --check METHOD P  print "allow" or "deny <reason>" and exit; no network I/O
"""
import http.client
import http.server
import json
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


# Fields that make the API act for the caller beyond answering: remote MCP servers, a code-execution
# container with skills, and server-side tools (web_search, web_fetch, code_execution ...), which
# fetch or run on Anthropic's side and so reach any URL the session names. Claude Code's own tools
# are plain custom tools (no `type`, or "custom"), so this allowlist costs inference nothing.
BODY_REFUSED_KEYS = ("mcp_servers", "container")


def _no_duplicate_keys(pairs):
    d = {}
    for k, v in pairs:
        if k in d:
            raise ValueError("duplicate key")
        d[k] = v
    return d


# Content blocks Claude Code sends. Anything else (server_tool_use, mcp_tool_use, container_upload,
# search results ...) is refused, and a block's `source` may only carry its data inline: a url or a
# file_id source makes the API fetch a URL or read a stored file on the caller's behalf.
CONTENT_TYPES = {"text", "image", "document", "tool_use", "tool_result", "thinking", "redacted_thinking"}
SOURCE_TYPES = {"base64", "text"}


def _blocks_verdict(blocks, depth=0):
    if depth > 4:
        return "content nests too deep"
    if isinstance(blocks, str):
        return None
    if not isinstance(blocks, list):
        return "content is neither a string nor a list"
    for b in blocks:
        if not isinstance(b, dict):
            return "a content block is not an object"
        if b.get("type") not in CONTENT_TYPES:
            return "content block type %s is not allowed" % str(b.get("type"))[:40]
        if "source" in b:
            s = b["source"]
            if not isinstance(s, dict) or s.get("type") not in SOURCE_TYPES:
                return "a %s block has a source that is not inline data" % b["type"]
        if b["type"] == "tool_result" and "content" in b:
            why = _blocks_verdict(b["content"], depth + 1)
            if why:
                return why
    return None


def _no_constant(name):
    raise ValueError("non-finite number")


def body_verdict(method, body, headers=()):
    """Return None when the body may be forwarded, else a reason. Pure. Only POST bodies are read.
    headers is the session's (name, value) pairs: the bytes are parsed here exactly once, strictly
    (UTF-8, no BOM, no NaN, no repeated key), and only as the plain JSON the API is sent."""
    if method != "POST":
        return None
    if not body:
        return "empty body on a POST"
    names = [k.lower() for k, _ in headers]
    if names.count("content-type") > 1 or names.count("content-encoding") > 1:
        return "a repeated Content-Type or Content-Encoding header"  # the check reads one copy, the API may read another
    h = {k.lower(): v.strip().lower().replace(" ", "") for k, v in headers}
    if h.get("content-encoding") not in (None, "", "identity"):
        return "a Content-Encoding is not forwarded"
    ct = h.get("content-type", "application/json")
    if ct not in ("application/json", "application/json;charset=utf-8"):
        return "Content-Type is not application/json"
    try:
        text = body.decode("utf-8")
        if text.startswith("﻿"):
            return "body starts with a byte-order mark"
        doc = json.loads(text, object_pairs_hook=_no_duplicate_keys, parse_constant=_no_constant)
    except (ValueError, RecursionError):  # a duplicate key is a ValueError too: parsers disagree on which one wins
        return "body is not strict UTF-8 JSON, or repeats a key"
    if not isinstance(doc, dict):
        return "body is not a JSON object"
    for k in BODY_REFUSED_KEYS:
        if k in doc:
            return "body asks for %s" % k
    tools = doc.get("tools", [])
    if not isinstance(tools, list):
        return "tools is not a list"
    for t in tools:
        if not isinstance(t, dict):
            return "a tool is not an object"
        if t.get("type", "custom") != "custom":
            return "body asks for a server-side tool (%s)" % str(t.get("type"))[:40]
    if "system" in doc:
        why = _blocks_verdict(doc["system"])
        if why:
            return why
    msgs = doc.get("messages", [])
    if not isinstance(msgs, list):
        return "messages is not a list"
    for m in msgs:
        if not isinstance(m, dict):
            return "a message is not an object"
        why = _blocks_verdict(m.get("content", ""))
        if why:
            return why
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
        why = body_verdict(self.command, body, self.headers.items())
        if why:
            return self.refuse(403, why)
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
