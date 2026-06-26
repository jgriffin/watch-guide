# Watch Guide — Build Prompt

Hand this to any capable Claude, along with **a fixture** and the accompanying **`example.html`**. It researches the match and produces a one-page HTML **watch guide** — for a fan at the game to read on their phone — styled like the example, populated for this match.

This is the whole thing in one run: **research + build.** No data schema, no template engine. The example shows the *look*; you do the *research* and emit a new self-contained HTML that looks like it, with this match's content.

---

## INPUT

> **FIXTURE:** `<teams · competition · date>` — e.g. `Spain vs Portugal — 2026 World Cup, today`

First team = **home** (left side); second = **away** (right side).

---

## THE LOOK — match `example.html`

Reproduce the **visual language** of the accompanying `example.html` (a phone-first one-pager), adapting the content to this match. Don't copy its text — copy its *style and structure*:

- Dense sports-programme aesthetic: condensed display fonts (Oswald / Barlow Condensed via a Google Fonts `@import`), **team-colored headers**, dark accent bars, gold highlights, dotted dividers, squad-number chips, two-column blocks that collapse to one column on a phone (`@media max-width:680px`).
- **Self-contained:** one HTML file, inline `<style>`, no external deps beyond the font import. Opens directly in a browser; reads/prints well on a phone.
- **Use each team's REAL colors** (kit/flag) for their side — not the example's red/green. (e.g. Spain red/gold, Portugal red/green, Argentina sky-blue/white.) Pick a primary + a darker shade per team.
- Conceptually one page; it can scroll on a phone.

If you can read the repo, `example.html` is at the project root. **If this was handed to you without the file, ask for it to be pasted/attached** — the look is defined by example, not re-described in full here.

---

## SECTIONS (same order as the example — adapt or skip per match)

1. **Header** — both teams: nickname, FIFA rank, coach, formation. Plus an **info bar**: venue, kickoff (local time + zone), TV, referee.
2. **Stakes strip + standings table.** (Knockout tie: replace the group table with the tie context — aggregate, what's at stake.)
3. **How They Got Here** — condensed, chronological: `date · vs opponent · score` with W/D/L chips. No long blurbs.
4. **What's At Stake & What's Next.**
5. **What To Watch For** — 3–4 key individual battles + a set-piece tip.
6. **The Names You'll Hear Most** — ~6 stars, **split by team**.
7. **The Lineups · By The Numbers** — full squads, **numerical order**, **Starters then Bench**, a number chip on every row (a live "who's #18?" lookup tool).
8. **Footer** — caveat (predicted XI; confirmed ~1hr before kickoff) + sources.

**Adapt intelligently.** A knockout has no group table. A huge-history fixture earns more fun facts. Don't force a section that doesn't fit, and don't pad.

---

## THE RESEARCH — fast, accurate, parallel

Target **single-digit minutes**. No broad crawl; no generic scrapers when a known page answers it. **If you have a sub-agent / Task capability, fan these streams out in parallel; otherwise do them in sequence.**

**Stream A — Numbered roster (the live-lookup core).** Get each team's **full squad with shirt numbers** — best single source is the competition's Wikipedia squads page (e.g. "2026 FIFA World Cup squads"), which usually has both teams with numbers, positions, clubs. Take the predicted XI (Stream B) and **join**: those 11 = starters, the rest = bench. ⚠️ **Official tournament numbers ≠ club numbers** — always use the squad-list number. Every player ends up with a number.

**Stream B — Match-centre bundle.** One match page (FotMob / ESPN / Sofascore / official): predicted XI + formation, recent form, head-to-head, venue, city, kickoff (local + zone), broadcast (Eng/Spa), referee, odds / win-probability, weather at kickoff. Group game → current standings + qualification scenarios.

**Stream C — The hard tier (where you add the most value).** Synthesis pass: 3–4 **key battles**, **set-piece threats**, **star blurbs** (signature trait + a hook: backstory, market value, records, recent form), **storylines** (stakes, milestones on the line, manager subplots, off-pitch context), 6–10 **fun facts / Opta-style quirks**.

**Accuracy rules:** prefer official/primary sources; **cross-check the spine** (date, venue, kickoff, standings, who's actually in the squad); **flag uncertainty** with a short note rather than inventing; note that predicted XIs are projections (confirmed ~1hr before KO). Don't over-verify the easy tier — spend the care on the spine and the numbers.

---

## OUTPUT

A single self-contained **`index.html`**, written to **`matches/<home>-<away>/index.html`** (slug = lowercase, hyphenated team names; create the folder). If you can't write files, output the full HTML in one code block to save there.

---

## QUALITY BAR (check before finishing)

- **Every player has a real shirt number** (no blanks), rosters numerically sorted, starters separated from bench.
- Spine cross-checked (date, venue, kickoff, standings/results).
- Each team rendered in its **own real colors**.
- Blurbs phone-readable and tight; the **hard tier** (storylines, battles, quirks) is what turns a stat-dump into a watch guide — invest there.
- Uncertainty flagged, not invented.
- **Eyeball-ready:** a human reads this on their phone before kickoff. Make it look finished.

End with a 3–4 line note: sources used, anything flagged uncertain, any judgment calls.
