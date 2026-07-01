#!/bin/bash
# build-site.sh — regenerate site/ (static, Vercel-ready) from matches/.
# Idempotent: blows away site/ and rebuilds from scratch each run.
# Source of truth = matches/<YYYY-MM-DD>-<HHMM>-<slug>/<slug>.html (+ data.md, ignored here).
set -euo pipefail

cd "$(dirname "$0")"
ROOT="$(pwd)"
MATCHES="$ROOT/matches"
SITE="$ROOT/site"

mkdir -p "$SITE"
# Clear generated contents but PRESERVE the Vercel project link (.vercel),
# otherwise the next `vercel --prod` re-links to a project named "site".
find "$SITE" -mindepth 1 -maxdepth 1 ! -name '.vercel' -exec rm -rf {} +

# ---- the hide-scores component (identical on every page) -------------------
# Fixed bottom-right toggle. Persists in localStorage key wcHideScores, shared
# across the origin. When active, masks .score result chips (text AND the
# win/draw/loss background colour, which is itself a spoiler) with a neutral
# "•–•" so layout doesn't collapse.
SNIPPET="$SITE/.snippet.html"
cat > "$SNIPPET" <<'SNIP'
<!-- hide-scores toggle (shared component) -->
<style>
  .wc-hs-btn{position:fixed;bottom:14px;right:14px;z-index:9999;font-family:'Oswald',sans-serif;font-weight:600;font-size:11px;letter-spacing:.08em;text-transform:uppercase;padding:8px 14px;border:1px solid #C39A2B;border-radius:22px;background:#26231f;color:#C39A2B;cursor:pointer;box-shadow:0 3px 12px rgba(0,0,0,.4);opacity:.92;}
  .wc-hs-btn:hover{opacity:1;}
  body.hide-scores .score{background:#8a8378 !important;color:transparent !important;position:relative;}
  body.hide-scores .score::after{content:"\2022\2013\2022";position:absolute;inset:0;display:flex;align-items:center;justify-content:center;color:#fff;font-weight:700;letter-spacing:.06em;}
</style>
<button class="wc-hs-btn" type="button" aria-pressed="false">Hide scores</button>
<script>
(function(){
  var KEY='wcHideScores';
  var btn=document.querySelector('.wc-hs-btn');
  function apply(on){
    document.body.classList.toggle('hide-scores',on);
    btn.textContent=on?'Show scores':'Hide scores';
    btn.setAttribute('aria-pressed',on?'true':'false');
  }
  // Default to HIDDEN (spoiler-safe for delayed viewing); honour an explicit
  // choice once the user has toggled it.
  var stored=localStorage.getItem(KEY);
  var on = (stored===null) ? true : (stored==='1');
  apply(on);
  btn.addEventListener('click',function(){
    on=!on;
    localStorage.setItem(KEY, on?'1':'0');
    apply(on);
  });
})();
</script>
SNIP

# ---- helpers ----------------------------------------------------------------
fmt_time(){ # HHMM -> "h:mm AM/PM PDT"
  local hh=$((10#${1:0:2})) mm=${1:2:2} ap=AM
  if [ "$hh" -ge 12 ]; then ap=PM; fi
  if [ "$hh" -eq 0 ]; then hh=12; elif [ "$hh" -gt 12 ]; then hh=$((hh-12)); fi
  printf '%d:%s %s PDT' "$hh" "$mm" "$ap"
}
fmt_date(){ # YYYY-MM-DD -> "Weekday · Month D"
  local dow mon day
  # Portable: GNU date (Linux/Vercel) first, BSD date (macOS) as fallback.
  dow=$(date -d "$1" "+%A" 2>/dev/null || date -j -f "%Y-%m-%d" "$1" "+%A")
  mon=$(date -d "$1" "+%B" 2>/dev/null || date -j -f "%Y-%m-%d" "$1" "+%B")
  day=$((10#${1:8:2}))
  printf '%s · %s %d' "$dow" "$mon" "$day"
}

# ---- per-match: copy guide as-is --------------------------------------------
# Guides are forward-looking (predicted XIs, no live score); any results in them
# are older games you'd want to see anyway. So NO hide-scores snippet here — the
# toggle lives only on the landing, where the bracket carries the day's results.
slugs=()
for dir in "$MATCHES"/*/; do
  [ -d "$dir" ] || continue
  html=$(find "$dir" -maxdepth 1 -name '*.html' ! -name 'data.md' | head -n1)
  [ -n "$html" ] || { echo "WARN: no guide html in $dir" >&2; continue; }
  base=$(basename "$html")
  slug=${base%.html}
  slugs+=("$slug")
  mkdir -p "$SITE/$slug"
  cp "$html" "$SITE/$slug/index.html"
done

# ---- landing page (rendered from fixtures.json + existing guides) -----------
# Source of truth for the SCHEDULE = fixtures.json (gives placeholders for
# games whose guide isn't generated yet). Existing guides in matches/ that
# aren't in fixtures.json (e.g. group-stage) are folded into "Earlier games".
LANDING="$SITE/index.html"
FIX="$ROOT/fixtures.json"
TODAY="$(date +%F)"

guide_exists(){ [ -f "$SITE/$1/index.html" ]; }      # slug -> guide was generated?
esc(){ printf '%s' "${1//&/&amp;}"; }                # minimal HTML-escape for & in names

# emit one card. args: exists(0/1) time_display slug name subline
emit_card(){
  local ex="$1" t="$2" slug="$3" name="$4" sub="$5"
  if [ "$ex" = "1" ]; then
    printf '  <a class="row" href="/%s"><span class="time">%s</span><span class="meta"><span class="name">%s</span><div class="rnd">%s</div></span><span class="chev">&rsaquo;</span></a>\n' \
      "$slug" "$t" "$name" "$sub" >> "$LANDING"
  else
    printf '  <div class="row placeholder"><span class="time">%s</span><span class="meta"><span class="name">%s</span><div class="rnd">%s</div></span><span class="tag">Guide not generated yet</span></div>\n' \
      "$t" "$name" "$sub" >> "$LANDING"
  fi
}

cat > "$LANDING" <<'HEAD'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>World Cup '26 — Watch Guides</title>
<style>
  @import url('https://fonts.googleapis.com/css2?family=Oswald:wght@400;600;700&family=Barlow+Condensed:wght@400;500;600&family=Barlow:wght@400;500;600&display=swap');
  :root{--gold:#C39A2B;--ink:#1a1714;--paper:#f6f3ec;--line:#d8d2c4;--muted:#6f675b;--dark:#26231f;}
  *{box-sizing:border-box;margin:0;padding:0;}
  body{font-family:'Barlow',sans-serif;background:var(--dark);color:var(--ink);padding:18px;line-height:1.32;}
  .sheet{max-width:860px;margin:0 auto;background:var(--paper);border:1px solid var(--line);box-shadow:0 14px 44px rgba(0,0,0,.5);overflow:hidden;}
  .hd{background:var(--ink);color:var(--paper);padding:20px 22px;}
  .hd .kicker{font-family:'Oswald';font-weight:600;font-size:11px;letter-spacing:.26em;color:var(--gold);text-transform:uppercase;}
  .hd h1{font-family:'Oswald';font-weight:700;font-size:30px;line-height:1.02;text-transform:uppercase;margin-top:4px;}
  .section{font-family:'Oswald';font-weight:700;font-size:14px;letter-spacing:.16em;text-transform:uppercase;padding:12px 22px;border-bottom:1px solid var(--line);}
  .section.today{background:var(--gold);color:var(--ink);}
  .section.next{background:var(--ink);color:var(--gold);}
  .day{font-family:'Oswald';font-weight:600;font-size:13px;letter-spacing:.14em;text-transform:uppercase;color:var(--muted);background:#efeadf;padding:8px 22px;border-bottom:1px solid var(--line);}
  a.row{display:flex;align-items:center;gap:14px;padding:13px 22px;border-bottom:1px solid var(--line);text-decoration:none;color:var(--ink);}
  a.row:hover{background:#efeadf;}
  .row.placeholder{display:flex;align-items:center;gap:14px;padding:13px 22px;border-bottom:1px solid var(--line);color:var(--muted);opacity:.65;cursor:default;}
  .row.placeholder .name{color:var(--muted);}
  .time{font-family:'Oswald';font-weight:600;font-size:12px;color:var(--gold);white-space:nowrap;min-width:92px;letter-spacing:.04em;}
  .row.placeholder .time{color:var(--muted);}
  .meta{flex:1;}
  .name{font-family:'Oswald';font-weight:700;font-size:17px;text-transform:uppercase;line-height:1.05;}
  .rnd{font-family:'Barlow Condensed';font-size:13px;color:var(--muted);letter-spacing:.03em;margin-top:1px;}
  .chev{color:var(--gold);font-size:18px;font-family:'Oswald';}
  .tag{font-family:'Oswald';font-weight:600;font-size:10px;letter-spacing:.06em;text-transform:uppercase;color:var(--muted);border:1px solid var(--line);border-radius:20px;padding:4px 10px;white-space:nowrap;}
  details.earlier>summary{font-family:'Oswald';font-weight:600;font-size:13px;letter-spacing:.14em;text-transform:uppercase;color:var(--muted);background:#efeadf;padding:12px 22px;border-bottom:1px solid var(--line);cursor:pointer;list-style:none;}
  details.earlier>summary::-webkit-details-marker{display:none;}
  details.earlier>summary::before{content:"\25B8\00a0";color:var(--gold);}
  details.earlier[open]>summary::before{content:"\25BE\00a0";}
  .foot{padding:13px 22px;font-family:'Barlow Condensed';font-size:12px;color:var(--muted);background:var(--paper);}
  /* ---- bracket (landing hero) ---- */
  .bracket-wrap{background:var(--ink);color:var(--paper);border-bottom:1px solid var(--line);}
  .b-hd{font-family:'Oswald';font-weight:700;font-size:12px;letter-spacing:.2em;text-transform:uppercase;color:var(--gold);padding:15px 22px 4px;}
  .b-sub{font-family:'Barlow Condensed';font-size:12px;color:#a59a86;padding:0 22px 6px;letter-spacing:.02em;}
  .brk-in{position:absolute;opacity:0;width:0;height:0;pointer-events:none;}
  .brk-tabs{display:none;}
  .bracket{display:flex;flex-direction:row;align-items:stretch;padding:6px 18px 20px;overflow-x:auto;}
  .rnd{flex:1 1 0;min-width:128px;display:flex;flex-direction:column;}
  .rnd:not(:last-child){margin-right:22px;}
  .rnd-hd{font-family:'Barlow Condensed';font-weight:600;font-size:10px;letter-spacing:.13em;text-transform:uppercase;color:var(--gold);text-align:center;padding:2px 0 7px;opacity:.85;}
  .ties{flex:1;display:flex;flex-direction:column;}
  .ties .tie{flex:1 1 0;display:flex;align-items:center;position:relative;}
  .card{width:100%;background:#241e10;border:1px solid #3a3220;border-radius:3px;overflow:hidden;text-decoration:none;color:var(--paper);display:block;}
  a.card:hover{border-color:var(--gold);}
  .tm{display:flex;align-items:center;gap:6px;padding:5px 7px;font-family:'Barlow';font-size:12px;line-height:1.1;}
  .tm + .tm{border-top:1px solid #3a3220;}
  .tm .fl{font-size:13px;flex:0 0 auto;line-height:1;}
  .tm .nm{flex:1;min-width:0;font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;text-transform:uppercase;letter-spacing:.01em;}
  .tm.tbd .nm{color:#8a8071;font-weight:500;}
  .tm.win{background:#3a3014;}
  .tm.win .nm{color:#ffe9a8;}
  .tm .sc{font-family:'Oswald';font-weight:700;font-size:11px;flex:0 0 auto;text-align:center;min-width:18px;padding:1px 4px;border-radius:3px;color:#fff;}
  .tm.win .sc{background:#2c5e38;}
  .tm:not(.win) .sc{background:#6e2530;}
  .note{font-family:'Barlow Condensed';font-size:9px;letter-spacing:.05em;text-transform:uppercase;color:#a59a86;text-align:right;padding:1px 7px 3px;background:#1d1810;}
  .mini{font-family:'Barlow Condensed';font-weight:600;font-size:9px;letter-spacing:.13em;text-transform:uppercase;color:#8a8071;text-align:center;padding:8px 0 3px;}
  /* connector elbows (desktop tree) */
  .rnd:not(:last-child) .ties .tie::after{content:'';position:absolute;left:100%;width:22px;height:50%;border-right:2px solid #3a3220;pointer-events:none;}
  .rnd:not(:last-child) .ties .tie:nth-child(odd)::after{top:50%;border-top:2px solid #3a3220;}
  .rnd:not(:last-child) .ties .tie:nth-child(even)::after{bottom:50%;border-bottom:2px solid #3a3220;}
  .rnd:last-child .ties{justify-content:center;}
  .rnd:last-child .ties .tie{flex:0 0 auto;margin:5px 0;}
  .rnd-final .card{border-color:var(--gold);}
  /* hide-scores: only TODAY's result / advancement are spoilers (earlier stays shown) */
  body.hide-scores .tie.today .tm.win{background:#241e10;}
  body.hide-scores .tie.today .tm.win .nm{color:var(--paper);}
  body.hide-scores .nm.adv{color:transparent;position:relative;}
  body.hide-scores .nm.adv::after{content:"TBD";position:absolute;left:0;top:0;color:#8a8071;font-weight:500;letter-spacing:.01em;}
  body.hide-scores .tie.today .note{visibility:hidden;}
  /* mobile: one round at a time via CSS-only tabs */
  @media (max-width:680px){
    .brk-tabs{display:flex;margin:2px 14px 0;border-bottom:2px solid #3a3220;}
    .brk-tabs label{flex:1;text-align:center;font-family:'Oswald';font-weight:600;font-size:12px;letter-spacing:.04em;text-transform:uppercase;padding:9px 2px;color:#a59a86;cursor:pointer;border-bottom:3px solid transparent;margin-bottom:-2px;}
    #brk-r32:checked~.brk-tabs .t-r32,#brk-r16:checked~.brk-tabs .t-r16,#brk-qf:checked~.brk-tabs .t-qf,#brk-sf:checked~.brk-tabs .t-sf,#brk-final:checked~.brk-tabs .t-final{color:var(--gold);border-bottom-color:var(--gold);}
    .bracket{flex-direction:column;overflow-x:visible;padding:10px 14px 16px;}
    .rnd{margin-right:0;min-width:0;}
    .rnd-hd{display:none;}
    .ties{display:none;gap:9px;}
    .ties .tie{flex:0 0 auto;margin:0;}
    .ties .tie::after{display:none;}
    .rnd:last-child .ties .tie{margin:0;}
    #brk-r32:checked~.bracket .rnd-r32 .ties,#brk-r16:checked~.bracket .rnd-r16 .ties,#brk-qf:checked~.bracket .rnd-qf .ties,#brk-sf:checked~.bracket .rnd-sf .ties,#brk-final:checked~.bracket .rnd-final .ties{display:flex;}
  }
</style>
</head>
<body>
<div class="sheet">
  <div class="hd"><div class="kicker">FIFA World Cup 2026</div><h1>Watch Guides</h1></div>
HEAD

# ---- bracket hero (rendered from bracket.json) ------------------------------
# The knockout tree is the landing's hero. Data = bracket.json (refreshed by
# fetch-bracket.sh). Desktop shows the connected tree; mobile shows one round at
# a time via CSS-only radio tabs. Result/advancement chips honour hide-scores.
BRK="$ROOT/bracket.json"
if [ -f "$BRK" ]; then
  {
    printf '  <div class="bracket-wrap">\n'
    printf '    <div class="b-hd">The Bracket — Road to the Final</div>\n'
    printf '    <div class="b-sub">Round of 32 onward. Tap a round on mobile; tap any tie for its watch guide.</div>\n'
    printf '    <input class="brk-in" type="radio" name="brk" id="brk-r32" checked>\n'
    printf '    <input class="brk-in" type="radio" name="brk" id="brk-r16">\n'
    printf '    <input class="brk-in" type="radio" name="brk" id="brk-qf">\n'
    printf '    <input class="brk-in" type="radio" name="brk" id="brk-sf">\n'
    printf '    <input class="brk-in" type="radio" name="brk" id="brk-final">\n'
    printf '    <div class="brk-tabs"><label class="t-r32" for="brk-r32">R32</label><label class="t-r16" for="brk-r16">R16</label><label class="t-qf" for="brk-qf">QF</label><label class="t-sf" for="brk-sf">SF</label><label class="t-final" for="brk-final">Final</label></div>\n'
    printf '    <div class="bracket">'
    jq -r --arg today "$TODAY" '
      # $spoilScore: this score is a TODAY result -> mark .score so the toggle masks it
      # $adv: this advanced team was decided TODAY -> mark .adv so the toggle blanks it
      def teamrow($nm;$fl;$sc;$win;$adv;$spoilScore):
        "<div class=\"tm\(if $win then " win" else "" end)\(if $nm==null then " tbd" else "" end)\">"
        + "<span class=\"fl\">\($fl // "")</span>"
        + "<span class=\"nm\(if $adv then " adv" else "" end)\">\($nm // "TBD")</span>"
        + (if $sc != null then "<span class=\"sc\(if $spoilScore then " score" else "" end)\">\($sc)</span>" else "" end)
        + "</div>";
      . as $b
      | (reduce ($b.rounds[].ties[], $b.third) as $t ({}; .[($t.num|tostring)]=$t.date)) as $dateByNum
      | def fedDate($t;$i): ($t.feeders[$i]) as $f | (if $f==null then null else $dateByNum[($f|tostring)] end);
        def tie($t;$isR32):
          ($t.date==$today) as $isToday
          | (if $isR32 then false else (($t.t1!=null) and (fedDate($t;0)==$today)) end) as $adv1
          | (if $isR32 then false else (($t.t2!=null) and (fedDate($t;1)==$today)) end) as $adv2
          | "<div class=\"tie\(if $isToday then " today" else "" end)\">"
          + (if $t.slug != null then "<a class=\"card\" href=\"/\($t.slug)\">" else "<div class=\"card\">" end)
          + teamrow($t.t1;$t.f1;$t.s1;($t.winner==1);$adv1;$isToday)
          + teamrow($t.t2;$t.f2;$t.s2;($t.winner==2);$adv2;$isToday)
          + (if $t.note != null then "<div class=\"note\">\($t.note)</div>" else "" end)
          + (if $t.slug != null then "</a>" else "</div>" end)
          + "</div>";
        $b.third as $third
        | [ $b.rounds[]
            | . as $r
            | "<div class=\"rnd rnd-\($r.key)\"><div class=\"rnd-hd\">\($r.label)</div><div class=\"ties\">"
              + ( [ $r.ties[] | tie(.; ($r.key=="r32")) ] | join("") )
              + ( if $r.key=="final"
                  then "<div class=\"mini\">Third place</div>" + tie($third; false)
                  else "" end )
              + "</div></div>"
          ] | join("")
    ' "$BRK"
    printf '</div>\n  </div>\n'
  } >> "$LANDING"
fi

# fixture slugs (to detect generated guides that AREN'T scheduled fixtures)
FIXSLUGS=(); _t=$(mktemp); jq -r '.fixtures[].slug' "$FIX" > "$_t"
while IFS= read -r s; do FIXSLUGS+=("$s"); done < "$_t"; rm -f "$_t"
in_fixtures(){ local s; for s in "${FIXSLUGS[@]}"; do [ "$s" = "$1" ] && return 0; done; return 1; }

# Schedule below the bracket (the bracket is the hero; this is "how you get to a
# guide"). Lead with what's actionable: Today + the next match day are open; the
# rest of the upcoming slate and past games fold into collapsed sections.
emit_day(){ # arg: YYYY-MM-DD -> that day's fixture cards, sorted by kickoff
  local d="$1" ko kod home away venue slug ex _t
  _t=$(mktemp)
  jq -r --arg d "$d" '.fixtures[]|select(.date==$d)|[.ko_pacific,.ko_display,.home,.away,.venue,.slug]|@tsv' "$FIX" | sort > "$_t"
  while IFS=$'\t' read -r ko kod home away venue slug; do
    ex=0; guide_exists "$slug" && ex=1
    emit_card "$ex" "$kod" "$slug" "$(esc "$home") vs $(esc "$away")" "Round of 32 &middot; $(esc "$venue")"
  done < "$_t"
  rm -f "$_t"
}

# upcoming match days (strictly after today), ascending
UPDATES=(); _t=$(mktemp); jq -r '.fixtures[].date' "$FIX" | sort -u | awk -v t="$TODAY" '$0>t' > "$_t"
while IFS= read -r s; do UPDATES+=("$s"); done < "$_t"; rm -f "$_t"
NEXTDAY="${UPDATES[0]:-}"

# ---- Today (open) -----------------------------------------------------------
if [ "$(jq -r --arg t "$TODAY" '[.fixtures[]|select(.date==$t)]|length' "$FIX")" -gt 0 ]; then
  printf '  <div class="section today">Today</div>\n' >> "$LANDING"
  printf '  <div class="day">%s</div>\n' "$(fmt_date "$TODAY")" >> "$LANDING"
  emit_day "$TODAY"
fi

# ---- Next up (open): the soonest upcoming match day -------------------------
if [ -n "$NEXTDAY" ]; then
  printf '  <div class="section next">Next up</div>\n' >> "$LANDING"
  printf '  <div class="day">%s</div>\n' "$(fmt_date "$NEXTDAY")" >> "$LANDING"
  emit_day "$NEXTDAY"
fi

# ---- More upcoming (collapsed): remaining future days ----------------------
if [ "${#UPDATES[@]}" -gt 1 ]; then
  printf '  <details class="earlier"><summary>More upcoming games</summary>\n' >> "$LANDING"
  for d in "${UPDATES[@]:1}"; do
    printf '  <div class="day">%s</div>\n' "$(fmt_date "$d")" >> "$LANDING"
    emit_day "$d"
  done
  printf '  </details>\n' >> "$LANDING"
fi

# ---- Earlier games (collapsed, bottom): past fixtures + orphan guides -------
EARLIER="$SITE/.earlier.tsv"
: > "$EARLIER"
_t=$(mktemp); jq -r --arg t "$TODAY" '.fixtures[]|select(.date<$t)|[.date,.ko_pacific,.ko_display,.home,.away,.venue,.slug]|@tsv' "$FIX" > "$_t"
while IFS=$'\t' read -r d ko kod home away venue slug; do
  ex=0; guide_exists "$slug" && ex=1
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$d" "$ko" "$ex" "$slug" "$(esc "$home") vs $(esc "$away")" "Round of 32 &middot; $(esc "$venue")" >> "$EARLIER"
done < "$_t"; rm -f "$_t"
# generated guides not present in fixtures.json (group-stage etc.) -> always earlier
for dir in "$MATCHES"/*/; do
  [ -d "$dir" ] || continue
  bn=$(basename "$dir"); gd="${bn:0:10}"; ghhmm="${bn:11:4}"
  html=$(find "$dir" -maxdepth 1 -name '*.html' ! -name 'data.md' | head -n1)
  [ -n "$html" ] || continue
  gslug=$(basename "$html"); gslug=${gslug%.html}
  in_fixtures "$gslug" && continue
  title=$(grep -o '<title>[^<]*</title>' "$html" | sed 's/<[^>]*>//g')
  gname="${title%%—*}"; gname="${gname%"${gname##*[![:space:]]}"}"   # rtrim
  grnd="${title#*—}";   grnd="${grnd#"${grnd%%[![:space:]]*}"}"      # ltrim
  printf '%s\t%s\t1\t%s\t%s\t%s\n' "$gd" "$ghhmm" "$gslug" "$gname" "$grnd" >> "$EARLIER"
done
if [ -s "$EARLIER" ]; then
  printf '  <details class="earlier"><summary>Earlier games</summary>\n' >> "$LANDING"
  cur=""
  _t=$(mktemp); sort -t$'\t' -k1,1 -k2,2 "$EARLIER" > "$_t"
  while IFS=$'\t' read -r d hh ex slug name sub; do
    if [ "$d" != "$cur" ]; then cur="$d"; printf '  <div class="day">%s</div>\n' "$(fmt_date "$d")" >> "$LANDING"; fi
    emit_card "$ex" "$(fmt_time "$hh")" "$slug" "$name" "$sub"
  done < "$_t"; rm -f "$_t"
  printf '  </details>\n' >> "$LANDING"
fi
rm -f "$EARLIER"

cat >> "$LANDING" <<'FOOT'
  <div class="foot">Times in Pacific. Predicted XIs; confirmed ~1hr before kickoff. Schedule from fixtures.json.</div>
</div>
FOOT
cat "$SNIPPET" >> "$LANDING"
printf '</body>\n</html>\n' >> "$LANDING"

# ---- vercel config (clean URLs: /brazil-japan, not /brazil-japan/) ----------
cat > "$SITE/vercel.json" <<'VJ'
{ "cleanUrls": true }
VJ

rm -f "$SNIPPET"

# ---- summary ----------------------------------------------------------------
echo "Built site/ with ${#slugs[@]} guides:"
for s in "${slugs[@]}"; do echo "  /$s"; done
