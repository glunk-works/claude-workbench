#!/usr/bin/env python3
"""Fixed git tools for the loop session (issue #345): a stdio MCP server, root-owned in the image.

Replaces the free-form `Bash(git add *)` / `Bash(git commit *)` allows. Those patterns let the
model supply git's options (`--pathspec-from-file`, `commit -F`, `diff` on a path outside the
tree), and a deny list cannot express git's option parsing. Here the model supplies values, never
options: every tool builds its own argv, runs git with a fixed option set in the work tree, and
takes no free-form path or flag.

Tools: git_status, git_diff(staged), git_log(count), git_add(paths), git_commit(message).

    git_tools.py            serve MCP (newline-delimited JSON-RPC) on stdin/stdout
    git_tools.py --check-path <path>   print "ok <relpath>" or "deny <reason>" and exit
"""
import json
import os
import subprocess
import sys

WORKDIR = os.environ.get("LOOP_WORKDIR", "/work")
MAX_MESSAGE = 4096
MAX_PATHS = 200
MAX_LOG = 50
GIT_TIMEOUT = 60
PROTOCOL_VERSIONS = ("2025-06-18", "2025-03-26", "2024-11-05")

# -c options come first so that no repo-level config can turn on a hook or a pager; the
# environment closes global and system config (the launch also sets the first two).
GIT_BASE = ["git", "-c", "core.hooksPath=/dev/null", "-c", "core.pager=cat",
            "-c", "core.fsmonitor=false", "-c", "commit.gpgsign=false", "--no-pager"]


# Only these reach git from the server's own environment; GIT_DIR, GIT_WORK_TREE, GIT_CONFIG_COUNT,
# GIT_CONFIG_PARAMETERS, GIT_INDEX_FILE and the rest never do, whatever the claude process carries.
PASS_ENV = ("PATH", "HOME", "LANG", "LC_ALL", "SYSTEMROOT", "TEMP", "TMP",
            "GIT_AUTHOR_NAME", "GIT_AUTHOR_EMAIL", "GIT_COMMITTER_NAME", "GIT_COMMITTER_EMAIL")


def git_env():
    env = {k: os.environ[k] for k in PASS_ENV if k in os.environ}
    env.update({
        "GIT_CONFIG_GLOBAL": "/dev/null",
        "GIT_CONFIG_NOSYSTEM": "1",
        "GIT_LITERAL_PATHSPECS": "1",  # a path is a path: no glob or pathspec magic
        "GIT_OPTIONAL_LOCKS": "0",
        "GIT_TERMINAL_PROMPT": "0",
        "GIT_EDITOR": "true",
    })
    return env


def check_path(p, workdir=None):
    """Return (True, relpath) or (False, reason). Pure but for the symlink resolution."""
    workdir = workdir or WORKDIR
    if not isinstance(p, str) or not p:
        return (False, "empty path")
    if "\x00" in p or "\n" in p:
        return (False, "control character in path")
    if p.startswith("-"):
        return (False, "path starts with '-'")
    if p.startswith(":") or p.startswith("@"):
        return (False, "path starts with ':' or '@'")
    if os.path.isabs(p) or p.startswith("~"):
        return (False, "path is not relative to the work tree")
    parts = [x for x in p.replace("\\", "/").split("/") if x not in ("", ".")]
    if ".." in parts:
        return (False, "path leaves the work tree")
    if ".git" in parts:
        return (False, "path is inside .git")
    root = os.path.realpath(workdir)
    full = os.path.realpath(os.path.join(root, *parts)) if parts else root
    if full != root and not full.startswith(root + os.sep):
        return (False, "path resolves outside the work tree")
    rel = os.path.relpath(full, root)
    if rel == ".git" or rel.startswith(".git" + os.sep):
        return (False, "path resolves inside .git")
    # Containment was checked on the resolved path; git gets the normalised path as given, so a
    # symlink inside the tree is staged as the link, not as its target.
    return (True, "/".join(parts) or ".")


def run_git(args):
    try:
        p = subprocess.run(GIT_BASE + args, cwd=WORKDIR, env=git_env(), stdin=subprocess.DEVNULL,
                           capture_output=True, text=True, timeout=GIT_TIMEOUT, errors="replace")
    except subprocess.TimeoutExpired:
        return ("git timed out", True)
    out = (p.stdout + p.stderr).strip()
    if len(out) > 20000:
        out = out[:20000] + "\n[truncated]"
    return (out or "(no output)", p.returncode != 0)


def tool_status(_a):
    return run_git(["status", "--short", "--branch"])


def tool_diff(a):
    staged = a.get("staged", False)
    if not isinstance(staged, bool):
        return ("staged must be a boolean", True)
    args = ["diff", "--no-ext-diff", "--no-textconv", "--no-color"]
    if staged:
        args.append("--cached")
    return run_git(args)


def tool_log(a):
    n = a.get("count", 10)
    if isinstance(n, bool) or not isinstance(n, int) or not 1 <= n <= MAX_LOG:
        return ("count must be an integer from 1 to %d" % MAX_LOG, True)
    return run_git(["log", "--oneline", "--no-decorate", "--no-color", "-n", str(n)])


def tool_add(a):
    paths = a.get("paths")
    if not isinstance(paths, list) or not paths or len(paths) > MAX_PATHS:
        return ("paths must be a non-empty list of at most %d work-tree-relative paths" % MAX_PATHS, True)
    rels = []
    for p in paths:
        ok, v = check_path(p)
        if not ok:
            return ("refused %r: %s" % (p, v), True)
        rels.append(v)
    return run_git(["add", "--"] + rels)


def tool_commit(a):
    msg = a.get("message")
    if not isinstance(msg, str) or not msg.strip():
        return ("message must be a non-empty string", True)
    if len(msg) > MAX_MESSAGE or "\x00" in msg:
        return ("message is too long or holds a NUL", True)
    return run_git(["commit", "--no-verify", "--no-gpg-sign", "--no-edit", "--message=" + msg])


TOOLS = {
    "git_status": (tool_status, "Short git status with the branch.", {"type": "object", "properties": {}}),
    "git_diff": (tool_diff, "Diff of the whole work tree against the index, or the index against HEAD when staged is true.",
                 {"type": "object", "properties": {"staged": {"type": "boolean"}}}),
    "git_log": (tool_log, "One line per commit, newest first.",
                {"type": "object", "properties": {"count": {"type": "integer", "minimum": 1, "maximum": MAX_LOG}}}),
    "git_add": (tool_add, "Stage files by work-tree-relative path. No globs, no options.",
                {"type": "object", "required": ["paths"],
                 "properties": {"paths": {"type": "array", "items": {"type": "string"}, "minItems": 1, "maxItems": MAX_PATHS}}}),
    "git_commit": (tool_commit, "Commit the staged changes with this message. Conventional-commit grammar applies.",
                   {"type": "object", "required": ["message"], "properties": {"message": {"type": "string"}}}),
}


def reply(mid, result=None, error=None):
    m = {"jsonrpc": "2.0", "id": mid}
    if error is not None:
        m["error"] = error
    else:
        m["result"] = result
    sys.stdout.write(json.dumps(m) + "\n")
    sys.stdout.flush()


def handle(msg):
    mid = msg.get("id")
    method = msg.get("method")
    if method is None:
        return  # a response or noise: nothing to answer
    if mid is None:
        return  # a notification
    params = msg.get("params")
    if not isinstance(params, dict):
        params = {}
    if method == "initialize":
        want = params.get("protocolVersion")
        reply(mid, {"protocolVersion": want if want in PROTOCOL_VERSIONS else PROTOCOL_VERSIONS[0],
                    "capabilities": {"tools": {}}, "serverInfo": {"name": "loopgit", "version": "1"}})
    elif method == "ping":
        reply(mid, {})
    elif method == "tools/list":
        reply(mid, {"tools": [{"name": n, "description": d, "inputSchema": s} for n, (_f, d, s) in TOOLS.items()]})
    elif method == "tools/call":
        name = params.get("name")
        args = params.get("arguments")
        if name not in TOOLS:
            reply(mid, error={"code": -32602, "message": "unknown tool"})
            return
        if args is None:
            args = {}
        if not isinstance(args, dict):
            reply(mid, error={"code": -32602, "message": "arguments must be an object"})
            return
        try:
            text, is_err = TOOLS[name][0](args)
        except Exception as e:  # never let a tool take the server down
            text, is_err = ("tool failed: %s" % type(e).__name__, True)
        reply(mid, {"content": [{"type": "text", "text": text}], "isError": is_err})
    else:
        reply(mid, error={"code": -32601, "message": "method not found"})


def serve():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except ValueError:
            continue
        if isinstance(msg, dict):
            handle(msg)


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "--check-path":
        ok, v = check_path(sys.argv[2])
        print(("ok " if ok else "deny ") + v)
    else:
        serve()
