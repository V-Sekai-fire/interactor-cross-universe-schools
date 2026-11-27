<!-- SPDX-License-Identifier: MIT -->
<!-- Copyright (c) 2026 K. S. Ernest (iFire) Lee -->

# Battles as Lottie animations

Six matches from the committed traces, drawn as Lottie shapes (`.lot`, IANA Lottie JSON), one clip per match, in
`videos/`. Open them with any Lottie player, for example ThorVG or the QuickLook plugin. They contain shapes and numbers
only: no card art, names or text.

**Reading a clip.** Teal cards are seat 1 and orange cards are seat 2. A gold border is the partner. On a card, the top-left
number is the level, the red number the attack, the blue number the defense and the small grey digits the card's id. The two
bars are life (seat 1 left, seat 2 right, 10 is full); the white number at the top is the turn; the yellow number is the
mana the player holds; the dimmed row at the bottom is the hand. An attacker lunges at its target; a destroyed card fades.

| Clip | Match (in `turns.yamlld`) | What it shows |
|------|--------------------------|---------------|
| `iteration-3-banker-first-loses-seed1` | `banker-steady-1-a` in `results/iteration-3` | `banker` moves first and loses on life after 4 turns |
| `iteration-3-banker-second-wins-seed1` | `banker-steady-1-b` | the same deal with the seats swapped: `banker` wins on life after 6 turns |
| `iteration-3-steady-wins-on-levels-seed3` | `banker-steady-3-b` | the turn limit: equal life, `steady` has more levels on the field |
| `iteration-3-banker-first-loses-seed4` | `banker-steady-4-a` | `banker` moves first and loses on life after 4 turns |
| `iteration-5-behind-hybrid-first-seed8` | `steady-if-behind-else-banker-steady-8-a` in `results/iteration-5` | the split school wins on more life at the turn limit |
| `iteration-5-behind-hybrid-second-seed8` | `steady-if-behind-else-banker-steady-8-b` | the same deal with the seats swapped: a draw |

**Making another.** From the repository root, with the rules engine and the card pool as in `RESUME.md`:
`CU_RESULTS=results/iteration-3 elixir tools/fight_lottie.exs match <match> videos/<name>.lot`. Add `video` as a last
argument to also render an MP4 (it needs ThorVG's `lottie2gif` and `ffmpeg`).
