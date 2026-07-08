---
name: watch-guide-sync
description: >-
  Refresh the World Cup watch-guide site and fill in any missing guides for
  upcoming games. Run when the user says /watch-guide-sync, or asks to "update
  the games / bracket", "build the guides that need building", "sync the watch
  guides", or catch the site up after results have moved on. Fetches the latest
  bracket + schedule, finds upcoming fixtures with no guide, generates them, and
  ships (commit + push → auto-deploy).
user_invocable: true
---

# Watch Guide Sync

One command to keep the matchday site current. It refreshes the data, finds
**upcoming games missing a guide**, generates them (each a real research pass
per `watch-guide-prompt.md`), rebuilds, and pushes to `main` (Vercel deploys).

Run from the project root: `/Users/griff/dev/claude/skills/watch-guide/`.

## Scope (from `$ARGUMENTS`)

- **(no argument)** → today + the next match day. The default. Matches the two
  "open" sections on the landing.
- **`all`** → every upcoming resolved fixture (today or later) with no guide.
  Use when catching up multiple days / a whole round.
- **a slug** (e.g. `france-morocco`) → just that one game (rebuild or force).
- **a date** (`2026-07-11`) → that day's games.

Only *resolved* fixtures (both teams known) exist in `fixtures.json`, so you
never generate a guide for a TBD slot.

## Workflow

### 1. Refresh the data (deterministic — no LLM)
```bash
./fetch-bracket.sh
```
This pulls live results → rewrites `bracket.json` and **derives `fixtures.json`**
from `schedule.json` (the fixed calendar) ⋈ resolved bracket ties. `fixtures.json`
and `bracket.json` are generated — never hand-edit them; venues/times live in
`schedule.json`.

### 2. Find the target fixtures (deterministic)
```bash
TODAY=$(TZ=America/Los_Angeles date +%F)
NEXT=$(jq -r --arg t "$TODAY" '[.fixtures[].date]|map(select(.>$t))|min // empty' fixtures.json)
# default scope = today + next match day; adjust the select() per $ARGUMENTS
jq -r --arg t "$TODAY" --arg n "$NEXT" '
  .fixtures[] | select(.date==$t or .date==$n)
  | [.date,.ko_pacific,.ko_display,.home,.away,.venue,.round,.slug] | @tsv' fixtures.json
```
For each row, a guide is **missing** if `matches/*-<slug>/` has no `*.html`.
Drop rows that already have a folder. What's left is the build list.
(For `all`, change the select to `.date>=$t`; for a slug/date, filter to it.)

If the build list is empty, say so and stop — nothing to do but the refresh
(still commit + push if `bracket.json`/`fixtures.json` changed in step 1).

### 3. Generate each missing guide (the LLM step — delegate, in parallel)
Dispatch **one subagent per missing game** (Agent tool, `general-purpose`, run
in background so they run concurrently). Each agent follows
**`watch-guide-prompt.md`** — do not restate the guide spec; point the agent at
it. Hand each agent a **pre-filled spine** so it doesn't re-derive the basics:

- **From `fixtures.json`:** home, away, date, `ko_display` (Pacific), venue,
  round, slug → folder `matches/<date>-<ko_pacific>-<slug>/`, file `<slug>.html`.
- **Venue-local kickoff:** derive from the venue's timezone (ET/CT/PT) vs the
  Pacific `ko_display`; tell the agent to confirm and show it in parens.
- **What's Next (the downstream tie):** in `bracket.json`, find this tie's
  `num`, then the tie whose `feeders` include it, then the *other* feeder →
  "winner meets the winner of X v Y" (or the named team if resolved). Pass it in.
- **TV / referee / weather / predicted XIs / kits / storylines:** the agent
  researches these (Streams B/C in the prompt).

**Retrospective mode:** if the game is already played — its `bracket.json` tie
has `winner != null` **and** `date < TODAY` — tell the agent to build it
retrospectively: final score up top, **actual** XIs (not "predicted"), stakes/
next in past tense, drop the "confirmed ~1hr before KO" caveat. (Won't happen in
the default scope, which is forward-looking; only via `all` or an explicit past
slug.)

Include the QF-pairing note in the spine when relevant (e.g. the two same-day
ties that feed one quarter-final meet each other's winners).

### 4. Rebuild, verify, ship
```bash
./build-site.sh
```
Spot-check: each new `matches/<...>/` has `data.md` + `<slug>.html`; the guide is
well-formed (`<title>`, closing `</html>`, full numbered rosters); the landing
shows it (no lingering "Guide not generated yet" for the games you built).

Then commit + push (publish gate = **straight to main**; the site auto-deploys):
```bash
git add schedule.json fixtures.json bracket.json matches/<new folders>
git commit -m "watch-guide: sync guides for <games> (<date>)"
git pull --rebase   # the bracket-refresh cron also pushes; rebase first
git push
```
If `git push` is rejected, `git pull --rebase` and re-push (the cron commits
`bracket.json`/`fixtures.json` on its own schedule; rebasing is expected).

## Report back
A compact summary: data refreshed (bracket/fixtures deltas), which guides were
built (and any that were retrospective), anything flagged uncertain by the
agents, and confirmation it's pushed/deploying. Keep tool output out of the main
thread — the subagents do the heavy lifting.

## Notes
- **Don't** hand-edit `fixtures.json` or `bracket.json` — regenerate via
  `fetch-bracket.sh`. To fix a venue/time, edit `schedule.json`.
- Predicted XIs firm up ~1hr before kickoff; running this again close to KO
  re-researches and overwrites the guide with confirmed lineups (re-skin mode in
  `watch-guide-prompt.md` skips research when only the look changes).
- This can be wrapped in a local cron / `/loop` later for hands-off daily runs;
  today it's user-triggered.
