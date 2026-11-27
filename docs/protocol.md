<!-- SPDX-License-Identifier: MIT -->
<!-- Copyright (c) 2026 K. S. Ernest (iFire) Lee -->

# Protocol: schools of play style by frontier learning

Written and committed before the first run of the loop. A rule changed after a result is a post-hoc decision and
the changelog says so. What was already known when this was written is in "Before the run".

## Words

- **Board**: one turn of mine. My partner, `g` units on the field and 2 cards in hand, against their partner and
  `g` units; both players at 1000 life; `mana` is what I hold after the mana supply phase. Cards are the units of
  the pinned rules engine that have no abilities (11 of 220), at most three copies a side, partners of level 5 or
  lower. A board on which the turn could take all their life is not drawn (the sum of my attack minus their
  partner's defense is under their life): after a win nothing is style.
- **Turn**: retire once, summon once, each before or after the battle; any unit attacks once; a combined attack
  needs the partner and a shared type. The partner is never retired.
- **Level**: `(g, mana)`. Levels of this run: `g2m1` (poor) and `g2m4` (rich).
- **Problem**: a level with a seed. Seeds 1 to 8.
- **Player**: a weighting `(damage, kill, board, life, bank)` of five outcomes: life taken from them (hundreds),
  levels of their units destroyed, levels of my units on the field at the end, life I lose (hundreds), and the
  mana I will hold after my next mana supply phase. A player plays the plan that minimises
  `life * life_lost - damage * damage_dealt - kill * kills - board * board_left - bank * banked`.
- **Outcome**: the five numbers of a plan, computed by `Cu.Rules.play` from the plan alone, not read from a solver.

## Proved

A solve counts only when all of these hold:

1. the Turbo port on the CPU reports an exhaustive search;
2. Chuffed proves an optimum and it equals Turbo's bound;
3. the plan Turbo returns is legal and its outcome, weighed by the player, equals that bound.

Whether the Lean front end's dump is byte-equal to the dump of Turbo's own preprocessing is recorded for every
solve and reported, but is not part of the definition.

## Success

Player A is **distinct** from player B on a problem when both solves are proved and each strictly prefers its own
plan: B's outcome is strictly worse than A's by A's weights, and A's outcome is strictly worse than B's by B's
weights. An outcome that differs only because a player is indifferent is search order, not style, and fails.

A candidate **succeeds** on a problem when it is distinct from every school kept so far. A cell is a level and a
candidate, with `s` successes of 8. Regret is `1[s >= 1] - s / 8`. A cell with regret above 0 is the frontier.

## Planted defects

Each level also runs two lanes. A level is **calibrated** when both lanes are found on 8 of 8 problems; results
count only on calibrated levels.

- **clone**: the baseline under a second name with every weight doubled. Found when it is reported not distinct
  from the baseline. It catches a test that takes different numbers for a different style.
- **dropped constraint**: the model with the kill sum written as `bool2int(not their_stands[...])` over every
  unit, the form for which Turbo's own front end refuses the model and the Lean port drops a constraint. Found when
  the solve is reported not proved. It catches a check that believes the solver.

A lane under 8 of 8 leaves its level uncalibrated in this run; mutating one attribute of the lane is then the next
iteration, not a waiver.

## Schools

The baseline `steady = (2, 2, 2, 2, 1)` is kept first: a level on the field is worth two mana, so that retiring a
unit for its level in mana is not a tie. Candidates, in this order, each multiply ONE weight of the baseline by
the ladder 2, 4, 8:

| Candidate | Weight raised |
|-----------|---------------|
| `striker` | damage |
| `hunter` | kill |
| `keeper` | board |
| `warden` | life |
| `banker` | bank |

A candidate starts on the first rung. While it has a frontier cell and a rung is left, the next rung is tried, and
is kept only if the sum of `s` over calibrated levels rises. A candidate is **kept as a school** when a calibrated
level has `s = 8`. Anything else is reported with its counts as the frontier, not a school yet.

## Winner rule

There is no winner between schools: they are kept or not. Between two rungs of one candidate the higher sum of `s`
wins and a tie goes to the lower rung.

## Chosen by the agent, not by a manual

The five outcomes and their units, the baseline, the candidate names and order, the ladder, the levels, the life
totals, the hand of 2, the partner level limit, the rule against winnable boards, the two lanes, and the
definition of distinct.

## Before the run

These were seen before this page was committed, with Chuffed alone except where said, and shaped it:

- A first model with fights only: five opposite weightings changed the play on 1 of 32 boards (2 to 5 units a
  side). Retire, summon and mana were added because of that.
- With them, at mana drawn from 0 to 5: the play changed on 7 of 8 boards at 2 units a side and 6 of 8 at 3, almost
  all of it for the bank weighting (11 of 16), which never changed the play when mana was already full. So mana is
  an attribute of the level here, not a draw.
- 3 of those 16 boards could be won in the turn. So winnable boards are not drawn.
- Turbo on the CPU, one solve each: `g2m1` 4.3 s and 4,685 nodes; `g3m1` 49.7 s and 149,193 nodes; `g3m4` 34.5 s and
  89,253 nodes; each proved. The levels with 3 units a side are left out of this run for time.

## Iteration 2: one change, made after a result

Iteration 1 kept no school: every candidate scored 0 of 8 at rung 2, and the rule above tries a further rung only
from a frontier cell, so rungs 4 and 8 were never tried. That rule is the one thing changed, and it is a post-hoc
decision: it was made knowing iteration 1's result and the probe in "Before the run", which used a weight of 8.

- The ladder for iteration 2 is 4, 8. Both rungs are tried for every candidate. The rung with the higher sum of
  `s` over calibrated levels is kept, and a tie goes to rung 4. Rung 2 stands as measured in iteration 1.
- Everything else is as above: the levels, the seeds, the baseline, the lanes, proved, distinct, and a school is
  kept only with `s = 8` on a calibrated level. A candidate that has a cell with `0 < s < 8` and no 8 is reported
  as the frontier.

## Real artifact

Findings on a real artifact are their own lane and are never averaged into a rate: the Turbo port's dropped
constraint, the Lean front end's dump that differs from Turbo's own on boards with a hand, and any difference
between a plan's outcome here and in the pinned rules engine, if that replay is built.

## Not measured in this run

3 or more units a side, more than one turn, a reply by the other player, cards with abilities, spells and items,
retiring the partner (the engine lists it as eligible and the translated rules say it cannot leave the field),
hidden information, play against a person, the rules engine's own verdict on any plan.

## Iteration 3: the schools face off

Written before iteration 3 ran. It asks whether a school wins, and keeps a change to a school only when it wins
more.

**Changes to the solve, by the owner (2026-11-26).** Turbo runs on the GPU only: before every solve the tool checks
that VRChat is not running (by absolute path; a failed check counts as running) and waits while it runs. No second
solver: a solve is **proved** when Turbo's search is exhaustive and the plan it returns is legal and worth the bound
under `Cu.Rules`, or when Turbo's preprocessing leaves no variable and no failure (`solved_at_root`), in which case
the plan is the only legal one and `Cu.Rules` gives its value. The model also always prefers a plan that takes
their last life, and units may attack only with an attack right (none on the first turn of a match). Iterations 1
and 2 drew no winnable board and gave every unit a right, so their results stand.

- **Match**: two seats, each dealt from the seed a partner of level 5 or lower and 29 cards from the 11 plain units
  (at most three copies each): 2 on the field, 2 in hand, the rest the deck. Life 1000 each. Turns alternate, seat 1
  first. Each turn: mana `min(5, min(5, carried) + 5 - partner level)`; draw one card (not on turn 1); the school
  plays the proved plan of the one-turn model, seeing its field and the 3 newest cards in hand; no attack on turn 1.
- **End**: a side whose life reaches 0 loses (both at once: a draw). After 6 turns, more life wins, then more levels
  on the field, then a draw.
- **Face-off** of A and B on a seed: two matches, A in seat 1 then in seat 2, the same deal. Points: win 1, draw ½.
  A face-off with an unproved turn has no score and counts as no success.
- **Calibration**, both must be 8 of 8 or the round is not run: **mirror** (`steady` against itself) scores exactly 1
  of 2; **idle** (every weight 0) scores under 1 of 2 against `steady`.
- **Baseline**: `banker` against `steady`, seeds 1 to 8.
- **Improvement round**: for `steady`, then `banker`, the five mutants with one weight doubled, in the order damage,
  kill, board, life, bank, each face their parent. A mutant that scores more than 1 of 2 on at least 5 seeds then
  faces the other school, and replaces its parent if its points there are more than its parent's. At most one
  replacement per school. After a replacement, the two schools' one-turn plays are compared on `g2m1` and the count
  of distinct seeds is reported.
- **Chosen by the agent**: the deal, the 6-turn limit, the hand view of 3, the tie-breaks, the 5-of-8 threshold,
  doubling as the mutation, one round.
- **Not measured**: longer matches, any lookahead past one turn, a hand over 3 cards, play in the rules engine.

## Iteration 4: the schools improve themselves

Asked for by the owner (2026-11-26, "please self improve") while iteration 3 ran; written before iteration 4 runs.
Everything in iteration 3 stands, with these changes:

- **Start** from the two schools iteration 3 ends with (`schools_after` in its summary).
- **Moves**: each weight doubled, then each weight halved (rounded down), in the order damage, kill, board, life,
  bank. A move that leaves the weights unchanged is skipped. Iteration 3 could only double, so a weight could rise
  and never come back.
- **Rounds repeat**: each round starts with a new baseline between the current two schools, then tries the moves for
  each school as in iteration 3. The loop stops after a round that changes neither school, or after 3 rounds.
- **Calibration** (mirror and idle, against the first school) runs once at the start; the rounds run only if both
  lanes are 8 of 8.
- **Chosen by the agent**: halving as the second move, the order, the limit of 3 rounds.

## Ruling of 2026-11-27: slow progress while VRChat runs

The owner, with VRChat open: "slowly progress". From then on a solve does not wait for VRChat to close; it runs on
the GPU at a 10 percent duty (`CU_GPU_DUTY_VR`; a launch is 10 percent of a 64 Hz frame) while VRChat runs, and at
50 percent otherwise (`CU_GPU_DUTY`). The duty of each turn is in `turns.jsonl`. The duty changes only how fast a
solve runs: every rule above, and what counts as proved, stays. The CPU profile is BCC's `profile-bpfcc` (folded
stacks, `deploy/ebpf/cross-universe-schools-profile@.service`, one instance per run unit), beside the bpftrace process timing.
