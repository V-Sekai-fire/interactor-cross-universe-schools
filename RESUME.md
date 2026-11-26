<!-- SPDX-License-Identifier: MIT -->
<!-- Copyright (c) 2026 K. S. Ernest (iFire) Lee -->

# Resume: Cross Universe schools of play style (parked 2026-11-26)

Parked by the owner's "halt all work", so it can be resumed offline, by another person, on another computer.
Branch `dev/schools` holds everything; `main` holds only the first commit. Nothing was pushed: no GitHub
repository exists yet (the name `V-Sekai-fire/interactor-cross-universe-schools` was free on 2026-11-26).

## Where things stand

Read `docs/mission.md`, `docs/protocol.md` and `CHANGELOG.md` first.

| Iteration | State | Result |
|-----------|-------|--------|
| 1, one turn, one rung | done | no school kept |
| 2, one turn, rungs 4 and 8 | done | `banker` = `(2, 2, 2, 2, 8)` kept as a school (8 of 8 and 7 of 8 boards) |
| 3, face-off matches | **halted** | mirror lane 8 of 8 done; idle lane 2 seeds of 8 (idle lost both); baseline and the improvement round never ran |
| 4, self-improving rounds | written, never started | protocol section and `tools/schools.exs iterate` committed |

Iteration 3's partial traces are in `results/iteration-3/`: 122 turns, every one proved on the GPU, none solved at
the root. They are a partial run; a resumed iteration 3 starts again from the beginning (see below), so keep the
folder as a record or move it aside.

Decisions the owner made during the work, which bind the next steps:
- Turbo runs **on the GPU only**, never the CPU engine; every solve waits while VRChat runs (`Cu.Solve.engine`).
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
