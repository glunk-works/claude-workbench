#!/usr/bin/env bash
# Driver preflight evaluators: pure checks over captured JSON, so each can be fixture-tested.
#
# Issue #320, plan v9 § 7.3 ("The driver's preflight") and decision 9 of
# docs/proposals/orchestrator-m2-decisions.md. Nothing here runs docker or gh: the driver
# captures the JSON and hands it over as files, and this script only judges it. That is what
# makes the live run (M2b) a separate piece of work from the rules.
#
# Usage:
#   preflight.sh container --session FILE --network FILE --expect-network NAME --proxy FILE...
#       FILE for --session   `docker inspect <session container>` (created, not started, is fine)
#       FILE for --network   `docker network inspect <the internal network>`
#       FILE for --proxy     `docker inspect <a proxy container>`; repeatable, at least one
#
#   preflight.sh github-dispatch --rules FILE --rulesets FILE --app-id N --identities FILE \
#       --issue FILE --issue-number N (--spec-comment FILE --spec-comment-id N | --no-spec-comment)
#       Run at dispatch, with the maintainer's read-only view.
#       FILE for --rules     `GET /repos/R/rules/branches/{pr_base}` (the rules that apply, each
#                            carrying its ruleset_id)
#       FILE for --rulesets  a JSON array of `GET /repos/R/rulesets/{id}` for every ruleset id
#                            in --rules (the list endpoint does not carry bypass_actors)
#       --issue/--spec-comment  the task issue and the anchored spec comment, as fetched
#       FILE for --identities  the `identities` value of .ai/project.yml on the DEFAULT branch,
#                            as one JSON document: null before the repo cuts over, a map
#                            after. Produce it with `yq -o=json 'select(has("identities")) |
#                            .identities'`, NOT a bare `.identities`: an ABSENT key is the
#                            unanswered question, and that form prints nothing for it (an
#                            empty file, unreadable) where the bare form prints `null` and
#                            would read as "not cut over". Required: a driver that does not
#                            say which model it trusts by is not asked to guess one.
#
#   preflight.sh github-push --installation FILE --repo OWNER/NAME --rules FILE --rulesets FILE \
#       --app FILE --loop-identity LOGIN
#       Run after the token is minted, with the token's own view.
#       FILE for --installation  `GET /installation/repositories`
#       FILE for --rulesets      as above, fetched with the minted token (that is what makes
#                                current_user_can_bypass describe the App)
#       FILE for --app           `GET /app` (the slug; the bot login is slug + "[bot]")
#       --loop-identity          orchestration.loop_identity; "-" for null, which refuses
#
# Output, on stdout, one line per finding:
#   pass                          exit 0, only when nothing was found
#   refused <rule>: <detail>      exit 3, the input says the check fails
#   unreadable <rule>: <detail>   exit 3, the input cannot say (missing field, a file that does
#                                 not parse, a truncated list); unknown is never a pass
#   (a usage fault is a message on stderr and exit 2)
#
# Rules:
#   container       User (and its group) non-root; ReadonlyRootfs; CapDrop has ALL and CapAdd is
#                   empty; not privileged; no host PID/IPC/UTS/user namespace, no Devices, no
#                   unconfined SecurityOpt; NetworkMode is --expect-network and the session is
#                   attached to no other network; every mount is a named volume or a tmpfs (a
#                   bind of any host path is refused, as launch.sh does) and none names /mnt,
#                   Docker Desktop's mount roots, a drive letter or a docker socket or pipe, and
#                   HostConfig.Binds is empty; the network is that name, Internal, IPv6 off,
#                   gateway_mode_ipv4=isolated and has no IPAM Gateway on any entry; every
#                   --proxy is running and attached to it. A gateway address is never derived
#                   from a subnet: an isolated network has none, and the subnet's .1 belongs to
#                   a container.
#   update-rule     the rules on pr_base include one of type `update` (decision 9).
#   bypass          no applicable ruleset lists the App (actor_type Integration, actor_id
#                   --app-id) in bypass_actors; a null bypass_actors (the view hides it) is
#                   unreadable. Applicable means its id appears in --rules; a missing ruleset
#                   document, or one supplied twice, is unreadable.
#   author          the task issue is --issue-number (and not a pull request), and its author,
#                   and the spec comment's (id --spec-comment-id, issue_url ending
#                   /issues/<number>), are trusted. With --identities null that is
#                   author_association OWNER, MEMBER or COLLABORATOR; with a map it is the
#                   author's user.login and user.id matching an identities.maintainer entry
#                   (WB-D24, #382: association is viewer-relative and reads CONTRIBUTOR for the
#                   maintainer through an App token). The id decides; a login is compared
#                   case-folded and only alongside its id; an id declared twice, or under
#                   another login, is unreadable, and a malformed entry matches nothing (here a
#                   non-positive or non-numeric id; unlike gh-identity.sh, which wants a YAML
#                   !!int, a declared `1001.0` reads as 1001 once yq has made it JSON, and a
#                   fractional id can never equal GitHub's integer author id). The dev,
#                   review and loop Apps are not maintainers: an agent never trusts its own text.
#   installation    /installation/repositories lists exactly --repo (case-folded) and its
#                   total_count equals the list it shows.
#   can-bypass      at least one ruleset applies to pr_base and every one reads
#                   current_user_can_bypass: never.
#   identity        the App's slug + "[bot]" equals --loop-identity, case-folded.
#
# The driver's captures: a paginated read must be one complete document. `gh api --paginate`
# concatenates pages into several top-level values, which this script reads as unreadable, and a
# first page captured alone is indistinguishable from the whole list (only
# /installation/repositories carries a total_count to check). Use `--paginate --slurp` and
# flatten, or `per_page=100`, and refuse a response of 100.
# GET /app takes the App's JWT, not the installation token; the other github-push reads take the
# minted token.
#
# Not checked here: a non-root name that /etc/passwd or /etc/group maps to id 0 inside the image
# (inspect cannot show it); that the update rule comes from the ruleset orchestration.restrict_updates
# names (the task asks only that the rule is present); bypass actors that are not the App
# itself (a team or role the App is a member of) -- the can-bypass read at push time covers
# those; a named volume backed by a host path (`--opt o=bind`, which needs `docker volume
# inspect`); how many containers sit on the network, and that the credential is absent from
# `docker inspect` (launch.sh checks both and is not moved onto this script).
set -euo pipefail

die() { echo "preflight.sh: $*" >&2; exit 2; }

command -v jq >/dev/null 2>&1 || die "jq not on PATH"

# Findings arrive as "R rule: detail" / "U rule: detail" lines from jq. Print them, sanitised
# (details quote input-chosen strings), and exit 3 unless there were none.
report() {
  local out=$1 line
  if [ -z "$out" ]; then echo pass; exit 0; fi
  while IFS= read -r line; do
    case "$line" in
      "R "*) printf 'refused %s\n' "$(printf '%s' "${line#R }" | tr '\000-\037\177' '?' | cut -c1-300)" ;;
      "U "*) printf 'unreadable %s\n' "$(printf '%s' "${line#U }" | tr '\000-\037\177' '?' | cut -c1-300)" ;;
      *)     printf 'unreadable preflight: evaluator emitted an unclassified line\n' ;;
    esac
  done <<<"$out"
  exit 3
}

# A file must hold exactly one JSON value.
one_doc() { # file -> 0 when it parses to exactly one value
  [ -f "$1" ] && [ -r "$1" ] && [ "$(jq -c . -- "$1" 2>/dev/null | wc -l)" = 1 ]
}

[ $# -ge 1 ] || die "usage: preflight.sh container|github-dispatch|github-push ... (see the header)"
mode=$1; shift

session= network= expect_net= rules= rulesets= app_id= issue= issue_no= comment= comment_id=
no_comment= install= repo= appf= loopid= identf=
proxies=()
while [ $# -gt 0 ]; do
  case "$1" in
    --no-spec-comment) no_comment=1; shift; continue ;;
  esac
  [ $# -ge 2 ] || die "$1 needs a value"
  case "$1" in
    --session)         session=$2 ;;
    --network)         network=$2 ;;
    --expect-network)  expect_net=$2 ;;
    --proxy)           proxies+=("$2") ;;
    --rules)           rules=$2 ;;
    --rulesets)        rulesets=$2 ;;
    --app-id)          app_id=$2 ;;
    --issue)           issue=$2 ;;
    --issue-number)    issue_no=$2 ;;
    --spec-comment)    comment=$2 ;;
    --spec-comment-id) comment_id=$2 ;;
    --installation)    install=$2 ;;
    --repo)            repo=$2 ;;
    --app)             appf=$2 ;;
    --loop-identity)   loopid=$2 ;;
    --identities)      identf=$2 ;;
    *)                 die "unknown option: $1" ;;
  esac
  shift 2
done

need() { local v n; for n in "$@"; do v=${!n}; [ -n "$v" ] || die "--${n//_/-} is required"; done; }
digits() { case "$2" in ''|*[!0-9]*|0*) die "--$1 must be a positive decimal number" ;; esac; }

# Every named file must parse before any rule runs: a read that failed upstream arrives here
# as an empty or truncated file, and that is "unreadable", not "nothing found".
unreadable_files=
check_files() {
  local f
  for f in "$@"; do
    if ! one_doc "$f"; then
      unreadable_files="${unreadable_files}U input: $(printf '%s' "${f##*/}" | tr '\000-\037\177' '?') is missing, empty or not exactly one JSON value
"
    fi
  done
}

case "$mode" in
  container)
    need session network expect_net
    [ ${#proxies[@]} -gt 0 ] || die "at least one --proxy is required"
    case "$expect_net" in *[!A-Za-z0-9._-]*) die "--expect-network has characters outside [A-Za-z0-9._-]" ;; esac
    check_files "$session" "$network" "${proxies[@]}"
    [ -z "$unreadable_files" ] || report "${unreadable_files%$'\n'}"
    out=$(jq -n -r --slurpfile s "$session" --slurpfile n "$network" --arg net "$expect_net" '
      # A rule is unreadable when its field is absent, refused when present and wrong.
      def need(rule; v; ok; msg):
        if v == null then "U \(rule): field missing"
        elif (try (v | ok) catch false) then empty
        else "R \(rule): \(msg)" end;
      def bad_src: test("^/mnt(/|$)|^/host_mnt|^/run/desktop/mnt|^[A-Za-z]:|^//./pipe|docker\\.sock|docker_engine"; "i");
      # Docker parses ids with ParseInt, which takes a sign: "+0" and "-0" are root.
      def rootish: . == "root" or test("^[+-]?0+$");
      [inputs] as $p | ($s[0]) as $S | ($n[0]) as $N |
      if ($S | type) != "array" or ($S | length) != 1 or ($S[0] | type) != "object" then "U container: session inspect is not a one-element array"
      elif ($N | type) != "array" or ($N | length) != 1 or ($N[0] | type) != "object" then "U network: network inspect is not a one-element array"
      elif ([$p[] | select(type != "array" or length != 1 or (.[0] | type) != "object")] | length) > 0 then "U proxy: a proxy inspect is not a one-element array"
      else
        $S[0] as $c | $N[0] as $nw |
        need("user"; $c.Config.User; type == "string" and (split(":") | (.[0] // "") != "" and all(.[]; rootish | not)); "User or its group is root, or User is empty"),
        need("readonly-rootfs"; $c.HostConfig.ReadonlyRootfs; . == true; "root filesystem is writable"),
        need("cap-drop"; $c.HostConfig.CapDrop; type == "array" and index("ALL") != null; "capabilities not all dropped"),
        # CapAdd is applied after CapDrop: a re-grant leaves the capability on. Docker reports none as null or [].
        ( if ($c.HostConfig | has("CapAdd")) and $c.HostConfig.CapAdd != null and $c.HostConfig.CapAdd != [] then "R cap-add: capabilities added back (\($c.HostConfig.CapAdd | tostring))" else empty end ),
        need("privileged"; $c.HostConfig.Privileged; . == false; "container is privileged"),
        # Host namespaces, devices and disabled confinement are privilege by another name.
        # A namespace shared with another container (`container:<proxy>`) is as bad as the host: the
        # credential-holding proxy runs as the same uid. Only the private forms are accepted.
        ( [ ({"PidMode":["","private"],"IpcMode":["","private","shareable","none"],"UsernsMode":[""],"UTSMode":[""],"CgroupnsMode":["","private"]} | to_entries[]) as $e
            | select($c.HostConfig[$e.key] != null and (($c.HostConfig[$e.key] | tostring) as $v | $e.value | index($v) == null))
            | "\($e.key)=\($c.HostConfig[$e.key])" ]
          + [ select(($c.HostConfig.Devices // []) != []) | "Devices" ]
          + [ select(($c.HostConfig.DeviceRequests // []) != []) | "DeviceRequests" ]
          + [ select(any(($c.HostConfig.GroupAdd // [])[]; tostring | rootish)) | "GroupAdd root" ]
          # SecurityOpt is an allow-list: launch.sh sets no-new-privileges and nothing else, so a
          # seccomp/apparmor/label option of any kind is a change to the confinement.
          + [ select((($c.HostConfig.SecurityOpt // []) | if type == "array" then any(.[]; tostring | test("^no-new-privileges([=:]true)?$") | not) else true end)) | "SecurityOpt other than no-new-privileges" ]
          + [ select((($c.HostConfig.Mounts // []) | if type == "array" then any(.[]; (.Type // "") != "volume" and (.Type // "") != "tmpfs") else true end)) | "HostConfig.Mounts has a bind or is not a list" ]
          | if length > 0 then "R privilege: \(join(", "))" else empty end ),
        need("network-mode"; $c.HostConfig.NetworkMode; . == $net; "NetworkMode is not \($net)"),
        # NetworkMode names one network; `docker network connect` can still add a second, routable one.
        need("session-networks"; $c.NetworkSettings.Networks; type == "object" and (keys == [$net]); "session is attached to networks other than \($net)"),
        need("mounts"; $c.Mounts; type == "array" and all(.[]; type == "object");
          "mounts are not a list of objects"),
        # Only a named local volume or a tmpfs is allowed: a bind of any host path (/var/run and / hold
        # the socket, /run reaches the drive) is refused outright, as launch.sh does. bad_src stays as a second net.
        ( if ($c.Mounts | type) == "array" then
            ([$c.Mounts[] | select(type == "object") | select(((.Type // "") != "volume" and (.Type // "") != "tmpfs") or ((.Source // "") | tostring | bad_src) or ((.Destination // "") | tostring | test("docker\\.sock|docker_engine"; "i"))) | "\(.Type // "?"): \(.Source // "?") -> \(.Destination // "?")"] | if length > 0 then "R mounts: forbidden mount \(join("; "))" else empty end)
          else empty end ),
        ( if ($c.HostConfig | has("Binds")) and $c.HostConfig.Binds != null and $c.HostConfig.Binds != [] then
            ( if ($c.HostConfig.Binds | type) != "array" then "U binds: Binds is not a list"
              else ([$c.HostConfig.Binds[] | tostring | select(test("^[A-Za-z0-9][A-Za-z0-9_.-]+:[^:]") | not)] | if length > 0 then "R binds: bind mounts are not allowed (\(join("; ")))" else empty end) end )
          else empty end ),
        need("network-name"; $nw.Name; . == $net; "network is not \($net)"),
        need("internal"; $nw.Internal; . == true; "network is not Internal"),
        need("ipv6"; $nw.EnableIPv6; . == false; "IPv6 is enabled on the network"),
        need("gateway-mode"; $nw.Options["com.docker.network.bridge.gateway_mode_ipv4"]; . == "isolated"; "gateway_mode_ipv4 is not isolated"),
        ( if ($nw.IPAM.Config | type) == "array" and ($nw.IPAM.Config | length) == 0 then "U ipam: IPAM.Config is empty" else empty end ),
        need("ipam"; $nw.IPAM.Config; type == "array" and all(.[]; type == "object");
          "IPAM.Config is not a list of entries"),
        ( if ($nw.IPAM.Config | type) == "array" then
            ([$nw.IPAM.Config[] | select(type == "object") | select((.Gateway // "") != "") | .Gateway] | if length > 0 then "R ipam: IPAM has a Gateway (\(join(", ")))" else empty end)
          else empty end ),
        ( $p[] | .[0] as $x | ($x.Name // "?") as $nm |
          need("proxy-running"; $x.State.Running; . == true; "proxy \($nm) is not running"),
          need("proxy-network"; $x.NetworkSettings.Networks; type == "object" and has($net); "proxy \($nm) is not on \($net)") )
      end | explode | map(if . < 32 or . == 127 then 63 else . end) | implode' "${proxies[@]}" 2>/dev/null | tr -d '\r') || report "U container: evaluator failed on the input"
    report "$out"
    ;;

  github-dispatch)
    need rules rulesets app_id issue issue_no identf
    digits app-id "$app_id"; digits issue-number "$issue_no"
    if [ -n "$no_comment" ]; then
      [ -z "$comment" ] && [ -z "$comment_id" ] || die "--no-spec-comment excludes --spec-comment and --spec-comment-id"
    else
      need comment comment_id
      digits spec-comment-id "$comment_id"
    fi
    files=("$rules" "$rulesets" "$issue" "$identf"); [ -z "$comment" ] || files+=("$comment")
    check_files "${files[@]}"
    [ -z "$unreadable_files" ] || report "${unreadable_files%$'\n'}"
    cf=${comment:-/dev/null}
    out=$(jq -n -r --slurpfile r "$rules" --slurpfile rs "$rulesets" --slurpfile i "$issue" --slurpfile ids "$identf" \
      --argjson app "$app_id" --argjson inum "$issue_no" --arg haveC "${comment:+1}" --argjson cid "${comment_id:-0}" \
      --slurpfile c "$cf" '
      def trusted: . == "OWNER" or . == "MEMBER" or . == "COLLABORATOR";
      ($ids[0]) as $ID |
      def lc: ascii_downcase;
      # Every well-formed identities entry with its role; a malformed one matches nothing.
      def declared: [ ( ($ID.maintainer // []) | if type == "array" then .[] else empty end | {role: "maintainer", e: .} ),
                      ( ["dev_app", "reviewer_app", "loop_app"][] as $k | {role: $k, e: $ID[$k]} ) ]
        | map(select((.e | type) == "object" and ((.e.id | type) == "number") and .e.id > 0 and ((.e.login | type) == "string")));
      def author(rule; o; what):
        if $ID == null then
          if (o.author_association // null) == null then "U \(rule): \(what) has no author_association"
          elif (o.author_association | type) == "string" and (o.author_association | trusted) then empty
          else "R \(rule): \(what) author_association is \(o.author_association) (not OWNER, MEMBER or COLLABORATOR)" end
        elif ($ID | type) != "object" then "U \(rule): identities is neither null nor a map"
        elif ((o.user | type) != "object") or ((o.user.login | type) != "string") or ((o.user.id | type) != "number")
          then "U \(rule): \(what) has no author login and id"
        else
          ([declared[] | select(.e.id == o.user.id)]) as $hit |
          if ($hit | length) > 1 then "U \(rule): author id \(o.user.id) is declared more than once"
          elif ($hit | length) == 0 then "R \(rule): \(what) author \(o.user.login) is not a declared maintainer"
          elif ($hit[0].e.login | lc) != (o.user.login | lc) then "U \(rule): \(what) author id \(o.user.id) is declared under a different login"
          elif $hit[0].role != "maintainer" then "R \(rule): \(what) author \(o.user.login) is the declared \($hit[0].role), not a maintainer"
          else empty end
        end;
      ($r[0]) as $R | ($rs[0]) as $RS | ($i[0]) as $I | ($c[0]) as $c |
      if ($R | type) != "array" or ([$R[] | select(type != "object" or (.ruleset_id | type) != "number")] | length) > 0
        then "U update-rule: rules are not a list of rule objects carrying ruleset_id"
      elif ($RS | type) != "array" or ([$RS[] | select(type != "object")] | length) > 0
        then "U bypass: rulesets are not a list of ruleset objects"
      elif ($I | type) != "object" then "U author: issue is not an object"
      else
        ([$R[].ruleset_id] | unique) as $ids |
        ( if any($R[]; .type == "update") then empty else "R update-rule: no `update` rule applies to pr_base" end ),
        ( $ids[] as $id |
          [$RS[] | select(.id == $id)] as $m |
          if ($m | length) == 0 then "U bypass: ruleset \($id) applies to pr_base but its document was not supplied"
          elif ($m | length) > 1 then "U bypass: ruleset \($id) was supplied \($m | length) times"
          elif ($m[0].bypass_actors | type) != "array" then "U bypass: ruleset \($id) bypass_actors is not visible to this view"
          elif any($m[0].bypass_actors[]; type != "object") then "U bypass: ruleset \($id) has a bypass actor that is not an object"
          elif any($m[0].bypass_actors[]; (.actor_type // "") == "Integration" and ((.actor_id // null) | type) != "number") then "U bypass: ruleset \($id) has an Integration actor with no numeric actor_id"
          elif any($m[0].bypass_actors[]; (.actor_type // "") == "Integration" and .actor_id == $app) then "R bypass: the App is a bypass actor of ruleset \($id)"
          else empty end ),
        ( if ($I.number // null) != $inum then "U author: issue number is not \($inum)"
          elif ($I | has("pull_request")) then "U author: #\($inum) is a pull request, not an issue"
          else empty end ),
        author("author"; $I; "task issue #\($inum)"),
        ( if $haveC == "" then empty
          elif ($c | type) != "object" then "U author: spec comment is not an object"
          elif ($c.id // null) != $cid then "U author: spec comment id is not \($cid)"
          elif ((($c.issue_url // null) | type) != "string") or (($c.issue_url | test("/issues/\($inum)$")) | not) then "U author: spec comment \($cid) is not shown to belong to issue #\($inum)"
          else author("author"; $c; "spec comment \($cid)") end )
      end | explode | map(if . < 32 or . == 127 then 63 else . end) | implode' 2>/dev/null | tr -d '\r') || report "U github-dispatch: evaluator failed on the input"
    report "$out"
    ;;

  github-push)
    need install repo rules rulesets appf loopid
    case "$repo" in */*) ;; *) die "--repo must be OWNER/NAME" ;; esac
    check_files "$install" "$rules" "$rulesets" "$appf"
    [ -z "$unreadable_files" ] || report "${unreadable_files%$'\n'}"
    out=$(jq -n -r --slurpfile ins "$install" --slurpfile r "$rules" --slurpfile rs "$rulesets" --slurpfile a "$appf" \
      --arg repo "$repo" --arg li "$loopid" '
      ($ins[0]) as $I | ($r[0]) as $R | ($rs[0]) as $RS | ($a[0]) as $A |
      ( if ($I | type) != "object" or ($I.repositories | type) != "array" or ($I.total_count | type) != "number" then "U installation: /installation/repositories is not the expected shape"
        elif $I.total_count != ($I.repositories | length) then "U installation: total_count \($I.total_count) differs from the \($I.repositories | length) repositories shown (truncated?)"
        elif ([$I.repositories[] | select((.full_name // null) | type != "string")] | length) > 0 then "U installation: a repository has no full_name"
        elif ($I.repositories | length) != 1 or (($I.repositories[0].full_name | ascii_downcase) != ($repo | ascii_downcase))
          then "R installation: the token reaches \([$I.repositories[].full_name] | join(", ")), not exactly \($repo)"
        else empty end ),
      ( if ($R | type) != "array" or ([$R[] | select(type != "object" or (.ruleset_id | type) != "number")] | length) > 0 then "U can-bypass: rules are not a list of rule objects carrying ruleset_id"
        elif ($RS | type) != "array" or ([$RS[] | select(type != "object")] | length) > 0 then "U can-bypass: rulesets are not a list of ruleset objects"
        elif ($R | length) == 0 then "R can-bypass: no ruleset applies to pr_base"
        else
          ( [$R[].ruleset_id] | unique[] ) as $id |
          [$RS[] | select(.id == $id)] as $m | ($m[0] // null) as $rsd |
          if ($m | length) == 0 then "U can-bypass: ruleset \($id) applies to pr_base but its document was not supplied"
          elif ($m | length) > 1 then "U can-bypass: ruleset \($id) was supplied \($m | length) times"
          elif ($rsd.current_user_can_bypass // null) == null then "U can-bypass: ruleset \($id) has no current_user_can_bypass"
          elif $rsd.current_user_can_bypass == "never" then empty
          else "R can-bypass: ruleset \($id) reads current_user_can_bypass: \($rsd.current_user_can_bypass)" end
        end ),
      ( if ($A | type) != "object" or (($A.slug // null) | type) != "string" or $A.slug == "" then "U identity: /app has no slug"
        elif $li == "" or $li == "-" then "R identity: no orchestration.loop_identity is configured"
        elif (($A.slug + "[bot]") | ascii_downcase) != ($li | ascii_downcase) then "R identity: the App is \($A.slug)[bot], loop_identity is \($li)"
        else empty end ) | explode | map(if . < 32 or . == 127 then 63 else . end) | implode' 2>/dev/null | tr -d '\r') || report "U github-push: evaluator failed on the input"
    report "$out"
    ;;

  *) die "unknown mode: $mode (container, github-dispatch or github-push)" ;;
esac
