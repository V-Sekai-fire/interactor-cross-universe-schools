# SPDX-FileCopyrightText: 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
# to_yamlld.exs RESULTS_DIR... : turn the JSON summary and the JSONL traces of a results folder into YAML-LD (tools/ld.exs),
# check that every row survived exactly (read back with ===, so 1.0 stays a float), and remove the old files only then.
Code.require_file("cu.exs", __DIR__)

defmodule Cu.ToLd do
  @kinds %{"traces.jsonl" => "Solve", "screen.jsonl" => "Solve", "turns.jsonl" => "Turn", "faceoffs.jsonl" => "Faceoff"}
  def rows(path), do: path |> File.stream!() |> Stream.map(&String.trim/1) |> Enum.reject(&(&1 == "")) |> Enum.map(&:json.decode/1)
  def target(path), do: Path.rootname(path) <> ".yamlld"
  def convert(path) do
    name = Path.basename(path)
    cond do
      name == "summary.json" -> document(path)
      Map.has_key?(@kinds, name) -> stream(path, @kinds[name])
      true -> {:skipped, path}
    end
  end
  def document(path) do
    original = path |> File.read!() |> :json.decode()
    Cu.Ld.write_document(target(path), "Summary", original)
    verdict(path, [original], [Cu.Ld.document(target(path))])
  end
  def stream(path, type) do
    original = rows(path)
    Cu.Ld.write_stream(target(path), type, original)
    verdict(path, original, Cu.Ld.stream(target(path)))
  end
  def verdict(path, before, after_rows) do
    if before === after_rows, do: (File.rm!(path); {:converted, path, length(before)}), else: (File.rm!(target(path)); {:differs, path})
  end
  def run(dirs) do
    for dir <- dirs, path <- Path.wildcard(Path.join(dir, "*.json*")), Path.extname(path) in [".json", ".jsonl"] do
      result = convert(path)
      IO.puts("#{inspect(elem(result, 0))} #{path}#{if match?({:converted, _, _}, result), do: " (#{elem(result, 2)} documents)", else: ""}")
      result
    end
  end
end

results = Cu.Ld |> then(fn _ -> Cu.ToLd.run(System.argv()) end)
if Enum.any?(results, &(elem(&1, 0) == :differs)), do: System.halt(1)
