# Agent rules

The standing rules are in the viewer repository's `AGENTS.md` and `docs/rules.md`: https://github.com/V-Sekai-fire/interactor-hair-cards-viewer (local `/mnt/fire/3-interactor/interactor-hair-cards-viewer`). The planner's rules in `/mnt/fire/3-interactor/interactor-persona-frontier/AGENTS.md` bind too.

## This repository

- Mission, success and stop criteria: `docs/mission.md`. The protocol of a run is `docs/protocol.md` and is committed before the run; `CHANGELOG.md` is the record of each iteration.
- Cross Universe is copyright Cross Universe (https://crossuniverse.jp/); its terms (`docs/licences.md`) bind. No card file, name, text or art is committed: cards are read at run time from the pinned rules engine and appear here as identifiers and numbers. Only units with no abilities are used, unmodified. Nothing may look official.
- Checks: `elixir tools/schools.exs check`. Solving uses the Turbo port of `interactor-persona-frontier` on the CPU only; the GPU engine is never used from here.
- A run is the user unit `deploy/cross-universe-schools.service`, never a background shell.
