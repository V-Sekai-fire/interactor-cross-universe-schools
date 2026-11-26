<!-- SPDX-License-Identifier: MIT -->
<!-- Copyright (c) 2026 K. S. Ernest (iFire) Lee -->

# Licences read

| Thing | Licence | Read where, when | Use here |
|-------|---------|------------------|----------|
| Cross Universe, the card game | its own terms of use; copyright Cross Universe | https://crossuniverse.jp/利用規約/ (Japanese, the official text), fetched 2026-11-26; the summary at https://crossuniverse.net/tos/ | card identifiers, levels, attack, defense and types of 11 units, read at run time; the rules, from the fan translation at https://crossuniverse.net/rules/ and from the engine |
| Galaxy Engine, the rules engine | MIT, copyright 2024 Psychpsyo; its README says the game itself stays under the terms above | `LICENSE` and `README.md` at commit `14ae23d398a6eaf93820b6ad64f4183cb7c8b3ce` of https://github.com/Psychpsyo/Galaxy-Engine | its card files are read, not copied; its source was read for the rules of fights, summons, retires and mana |
| Turbo, through the port in interactor-persona-frontier | Apache-2.0 AND MIT | that repository's `REUSE.toml` | run as the solver |
| MiniZinc 2.11.0 and Chuffed | MPL-2.0 and MIT | as recorded in interactor-persona-frontier | run as a compiler and as a second solver; no source read |

What the terms ask, as read (the page says it may change without notice; the Japanese text governs): no change to
the published card images apart from two narrow exceptions; no use that harms the game's image or could be taken
for an official product; the site's name, a statement that the copyright is the project's, and a link; no paid
distribution of a game that uses them; goods such as cards and sleeves only with permission; a company needs
permission even for non-commercial use. The owner of this repository is an individual (owner, 2026-11-26).
The link in the engine's README to the Japanese terms (`/約束事/`) no longer resolves.
