<!-- SPDX-License-Identifier: MIT -->
<!-- Copyright (c) 2026 K. S. Ernest (iFire) Lee -->

# Mission

Find schools of play style for one turn of the Cross Universe card game: named weightings of what a player
values, each of which provably plays differently from the others.

## Success criteria

1. A model of one battle turn, for units with no abilities only, whose answers equal the pinned rules engine's
   on every hand-checkable case.
2. Every reported optimum is proved by the Turbo port on the CPU and equals a second solver's proved optimum.
3. A written protocol, committed before the first run, that says what a school is and when one is kept.
4. A changelog entry for each iteration: what was tried, whether frontier success rose, what was kept.

## Stop criteria

- The Turbo front end rejects the model: report it, do not change solver.
- Two opposite weightings never give different proved plays: add one rules layer, try once more, then report.
- Any step would use the GPU while the game is running, or publish anything: stop and ask.

## Not in the mission

Cards with abilities, spells, items, more than one turn, hidden information, a playable game, art, card text.
