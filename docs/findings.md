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

## Not checked against a real artifact

No plan was replayed in the rules engine (Galaxy Engine at `14ae23d`). The model follows the engine's source for
fights, combined attacks, summons, retires and the mana supply, and the fan translation of the rules for the
rest. One difference was seen and left out of the model: the engine lists the partner among the units that may
be retired, and the translated rules say the partner cannot leave the field.
