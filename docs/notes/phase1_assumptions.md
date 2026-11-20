# Phase 1 assumptions and AI work log

Date: 2026-11-20

## Scope

1. Game 3D on Godot 4 with a separate headless entrypoint.
2. Headless CLI contract v1.0 and a single playable night.
3. Chosen tuning is explicitly recorded in game.contract.json; Phase 2 will change it to the official constants.

## Decisions

- Input button edge detection implemented in GameCore, so headless and 3D use the same code.
- Event tick number increments before gameplay actions.
- Scenario setup yields no points or gameplay events.
- Motes score on deposit, not pickup; per-mote score recorded in contract.
- Default entity placement is deterministic; given a seed and identical input/scenario, JSONL should match byte-for-byte.
- Sprint is visual-only enhancement (left Shift); headless contract v1.0 does not expose sprint.

## AI usage

AI assisted with code generation, structuring GameCore, writing CLI parser, validation, tests and README. All runtime claims must be verified by running tests and recording outputs; the assistant did not run Godot on the user's Windows installation.

## Open checks

- Confirm 3D gameplay through win/loss/replay; confirm FPS on local laptop.
- Confirm headless scenario/input error codes and byte-for-byte determinism.
- Confirm that no files with secrets or cache are staged for commit.
