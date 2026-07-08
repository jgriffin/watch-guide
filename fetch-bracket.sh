#!/bin/bash
# fetch-bracket.sh — fetch the live 2026 WC knockout results and cache them to
# bracket.json (the single source of truth for the landing-page bracket).
#
# Source: openfootball/worldcup.json — one public-domain JSON file, no API key.
# Run this periodically during the knockouts (results change at most ~3x/day);
# build-site.sh reads the committed bracket.json and never hits the network.
#
#   ./fetch-bracket.sh && ./build-site.sh && (cd site && vercel --prod)
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$(pwd)"

SRC="https://raw.githubusercontent.com/openfootball/worldcup.json/master/2026/worldcup.json"
RAW="$(mktemp)"; trap 'rm -f "$RAW"' EXIT
curl -fsS "$SRC" -o "$RAW"

GEN="$(date +%F)"

# jq does the whole transform: winner logic (pens > ET > FT), name resolution
# (Wxx/Lxx placeholders -> null/TBD), per-team score strings, flag emoji, the
# fixed 2026 feeder map + canonical display order, and slug matching against
# fixtures.json (order-independent, with a couple of name aliases).
jq -n \
  --slurpfile wc "$RAW" \
  --arg gen "$GEN" '
  # --- slugify a team name to its guide-folder token --------------------------
  def slugify(s): (s|ascii_downcase|gsub("[^a-z0-9]+";"-")|gsub("^-|-$";""));
  # --- helpers over a raw openfootball match ----------------------------------
  def team(t): if (t|type)=="string" and (t|test("^[WL][0-9]+$")) then null else t end;
  def winner(x):
      if x.score==null then null
      elif x.score.p!=null   then (if x.score.p[0]>x.score.p[1]   then 1 else 2 end)
      elif x.score.et!=null  then (if x.score.et[0]>x.score.et[1] then 1 elif x.score.et[1]>x.score.et[0] then 2 else null end)
      else (if x.score.ft[0]>x.score.ft[1] then 1 elif x.score.ft[1]>x.score.ft[0] then 2 else null end)
      end;
  def sc(x;i): if x.score==null then null else (x.score.ft[i-1]|tostring) end;
  def note(x):
      if x.score==null then null
      elif x.score.p!=null then ((x.score.p[0]|tostring)+"–"+(x.score.p[1]|tostring)+" pen")
      elif (x.score.et!=null and x.score.et!=x.score.ft) then "a.e.t."
      else null end;

  ($wc[0].matches) as $m

  # --- flag emoji for every team that can reach the knockouts -----------------
  | {
      "South Africa":"🇿🇦","Canada":"🇨🇦","Germany":"🇩🇪","Paraguay":"🇵🇾",
      "Netherlands":"🇳🇱","Morocco":"🇲🇦","Brazil":"🇧🇷","Japan":"🇯🇵",
      "France":"🇫🇷","Sweden":"🇸🇪","Ivory Coast":"🇨🇮","Norway":"🇳🇴",
      "Mexico":"🇲🇽","Ecuador":"🇪🇨","England":"🏴󠁧󠁢󠁥󠁮󠁧󠁿","DR Congo":"🇨🇩",
      "USA":"🇺🇸","Bosnia & Herzegovina":"🇧🇦","Belgium":"🇧🇪","Senegal":"🇸🇳",
      "Portugal":"🇵🇹","Croatia":"🇭🇷","Spain":"🇪🇸","Austria":"🇦🇹",
      "Switzerland":"🇨🇭","Algeria":"🇩🇿","Argentina":"🇦🇷","Cape Verde":"🇨🇻",
      "Colombia":"🇨🇴","Ghana":"🇬🇭","Australia":"🇦🇺","Egypt":"🇪🇬"
    } as $flags

  # per-match slug overrides where the folder order/spelling differs from
  # slugify(t1)-slugify(t2): M73 (Canada is home, not S. Africa) and M80
  # (DR Congo -> congo-dr reorder). Future rounds derive cleanly, no override.
  | ({"73":"canada-south-africa","80":"england-congo-dr"}) as $slugOverride

  # raw match by num
  | (reduce $m[] as $x ({}; . + { ($x.num|tostring): $x })) as $byNum

  # build one tie object for a given match number (+ fixed feeders)
  | def tie($num; $feeders):
      ($byNum[$num|tostring]) as $x
      | (team($x.team1)) as $t1
      | (team($x.team2)) as $t2
      | {
          num: $num,
          date: ($x.date // null),
          t1: $t1, t2: $t2,
          f1: (if $t1==null then null else ($flags[$t1] // null) end),
          f2: (if $t2==null then null else ($flags[$t2] // null) end),
          s1: sc($x;1), s2: sc($x;2),
          winner: winner($x),
          note: note($x),
          feeders: $feeders,
          slug: (if ($t1!=null and $t2!=null)
                 then ($slugOverride[($num|tostring)] // (slugify($t1)+"-"+slugify($t2)))
                 else null end)
        };

  # --- canonical display order + feeder map (fixed 2026 bracket topology) ------
  {generated: $gen,
      source: "openfootball/worldcup.json (2026) — github.com/openfootball/worldcup.json",
      rounds: [
        { key:"r32",   label:"Round of 32", ties: [
            [74,null],[77,null],[73,null],[75,null],[83,null],[84,null],[81,null],[82,null],
            [76,null],[78,null],[79,null],[80,null],[86,null],[88,null],[85,null],[87,null]
          ] | map(tie(.[0]; .[1])) },
        { key:"r16",   label:"Round of 16", ties: [
            [89,[74,77]],[90,[73,75]],[93,[83,84]],[94,[81,82]],
            [91,[76,78]],[92,[79,80]],[95,[86,88]],[96,[85,87]]
          ] | map(tie(.[0]; .[1])) },
        { key:"qf",    label:"Quarter-finals", ties: [
            [97,[89,90]],[98,[93,94]],[99,[91,92]],[100,[95,96]]
          ] | map(tie(.[0]; .[1])) },
        { key:"sf",    label:"Semi-finals", ties: [
            [101,[97,98]],[102,[99,100]]
          ] | map(tie(.[0]; .[1])) },
        { key:"final", label:"Final", ties: [
            [104,[101,102]]
          ] | map(tie(.[0]; .[1])) }
      ],
      third: ( [103,[101,102]] | tie(.[0]; .[1]) )
    }

  # --- propagate winners into downstream TBD slots ----------------------------
  # openfootballs own placeholder-resolution lags (it filled one R16 slot but
  # not its sibling). Derive each empty downstream team from its feeders winner
  # so the tree fills in consistently. One level per fetch; it cascades round by
  # round as games complete (a played round gains winners on the next refresh).
  | . as $b0
  | ([ $b0.rounds[].ties[], $b0.third ]
       | map({ key:(.num|tostring),
               value:(if .winner==1 then .t1 elif .winner==2 then .t2 else null end) })
       | from_entries) as $wname
  | def fillTie(t):
      t
      | (if (.t1==null and .feeders!=null) then (.t1 = $wname[(.feeders[0]|tostring)]) else . end)
      | (if (.t2==null and .feeders!=null) then (.t2 = $wname[(.feeders[1]|tostring)]) else . end)
      | (.f1 = (if .t1==null then null else ($flags[.t1] // null) end))
      | (.f2 = (if .t2==null then null else ($flags[.t2] // null) end))
      # recompute slug now that feeders may have filled the teams (tie() saw nulls)
      | (.slug = (if (.t1!=null and .t2!=null)
                  then ($slugOverride[(.num|tostring)] // (slugify(.t1)+"-"+slugify(.t2)))
                  else null end));
    $b0
    | (.rounds |= map(.ties |= map(fillTie(.))))
    | (.third |= fillTie(.))
  ' > "$ROOT/bracket.json"

echo "Wrote bracket.json (generated $GEN)"
jq -r '
  "  R32 results: " + ([.rounds[0].ties[]|select(.winner!=null)]|length|tostring) + "/16 played",
  "  Linked guides: " + ([.rounds[0].ties[]|select(.slug!=null)]|length|tostring) + "/16"
' "$ROOT/bracket.json"

# --- derive fixtures.json from schedule.json (fixed calendar) x bracket ties --
# fixtures.json is GENERATED, not hand-maintained: every knockout tie whose two
# teams are known gets a schedule row (venue/kickoff from schedule.json), so the
# site's schedule auto-extends each round with no manual edits. Group-stage
# guides live outside the bracket and stay "orphan" guides in build-site.sh.
# To change a venue/time, edit schedule.json (the source of truth) — not here.
jq -n \
  --slurpfile br "$ROOT/bracket.json" \
  --slurpfile sc "$ROOT/schedule.json" \
  --arg gen "$GEN" '
  ($sc[0].matches) as $S
  | { generated: $gen,
      source: "GENERATED by fetch-bracket.sh — schedule.json (fixed calendar) joined to resolved bracket.json ties. Do not hand-edit; change venues/times in schedule.json.",
      fixtures:
        ( [ $br[0].rounds[].ties[], $br[0].third ]
          | map(select(.t1!=null and .t2!=null and ($S[(.num|tostring)]!=null))
                | ($S[(.num|tostring)]) as $s
                | { date:$s.date, ko_pacific:$s.ko_pacific, ko_display:$s.ko_display,
                    home:.t1, away:.t2, round:$s.round, venue:$s.venue, slug:.slug })
          | sort_by(.date, .ko_pacific) )
    }
  ' > "$ROOT/fixtures.json"

echo "Wrote fixtures.json ($(jq '.fixtures|length' "$ROOT/fixtures.json") resolved knockout fixtures)"
