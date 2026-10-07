#!/bin/sh
# Fixture tests for scripts/loop/git_tools.py (issue #345): the fixed git tools the loop session
# gets in place of free-form git allows. Drives the MCP server over stdin in a throwaway repo.
#
# The point of the suite: the tools take values, never options, so each option route the #317
# critic pass found (--pathspec-from-file, commit -F, diff on a path outside the tree) has no
# way in. Permitted toolset: sh, git and python3 (skips if either is absent).
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
tools="$root_dir/scripts/loop/git_tools.py"
# A Windows python cannot open an MSYS /c/... path; cygpath -m gives it one (absent elsewhere).
tools="$(cygpath -m "$tools" 2>/dev/null || printf %s "$tools")"

py=
for c in python3 python; do
  if command -v "$c" >/dev/null 2>&1 && "$c" -c 'import sys; sys.exit(sys.version_info < (3, 8))' 2>/dev/null; then
    py=$c
    break
  fi
done
if [ -z "$py" ] || ! command -v git >/dev/null 2>&1; then
  echo "SKIP - no python3 or git on PATH; loop-git-tools fixtures not run" >&2
  exit 0
fi

export MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*'
tmp=$(mktemp -d)
tmp_py="$(cygpath -m "$tmp" 2>/dev/null || printf %s "$tmp")"
trap 'rm -rf "$tmp"' EXIT
repo="$tmp/work"
mkdir "$repo"
(
  cd "$repo"
  git init -q -b main .
  echo seed >README && git add README
  git -c user.name=t -c user.email=t@invalid commit -q -m seed
)
echo "SECRET-OUTSIDE" >"$tmp/secret.txt"

"$py" -I - "$tools" "$tmp_py/work" "$tmp_py/secret.txt" <<'PY'
import json, os, subprocess, sys
tools, repo, secret = sys.argv[1:4]
env = dict(os.environ, LOOP_WORKDIR=repo, GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@invalid",
           GIT_COMMITTER_NAME="t", GIT_COMMITTER_EMAIL="t@invalid")
p = subprocess.Popen([sys.executable, tools], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, env=env)
n = 0


def rpc(method, params=None, note=False):
    global n
    m = {"jsonrpc": "2.0", "method": method}
    if params is not None:
        m["params"] = params
    if not note:
        n += 1
        m["id"] = n
    p.stdin.write(json.dumps(m) + "\n")
    p.stdin.flush()
    return None if note else json.loads(p.stdout.readline())


def call(name, **args):
    r = rpc("tools/call", {"name": name, "arguments": args})
    if "error" in r:
        return True, "rpc-error " + r["error"]["message"]
    return r["result"]["isError"], r["result"]["content"][0]["text"]


fails = 0


def want(label, cond):
    global fails
    print(("ok   " if cond else "FAIL ") + label)
    fails += 0 if cond else 1


def git(*a):
    return subprocess.run(["git", "-C", repo] + list(a), capture_output=True, text=True).stdout


r = rpc("initialize", {"protocolVersion": "2025-06-18", "capabilities": {}, "clientInfo": {"name": "t", "version": "0"}})
want("initialize answers with the tools capability", r["result"]["capabilities"] == {"tools": {}})
rpc("notifications/initialized", note=True)
r = rpc("tools/list")
names = sorted(t["name"] for t in r["result"]["tools"])
want("the five fixed tools and nothing else", names == ["git_add", "git_commit", "git_diff", "git_log", "git_status"])
want("no tool schema takes a free-form flag or options field",
     all(set(t["inputSchema"].get("properties", {})) <= {"staged", "count", "paths", "message"} for t in r["result"]["tools"]))
want("unknown tool is an error", call("git_push")[0])
want("unknown method is an error", "error" in rpc("resources/list"))

for name, body in (("a.txt", "a\n"), ("b.txt", "b\n")):
    open(os.path.join(repo, name), "w").write(body)
os.makedirs(os.path.join(repo, "sub"))
open(os.path.join(repo, "sub", "c.txt"), "w").write("c\n")
err, out = call("git_status")
want("status lists the new files", not err and "a.txt" in out and "main" in out)

# the option routes from the #317 critic pass, and path tricks
for bad in ("--pathspec-from-file=" + secret, "-A", "--all", "-f", "../secret.txt", secret, "sub/../../secret.txt",
            ".git/config", "sub/../.git/HEAD", ".git", ":(top)a.txt", ":!a.txt", "@{u}", "~/x", "", "a\nb"):
    err, out = call("git_add", paths=[bad])
    want("git_add refuses %r" % bad, err and "refused" in out)
want("git_add refuses a string, not a list", call("git_add", paths="a.txt")[0])
want("git_add refuses an empty list", call("git_add", paths=[])[0])
want("nothing was staged by the refusals", git("diff", "--cached", "--name-only").strip() == "")
err, out = call("git_add", paths=["a.txt"], options=["--force"])
want("an unknown extra field is ignored, never run as an option", not err and git("diff", "--cached", "--name-only").strip() == "a.txt")

try:
    os.symlink(secret, os.path.join(repo, "link.txt"))
    linked = True
except OSError:
    linked = False  # no symlink right on this host: the fixture cannot run
if linked:
    err, out = call("git_add", paths=["link.txt"])
    want("git_add refuses a symlink that resolves outside the tree", err and "outside" in out)
else:
    print("SKIP git_add symlink fixture: no symlink right on this host")
err, out = call("git_add", paths=["*.txt"])
want("a glob is a literal path, not magic", err and "b.txt" not in git("diff", "--cached", "--name-only"))
err, out = call("git_add", paths=["b.txt", "sub/c.txt"])
staged = git("diff", "--cached", "--name-only").split()
want("git_add stages relative paths", not err and "b.txt" in staged and "sub/c.txt" in staged)

# commit: a message is a value, whatever it looks like
for bad in ("", "   ", None, 5):
    want("git_commit refuses message %r" % (bad,), call("git_commit", message=bad)[0])
err, out = call("git_commit", message="-F " + secret)
want("a message that looks like an option is committed as text", not err)
want("... and is the subject, not a file read", git("log", "-1", "--format=%s").strip() == "-F " + secret and "SECRET" not in git("log", "-1", "--format=%B"))
call("git_add", paths=["README"])
open(os.path.join(repo, "README"), "a").write("more\n")
call("git_add", paths=["README"])
err, out = call("git_commit", message="feat: x\n\nbody --amend")
want("a multi-line message is kept", not err and "body --amend" in git("log", "-1", "--format=%B"))
want("git_commit refuses with nothing staged", call("git_commit", message="empty")[0])

# diff and log take no path
want("git_diff reads the work tree", not call("git_diff", staged=False)[0])
want("git_diff refuses a non-boolean staged", call("git_diff", staged="--no-index /x /y")[0])
err, out = call("git_log", count=2)
want("git_log lists commits", not err and "feat: x" in out)
for bad in (0, 51, -1, "5", True, 2.5):
    want("git_log refuses count %r" % (bad,), call("git_log", count=bad)[0])

# a hook in the repo does not run
hook = os.path.join(repo, ".git", "hooks", "post-commit")  # --no-verify skips pre-commit only: this guards hooksPath
marker = os.path.join(os.path.dirname(secret), "hook-ran")
open(hook, "w").write("#!/bin/sh\ntouch '%s'\nexit 0\n" % marker.replace("\\", "/"))
os.chmod(hook, 0o755)
open(os.path.join(repo, "d.txt"), "w").write("d\n")
call("git_add", paths=["d.txt"])
call("git_commit", message="chore: d")
want("a repo hook does not run", not os.path.exists(marker))

p.stdin.close()
p.wait(timeout=10)
want("the server exits cleanly on EOF", p.returncode == 0)
sys.exit(1 if fails else 0)
PY
