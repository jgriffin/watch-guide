# Watch Guide — Build Prompt

Hand this to any capable Claude, along with **a fixture** and the accompanying **`example.html`**. It researches the match and produces a one-page HTML **watch guide** — for a fan at the game to read on their phone — styled like the example, populated for this match.

Research and presentation are **two separate steps**, producing **two files** per match:

1. **`data.md`** — the research sidecar: every fact you gather, in a readable markdown structure. The **single source of truth**.
2. **`index.html`** — the watch guide, rendered **from `data.md`** in the visual language of `example.html`.

There's no rigid schema and no template engine — `data.md` is structured markdown, and you emit the HTML directly. The point of the split: once `data.md` exists, you can **re-render the look (or iterate formatting) without re-researching** — read `data.md` + `example.html`, emit fresh HTML. Only re-run research when the facts are stale (e.g. confirmed XIs dropped ~1hr before kickoff).

---

## INPUT

> **FIXTURE:** `<teams · competition · date>` — e.g. `Spain vs Portugal — 2026 World Cup, today`

First team = **home** (left side); second = **away** (right side).

**Reader's timezone.** The reader is in **Pacific (Seattle)** — display every kickoff time in **Pacific** (primary), with the venue-local time in parens, e.g. `7:00 PM PDT (10:00 PM EDT · Arlington)`. The folder-name `<HHMM>` (see OUTPUT) also uses Pacific, so the day's guides sort in the order the reader actually experiences them. (This is one consistent zone everywhere — not per-venue — which is what makes a multi-game day legible.)

**If a specific fixture isn't named** (e.g. "watch guides for today's games", "what's on today"): **don't start building.** First find the day's fixtures, **list them** (time · group/round · teams · venue), and **ask the user which to build** — they may want one, a few, or all. Each guide is a real research pass, so confirm scope before fanning out. Only after the user picks do you proceed. (When a specific game *is* named, skip this — go straight to research.)

---

## THE LOOK — match `example.html`

Reproduce the **visual language** of the accompanying `example.html` (a phone-first one-pager), adapting the content to this match. Don't copy its text — copy its *style and structure*:

- Dense sports-programme aesthetic: condensed display fonts (Oswald / Barlow Condensed via a Google Fonts `@import`), **team-colored headers**, dark accent bars, gold highlights, dotted dividers, squad-number chips. **Prose sections are single-column** (What's At Stake, What To Watch For, Names You'll Hear Most) — easier to scan on a phone. **Lineups** side-by-side on wide screens; **CSS-only tabs** on narrow (`@media max-width:680px`).
- **Stakes strip** stacks vertically: gold **message** on top, then a full-width dark **`.tie`** bar below (knockout) or full-width **group table** (group stage). Knockout `.tie` = two prose lines, not a key-value table:
  - `.tie-main` — e.g. `<b>Winner → Round of 16</b> · Loser eliminated`
  - `.tie-sub` — e.g. `<b>Next:</b> vs … · <b>Odds:</b> …` (fold odds here; skip redundant Winner/Loser rows)
- **Self-contained:** one HTML file, inline `<style>`, no external deps beyond the font import. Opens directly in a browser; reads/prints well on a phone.
- **Use each team's REAL colors** (kit/flag) for their side — not the example's red/green. (e.g. Spain red/gold, Portugal red/green, Argentina sky-blue/white.) Pick a primary + a darker shade per team.
- Conceptually one page; it can scroll on a phone.

If you can read the repo, `example.html` is at the project root. **If this was handed to you without the file, ask for it to be pasted/attached** — the look is defined by example, not re-described in full here.

---

## SECTIONS (same order as the example — adapt or skip per match)

1. **Header** — both teams: nickname, FIFA rank, coach, formation. Plus an **info bar**: venue, kickoff (Pacific primary + venue-local in parens — see INPUT), TV, referee.
   - **FIFA rank** is a sourcing-cliff field (previews rarely surface it cleanly) — include it only if you have it from a reliable source; otherwise mark it approx or omit. **Never invent a rank.**
   - **Formation** can be genuinely disputed pre-match (e.g. 3-4-3 vs 5-4-1 are the same shape seen two ways). Label per source consensus and **flag the dispute inline** in the lineup note if sources disagree.
2. **Stakes strip + standings.** Knockout: gold `.msg` narrative, then full-width dark `.tie` bar (`.tie-main` + `.tie-sub` — winner/loser + next opponent + odds). Group stage: same stacked strip with a full-width `table.grp` instead of `.tie`.
3. **How They Got Here** — condensed, chronological: `date · vs opponent · score` with W/D/L chips. No long blurbs.
4. **What's At Stake & What's Next.**
5. **What To Watch For** — 3–4 key individual battles + a set-piece tip.
6. **The Names You'll Hear Most** — ~6 stars, **split by team**.
7. **The Lineups · By The Numbers** — full squads, **numerical order**, **Starters then Bench**, a number chip on every row (a live "who's #18?" lookup tool). **Bench players use the same full lineup rows as starters** (number chip + name + position + club) — never condensed prose. The only divide is a "Bench" sub-heading; every bench player still gets their own row with a number chip.
   - **Tint each team's lineup by the kit they're actually WEARING this match** (the matchday-kit colors from `data.md`, not just identity colors) — e.g. a small kit swatch or a kit-colored accent on the column — so the sheet matches what's on the pitch. (Identity/flag colors still drive the header; the *kit* can differ, e.g. a team in its white away shirt.)
8. **Footer** — caveat (predicted XI; confirmed ~1hr before kickoff) + sources.

**Adapt intelligently.** A knockout has no group table. A huge-history fixture earns more fun facts. Don't force a section that doesn't fit, and don't pad.

---

## THE RESEARCH — fast, accurate, parallel

Target **single-digit minutes**. No broad crawl; no generic scrapers when a known page answers it. **If you have a sub-agent / Task capability, fan these streams out in parallel; otherwise do them in sequence.**

**Stream A — Numbered roster (the live-lookup core).** Get each team's **full squad with shirt numbers** — best single source is the competition's Wikipedia squads page (e.g. "2026 FIFA World Cup squads"), which usually has both teams with numbers, positions, clubs. Take the predicted XI (Stream B) and **join**: those 11 = starters, the rest = bench. ⚠️ **Official tournament numbers ≠ club numbers** — always use the squad-list number. Every player ends up with a number.

**Stream B — Match-centre bundle.** One match page (FotMob / ESPN / Sofascore / official): predicted XI + formation, recent form, head-to-head, venue, city, kickoff (local + zone), broadcast (Eng/Spa), referee, odds / win-probability, weather at kickoff, **matchday kit each team wears** (home/away/third — the kit-clash assignment; flag if unconfirmed, as it firms up a few days out). Group game → current standings + qualification scenarios.

**Stream C — The hard tier (where you add the most value).** Synthesis pass: 3–4 **key battles**, **set-piece threats**, **star blurbs** (signature trait + a hook: backstory, market value, records, recent form), **storylines** (stakes, milestones on the line, manager subplots, off-pitch context), 6–10 **fun facts / Opta-style quirks**.

**Accuracy rules:** prefer official/primary sources; **cross-check the spine** (date, venue, kickoff, standings, who's actually in the squad); **flag uncertainty** with a short note rather than inventing; note that predicted XIs are projections (confirmed ~1hr before KO). Don't over-verify the easy tier — spend the care on the spine and the numbers.

---

## OUTPUT — two files per match

Write to **`matches/<YYYY-MM-DD>-<HHMM>-<home>-<away>/`** — folder named by **kickoff date + Pacific 24h time** (e.g. `matches/2026-06-27-1400-panama-england/` for a 5 PM ET / 2 PM PT kickoff), slug = lowercase hyphenated team names. The date+time prefix makes the folder list sort chronologically (in the reader's Pacific zone) and tells you at a glance when each match is. Create the folder, then write:

1. **`data.md`** first — the research sidecar (structure below).
2. **`<home>-<away>.html`** (e.g. `panama-england.html`, NOT `index.html`) — rendered from `data.md`, styled like `example.html`. A match-named file saves to a phone with a meaningful name.

If you can't write files, output both in separate labelled code blocks.

**Re-skin mode (no research):** if `data.md` already exists and you're only changing the look, **skip all research** — read the existing `data.md` + `example.html` and re-emit the `<home>-<away>.html`.

### `data.md` structure

Readable markdown, not a rigid schema — but cover these so the render step (now or later) has everything it needs:

```markdown
# <Home> vs <Away> — <competition>, <round> · <date>
<!-- Watch-guide research sidecar. Source of truth; index.html is rendered from this. -->

## Spine
- Kickoff: <Pacific time> (<venue-local in parens>)  ·  Date: <YYYY-MM-DD>
- Venue / city  ·  TV: <Eng> / <Spa>  ·  Referee
- Home — nickname · FIFA rank (or "approx"/omit) · coach · formation
- Away — nickname · FIFA rank (or "approx"/omit) · coach · formation

## Stakes & Standings
- Group table (pos · team · P · pts · GD) OR knockout-tie context
- Qualification scenarios per team · parallel match

## How They Got Here
- Home: date · vs opp · score (W/D/L) …
- Away: …

## What To Watch For
- 3–4 key battles · set-piece / dead-ball tip

## The Names You'll Hear Most
- Home: ~3 — name · club · role · hook
- Away: ~3 — …

## Rosters (numbered — official tournament numbers)
### <Home>
- Starters: # · name · pos · club · (C/injury/notes)
- Bench: # · name · pos · club
### <Away>
- …

## Fun Facts / Quirks
- 6–10 Opta-style facts

## Colors
- Identity (header) — Home: primary / dark (real flag/crest); Away: primary / dark
- Matchday kit (what they WEAR this game) — Home: shirt / shorts (e.g. "white shirt, navy shorts"); Away: shirt / shorts. Flag if unconfirmed (kit-clash assignment firms up a few days out).

## Sources & Flags
- Sources used
- Flagged uncertain (not invented)
- Judgment calls
```

---

## QUALITY BAR (check before finishing)

- **`data.md` written first** and complete (it's the source of truth; `index.html` must not contain facts that aren't in it).
- **Every player has a real shirt number** (no blanks), rosters numerically sorted, starters separated from bench.
- Spine cross-checked (date, venue, kickoff, standings/results).
- Each team rendered in its **own real colors** (identity in the header; **matchday-kit colors in the lineup**).
- Kickoff shown in **Pacific** (primary) with venue-local in parens; folder `<HHMM>` in Pacific.
- Blurbs phone-readable and tight; the **hard tier** (storylines, battles, quirks) is what turns a stat-dump into a watch guide — invest there.
- Uncertainty flagged, not invented.
- **Eyeball-ready:** a human reads this on their phone before kickoff. Make it look finished.

End with a 3–4 line note: sources used, anything flagged uncertain, any judgment calls.
