#!/usr/bin/env python3
"""Allowlisting CONNECT proxy for the loop container (plan v9 § 7.3, "Egress").

Runs in a second container from the same image, on the isolated `--internal` network (where
the session container is its only peer) and on an external network. The session reaches
Anthropic only through it, by HTTPS_PROXY. It is a CONNECT-only tunnel: it never sees
plaintext, and it refuses everything but a CONNECT to an allowlisted name on port 443.

Refused, whatever the allowlist says:
  - an IP literal as the target (v4, v6, bracketed, or the decimal/hex forms inet_aton
    accepts): the proxy's own external network still reaches its gateway and the host, so a
    name is the only target it will resolve;
  - `host.docker.internal` and `gateway.docker.internal` and any `localhost` name;
  - an allowlisted name that resolves to a non-global address (DNS rebinding onto the
    gateway, the VM or the LAN): every resolved address must be globally routable, and the
    tunnel is opened to the address that was checked, not to a second lookup.

The allowlist is LOOP_ALLOW_HOSTS (comma-separated exact names), default the four hosts Claude
Code needs with the update hosts left off, since auto-update is off in the image. A repo whose
gate fetches from elsewhere widens it per repo (orchestration.*, not this file).

    proxy.py                     serve on :3128
    proxy.py --check host[:port]  print "allow" or "deny <reason>" and exit; no network I/O
"""
import ipaddress
import os
import re
import socket
import sys
import threading

DEFAULT_ALLOW = "api.anthropic.com,claude.ai,claude.com,platform.claude.com"
ALWAYS_DENY = {"host.docker.internal", "gateway.docker.internal", "localhost"}
NAME_RE = re.compile(r"^(?=.{1,253}$)([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$")
LISTEN_PORT = 3128
IDLE_SECONDS = 600


def allowlist():
    raw = os.environ.get("LOOP_ALLOW_HOSTS", DEFAULT_ALLOW)
    return {h.strip().lower().rstrip(".") for h in raw.split(",") if h.strip()}


def looks_like_ip(host):
    """True for anything an address parser would take for an IP, including legacy forms."""
    h = host.strip("[]")
    try:
        ipaddress.ip_address(h)
        return True
    except ValueError:
        pass
    try:
        socket.inet_aton(h)  # accepts 2130706433, 0x7f.1, 127.1
        return True
    except OSError:
        pass
    return ":" in h


def decide(target, allow):
    """Return (True, host, port) or (False, reason). Pure: no resolution here."""
    target = target.strip()
    if target.startswith("["):  # [v6]:port -- an IP literal, refused below
        host, _, port = target[1:].partition("]")
        port = port.lstrip(":")
    else:
        host, sep, port = target.rpartition(":")
        if not sep:
            host, port = target, ""
    host = host.lower().rstrip(".")
    if not host:
        return (False, "empty host")
    if looks_like_ip(host):
        return (False, "ip literal")
    if host in ALWAYS_DENY or host.endswith(".localhost") or host.endswith(".internal"):
        return (False, "internal name")
    if not NAME_RE.match(host):
        return (False, "not a dns name")
    if host not in allow:
        return (False, "not on the allowlist")
    if port != "443":
        return (False, "port is not 443")
    return (True, host, 443)


def resolve_global(host):
    """Resolve once; return a checked address, or None if any answer is non-global."""
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


def pipe(src, dst):
    try:
        while True:
            data = src.recv(65536)
            if not data:
                break
            dst.sendall(data)
    except OSError:
        pass
    finally:
        for s in (src, dst):
            try:
                s.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass


def handle(client, allow):
    client.settimeout(30)
    upstream = None
    try:
        buf = b""
        while b"\r\n\r\n" not in buf and len(buf) < 8192:
            chunk = client.recv(4096)
            if not chunk:
                return
            buf += chunk
        line = buf.split(b"\r\n", 1)[0].decode("latin-1")
        parts = line.split(" ")
        if len(parts) != 3 or parts[0] != "CONNECT":
            client.sendall(b"HTTP/1.1 405 Method Not Allowed\r\nConnection: close\r\n\r\n")
            return
        verdict = decide(parts[1], allow)
        if not verdict[0]:
            print("deny %s: %s" % (parts[1], verdict[1]), flush=True)
            client.sendall(b"HTTP/1.1 403 Forbidden\r\nConnection: close\r\n\r\n")
            return
        info = resolve_global(verdict[1])
        if info is None:
            print("deny %s: resolves to a non-global address or not at all" % verdict[1], flush=True)
            client.sendall(b"HTTP/1.1 403 Forbidden\r\nConnection: close\r\n\r\n")
            return
        upstream = socket.socket(info[0], socket.SOCK_STREAM)
        upstream.settimeout(30)
        try:
            upstream.connect(info[4])
        except OSError:
            client.sendall(b"HTTP/1.1 502 Bad Gateway\r\nConnection: close\r\n\r\n")
            upstream.close()
            return
        print("allow %s" % verdict[1], flush=True)
        client.sendall(b"HTTP/1.1 200 Connection Established\r\n\r\n")
        client.settimeout(IDLE_SECONDS)
        upstream.settimeout(IDLE_SECONDS)
        t = threading.Thread(target=pipe, args=(upstream, client), daemon=True)
        t.start()
        pipe(client, upstream)
        t.join(5)
    except OSError:
        pass
    finally:
        if upstream is not None:
            upstream.close()
        client.close()


def serve():
    allow = allowlist()
    print("proxy up; allowlist: %s" % ",".join(sorted(allow)), flush=True)
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("0.0.0.0", LISTEN_PORT))
    srv.listen(64)
    while True:
        c, _ = srv.accept()
        threading.Thread(target=handle, args=(c, allow), daemon=True).start()


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "--check":
        t = sys.argv[2] if ":" in sys.argv[2] else sys.argv[2] + ":443"
        v = decide(t, allowlist())
        print("allow" if v[0] else "deny " + v[1])
    else:
        serve()
