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

## Iteration 3 (2026-11-26): halted

Started on the GPU. Halted by the owner after the mirror lane (8 of 8 seeds scored exactly 1 of 2)
and 2 seeds of the idle lane (idle scored 0 on both). 122 turns, all proved on the GPU, none solved at the root.
No baseline, no improvement round, so nothing is kept or changed; the partial traces and the eBPF profile are in
`results/iteration-3-halted-20261126/`. Resume from `RESUME.md`.

## Iteration 3 (2026-11-27): the schools face off

**Tried.** Matches of 6 turns, two seats, 8 seeds; Turbo on the GPU only, 64 blocks, a turn retried when its plan is
illegal (finding 4). 1,185 turns, all proved, none needed a retry, none solved at the root; 976 at 50 percent duty and
209 at 10 percent while VRChat ran. 104 face-offs. An earlier rerun that hit the race is kept as
`results/iteration-3-provisional-20261127/`.

**Calibration.** Mirror 8 of 8 (exactly 1 of 2 on every seed), idle 8 of 8 (idle lost every seed).

**Baseline.** `banker` against `steady`: 0 of 8 seeds won, 4 of 16 points (per seed 1, 1, 0, 0, 1, 0, ½, ½). In
whole matches the school that banks mana never beats the balanced one.

**Improvement round.** No mutant reached 5 of 8, so nothing was kept.

| Mutant | Seeds won against its parent | Points of 16 |
|--------|------------------------------|--------------|
| every `steady` mutant (each weight doubled) | 0 | 8 (a tie on every seed: it plays exactly like `steady`) |
| `banker+damage` | 1 | 8.5 |
| `banker+kill`, `banker+life`, `banker+bank` | 0 | 8 |
| `banker+board` `(2, 2, 4, 2, 8)` | 3 | 10 |

**Frontier success.** `banker+board` is the frontier: better than its parent on some seeds, not reliably.
**Kept.** `steady` and `banker` unchanged.

**Reading.** Doubling one weight does not change `steady`'s play at all; for `banker` only the board weight moves
it in a useful direction, back toward keeping units, which is what `steady` does.

**Profile** (BCC `profile`, 12 windows of 10 minutes, the whole host): of the run's own processes the Erlang
runtime took the most CPU (a scheduler at 16 percent of all samples, mostly starting a fresh `elixir` for the
Turbo player and its GPU preparation on every solve), then the GPU host (6.9), the planner (3.4) and MiniZinc
(2.6). Other work on the host (PolyFEM 24, a C++ compile 17) took more. Erlang frames are not resolved: BEAM needs
`+JPperf true` for that. Not measured: the GPU kernels, and VRChat's frame times.

**Not measured.** Longer matches, lookahead past one turn, bigger moves than doubling.

## Iteration 4 (2026-11-27): stopped early by the agent

Started from iteration 3's schools; calibration 8 of 8 on both lanes; round 1's baseline `banker` against `steady`
was 0 of 8 seeds, 4 of 16 points, the same as iteration 3. Stopped during `steady-bank`, 12 moves in, because the
result was predictable and the owner's next idea (splitting the schools, iteration 5) was waiting behind it. 1,155
turns, all proved, one retry (it succeeded). No `summary.json`: the run did not finish. Traces are in
`results/iteration-4/`.

| Moves of `steady` (11 finished, one weight changed each) | Seeds won against `steady` | Seeds tied |
|----------------------------------------------------------|----------------------------|------------|
| `+damage`, `+kill`, `+board`, `+life`, `+bank` (doubled) | 0 | 8 of 8 each |
| `-damage`, `-kill`, `-board` (halved) | 0 | 8 of 8 each |
| `-life` (halved) | 0 | 7 of 8; it lost seed 4 |

`steady-bank` (bank weight 0) had one seed. `banker`'s ten moves never ran. **Kept:** nothing.

**Reading.** Near `steady`, one weight changed by a factor of two does not change the play; the one change that did
(a smaller life weight) made it worse. Repeating iteration 3's doubling moves reproduced its result exactly, so the
matches are repeatable.

**Not measured.** The ten moves of `banker`, `steady-bank`, rounds 2 and 3.

## Iteration 5 (2026-11-27): splitting the schools, first run

**Tried.** Calibration, the baseline and the seven split candidates of `docs/protocol.md`, GPU only. The run ended in a
crash (`docs/findings.md`, finding 4, addendum) after calibration, the baseline, four candidates, and six seeds of the
fifth. Its traces are in `results/iteration-5/`. The last three candidates are run again on the faster driver.

**Calibration.** Mirror 8 of 8, idle 8 of 8. **Baseline.** `banker` against `steady`: 0 of 8 seeds won, 4 of 16 points.

| Candidate | Seeds won against `steady` | Points of 16 | Ties |
|-----------|----------------------------|--------------|------|
| `steady-if-last_turn-else-banker` | 0 | 6.0 | 6 |
| `banker-if-last_turn-else-steady` | 0 | 7.0 | 6 |
| `steady-if-behind-else-banker` | 1 | 6.0 | 4 |
| `banker-if-behind-else-steady` | 0 | 8.0 | 8 |

**Kept.** Nothing. **Frontier.** `steady-if-behind-else-banker` won one seed (seed 8: a win and a draw) and lost two.

**Reading.** Playing `steady` on its last turn lifts `banker` from 4 to 6 or 7 points. `banker-if-behind-else-steady` ties
`steady` on all 8 seeds: switching when behind never changed its play in these matches.

**Not measured.** `steady-if-first_turn-else-banker` (six of its eight seeds were played), `banker-if-first_turn-else-steady`
and `banker-no-bank-last`: run again.

## Iteration 6 (2026-11-27): a broad screen of 66 weightings

**Tried.** 66 weightings (five weights each from 0, 1, 2, 4, 8, 16 at random, the five one-weight-at-16 corners,
`steady`, `banker`; scaled copies removed) on 8 one-turn boards (`g2m1` and `g2m4`, seeds 1 to 4). 528 solves,
Turbo on the GPU at 25 percent duty, all proved, none needed a retry. Not a match: it measures how weightings play,
not whether they win.

**Result.** **14 distinct styles** (weightings with the same plays on all 8 boards). Sizes 23, 8, 6, 5, 4, 4, 3, 3,
2, 2, 2, 2, 1, 1. The 23-weighting style contains `steady`; the 4-weighting style `(1, 1, 1, 1, 4)` contains
`banker`. Over the 8 boards the styles differ along four axes:

| Axis | Values seen (mean per board) | Styles |
|------|------------------------------|--------|
| attack | damage 0.63 or 0.0 | 4, 9, 13, 14 deal none |
| kills | 5.4, 5.1, 1.75, 0.0 | 3 and 5 kill about a third; 9 kills nothing |
| bank | 3.0 to 3.5, or 4.6 to 5.0 | 5 to 8 and 10 to 14 bank; the rest do not |
| board kept | 7.5, 5.1 to 5.9, 7.0 | the banking styles keep fewer levels |

`life_lost` is 0.0 on every board and style: the one-turn boards give the opponent no reply. Representatives and
mean outcomes of each style are in `results/iteration-6/summary.json`.

**Reading.** The neighbourhood of `steady` (iterations 1 to 5) is one style out of 14, which is why nudging one
weight there changed nothing: 23 of 66 weightings play like `steady`. The other 13 are untried in matches.

**Not measured.** Which style wins matches (iteration 7, queued: each style's representative against `steady`);
boards with 3 or more units; weights above 16.
