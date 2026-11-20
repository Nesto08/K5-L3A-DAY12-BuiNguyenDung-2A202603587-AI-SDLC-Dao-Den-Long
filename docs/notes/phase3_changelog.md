# Phase 3 breaking changes (Ticket-03)

- `contract_version`: 1.1 -> 1.2.
- Durations: night 1/2/3 now 240/270/300 seconds.
- Lanterns no longer stay lit permanently: fuel cap 100, natural decay 1/second; `lantern_out` event; new relight rule (5 motes).
- Lit lanterns can be refuelled up to 100; full lanterns cannot be interaction targets.
- Shades in wander mode can target lit lanterns with fuel below 30, enter `drain` state, remove 5 fuel/second.
- Safe zones require lantern fuel >= 30, not just `lit`.
- No instant `all_lit` win; replace with at-dawn 60%-lit survival threshold and new `dawn_survived` game-over reason.
- Carrying capacity grows from 10 to a maximum of 20 based on successful light/relight actions.
- Scoring replaced: +5 deposited/refuelled mote, +100 first light, +40 relight, +5 stun or +15 drain stun, at-dawn bonuses; time-left bonus removed.
- Headless scenario/snapshot fields added for lantern fuel, ever-lit, relight count; player capacity and successful_lights; shade target_lantern_id; new events.
- Added saved distinguishable-colors UI option and lantern fuel indicators.

Regression policy: retain tests of unchanged mechanics (movement, dash, pause, schedules, deterministic JSONL, input validation), revise obsolete scoring/immediate-victory assertions under Ticket-03, and disclose the change. Never change an old test quietly merely to hide a failure.
