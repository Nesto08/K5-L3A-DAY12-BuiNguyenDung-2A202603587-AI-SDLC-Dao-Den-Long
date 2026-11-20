# ADR-03 — Lantern fuel and dawn survival

Status: implemented for Ticket-03 (Test Contract v1.2).

## Context

Ticket-03 explicitly replaces immediate all-lit victory with survival until dawn. It also replaces permanent light and safety with decaying fuel and shade draining.

## Decision

- Store per-lantern `lit`, `ever_lit`, `deposited`, `relit_count`, and exact integer `fuel_units` (one fuel unit = 1/60 visible fuel). Display and export visible `fuel` rounded to one decimal.
- The `lit` state is extinguished once fuel reaches zero. A previously lit lantern needs five motes to relight, otherwise ten.
- Full lit lanterns cannot accept motes; partial refuelling accepts only enough motes to reach 100 fuel.
- Capacity increases by two after each successful light/relight, cap 20. Scenario-lit lanterns do not increment the counter.
- Resolve losses due to zero flames before dawn evaluation. Dawn requires at least 60% of lanterns lit and at least one flame.
- Keep the tick scheduler and headless CLI from v1.1, extend event/snapshot schema for v1.2.

## Consequences

- Prior scoring and win-condition tests must be updated or explicitly retired with a change-request explanation. Do not artificially change the new game to make obsolete assertions pass.
- User-facing settings are saved under Godot `user://lantern_settings.cfg`, not inside the repository.
- Other gameplay mechanics from v1.1 remain in effect unless superseded by Ticket-03.
