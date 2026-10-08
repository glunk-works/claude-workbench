#!/bin/sh
# Fixture tests for scripts/loop/critic.sh (issue #321).
#
# Hermetic: a throwaway origin and clone for the bundle, hand-built stream-json files for the
# init check, and a stub `claude` on PATH for the launch line. No network, no gh, no model call.
#
# Permitted toolset: POSIX sh, its standard utilities, bash (the script is bash), git, jq.
set -eu

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
script="$root_dir/scripts/loop/critic.sh"

for tool in jq bash git; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "SKIP - $tool not on PATH; critic fixtures not run" >&2
    exit 0
  fi
done
if ! echo '#1' | grep -P '#1' >/dev/null 2>&1; then
  echo "SKIP - grep -P not available; critic fixtures not run" >&2
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0

# Nothing in this script may call gh: a stub on PATH from the start records any call.
mkdir "$tmp/bin"
printf '#!/bin/sh\necho "gh must not run" >&2\ntouch "%s/gh-ran"\nexit 1\n' "$tmp" >"$tmp/bin/gh"
chmod +x "$tmp/bin/gh"
PATH="$tmp/bin:$PATH"

assert_eq() {
  if [ "$2" = "$3" ]; then echo "ok - $1"; else echo "FAIL - $1: expected [$2], got [$3]" >&2; fail=1; fi
}
assert_has() { # desc, haystack, needle
  case "$2" in *"$3"*) echo "ok - $1" ;; *) echo "FAIL - $1: [$2] lacks [$3]" >&2; fail=1 ;; esac
}
assert_lacks() {
  case "$2" in *"$3"*) echo "FAIL - $1: [$2] has [$3]" >&2; fail=1 ;; *) echo "ok - $1" ;; esac
}

# run <args...>: stdout and exit code in $out and $rc
run() { set +e; out=$(bash "$script" "$@" 2>"$tmp/err"); rc=$?; set -e; }

# --- the repo the bundle is staged from ------------------------------------------------------
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
g() { git -c commit.gpgsign=false -c core.autocrlf=false "$@"; }

mkdir "$tmp/origin"
(
  cd "$tmp/origin"
  g init -q -b main .
  printf 'base a\n' >a.txt
  printf 'base doc cites #5\n' >DECISIONS.md
  printf 'untouched doc cites #77\n' >README.md
  mkdir scripts
  printf 'echo base\n' >scripts/x.sh
  yes xxxxxxxxx | head -c 1100000 >big.txt   # many short lines: the later append is a small diff hunk
  g add -A
  g commit -q -m "feat: base"
)
g clone -q "$tmp/origin" "$tmp/work"
(
  cd "$tmp/work"
  g checkout -q -b task/demo
  printf 'changed a\n' >a.txt
  printf 'new b\n' >b.txt
  printf 'base doc cites #5\nand #12, acme/other#7, https://github.com/glunk-works/claude-workbench/pull/99, &#123; and a#b\n' >DECISIONS.md
  printf 'echo changed # see #8\n' >scripts/x.sh
  printf 'bigger\n' >>big.txt
  g add -A
  g commit -q -m "feat: the change"
)

printf 'gate says all green\n' >"$tmp/gate.txt"
printf 'fixtures: 3 passed\n' >"$tmp/fix.txt"
printf '[{"name":"lint","conclusion":"success"}]\n' >"$tmp/ci.json"
printf '[{"id":1,"name":"restrict-updates"}]\n' >"$tmp/rules.json"
cat >"$tmp/refs.json" <<'EOF'
[{"id":"#12","state":"open"},{"id":"glunk-works/claude-workbench#99","state":"merged"},{"id":"#8","state":"banana"},{"id":"#5","state":"closed"}]
EOF

bundle() { # out [extra args...]
  o=$1; shift
  run bundle --clone "$tmp/work" --base main --out "$o" --gate-output "$tmp/gate.txt" \
    --fixture-output "$tmp/fix.txt" --ci-jobs "$tmp/ci.json" --ruleset "$tmp/rules.json" \
    --load-bearing-doc DECISIONS.md --load-bearing-doc README.md "$@"
}

# --- bundle ----------------------------------------------------------------------------------
bundle "$tmp/b1" --ref-states "$tmp/refs.json"
assert_eq "bundle: exit 0" 0 "$rc"
assert_has "bundle: staged line" "$out" "staged "
B="$tmp/b1"
assert_has "bundle: the diff carries the new file" "$(cat "$B/diff.patch")" "+new b"
assert_has "bundle: the diff carries the change" "$(cat "$B/diff.patch")" "+changed a"
assert_eq "bundle: base copy of a touched file is the base content" "base a" "$(cat "$B/base/a.txt")"
assert_eq "bundle: no base copy of an added file" no "$([ -e "$B/base/b.txt" ] && echo yes || echo no)"
assert_eq "bundle: base copy in a subdirectory" "echo base" "$(cat "$B/base/scripts/x.sh")"
assert_has "bundle: log has the branch commit" "$(cat "$B/log.txt")" "feat: the change"
assert_has "bundle: log has the base commit" "$(cat "$B/log.txt")" "feat: base"
assert_eq "bundle: gate output headed untrusted" "UNTRUSTED" "$(head -n 1 "$B/untrusted/gate-output.txt" | cut -c1-9)"
assert_has "bundle: gate output kept" "$(cat "$B/untrusted/gate-output.txt")" "gate says all green"
assert_has "bundle: fixture output kept" "$(cat "$B/untrusted/fixture-output.txt")" "fixtures: 3 passed"
assert_eq "bundle: ci jobs copied" "$(jq -c . "$tmp/ci.json")" "$(jq -c . "$B/ci-jobs.json")"
assert_eq "bundle: ruleset copied" "$(jq -c . "$tmp/rules.json")" "$(jq -c . "$B/ruleset.json")"
refs="$(cat "$B/refs.md")"
assert_has "refs: an open id carries its state" "$refs" "- #12: open"
assert_has "refs: a cross-repo URL becomes owner/repo#N" "$refs" "- glunk-works/claude-workbench#99: merged"
assert_has "refs: a doc id from a touched load-bearing doc" "$refs" "- #5: closed"
assert_has "refs: a state outside the vocabulary is not carried" "$refs" "- #8: NOT CARRIED"
assert_has "refs: an id with no state is not carried" "$refs" "- acme/other#7: NOT CARRIED -- could not look"
assert_lacks "refs: an untouched load-bearing doc is not read" "$refs" "#77"
assert_lacks "refs: an HTML entity is not an id" "$refs" "#123"
assert_has "manifest: oversized base file left out, said so" "$(cat "$B/MANIFEST.md")" "big.txt: skipped"
assert_has "manifest: untrusted files labelled" "$(cat "$B/MANIFEST.md")" "UNTRUSTED"

bundle "$tmp/b2"
assert_eq "bundle without ref-states: exit 0" 0 "$rc"
refs="$(cat "$tmp/b2/refs.md")"
assert_has "no ref-states: every id is not carried" "$refs" "- #12: NOT CARRIED -- could not look"
assert_lacks "no ref-states: nothing reads as a state" "$refs" ": open"

bundle "$tmp/b3" --base nosuchbranch
assert_eq "unknown base: exit 3" 3 "$rc"
assert_has "unknown base: refused base" "$out" "refused base:"

printf 'not json' >"$tmp/bad.json"
run bundle --clone "$tmp/work" --base main --out "$tmp/b4" --gate-output "$tmp/gate.txt" \
  --fixture-output "$tmp/fix.txt" --ci-jobs "$tmp/bad.json" --ruleset "$tmp/rules.json"
assert_eq "unparseable ci-jobs: exit 3" 3 "$rc"
assert_has "unparseable ci-jobs: refused input" "$out" "refused input:"

printf '{"id":"#1"}' >"$tmp/badrefs.json"
bundle "$tmp/b5" --ref-states "$tmp/badrefs.json"
assert_eq "ref-states not an array: exit 3" 3 "$rc"

mkdir "$tmp/full"; : >"$tmp/full/x"
bundle "$tmp/full"
assert_eq "non-empty --out: usage fault" 2 "$rc"

run bundle --clone "$tmp/work" --base main --out "$tmp/b6" --gate-output "$tmp/nope" \
  --fixture-output "$tmp/fix.txt" --ci-jobs "$tmp/ci.json" --ruleset "$tmp/rules.json"
assert_eq "missing gate output: usage fault, not an empty file" 2 "$rc"

# --- the pinned plugin copy and the init event -----------------------------------------------
P="$tmp/plug"
mkdir -p "$P/.claude-plugin" "$P/agents"
printf '{"name":"wow","version":"1.2.3"}\n' >"$P/.claude-plugin/plugin.json"
printf -- '---\nname: architect\ndescription: x\nmodel: opus\ntools: Read, Bash, Grep, Glob\n---\nbody\n' >"$P/agents/architect.md"
printf -- '---\nname: exact\nmodel: claude-haiku-4-5-20251001\ntools: Read, Grep\n---\nbody\n' >"$P/agents/exact.md"
printf -- '---\nname: blind\nmodel: opus\ntools: Bash, Edit\n---\nbody\n' >"$P/agents/blind.md"

good_init() { # model [tools-json]
  jq -nc --arg m "$1" --arg p "$P" --argjson t "${2:-[\"Read\",\"Grep\",\"Glob\"]}" \
    '{type:"system",subtype:"init",model:$m,tools:$t,agents:["wow:architect","wow:exact","wow:blind"],
      plugins:[{name:"wow",path:$p,source:"wow@inline",version:"1.2.3"},{name:"cc-plugin-sec-default",path:"/builtin"}]}'
}
check() { # name critic   (stream in $tmp/s)
  run check-init --stream "$tmp/s" --plugin-dir "$P" --critic "$1"
}

good_init claude-opus-5-5 >"$tmp/s"; check architect
assert_eq "init match: exit 0" 0 "$rc"; assert_eq "init match: loaded" "loaded architect" "$out"

{ echo 'a progress line that is not json'; good_init claude-opus-5-5; echo '{"type":"result"}'; } >"$tmp/s"; check architect
assert_eq "init after a junk line: loaded" "loaded architect" "$out"

good_init claude-sonnet-5-5 >"$tmp/s"; check architect
assert_eq "wrong model: exit 3" 3 "$rc"; assert_has "wrong model: refused init" "$out" "refused init: model is [claude-sonnet-5-5]"

good_init claude-opus-5-5 | jq -c '.plugins = [.plugins[1]]' >"$tmp/s"; check architect
assert_eq "missing plugin: exit 3" 3 "$rc"; assert_has "missing plugin: refused init" "$out" "refused init: the pinned plugin wow"

good_init claude-opus-5-5 | jq -c '.plugins[0].path = "/somewhere/else"' >"$tmp/s"; check architect
assert_eq "plugin from another path: exit 3" 3 "$rc"

good_init claude-opus-5-5 | jq -c '.plugins[0].version = "9.9.9"' >"$tmp/s"; check architect
assert_eq "plugin of another version: exit 3" 3 "$rc"

good_init claude-opus-5-5 | jq -c '.plugins[0].path += "/"' >"$tmp/s"; check architect
assert_eq "plugin path with a trailing slash still matches" 0 "$rc"

good_init claude-opus-5-5 '["Read","Bash","Grep","Glob"]' >"$tmp/s"; check architect
assert_eq "Bash present: exit 3" 3 "$rc"; assert_has "Bash present: names the tools" "$out" "tools are [Bash,Glob,Grep,Read]"

good_init claude-opus-5-5 '["Read","Grep"]' >"$tmp/s"; check architect
assert_eq "a tool missing: exit 3" 3 "$rc"

good_init claude-opus-5-5 | jq -c '.agents = ["wow:coder"]' >"$tmp/s"; check architect
assert_eq "agent missing: exit 3" 3 "$rc"; assert_has "agent missing: refused init" "$out" "agent wow:architect"

good_init claude-opus-5-5 | jq -c '.plugin_errors = ["could not load"]' >"$tmp/s"; check architect
assert_eq "plugin_errors: exit 3" 3 "$rc"

printf '{"type":"result","is_error":false}\n' >"$tmp/s"; check architect
assert_eq "no init event: exit 3" 3 "$rc"; assert_has "no init event: refused no-init" "$out" "refused no-init:"

: >"$tmp/s"; check architect
assert_eq "empty stream: exit 3" 3 "$rc"

good_init claude-haiku-4-5-20251001 '["Read","Grep"]' >"$tmp/s"; check exact
assert_eq "exact model id, tools a subset of the staged list: loaded" "loaded exact" "$out"
good_init claude-haiku-4-5 '["Read","Grep"]' >"$tmp/s"; check exact
assert_eq "exact model id differs: exit 3" 3 "$rc"

good_init claude-opus-5-5 >"$tmp/s"; check blind
assert_eq "frontmatter tools share nothing with the staged list: exit 3" 3 "$rc"

run check-init --stream "$tmp/s" --plugin-dir "$P" --critic "../architect"
assert_eq "path-shaped critic name: usage fault" 2 "$rc"

# --- run, against a stub claude --------------------------------------------------------------
mkdir "$tmp/clone-for-run"
cat >"$tmp/bin/claude" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" >"$STUB_ARGS"
pwd >"$STUB_CWD"
echo $$ >"$STUB_PID"
[ -z "${STUB_STREAM:-}" ] || cat "$STUB_STREAM"
[ -z "${STUB_HANG:-}" ] || exec sleep 30
exit "${STUB_RC:-0}"
EOF
chmod +x "$tmp/bin/claude"
export STUB_ARGS="$tmp/stub.args" STUB_CWD="$tmp/stub.cwd" STUB_PID="$tmp/stub.pid"
printf '{"type":"object"}\n' >"$tmp/schema.json"

go() { # extra args
  rm -f "$STUB_ARGS" "$STUB_CWD" "$STUB_PID"
  run run --clone "$tmp/clone-for-run" --plugin-dir "$P" --critic architect --bundle "$B" \
    --stream-out "$tmp/stream.out" --max-turns 7 --max-budget-usd 1.5 --settings-json '{"env":{}}' \
    --schema-file "$tmp/schema.json" --task "review the diff" "$@"
}

good_init claude-opus-5-5 >"$tmp/good.stream"
export STUB_STREAM="$tmp/good.stream"
go
assert_eq "run: exit 0" 0 "$rc"; assert_eq "run: completed" "completed architect" "$out"
args="$(cat "$STUB_ARGS")"
pair() { # flag value: the value is the very next argument after the flag
  if printf '%s\n' "$args" | awk -v f="$1" -v v="$2" 'prev == f && $0 == v { ok = 1 } { prev = $0 } END { exit !ok }'; then
    echo "ok - run: $1 is followed by its value"
  else echo "FAIL - run: $1 not followed by [$2]" >&2; fail=1; fi
}
for a in -p --restricted --strict-mcp-config --verbose; do
  assert_eq "run: argv has $a as an argument of its own" 1 "$(printf '%s\n' "$args" | grep -cFx -- "$a")"
done
pair --agent wow:architect
pair --plugin-dir "$P"
pair --tools Read,Grep,Glob
pair --model opus
pair --add-dir "$B"
pair --max-turns 7
pair --max-budget-usd 1.5
pair --permission-mode dontAsk
pair --permission-prompts none
pair --output-format stream-json
pair --settings '{"env":{}}'
pair --json-schema '{"type":"object"}'
assert_eq "run: the task is the last argument" "review the diff" "$(printf '%s\n' "$args" | tail -n 1)"
assert_eq "run: no tool list in the argv names Bash" 0 "$(printf '%s
' "$args" | grep -cE '^[A-Za-z,]*Bash[A-Za-z,]*$' || true)"
assert_has "run: the addendum says staged mode" "$args" "staged mode"
assert_has "run: the addendum says could not look, never dangling" "$args" "could not look"
assert_eq "run: launched from inside the clone" "$(cd "$tmp/clone-for-run" && pwd)" "$(cat "$STUB_CWD")"

# a mismatched init: the session is killed before it can do anything, not left to finish
good_init claude-opus-5-5 '["Read","Bash","Grep","Glob"]' >"$tmp/bad.stream"
export STUB_STREAM="$tmp/bad.stream" STUB_HANG=1
start=$(date +%s)
go
elapsed=$(( $(date +%s) - start ))
assert_eq "run, Bash loaded: exit 3" 3 "$rc"
assert_has "run, Bash loaded: refused init" "$out" "refused init:"
[ "$elapsed" -lt 20 ] && echo "ok - run, Bash loaded: refused at once, not after the session" || { echo "FAIL - run, Bash loaded: took ${elapsed}s" >&2; fail=1; }
if kill -0 "$(cat "$STUB_PID")" 2>/dev/null; then echo "FAIL - run, Bash loaded: the session is still running" >&2; fail=1; kill "$(cat "$STUB_PID")" 2>/dev/null || true; else echo "ok - run, Bash loaded: the session was killed"; fi

# no init at all within the timeout
unset STUB_STREAM
start=$(date +%s)
go --init-timeout 1
elapsed=$(( $(date +%s) - start ))
assert_eq "run, no init event: exit 3" 3 "$rc"; assert_has "run, no init event: refused no-init" "$out" "refused no-init:"
[ "$elapsed" -lt 15 ] && echo "ok - run, no init event: gave up at the timeout" || { echo "FAIL - run, no init event: took ${elapsed}s" >&2; fail=1; }
kill "$(cat "$STUB_PID")" 2>/dev/null || true
unset STUB_HANG

# a good init, then claude fails
export STUB_STREAM="$tmp/good.stream" STUB_RC=1
go
assert_eq "run, claude exits 1 after a good init: exit 3" 3 "$rc"; assert_has "run, claude exits 1: refused exit" "$out" "refused exit:"
unset STUB_RC

# relative paths are resolved where the caller stands, never inside the clone under review
mkdir -p "$tmp/caller" "$tmp/clone-for-run/rel"
printf '{"from":"CLONE-PLANTED"}
' >"$tmp/clone-for-run/schema.json"
cp "$tmp/schema.json" "$tmp/caller/schema.json"
cp -R "$B" "$tmp/caller/bun"
mkdir -p "$tmp/clone-for-run/bun"; cp "$B/MANIFEST.md" "$tmp/clone-for-run/bun/"
rm -f "$STUB_ARGS"
set +e
out=$(cd "$tmp/caller" && bash "$script" run --clone "$tmp/clone-for-run" --plugin-dir "$P" --critic architect   --bundle bun --stream-out "$tmp/stream.out" --max-turns 7 --max-budget-usd 1.5 --settings-json '{}'   --schema-file schema.json --task t 2>"$tmp/err"); rc=$?
set -e
args="$(cat "$STUB_ARGS")"
assert_eq "run, relative paths: completed" "completed architect" "$out"
pair --add-dir "$tmp/caller/bun"
assert_lacks "run, relative paths: the clone's planted schema is not used" "$args" "CLONE-PLANTED"

# settings that run commands, and a plugin copy inside the clone, are refused before launch
for k in hooks apiKeyHelper statusLine permissions; do
  go --settings-json "{\"$k\":{}}" 2>/dev/null || true
  assert_eq "run with settings key $k: usage fault" 2 "$rc"
done
mkdir -p "$tmp/clone-for-run/inside"; cp -R "$P" "$tmp/clone-for-run/inside/plug"
run run --clone "$tmp/clone-for-run" --plugin-dir "$tmp/clone-for-run/inside/plug" --critic architect --bundle "$B"   --stream-out "$tmp/stream.out" --max-turns 7 --max-budget-usd 1.5 --settings-json '{}'   --schema-file "$tmp/schema.json" --task t
assert_eq "run with the plugin inside the clone: usage fault" 2 "$rc"

# a session that outlives --run-timeout is stopped
export STUB_STREAM="$tmp/good.stream" STUB_HANG=1
start=$(date +%s)
go --run-timeout 1
elapsed=$(( $(date +%s) - start ))
assert_eq "run past the run timeout: exit 3" 3 "$rc"; assert_has "run past the run timeout: refused timeout" "$out" "refused timeout:"
[ "$elapsed" -lt 20 ] && echo "ok - run timeout: returned promptly" || { echo "FAIL - run timeout took ${elapsed}s" >&2; fail=1; }
kill "$(cat "$STUB_PID")" 2>/dev/null || true
unset STUB_HANG

# usage faults
run run --clone "$tmp/clone-for-run" --plugin-dir "$P" --critic architect --bundle "$tmp/clone-for-run" \
  --stream-out "$tmp/stream.out" --max-turns 7 --max-budget-usd 1.5 --settings-json '{}' \
  --schema-file "$tmp/schema.json" --task t
assert_eq "run on a directory that is not a bundle: usage fault" 2 "$rc"
go --settings-json 'not json' 2>/dev/null || true
assert_eq "run with non-JSON settings: usage fault" 2 "$rc"

cp "$tmp/schema.json" "$tmp/clone-for-run/own-schema.json"
run run --clone "$tmp/clone-for-run" --plugin-dir "$P" --critic architect --bundle "$B" \
  --stream-out "$tmp/stream.out" --max-turns 7 --max-budget-usd 1.5 --settings-json '{}' \
  --schema-file "$tmp/clone-for-run/own-schema.json" --task t
assert_eq "run with the schema file inside the clone: usage fault" 2 "$rc"
assert_has "run with the schema file inside the clone: says so" "$(cat "$tmp/err")" "--schema-file is inside the clone"

# killing the script stops the session it started (a signal no longer reaches it by group)
rm -f "$STUB_PID"
export STUB_STREAM="$tmp/good.stream" STUB_HANG=1
bash "$script" run --clone "$tmp/clone-for-run" --plugin-dir "$P" --critic architect --bundle "$B" \
  --stream-out "$tmp/stream.out" --max-turns 7 --max-budget-usd 1.5 --settings-json '{}' \
  --schema-file "$tmp/schema.json" --task t >/dev/null 2>&1 &
cpid=$!
n=0; while [ ! -s "$STUB_PID" ] && [ "$n" -lt 100 ]; do sleep 0.2; n=$((n + 1)); done
sleep 1
kill -TERM "$cpid" 2>/dev/null || true
wait "$cpid" 2>/dev/null || true
sleep 1
if kill -0 "$(cat "$STUB_PID")" 2>/dev/null; then echo "FAIL - terminating critic.sh left the session running" >&2; fail=1; kill -KILL "$(cat "$STUB_PID")" 2>/dev/null || true; else echo "ok - terminating critic.sh stops the session"; fi
unset STUB_HANG

assert_eq "no gh was run anywhere in this suite" no "$([ -e "$tmp/gh-ran" ] && echo yes || echo no)"

[ "$fail" -eq 0 ] && echo "all critic fixtures passed" || { echo "critic fixtures FAILED" >&2; exit 1; }
