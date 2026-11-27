<!-- SPDX-License-Identifier: MIT -->
<!-- Copyright (c) 2026 K. S. Ernest (iFire) Lee -->

# Resume: Cross Universe schools of play style (parked 2026-11-26, handed to Hermes 2026-11-27)

Parked by the owner's "halt all work", so it can be resumed offline, by another person, on another computer.
Branch `dev/schools` holds everything; `main` holds only the first commit. Nothing was pushed: no GitHub
repository exists yet (the name `V-Sekai-fire/interactor-cross-universe-schools` was free on 2026-11-26).

## Handover to Hermes (2026-11-27, owner: "transfer to hermes a2a")

The Claude session that built this hands it to the Hermes agent over A2A. Its monitors die with it; the runs do not.

**What runs now** (systemd user units, GPU only, slow while VRChat runs): check with
`systemctl --user show cross-universe-schools-split cross-universe-schools-screen cross-universe-schools-styles -p ActiveState`;
logs `.work/split.log`, `.work/screen.log`, `.work/styles.log`; results `results/iteration-5`, `-6`, `-7`; each unit
writes `summary.json` when it ends. Rough ends (UTC, 2026-11-27): screen 17:35, splits 18:30, styles about 2 hours after
the screen. An `eBPF` profile of each runs beside it (`.work/ebpf/`).

**Your next steps, in order. Each new experiment gets its protocol written and committed BEFORE it runs.**
1. When iteration 5 ends: read `results/iteration-5/summary.json`; add its entry to `CHANGELOG.md` (lanes, baseline,
   each candidate's seeds won, points, ties; what was kept) from the traces, not from memory.
2. When iteration 6 ends: the same for `results/iteration-6/summary.json` (the number of styles, members, mean outcomes).
3. When iteration 7 ends: the same; it is the iteration that says whether a style beats `steady` (5 of 8 seeds).
4. Commit on `dev/schools`, authored as the owner, no agent credit, no trailing period.
5. If nothing beat `steady`, say so plainly. Ideas not tried: matches longer than 6 turns, a lookahead past one turn,
   boards with 3 or more units a side.
6. Report to the owner every 5 minutes while anything runs (owner, 2026-11-27: "keep to 5 minute cycles"), and say
   what you did not check.

**Owner rulings that bind you**: Turbo on the GPU only, 10 percent duty while VRChat runs, no second solver; do not
push, publish, create a repository or merge without asking the owner (publishing was approved once and then
overtaken); do not use the VRChat trademark in names; the owner is an individual, not a company; Cross Universe
card data is read at run time and never committed. Never print or log a token.

**Do not**: stop or restart a running unit, delete results, or run a second GPU job beside the three above.

## Where things stand

Read `docs/mission.md`, `docs/protocol.md` and `CHANGELOG.md` first.

| Iteration | State | Result |
|-----------|-------|--------|
| 1, one turn, one rung | done | no school kept |
| 2, one turn, rungs 4 and 8 | done | `banker` = `(2, 2, 2, 2, 8)` kept as a school (8 of 8 and 7 of 8 boards) |
| 3, face-off matches | done (2026-11-27) | `banker` loses every seed to `steady` (0 of 8, 4 of 16 points); no mutation kept; 1,185 turns, all proved |
| 4, self-improving rounds | stopped early | 12 one-weight moves of `steady` tied (one lost a seed); nothing kept |
| 5, split schools | **running** (user unit `cross-universe-schools-split`) | 4 of 7 candidates in, none kept; `steady-if-behind-else-banker` won 1 seed |
| 6, broad screen of 66 weightings (one turn) | **running** (`cross-universe-schools-screen`) | partway: 11 styles among the first 24 weightings |
| 7, the styles face `steady` | **queued**: starts by itself when 6 ends (`cross-universe-schools-chain7`) | `tools/schools.exs styles` |

Decisions the owner made during the work, which bind the next steps:
- Turbo runs **on the GPU only**, never the CPU engine. While VRChat runs it continues at a 10 percent GPU duty
  (owner, 2026-11-27: "slowly progress"); otherwise at 50 percent (`Cu.Solve.duty`).
- **No second solver** (Chuffed) from iteration 3 on. "Proved" is in `docs/protocol.md`, iteration 3.
- A turn that Turbo's preprocessing solves completely (`variables 0`, bound 2147483647) is the one legal play; it is
  counted as `solved_at_root`, not as a failure. The owner asked about it; switching it to a failure is a one-line
  change in `Cu.Run.judge`.
- The owner is an individual, not a company (the Cross Universe terms ask companies for permission).
- Publishing (create the repository public, push both branches, open a pull request, no merge) was approved and then
  overtaken by the halt. Ask again before pushing.

Known faults found on the way: `docs/findings.md` (the Turbo port's front end drops a constraint Turbo refuses, and
leaves a set-literal domain unbounded; plus the root-solved bound above). eBPF profile of iteration 3:
`results/iteration-3/ebpf-summary.txt` (CPU time is mostly the Elixir runtime, the GPU host and 300 planner calls of
`frontier_store`; the GPU kernels themselves are not visible to eBPF).

## What it needs

Everything below is in the park folder `cross-universe-schools-parked-20261126/` (see its `CONTENTS.md`), except the
system tools.

| Need | Where it is expected | In the park |
|------|----------------------|-------------|
| this repository | `/mnt/fire/3-interactor/interactor-cross-universe-schools` | `git/interactor-cross-universe-schools.bundle` |
| the planner and the Turbo port, commit `ad4c118` | `/mnt/fire/3-interactor/interactor-persona-frontier` (`PERSONA_FRONTIER`) | `git/interactor-persona-frontier.bundle`, `git/lake-packages/`, prebuilt binaries and the Slang SDK |
| the rules engine, commit `14ae23d` (card data) | `/mnt/fire/6-datasource/galaxy-engine-14ae23d` (`GALAXY_ENGINE`) | `git/galaxy-engine.bundle` |
| MiniZinc 2.11.0 | `/mnt/fire/6-datasource/minizinc-bundle/x/MiniZincIDE-2.11.0-x86_64-linux-gnu` (`MINIZINC_HOME`) | `tools/mzn.tgz` |
| the GPU host, its cubin (sm_89) and Turbo's own dump oracle | `/mnt/fire/6-datasource/turbo-runs` (fixed path in the planner's `tools/turbo_gpu.exs`; `TURBO_ORACLE` for the oracle) | `tools/turbo-runs.tar` |
| ThorVG 1.1.4 `tvg-lottie2gif` | `/mnt/fire/6-datasource/thorvg-1.1.4-linux/build/tools/lottie2gif/` (`THORVG_LOTTIE2GIF`) | `tools/thorvg-1.1.4.tar.xz` and the prebuilt binary |
| Elixir 1.18 or later on OTP 27 or later, `g++`, `ffmpeg`, an NVIDIA driver with CUDA | on `PATH` | not included |
| `bpftrace` and root, only for the profile | on `PATH` | not included |

The GPU host and cubin were built for an RTX 4090 (sm_89). Another GPU needs the cubin rebuilt by the planner's
`tools/turbo_gpu.exs`, which needs `nvcc` from the planner's CUDA environment (`CUDA_ENV`); that needs a network once.
The Lean toolchain (leanprover/lean4 v4.34.1, 3 GB) is needed only to rebuild the planner's binaries; it is not in the
park. A proposed rule (RFD66606-2501, V-Sekai-fire/rfds PR 626, not merged on 2026-11-26) would build such binaries in
an offline Nix flake per repository and publish them with ORAS; if it lands, it replaces the prebuilt files here.

## Restore on another computer

Use the same paths; that needs no edits. As a user who can write `/mnt/fire`:

```sh
P=/path/to/cross-universe-schools-parked-20261126
cd "$P" && sha256sum -c SHA256SUMS
mkdir -p /mnt/fire/3-interactor /mnt/fire/6-datasource
git clone -b dev/schools "$P/git/interactor-cross-universe-schools.bundle" /mnt/fire/3-interactor/interactor-cross-universe-schools
git clone "$P/git/interactor-persona-frontier.bundle" /mnt/fire/3-interactor/interactor-persona-frontier
git -C /mnt/fire/3-interactor/interactor-persona-frontier checkout ad4c118
tar -xf "$P/tools/persona-frontier-prebuilt.tar" -C /mnt/fire/3-interactor/interactor-persona-frontier
git clone "$P/git/galaxy-engine.bundle" /mnt/fire/6-datasource/galaxy-engine-14ae23d
git -C /mnt/fire/6-datasource/galaxy-engine-14ae23d checkout 14ae23d398a6eaf93820b6ad64f4183cb7c8b3ce
mkdir -p /mnt/fire/6-datasource/minizinc-bundle/x && tar -xzf "$P/tools/mzn.tgz" -C /mnt/fire/6-datasource/minizinc-bundle/x
tar -xf "$P/tools/turbo-runs.tar" -C /mnt/fire/6-datasource
mkdir -p /mnt/fire/6-datasource/thorvg-1.1.4-linux/build/tools/lottie2gif && cp "$P/tools/tvg-lottie2gif" /mnt/fire/6-datasource/thorvg-1.1.4-linux/build/tools/lottie2gif/
```

The planner's Lean packages are in `git/lake-packages/<name>.bundle` at the revisions of its `lake-manifest.json`,
for a rebuild without network. Check the restore with `elixir tools/schools.exs check` from this repository: 7 tests,
`OK: 7 tests` (it uses the GPU).

## Resume

- **Iteration 3**: move `results/iteration-3` aside, then run `elixir tools/schools.exs faceoff` as the user unit
  `deploy/cross-universe-schools.service` (`systemctl --user link` it first). About 1.5 minutes a seed on a shared RTX
  4090, so about 3 hours. The profile: `deploy/ebpf/faceoff.bt` with `bpftrace` as root, its cgroup path edited.
- **Iteration 4**: after iteration 3 ends, `deploy/cross-universe-schools-iterate.service` (`tools/schools.exs
  iterate`); it reads iteration 3's `summary.json` for its starting schools.
- **Then**: the changelog entries from the traces, match videos with `tools/fight_lottie.exs match TAG OUT.lot video`
  (a sample of a test match is in the park's `videos/`), and publishing if the owner still wants it.

Both units run only when the one-minute load is under 4, and wait while VRChat runs. The VRChat check needs the
Windows `tasklist.exe` under `/mnt/c`; where that file does not exist (no Windows host) there is no VRChat and nothing
waits, and where it exists but fails, it counts as running.
