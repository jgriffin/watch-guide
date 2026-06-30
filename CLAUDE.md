# Watch Guide

A **matchday watch guide / cheat sheet** for someone attending a live football match in person — read before and during the game (usually on a phone) to enjoy it at a deeper level. Lineups, player blurbs, storylines, fun facts, who-to-watch.

First instance: **Egypt vs Iran, 2026 World Cup, Group G decider** (today, Fri Jun 26 2026). Longer-term this likely becomes a reusable pattern/skill — but nail one concrete sheet first, extract the pattern after.

## Working method

The user wants **data first, presentation second** — decide *what facts to collect* before touching format. Keep the structured data (single source of truth) decoupled from any rendered output (DRY / decouple-modules preference).

Reference draft (Claude-generated, good direction, one-page): `/Users/griff/Downloads/egypt-iran-matchday.html`. Layout sections worth keeping: dual-team header + infobar · stakes strip + group table · two lineup columns (XI + bench) · "how they got here" · players-to-watch callout · "what's next/at stake" · footer caveat.

## Data field inventory (from research — tiered)

**TIER 1 — CORE (spine; easy to source):** teams+crests · competition/round · kickoff (local+TZ) · venue · where-to-watch · league/table position · predicted→confirmed XI · formation diagram · per-player identity (pos, #, club, age) · injuries/fitness · last-5 form · what's-at-stake one-liner · signature trait per key player · live scoreboard (if persistent).

**TIER 2 — HIGH-VALUE (the "enjoy it deeper" payload; the differentiators):** home/away form splits · H2H record + last meeting · qualification permutation scenarios · 2-3 narrative hooks · manager subplot · milestone-on-the-line · player blurb hooks (market value, signature skill, recent form, backstory, records vs this opponent, set-piece/pen taker) · win-probability / odds · **key individual battles** (winger vs full-back etc.) · **set-piece threat** · pressing identity (high press vs low block) · in-play stats (xG, momentum, ratings) · fun facts (streaks, Opta "first/only", stadium/nickname trivia).

**TIER 3 — NICE-TO-HAVE:** referee + card tendencies · weather · attendance · bench/key subs · suspension risk · nickname/cult-hero · heritage (founding year, crest/kit origin, famous alumni) · tactical depth (overloads, set-piece defending) · heatmaps/shotmaps.

**Key structural insight — the "sourcing cliff":** identity/form/stats fields are easy/free (FotMob, Sofascore, Transfermarkt, Wikipedia). The *storyline, rivalry, tactical-battle, Opta-quirk* fields are the hard layer — and they're exactly what separates a stat-dump from a watch guide. That hard layer is the natural target for LLM synthesis from match context.

Best-of-breed format references: **FotMob match centre** (pre-match bundle), **Sofascore Attack Momentum** (in-play), **Opta Facts** (quirk facts), **PremierLeague.com Permutations** (stakes), **Sports Mole / OneFootball** (written-preview schema).

## Egypt vs Iran — VERIFIED facts (Jun 26 2026)

Fact-checked against Wikipedia/ESPN/Al Jazeera/FOX. The reference draft is mostly correct; corrections noted.

- **Fixture:** Egypt v Iran, **Lumen Field, Seattle, Fri Jun 26 2026, 8:00 PM PDT** (Match 63, Group G final round). TV: **FS1** (Eng) / **Universo + Peacock** (Spa). Ref: **Szymon Marciniak**. ✅
- **Group G standings (after R2):** Egypt 4 (W1 D1, +2) · Iran 2 (D2, 0) · Belgium 2 (D2, 0) · New Zealand 1 (D1 L1, −2). Egypt v Iran and NZ v Belgium kick off simultaneously. ✅
- **Results so far:** Egypt — drew Belgium 1-1, beat NZ 3-1 (**first-ever WC win**, debut 1934). Iran — drew NZ 2-2, drew Belgium 0-0 (**Beiranvand MOTM, 7 saves**). ✅
- **Stakes:** Egypt win = group winners + first-ever knockout berth; draw likely enough unless Belgium beat NZ by 3+. Iran win tops group (if Belgium don't win); can still advance 2nd/3rd via best-thirds math. ✅
- **Neither nation has ever reached a WC knockout round.** ✅
- **Coaches:** Egypt — **Hossam Hassan**; Iran — **Amir Ghalenoei**. ✅
- **Salah** (34, Liverpool, capt): on **68** intl goals, **one shy of Hassan's 69** national record — Hassan is *both* record-holder and current coach. (Already Egypt's all-time WC top scorer.) ✅
- **Captains:** Egypt — Salah. Iran — **Ehsan Hajsafi** (145 caps, chasing Nekounam's 149); Jahanbakhsh sometimes wears armband — treat Hajsafi as captain. ✅
- **H2H:** only ~2 prior meetings, both friendlies (1975, 2000 1-1) → **first-ever competitive meeting**. Egypt has never beaten Iran. ✅
- **Iran travel saga:** based in **Tijuana**; visas ~10 days before opener, some staff denied entry, in-and-out US travel rule, FIFA complaint filed. Well-documented off-pitch story. ✅
- **Jahanbakhsh:** first Asian player to top-score a major European league — **Eredivisie 2017-18, 21 goals, AZ Alkmaar.** ✅
- **Beiranvand:** saved Ronaldo's penalty (2018 WC); now at **Tractor.** ✅

### CORRECTIONS to the reference draft
- ❌ **Marmoush "27-goal season"** — not real. He's a Man City player (joined Jan 2025 from Frankfurt) but 2025-26 has been quiet (~3 PL goals). The "27" looks conflated with his 2024-25 Frankfurt breakout. Fix or drop.
- ⚠️ **Taremi** "60 goals in 104 caps" → actually **~58 goals / ~103 caps**. At **Olympiacos** (joined Aug 2025 from Inter). Fix.
- ⚠️ **Squad numbers UNVERIFIED** — preview sources listed XIs without shirt numbers. Common assumptions (Salah 10, Taremi 9, Jahanbakhsh 7, Beiranvand 1, Hajsafi 3) are plausible but not confirmed. Flag if numbers matter; confirmed XIs + numbers drop ~1hr before kickoff.

## Speed constraint (hard requirement for the real product)

A fan generates this for a game they're about to attend — it has to be **fast**, not a 25-min research project. The slow first pass here was a one-time *scoping* cost (4 deep agents doing full web research + cross-checking the whole menu). The shipping generator must not work this way.

Fast-path design (from the research): ~60% of content is **easy-tier** and bundles from 1-2 structured sources — **FotMob match centre alone** gives predicted XIs + formation + form + H2H + weather + broadcaster; one odds/Opta call covers predictions. The expensive part is the **hard-tier** storyline/trivia/quirk synthesis. So the real run = a couple of targeted fetches + one synthesis pass, single-digit minutes — not a fan-out of deep researchers. Scope tight; don't re-collect the whole menu every time.

## Presentation architecture (decisions + direction)

**Chosen architecture: exemplar-driven render, with a research sidecar.** The user rejected the procedural pipeline (rigid `content.json` schema + Jinja `template.html` + `render.py`) as "too procedural" — for a one-page guide a human eyeballs before kickoff, the determinism/cheap-re-render the pipeline bought isn't worth its weight, and the fixed schema fought per-match variety. So the *render* stays exemplar-driven: the example sheet IS the template (a visual reference), and the LLM emits HTML directly.

**Sidecar decision REOPENED (Jun 27 2026):** the original choice was *one prompt, no sidecar* — but iterating on the look meant re-running the whole research, and nothing about a finished match was inspectable. So research and presentation are now **two steps / two files**: `data.md` (structured-markdown research sidecar, the single source of truth) + `index.html` (rendered from it). This is NOT the parked pipeline — no rigid JSON schema, no Jinja, no `render.py`; `data.md` is readable markdown and the LLM still emits HTML directly. It just means **re-skinning reads saved data instead of re-researching.**

```
watch-guide/
  example.html             ← THE LOOK. A finished, good-looking sheet (the Egypt/Iran one).
                              "Make me something that looks like this." Edit to evolve the house style.
  watch-guide-prompt.md    ← THE PROMPT. fixture in → researches + emits a self-contained
                              index.html styled like example.html, populated for that match.
                              Portable to ANY Claude (sub-agents if available; attach example.html if no repo).
  matches/<date>-<time>-<home>-<away>/   ← one produced guide; folder named by kickoff
      data.md                            ← research sidecar (source of truth)
      index.html                         ← rendered from data.md, styled like example.html
  archive/deterministic-pipeline/    ← parked render.py + template.html + content.json (reference; not used)
  archive/egypt-iran-handbuilt/      ← the original hand-assembled draft
```

- **How it works:** research writes `data.md` (the facts). The render step reads the *look* from `example.html` + the *facts* from `data.md` and emits the finished HTML — no template engine, no rigid schema. Each team is rendered in its own real kit/flag colors (carried as content in `data.md`, not hardcoded).
- **Folder naming:** `matches/<YYYY-MM-DD>-<HHMM>-<home>-<away>/` — kickoff date + venue-local 24h time, so the list sorts chronologically and you can tell at a glance which match is which / which is latest.
- **The trade (accepted):** render is non-deterministic — two renders aren't byte-identical and it may occasionally fumble a detail. Fine because a human reads it before the game. **Cheap re-skin now restored:** iterate the look by editing `example.html` and re-rendering from the saved `data.md` (no re-research). Re-run research only when facts go stale (confirmed XIs ~1hr pre-KO).
- **Agreed section order (now encoded in the prompt + shown in example.html):** header (+infobar+standings) → How They Got Here (condensed chronological) → What's At Stake & What's Next → What To Watch For (key battles + set-piece tip) → The Names You'll Hear Most (split by team) → The Lineups · By The Numbers (numerical, starters then bench, every player numbered).

## Efficient research recipe (avoid the 26-min fanout — aim single-digit minutes)

Scope research to what the format needs (table below), from a few high-yield sources — NOT a broad crawl, NOT firecrawl.

1. **Numbered roster (the live-lookup core):** Wikipedia "<year> FIFA World Cup squads" lists every nation's full 26 WITH shirt numbers/positions/clubs — one page covers both teams. This is the source of truth for numbers (official WC numbers ≠ club numbers: e.g. Taremi WC #9, not club 99). Join to the predicted XI (mark starters) → full numbered roster.
2. **Match-centre bundle:** one match page (FotMob/ESPN/Sofascore) → predicted XI, form, H2H, venue, broadcast, odds.
3. **Hard tier (storylines, fun facts, tactics, blurbs):** ONE synthesis pass — this is where the LLM earns its keep. Flag uncertainty instead of triple-checking.

| Section | Needs | Source |
|---|---|---|
| Header/infobar | teams, nicknames, FIFA ranks, coaches, formations, venue, kickoff, TV, ref | match centre |
| Group table + stakes | standings, qualification scenarios | standings + derive |
| How they got here | results: date·opp·score | fixtures/standings |
| What to watch for | 3-4 key battles + set-piece tip | synthesis |
| Names you'll hear most | ~6 stars: club, role, blurb | synthesis + Transfermarkt |
| Lineups (numbered roster) | full ~26 + numbers + starter/bench flag | **WC squads page ⋈ predicted XI** |

## Status / next steps

- [x] Brainstorm + verify Egypt-Iran facts, fact-check the reference draft
- [x] Lock data depth (maximal) into a structured single-source file
- [x] Iterate phone-first presentation; settle section order (look frozen in `example.html`)
- [x] Pivot from procedural pipeline → exemplar-driven single prompt (`watch-guide-prompt.md`)
- [x] **Test-drove the prompt on two fixtures** (Jun 26 2026): `matches/egypt-iran/` (Group G — same fixture as `example.html`, a regression test) and `matches/spain-uruguay/` (Group H). Both follow the prompt's sections/look; real team colors; full 52-player numbered rosters (starters split from bench). Spain XI + storyline cross-checked against SI/Sky/FIFA/CBS and confirmed.
  - **Prompt-test findings (apply before next run):**
    1. **`.bench`/`.bn` CSS in `example.html` is a trap** — the example *body* renders bench as full `xi` rows, but leftover prose-box CSS (≈ lines 69-72) led one builder to emit condensed prose benches that fail the "number chip on every row" bar. → **Delete the unused `.bench`/`.bn` CSS from `example.html`**, and/or make §7 explicit that bench = full `xi` rows.
    2. **"FIFA rank" header field is a sourcing-cliff item** — previews don't surface it cleanly; mark optional/approx so it isn't invented.
    3. **Formation can be genuinely disputed pre-match** (Iran 3-4-3 vs 5-4-1) — prompt should say "label per source consensus; flag if disputed" (done inline in both sheets' lineup notes).
    4. Worked well: `<home>-<away>` slug, section order, look/colors all came through from two independent builders.
  - [x] Applied findings 1-3 to `watch-guide-prompt.md` + `example.html` (Jun 27).
- [x] Efficient squad-number research (Wikipedia WC squads ⋈ predicted XI) → full numbered roster, all 52 players
- [x] **Two-file split** (Jun 27): each match folder = `data.md` (research, source of truth) + `<home>-<away>.html` (rendered from it). Re-skin without re-research. Folders `matches/<YYYY-MM-DD>-<HHMM>-<slug>/`, time in **Pacific** (reader is Seattle). Filename match-slug (saves cleanly to phone).
- [x] **Matchday kit colors** added to spec — lineups tinted by the worn kit, identity colors in header.
- [x] **Mobile look** (Jun 29): `example.html` got CSS-only lineup tabs (radio switcher), 2×2 infobar, single-column prose. Re-skin the day's guides to inherit it.
- [x] **9 guides built so far:** Jun 26 (egypt-iran, spain-uruguay), Jun 27 (panama-england, colombia-portugal, jordan-argentina), Jun 28 (canada-south-africa), Jun 29 R32 (brazil-japan, germany-paraguay, netherlands-morocco).
- [x] **Vercel site LIVE** (Jun 29): **https://wc-watch-guide.vercel.app** — static, schedule landing (grouped by day) + clean guide URLs (`/brazil-japan`) + hide-scores toggle. Solves the iPhone Files-preview problem.
- [x] **v1b — knockout bracket is the landing HERO** (Jun 29): hand-rolled R32→Final tree (no library; site is static HTML from a shell script). Desktop = connected tree with CSS elbow connectors; mobile = CSS-only round tabs (R32/R16/QF/SF/Final, same radio-`:checked ~` pattern as the lineup tabs). Each R32 tie links to its guide; fills in round-by-round as results land. **Data fetched separately** (see below). Schedule moved BELOW the bracket and reworked: **Today** + **Next up** (next match day) open, **More upcoming** + **Earlier games** collapsed — middle ground between today-only and show-all.

### Bracket data — `fetch-bracket.sh` → `bracket.json` (source of truth)
- `./fetch-bracket.sh` pulls **openfootball/worldcup.json** (one public-domain JSON file, `raw.githubusercontent.com/openfootball/worldcup.json/master/2026/worldcup.json`, no key/auth) and transforms (jq) → committed `bracket.json`. Run it periodically during knockouts (results change ≤3×/day; cache the rest). `build-site.sh` reads the committed cache → build stays offline/deterministic. Real data **matches** the repo's fixtures (verified: Brazil-Japan, Germany-Paraguay, Netherlands-Morocco, SA-Canada are the real R32 ties; pen shootouts decoded), so the bracket links straight to existing guides.
- `bracket.json` shape: `rounds[]` (r32/r16/qf/sf/final) of ordered `ties` + `third`. Per tie: `num, date, t1/t2, f1/f2 (flag emoji), s1/s2, winner, note (pens/AET), feeders[2], slug`. **Topology is fixed** (canonical 2026 feeder map baked into `fetch-bracket.sh`, not read from openfootball's laggy placeholder-resolution). Downstream TBD slots are **filled from feeder winners** in the fetch (one level/fetch, cascades round by round). Flags + slug (name-normalized, order-independent ⋈ `fixtures.json`) are baked in `fetch-bracket.sh`.

### Hide-scores (rethought Jun 29) — **date-aware, today-only**
- Default **ON**, but masks **only TODAY's** results (the only spoiler for a delayed viewer); earlier results — and the bracket advancement they caused — always show. Per tie: build-site marks `.tie.today` + `.sc score` only when `tie.date == $(date +%F)`; an advanced team gets `.nm.adv` only if its **feeder game was today** (so e.g. Canada from a Jun-28 win shows in R16, Morocco from a Jun-29 win is TBD). "Show scores" button reveals today. **Lives only on the landing.**
- **Guides do NOT hide scores** (Jun 29): per-guide copy is plain `cp` (no snippet injected). Guides are forward-looking (predicted XIs, no live score); any results in them are older games you'd want to see. The toggle/snippet is appended to the landing only.

### Site / redeploy
- Build: `./build-site.sh` regenerates `site/` from `matches/` + `fixtures.json` + `bracket.json`. Copies each guide → `site/<slug>/index.html` **as-is (no snippet)**; renders the bracket hero + schedule landing; appends the hide-scores snippet to the landing only. `fixtures.json` (project root) is the maintained schedule source → **placeholders** for unbuilt games; refresh as the bracket fills in. Landing order: bracket → **Today** (open) → **Next up** (open) → **More upcoming** (`<details>`) → **Earlier games** (`<details>`, + orphan group guides). `.sheet` widened to 860px to fit the 5-column tree. `site/` is gitignored (derived); `build-site.sh` + `fetch-bracket.sh` + `fixtures.json` + `bracket.json` are the source.
- Deploy: `cd site && vercel --prod` (project `wc-watch-guide`, scope `johngrif`, linked via `site/.vercel`). Manual CLI by design. ⚠️ `build-site.sh` **must preserve `site/.vercel`** (it clears site/ contents but excludes `.vercel`) — else `vercel --prod` re-links to a junk project named after the dir ("site"). Don't revert that to a plain `rm -rf site`.
- Full refresh during knockouts: `./fetch-bracket.sh && ./build-site.sh && (cd site && vercel --prod)`.

### Open
- [ ] **v1b-next: visual two-sided/connector polish** — final+3rd-place alignment in the last column is slightly off-center (3rd-place card shifts the final up); fine for now.
- [ ] Re-skin the 6 pre-Jun-29 guides to the mobile lineup-tabs look (only the Jun-29 three have it).
- [ ] Automate `fetch-bracket.sh` refresh (cron/routine ~3×/day during knockouts) — currently manual.
- [ ] Eventually: fold the whole flow into a reusable skill.
