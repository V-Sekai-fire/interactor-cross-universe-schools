<!-- SPDX-License-Identifier: MIT -->
<!-- Copyright (c) 2026 K. S. Ernest (iFire) Lee -->

# Findings on real artifacts

Each is its own lane and is never averaged into a rate. Both are about the Lean port of Turbo's front end in
`interactor-persona-frontier` (`frontier_frontend --dump`, checkout at `ad4c118`), compared with Turbo's own
preprocessing (`/mnt/fire/6-datasource/turbo-runs/cp_dump -arch barebones -or 1 -sub 0`). Neither is fixed here.

## 1. A formula Turbo refuses is accepted, and a constraint is lost (2026-11-26)

**What.** A FlatZinc `bool_not` against a constant, which MiniZinc writes for `bool2int(not b)` when `b` is already
true. Turbo's own front end stops with `Uninterpretable formula ... (true ⊕ X_INTRODUCED_67_)`. The Lean port
accepts the same file, the variable is left free, and the search reports an exhaustive optimum that is wrong.

**Seen.** On the first fights-only model, one board (my partner CUU00034 and CUU00043 against CUU00217 and
CUU00074, all weights 1): Chuffed -2, the hand calculation -2, the port -6 with every variable fixed and
`exhaustive 1`. The term "their partner is destroyed" was 1 while the same store held their partner standing.

**Repro.** In `model/turn.mzn` write the kill sum as
`sum(j in THEIRS)(their_level[j] * bool2int(not their_stands[mine + 1, j]))`. `tools/cu.exs` does this for the
dropped-constraint lane (`Cu.Run.faulty_model`); the lane's rows in `results/traces.jsonl` have
`"lane":"dropped"`.

**Consequence here.** The model keeps partners out of the kill and board sums and writes `1 - bool2int(b)`. No
solve is believed on the solver's word: see "Proved" in `docs/protocol.md`.

## 2. A set-literal domain is left unbounded (2026-11-26)

**What.** MiniZinc writes `var {0,2}: summon` when a value in the middle is already excluded. Turbo's dump starts
that variable at `0 2`; the Lean dump starts it at `-2147483648 2147483647`. The rest of the two dumps is
byte-equal.

**Seen.** First on test `t05` (one line of 230 differs). `results/traces.jsonl` records `frontend_equal` for every
solve of a run.

**Consequence here.** None found: every optimum agreed with Chuffed and with the rules evaluator. It is recorded,
not counted.

## 4. The GPU search with many blocks sometimes returns a corrupted best plan (2026-11-27)

**What.** With 64 blocks (the planner's default), the cooperative GPU kernel now and then ends an exhaustive search
with a best "solution" that breaks a constraint of the model, and a bound to match it. On the same board the same
input gives a different answer from run to run; with one block the answer is always right.

**Seen.** Iteration 3, match `idle-steady-6-b`, turn 5 (`steady`, board in the trace): bound -1059, a plan that
"takes the last life" with a combined attack by units that share no type with the partner. Repeated on that board
with 64 blocks: -1059 and an illegal plan twice, -55 and a legal plan twice (50 and 10 percent duty both). With one
block: -55 and the same legal plan, twice. The Lean front end's dump differs from Turbo's own on this board in the
same three places every run (finding 2 and two more), so the dump does not explain why the answer changes.

**Consequence here.** A solve whose plan is illegal is tried again, up to three times (`tries` in the trace); the
rules evaluator decides. A bogus best plan can only improve the bound, so it is always the final answer and always
caught. Not excluded: a race that wrongly cuts a correct branch and returns a legal but worse plan; one block would
exclude it, at about 9 minutes a solve on a board of this size against seconds.

**Addendum (2026-11-27): the same race crashed my evaluator.** In iteration 5 a corrupted plan came back with a
`summon` index that does not exist on the board, and `Cu.Rules.summon` raised on it (`BadMapError`, `nil`), ending
the run after four candidates and six seeds of the fifth, before the retry could run. The evaluator now calls a
summon outside the board illegal, so the retry takes it. Only that field was unguarded: the other plan values are
positions, or are checked against the board before they are used.

## Not checked against a real artifact

No plan was replayed in the rules engine (Galaxy Engine at `14ae23d`). The model follows the engine's source for
fights, combined attacks, summons, retires and the mana supply, and the fan translation of the rules for the
rest. One difference was seen and left out of the model: the engine lists the partner among the units that may
be retired, and the translated rules say the partner cannot leave the field.
