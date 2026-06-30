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
  var on=localStorage.getItem(KEY)==='1';
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
  dow=$(date -j -f "%Y-%m-%d" "$1" "+%A")
  mon=$(date -j -f "%Y-%m-%d" "$1" "+%B")
  day=$((10#${1:8:2}))
  printf '%s · %s %d' "$dow" "$mon" "$day"
}

# ---- per-match: copy guide, inject snippet ----------------------------------
slugs=()
for dir in "$MATCHES"/*/; do
  [ -d "$dir" ] || continue
  html=$(find "$dir" -maxdepth 1 -name '*.html' ! -name 'data.md' | head -n1)
  [ -n "$html" ] || { echo "WARN: no guide html in $dir" >&2; continue; }
  base=$(basename "$html")
  slug=${base%.html}
  slugs+=("$slug")
  mkdir -p "$SITE/$slug"
  awk -v snip="$SNIPPET" '
    BEGIN{ while((getline l < snip) > 0) s=s l ORS }
    /<\/body>/{ printf "%s", s }
    { print }
  ' "$html" > "$SITE/$slug/index.html"
done

# ---- landing page (rendered from fixtures.json + existing guides) -----------
# Source of truth for the SCHEDULE = fixtures.json (gives placeholders for
# games whose guide isn't generated yet). Existing guides in matches/ that
# aren't in fixtures.json (e.g. group-stage) are folded into "Earlier games".
LANDING="$SITE/index.html"
FIX="$ROOT/fixtures.json"
TODAY="$(date +%F)"
YEST="$(date -v-1d +%F)"

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
  .sheet{max-width:720px;margin:0 auto;background:var(--paper);border:1px solid var(--line);box-shadow:0 14px 44px rgba(0,0,0,.5);overflow:hidden;}
  .hd{background:var(--ink);color:var(--paper);padding:20px 22px;}
  .hd .kicker{font-family:'Oswald';font-weight:600;font-size:11px;letter-spacing:.26em;color:var(--gold);text-transform:uppercase;}
  .hd h1{font-family:'Oswald';font-weight:700;font-size:30px;line-height:1.02;text-transform:uppercase;margin-top:4px;}
  .section{font-family:'Oswald';font-weight:700;font-size:14px;letter-spacing:.16em;text-transform:uppercase;padding:12px 22px;border-bottom:1px solid var(--line);}
  .section.today{background:var(--gold);color:var(--ink);}
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
</style>
</head>
<body>
<div class="sheet">
  <div class="hd"><div class="kicker">FIFA World Cup 2026</div><h1>Watch Guides</h1></div>
HEAD

# fixture slugs (to detect generated guides that AREN'T scheduled fixtures)
FIXSLUGS=(); while IFS= read -r s; do FIXSLUGS+=("$s"); done < <(jq -r '.fixtures[].slug' "$FIX")
in_fixtures(){ local s; for s in "${FIXSLUGS[@]}"; do [ "$s" = "$1" ] && return 0; done; return 1; }

# Chronological top->bottom (oldest first). Only TODAY is open by default;
# past games fold into a collapsed <details> ABOVE, future games into one BELOW.

# ---- Earlier games (collapsed, TOP): fixtures before today + orphan guides --
EARLIER="$SITE/.earlier.tsv"
: > "$EARLIER"
# scheduled fixtures earlier than today -> date\thhmm\texists\tslug\tname\tsubline
while IFS=$'\t' read -r d ko kod home away venue slug; do
  ex=0; guide_exists "$slug" && ex=1
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$d" "$ko" "$ex" "$slug" "$(esc "$home") vs $(esc "$away")" "Round of 32 &middot; $(esc "$venue")" >> "$EARLIER"
done < <(jq -r --arg t "$TODAY" '.fixtures[]|select(.date<$t)|[.date,.ko_pacific,.ko_display,.home,.away,.venue,.slug]|@tsv' "$FIX")
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
  while IFS=$'\t' read -r d hh ex slug name sub; do
    if [ "$d" != "$cur" ]; then cur="$d"; printf '  <div class="day">%s</div>\n' "$(fmt_date "$d")" >> "$LANDING"; fi
    emit_card "$ex" "$(fmt_time "$hh")" "$slug" "$name" "$sub"
  done < <(sort -t$'\t' -k1,1 -k2,2 "$EARLIER")
  printf '  </details>\n' >> "$LANDING"
fi
rm -f "$EARLIER"

# ---- Today (open, MIDDLE) ---------------------------------------------------
if [ "$(jq -r --arg t "$TODAY" '[.fixtures[]|select(.date==$t)]|length' "$FIX")" -gt 0 ]; then
  printf '  <div class="section today">Today</div>\n' >> "$LANDING"
  printf '  <div class="day">%s</div>\n' "$(fmt_date "$TODAY")" >> "$LANDING"
  while IFS=$'\t' read -r ko kod home away venue slug; do
    ex=0; guide_exists "$slug" && ex=1
    emit_card "$ex" "$kod" "$slug" "$(esc "$home") vs $(esc "$away")" "Round of 32 &middot; $(esc "$venue")"
  done < <(jq -r --arg t "$TODAY" '.fixtures[]|select(.date==$t)|[.ko_pacific,.ko_display,.home,.away,.venue,.slug]|@tsv' "$FIX" | sort)
fi

# ---- Upcoming games (collapsed, BOTTOM): dates > today ----------------------
UPDATES=(); while IFS= read -r s; do UPDATES+=("$s"); done < <(jq -r '.fixtures[].date' "$FIX" | sort -u | awk -v t="$TODAY" '$0>t')
if [ "${#UPDATES[@]}" -gt 0 ]; then
  printf '  <details class="earlier"><summary>Upcoming games</summary>\n' >> "$LANDING"
  for d in "${UPDATES[@]}"; do
    printf '  <div class="day">%s</div>\n' "$(fmt_date "$d")" >> "$LANDING"
    while IFS=$'\t' read -r ko kod home away venue slug; do
      ex=0; guide_exists "$slug" && ex=1
      emit_card "$ex" "$kod" "$slug" "$(esc "$home") vs $(esc "$away")" "Round of 32 &middot; $(esc "$venue")"
    done < <(jq -r --arg d "$d" '.fixtures[]|select(.date==$d)|[.ko_pacific,.ko_display,.home,.away,.venue,.slug]|@tsv' "$FIX" | sort)
  done
  printf '  </details>\n' >> "$LANDING"
fi

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
