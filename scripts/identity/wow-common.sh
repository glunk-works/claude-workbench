# Shared helpers for wow-admin, wow-preflight, wow-readback, wow-review, wow-review-poll and wow-review-mint (WB-D24, issues #374, #635, #1383, #1414). Sourced, not run.
#
# Host layout, under $WOW_HOME (default ~/.config/glunk-identity):
#   apps.json              {"admin": {app_id, client_id, installation_id, bot_user_id, key},
#                           "review": {...}, ...}; entries are keyed by role, the suffix after the last
#                           dash of the App's name (<org>-admin, <org>-review, <org>-dev), so any
#                           org's config reads the same; "key" is a PEM filename in this directory
#   admin.enc.pem          the admin App's private key, passphrase-encrypted (name by convention)
#   review.pem             the reviewer App's private key, unencrypted (minted on request)
#   tokens-root            optional (#1568): a regular file whose content is exactly the word default-home (one LF or CRLF may follow); the default home itself, reached through a link or written in another letter case, takes none.
#                          It moves this home's tokens/ to the default identity home's tokens/ (~/.config/glunk-identity/tokens), so a
#                          second org's home delivers its tokens where the shared dev-container template mounts them. Any other state
#                          (other content, empty, a symbolic link, a directory, HOME empty, or the file in the default home itself) is a refusal,
#                          never a fall-back. Absent: the home's own tokens/.
#   tokens/<owner>/<repo>/ (under the tokens root) the one directory of secrets a repo's container may mount, read-only: admin-token
#                          (wow-admin) and dev-token (broker.ps1), each the token then its expires_at.
#                          Admin and dev credentials only (#1276, #1340).
#   tokens/<repo>/         the layout before #1340, in a home without tokens-root: nothing writes it now, and only wow-admin --revoke removes a file in it; a leftover the maintainer removes
#                          (after wow-admin <owner/name> --revoke finds no readable admin token in it and no admin-token file is there). A home with tokens-root never looks there.
#   dev.pem, broker.json   broker.ps1 config: the dev App's unencrypted key (name by convention), and
#                          {"repos": [...]}, the repos it keeps a dev token for. Also broker.lock,
#                          broker.log and staging/<repo>/, none mounted anywhere.
#   review-tokens/<repo>/  reviewer-token, in the same format. Never mounted into a dev
#                          container: the reviewer is a different identity from the PR's author.
#   bin/                   the installed copies of these scripts (install-host-tools.ps1, from
#                          committed code on origin/main, with a MANIFEST); the broker task and the
#                          human commands run from here, never from a checkout a container can write.
#   bin/review/            the review image's build context (#634), exported with the scripts: the
#                          Dockerfile plus exactly the files it copies.
#   review-sessions/<id>/  only session-token, mounted read-only into a review container (the one directory
#                          the broker sweeps).
#   review-host/<id>/      wow-review's working files, never mounted: the project.yml copy, the outbox
#                          copies, every kept copy of the session token, and its read-token, post-token
#                          and filing-token, and the transient staged session log. Removed by the launcher's trap.
#   driver/<leaf>.json     wow-driver.ps1's record of the container it started for the clone <leaf>: {id, commit,
#                          clone, origin, reference}. Never mounted.
#   review-state/          wow-review's lock and its dedupe ledger (<owner>/<name>/<N>/<sha>/).
#   review-state/.home-key  the home's container-label key (wow.review.home), never to be removed while that home has containers, networks or volumes.
#   review-state/.live/<id>  a live run's lease (wow-review), touched every 60 seconds while its launcher lives; the overdue sweep
#                          leaves a container whose run's lease is under 5 minutes old. Removed by the launcher's trap.
#   review-poll.json       {"repos": ["owner/name", ...]}, the repos wow-review-poll polls (the maintainer writes it).
#   review-poll.log        wow-review-poll's decision log, rotated to review-poll.log.1 past 1 MiB.
#   review-state/.poll-lock  wow-review-poll's own lock directory, separate from wow-review's .lock.
#   review-host/poll-<id>/ wow-review-poll's working files and its session token, never mounted. Removed by its trap.
#   claude-credential      the Claude setup-token credential, one line; read only by wow-review and
#                          written only to the injector sidecar's stdin.
#   review-logs/           review run logs; may hold secrets and private contents the session read, swept by the
#                          broker by age.
# Invariant: no path under $WOW_HOME is container-writable. The tokens root is the home's own tokens/ or the default home's
# (tokens-root); the cross-entry rules (no shared name half, no owner equal to another entry's name) are checked within one home's
# broker.json only, never across two homes sharing a root. tokens/<owner>/<repo>/ is
# mounted only into a dev container (for the repos listed in broker.json, tokens/<owner>/ is never another repo's mount source; wow-admin's owner half is checked against the admin installation's account at mint), and
# review-sessions/<id>/ only into a review container, each read-only.
# claude-credential is never mounted into any container and reaches only the injector's stdin.
# What these commands write: tokens/ (under the tokens root) and review-tokens/ directories, a per-repo-name .admin-lock.<name> directory directly under $WOW_HOME
# (in a home with tokens-root, made in the default home instead) and a transient .unlock.* directory (both removed on exit), admin-token (replaced or removed under the root's <owner>/<repo>/;
# only a home without tokens-root has wow-admin --revoke also remove a leftover tokens/<repo>/admin-token),
# reviewer-token (default review-tokens/<repo>/, or the path --out names), the session and filing
# tokens (wow-review-mint --read / --file, written only to the path --out names), and the .mint.* file
# mint.sh stages beside any token it writes. wow-review (the launcher) also writes its own review-sessions/,
# review-host/, review-state/ (its lock, ledger and .live/ lease files) and review-logs/ entries. wow-review-poll writes review-poll.log (and .1),
# review-state/.poll-lock and review-host/poll-<id>/. wow-driver.ps1 writes driver/<leaf>.json and its same-directory
# temp file. wow-preflight writes nothing under $WOW_HOME: it only reads <tokens root>/<owner>/<repo>/admin-token. wow-readback likewise writes nothing under it and only reads that admin-token and apps.json. Nothing else under $WOW_HOME is modified.
#
# The caller sets $prog before sourcing. Toolset: POSIX sh, jq, plus what mint.sh needs.

LC_ALL=C; export LC_ALL

wow_home=${WOW_HOME:-${HOME:-}/.config/glunk-identity}

die() { echo "$prog: $1" >&2; exit "${2:-1}"; }

# app_get <app> <field>: a bare value (letters, digits, . _ -) from apps.json, or empty.
# <app> and <field> are fixed words from the caller, never user input.
app_get() {
  [ -r "$wow_home/apps.json" ] || return 0
  v=$(jq -r --arg a "$1" --arg f "$2" '.[$a][$f] // empty' "$wow_home/apps.json" 2>/dev/null | tr -d '\r') || return 0
  case "$v" in *[!A-Za-z0-9._-]*) return 0 ;; esac
  printf '%s\n' "$v"
}

# app_key <app>: the App's PEM path. Its "key" must be a bare filename in $wow_home.
app_key() {
  k=$(app_get "$1" key)
  case "$k" in ''|.|..|-*) return 0 ;; esac
  printf '%s\n' "$wow_home/$k"
}

# The repo becomes a directory name and a --repos element: plain characters only, no leading
# dash or dot-only name.
check_repo() {
  case "$1" in
    ''|.|..|-*|*[!A-Za-z0-9._-]*) die "repository must be a bare name of letters, digits, . _ -" 2 ;;
  esac
}

# resolve_tokens_root: sets tokens_root (the directory holding <owner>/<repo>) and tokens_shared (1 when
# the home's tokens-root file is present, else empty). Dies on any refusal state (#1568).
tokens_root= tokens_shared=
resolve_tokens_root() {
  tokens_root=$wow_home/tokens tokens_shared=
  f=$wow_home/tokens-root
  [ -e "$f" ] || [ -L "$f" ] || return 0
  msg="the file $f must be a regular file holding exactly default-home"
  [ ! -L "$f" ] && [ -f "$f" ] || die "$msg"
  [ -n "${HOME:-}" ] || die "$msg, and HOME is empty, so the default home cannot be found"
  dh=$HOME/.config/glunk-identity
  # the default home itself: equal paths, or equal after every link is followed (cd -P), either ignoring ASCII letter case
  lc_a=$(printf '%s' "$wow_home" | tr 'A-Z' 'a-z' | sed 's#//*#/#g; :a; s#/\./#/#; ta; s#/\.$##; s#/$##') lc_b=$(printf '%s' "$dh" | tr 'A-Z' 'a-z' | sed 's#//*#/#g; :a; s#/\./#/#; ta; s#/\.$##; s#/$##')
  rp_a=$(CDPATH= cd -P -- "$wow_home" 2>/dev/null && pwd | tr 'A-Z' 'a-z') || :
  rp_b=$(CDPATH= cd -P -- "$dh" 2>/dev/null && pwd | tr 'A-Z' 'a-z') || :
  if [ "$lc_a" = "$lc_b" ] || { [ -n "$rp_a" ] && [ "$rp_a" = "$rp_b" ]; }; then
    die "$msg, and the default home itself takes no tokens-root file"
  fi
  # the trailing x keeps every final newline, which a bare $(cat) would strip; the byte count refuses a NUL
  # byte, which command substitution drops (pwsh compares the bytes exactly)
  n=$(wc -c <"$f" | tr -d ' ')
  c=$(cat -- "$f"; echo x)
  c=${c%x}
  nl='
'
  cr=$(printf '\r')
  case "$n:$c" in
    "12:default-home" | "13:default-home$nl" | "14:default-home$cr$nl") ;;
    *) die "$msg" ;;
  esac
  tokens_root=$dh/tokens tokens_shared=1
}

# token_dir <tokens|review-tokens> <repo>: create (private) and print that repo's token directory.
token_dir() {
  case "$1" in
    tokens) [ -n "$tokens_root" ] || resolve_tokens_root; d="$tokens_root/$2" ;;
    *) d="$wow_home/$1/$2" ;;
  esac
  (umask 077 && mkdir -p -- "$d") || die "cannot create $d"
  printf '%s\n' "$d"
}
