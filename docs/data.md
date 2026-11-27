<!-- SPDX-License-Identifier: MIT -->
<!-- Copyright (c) 2026 K. S. Ernest (iFire) Lee -->

# The data is YAML-LD

Every summary and trace in `results/` is YAML-LD (https://www.w3.org/TR/yaml-ld/), written and read with the Lean 4 library
`lean-yaml-ld` through `leanler`, not with JSON or JSONL.

| File | What it is |
|------|------------|
| `summary.yamlld` | one document: the iteration's lanes, baseline, candidates or styles |
| `turns.yamlld`, `faceoffs.yamlld`, `screen.yamlld`, `traces.yamlld` | a YAML stream, one document a row (a turn, a face-off, a one-turn solve), so a run appends to it as it goes |

Each document has an `@context` with a `@vocab` (`https://v-sekai.org/cross-universe/`), so expansion keeps the data keys, and an
`@type` (`Summary`, `Turn`, `Faceoff` or `Solve`). A number keeps its digits: a score of `1.0` stays `1.0`.

## How it is written and read

`ld/` is a small Lean package that requires `lean-yaml-ld` (pinned) and exports two functions, `renderDocument` and
`readDocuments`, which `leanler` builds as an OTP NIF (`CuLd.Native`). `tools/ld.exs` calls them in the running process (1,000 rows
write in about 0.2 s). Every document is read back inside Lean and must equal what was given, or the write fails.

Build it once: `cd ld && mix deps.get && mix compile` (needs `elan`, a C compiler and Elixir 1.18 or later; `CU_LD_BUILD` moves
the build folder). Built and tested on x86_64 Linux with Lean 4.34.1.

## Converting and checking

`elixir tools/to_yamlld.exs results/iteration-N` turns the JSON summary and JSONL traces of a results folder into YAML-LD and removes
the old files only after reading every row back with strict equality (so `1.0` cannot become `1`). The committed results were
converted this way: 18 files, 4,623 documents, and an independent YAML 1.2 parser (`ruamel.yaml`) read every document to the same
JSON as the originals in git. A battle animation rebuilt from the converted traces is byte-identical to the one built from the JSONL.
