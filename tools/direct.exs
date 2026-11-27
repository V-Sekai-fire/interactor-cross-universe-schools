# SPDX-FileCopyrightText: 2026 K. S. Ernest (iFire) Lee
# SPDX-FileCopyrightText: 2025 Pierre Talbot
# SPDX-FileCopyrightText: 2021 Pierre Talbot, Frédéric Pinel
# SPDX-License-Identifier: Apache-2.0 AND MIT
# A solve without the Turbo player: the input file is built here (the same text tools/turbo_solve.exs writes), the
# resident GPU host runs it in this process, the planner is asked once. It starts no second Elixir and no turbo_emit.
defmodule Cu.Direct do
  @codes %{"+" => 0, "*" => 1, "min" => 2, "max" => 3, "=" => 4, "≤" => 5}
  def build, do: System.get_env("TURBO_GPU_BUILD", "/mnt/fire/6-datasource/turbo-runs/gpu-build")
  def blocks, do: System.get_env("CU_GPU_BLOCKS", "64")

  def section(lines, header) do
    [count_line | tail] = Enum.drop_while(lines, &(not String.starts_with?(&1, header)))
    count = count_line |> String.split() |> List.last() |> String.to_integer()
    {Enum.take(tail, count), Enum.drop(tail, count)}
  end
  def ints(row), do: row |> String.split() |> Enum.map(&String.to_integer/1)
  def strategy_columns(rows) do
    {strategies, members, _} =
      Enum.reduce(rows, {[], [], 0}, fn row, {acc, vars, offset} ->
        [order, value, count | rest] = ints(row)
        {acc ++ [order, value, offset, count], vars ++ rest, offset + count}
      end)
    {strategies, if(members == [], do: [0], else: members)}
  end
  def input(dump) do
    lines = String.split(dump, "\n", trim: true)
    if "bot 1" in lines, do: raise("the problem is bot at the root")
    {store, rest} = section(lines, "variables")
    {bytecodes, rest} = section(rest, "bytecodes")
    {strategy_rows, rest} = section(rest, "strategies")
    [_, untyped, variable] = rest |> Enum.find(&String.starts_with?(&1, "objective ")) |> String.split()
    objective = if untyped == "1", do: -1, else: String.to_integer(variable)
    code = Enum.flat_map(bytecodes, fn row -> [op | ids] = String.split(row); [Map.fetch!(@codes, op) | Enum.map(ids, &String.to_integer/1)] end)
    {strategies, members} = strategy_columns(strategy_rows)
    header = [length(store), length(bytecodes), div(length(strategies), 4), objective, 0, 10_000, 1, 2_147_483_647, 0, length(members)]
    Enum.join(header ++ Enum.flat_map(store, &ints/1) ++ code ++ strategies ++ members, " ") <> "\n"
  end

  def problem(name) do
    %{"@context" => %{"@vocab" => "https://v-sekai.org/planning/", "VSEKAI" => "https://v-sekai.org/", "domain" => "VSEKAI:planning/domain/"}, "@type" => "domain:Problem",
      "capabilities" => %{"entities" => %{}, "graph" => %{"edges" => []}}, "domain" => "turbo_solve", "name" => name, "source" => "interactor-persona-frontier",
      "todo_list" => [["solve-level", "machine.host", "level.party"]], "version" => "0.1.0",
      "variables" => [%{"init" => %{"1" => 1}, "name" => "free", "type" => "int"}, %{"init" => %{"2" => 0}, "name" => "done", "type" => "int"}]}
  end
  def store_run(args, db) do
    binary = Path.join(Cu.frontier(), ".lake/build/bin/frontier_store")
    {out, 0} = System.cmd(binary, args, cd: Cu.frontier(), env: [{"FRONTIER_DB", db}], stderr_to_stdout: true)
    out
  end
  def base_database(dir) do
    base = Path.join(dir, "planner-base.sqlite")
    if not File.exists?(base) do
      partial = base <> ".partial"
      File.rm(partial)
      store_run(["migrate"], partial)
      store_run(["import", Path.join(Cu.frontier(), "entities/domains/turbo-solve.yamlld")], partial)
      File.rename!(partial, base)
    end
    base
  end
  def planned(dir) do
    db = Path.join(dir, "planner.sqlite")
    File.cp!(base_database(dir), db)
    name = "turbo_solve_party_#{System.unique_integer([:positive])}"
    file = Path.join(dir, "problem.jsonld")
    File.write!(file, JSON.encode!(problem(name)))
    store_run(["import", file], db)
    doc = ["plan", name] |> store_run(db) |> JSON.decode!()
    steps = if doc["reached"] == true, do: Enum.map(doc["steps"], & &1["action"]), else: []
    if hd(steps ++ ["none"]) != "solve-slice", do: raise("the planner did not choose to solve: #{inspect(steps)}")
  end

  def deadline(ms), do: System.monotonic_time(:millisecond) + ms
  def remaining(limit), do: max(limit - System.monotonic_time(:millisecond), 0)
  def until_status(port, limit) do
    receive do
      {^port, {:data, {:eol, "status" <> _ = line}}} -> line
      {^port, {:data, _}} -> until_status(port, limit)
      {^port, {:exit_status, code}} -> "exit #{code}"
    after
      remaining(limit) -> "timeout"
    end
  end
  def collect(port, limit, lines) do
    receive do
      {^port, {:data, {_, line}}} -> collect(port, limit, [line | lines])
      {^port, {:exit_status, _}} -> {:ok, lines |> Enum.reverse() |> Enum.join("\n") |> Kernel.<>("\n")}
    after
      remaining(limit) -> {:error, "timeout reading the result"}
    end
  end
  def drive(port, limit) do
    Port.command(port, "run 500 #{Bitwise.bsl(System.os_time(:millisecond), 16)}\n")
    case until_status(port, limit) do
      "status done" <> _ -> Port.command(port, "result\n") && collect(port, limit, [])
      "status" <> _ -> drive(port, limit)
      other -> {:error, other}
    end
  end
  def stop(port) do
    with {:os_pid, pid} <- Port.info(port, :os_pid), do: System.cmd("kill", ["-9", Integer.to_string(pid)])
    if Port.info(port), do: Port.close(port)
  end
  def host(input_path, duty) do
    {percent, _} = Float.parse(duty)
    launch_us = round(percent / 100 * 1_000_000 / 64)
    port = Port.open({:spawn_executable, Path.join(build(), "turbo_gpu")}, [:binary, :exit_status, :stderr_to_stdout, {:line, 4096},
      {:env, [{~c"TURBO_SERVE", ~c"1"}, {~c"TURBO_GPU_DUTY", String.to_charlist("#{percent}")}]},
      {:args, [Path.join(build(), "solve_coop.cubin"), input_path, blocks(), Integer.to_string(launch_us)]}])
    result = drive(port, deadline(600_000))
    stop(port)
    result
  end

  def solve(dump, fzn, scratch, dir, duty) do
    File.mkdir_p!(scratch)
    input_path = Path.join(scratch, "input.txt")
    File.write!(input_path, input(dump))
    planned(dir)
    case host(input_path, duty) do
      {:ok, text} ->
        result = Path.join(scratch, "result.txt")
        File.write!(result, text)
        {printed, 0} = System.cmd(Path.join(Cu.frontier(), ".lake/build/bin/frontier_frontend"), ["--solution", fzn, result])
        File.write!(Path.join(scratch, "solution.mzn"), printed)
        {"", 0}
      {:error, why} ->
        {why, 1}
    end
  end
end
