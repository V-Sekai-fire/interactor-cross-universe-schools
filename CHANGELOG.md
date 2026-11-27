<!-- SPDX-License-Identifier: MIT -->
<!-- Copyright (c) 2026 K. S. Ernest (iFire) Lee -->

# Changelog

The frontier-learning record: what was tried, whether frontier success rose, what was kept. Counts are recounted
from `results/iteration-N/traces.jsonl`.

## Iteration 1 (2026-11-26): the protocol as first committed

**Tried.** Baseline `steady = (2, 2, 2, 2, 1)` and five candidates, each with one weight doubled, on levels `g2m1`
and `g2m4`, seeds 1 to 8. 128 solves, Turbo port on the CPU, 525 to 12,637 nodes a solve (median 4,789).

**Calibration.** Both levels calibrated: the clone lane found on 8 of 8 and 8 of 8, the dropped-constraint lane on
8 of 8 and 8 of 8. All 96 player solves were proved (Turbo exhaustive, equal to Chuffed, plan legal and worth the
bound). The 16 solves not proved are the 16 of the dropped-constraint lane.

**Result.** No school kept. Every candidate scored 0 of 8 on both levels at rung 2, so there was no frontier cell
and, by the rule as written, no further rung was tried.

| Candidate | Outcome equal to steady's | Different | Different but a tie for one side |
|-----------|---------------------------|-----------|----------------------------------|
| `striker`, `hunter`, `keeper`, `warden` | 16 of 16 each | 0 | 0 |
| `banker` | 14 of 16 | 2 | 2 |

**Frontier success.** 0, unchanged from nothing. **Kept.** The baseline only.

**Reading.** Doubling one weight does not move the optimum on these boards. The two boards where `banker` played
differently were ties, which the definition of distinct is there to refuse.

**Real artifact.** The Lean front end's dump differed from Turbo's own on 128 of 128 solves (`docs/findings.md`,
finding 2); no optimum disagreed.

**Not measured.** Rungs 4 and 8; 3 or more units a side; the rules engine's verdict on any plan; more than one
turn. One run, one draw of 8 boards a level.

## Iteration 2 (2026-11-26): every rung tried (a change made after iteration 1)

**Tried.** The same baseline, levels, seeds and lanes; each candidate at rungs 4 and 8. 208 solves, 407 to 13,745
nodes a solve (median 4,685).

**Calibration.** Both levels calibrated again: clone 8 of 8 and 8 of 8, dropped constraint 8 of 8 and 8 of 8. All
176 player and clone solves proved; the 16 not proved are the dropped-constraint lane.

**Result.** One school kept: `banker`, bank weight ×8, `(2, 2, 2, 2, 8)`.

| Candidate | Rung 4 (`g2m1`, `g2m4`) | Rung 8 | Kept |
|-----------|-------------------------|--------|------|
| `striker`, `hunter`, `keeper`, `warden` | 0, 0 | 0, 0 | no |
| `banker` | 8, 6 | 8, 7 | rung 8, a school |

**How `banker` plays.** On 15 of 16 boards it ends the turn with 5 mana for next turn where `steady` ends with 1
to 4, and pays for it with board: it keeps fewer levels of units on the field (for example 0 against 4 at `g2m1`
seeds 4 and 5). Damage and kills are the same as `steady`'s on 13 of 16 boards. The one board where it does not
differ (`g2m4` seed 1) is one where `steady` already banks 5.

**Frontier success.** From 0 to 15 of 16 for `banker`; 0 for the rest. **Kept.** `steady` and `banker`.

**Real artifact.** The Lean front end's dump differed from Turbo's own on 208 of 208 solves; no optimum disagreed.

**Not measured.** Whether a school wins more: a school here only plays differently for one turn. 3 or more units a
side; the engine's verdict; more than one turn.

