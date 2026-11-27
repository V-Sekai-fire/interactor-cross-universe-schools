# SPDX-FileCopyrightText: 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
# The study's data as YAML-LD, written and read by lean-yaml-ld through the leanler NIF in ld/ (built with `mix compile` there).
# A summary is one document; a trace is a YAML stream, one document a row, so a run can append to it.
# Every document has an @context with @vocab, so expansion keeps the data keys.
defmodule Cu.Ld do
  @context %{"@vocab" => "https://v-sekai.org/cross-universe/"}
  def build, do: System.get_env("CU_LD_BUILD", Path.join(Cu.root(), "ld/_build/dev/lib"))
  def load do
    if :persistent_term.get({__MODULE__, :loaded}, false) == false do
      for app <- ~w(cu_ld leanler), do: Code.prepend_path(Path.join([build(), app, "ebin"]))
      {:module, CuLd.Native} = Code.ensure_loaded(CuLd.Native)
      :persistent_term.put({__MODULE__, :loaded}, true)
    end
  end
  def native(function, text) do
    load()
    case apply(CuLd.Native, function, [text]) do
      {:ok, "!" <> reason} -> raise("cu_ld: #{reason}")
      {:ok, result} -> result
      {:error, reason} -> raise("cu_ld: #{inspect(reason)}")
    end
  end

  def node(type, map), do: Map.merge(%{"@context" => @context, "@type" => type}, map)
  def plain(map), do: Map.drop(map, ["@context", "@type"])
  def render(type, map), do: "---\n" <> native(:render_document, Cu.json(node(type, map)))
  def append(path, type, map), do: File.write!(path, render(type, map), [:append])
  def write_document(path, type, map), do: File.write!(path, render(type, map))
  def write_stream(path, type, rows), do: File.write!(path, Enum.map_join(rows, &render(type, &1)))
  def stream(path), do: path |> File.read!() |> then(&native(:read_documents, &1)) |> String.split("\n", trim: true) |> Enum.map(&(&1 |> :json.decode() |> plain()))
  def document(path), do: path |> stream() |> hd()
end
