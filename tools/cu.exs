# SPDX-FileCopyrightText: 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
# The card pool, the board generator, the rules, the two solvers and the frontier loop (docs/protocol.md)
defmodule Cu do
  @root Path.expand("..", __DIR__)
  def root, do: @root
  def engine, do: System.get_env("GALAXY_ENGINE", "/mnt/fire/6-datasource/galaxy-engine-14ae23d")
  def frontier, do: System.get_env("PERSONA_FRONTIER", "/mnt/fire/3-interactor/interactor-persona-frontier")
  def minizinc, do: System.get_env("MINIZINC_HOME", "/mnt/fire/6-datasource/minizinc-bundle/x/MiniZincIDE-2.11.0-x86_64-linux-gnu")
  def oracle, do: System.get_env("TURBO_ORACLE", "/mnt/fire/6-datasource/turbo-runs/cp_dump")
  def work, do: Process.get(:cu_work) || System.get_env("CU_WORK", Path.join(@root, ".work"))
  def model, do: Path.join(@root, "model/turn.mzn")
  def results, do: System.get_env("CU_RESULTS", Path.join(@root, "results/iteration-3"))
  def traces, do: Path.join(results(), "traces.jsonl")
  def json(term), do: IO.iodata_to_binary(:json.encode(term))
end

defmodule Cu.Cards do
  @plain ~w(id cardType name level types attack defense)
  def rows(text), do: text |> String.split("\n", trim: true) |> Enum.map(&String.split(&1, ":", parts: 2))
  def plain?(rows), do: Enum.all?(rows, &match?([key, _] when key in @plain, &1))
  def hundreds(text), do: text |> String.trim() |> String.to_integer() |> div(100)
  def card(rows) do
    f = Map.new(rows, fn [key, value] -> {key, String.trim(value)} end)
    %{id: f["id"], kind: f["cardType"], level: String.to_integer(f["level"]), attack: hundreds(f["attack"]),
      defense: hundreds(f["defense"]), types: String.split(f["types"], ~r/,\s*/, trim: true)}
  end
  def pool do
    Path.join(Cu.engine(), "cards/CUU*.cdf")
    |> Path.wildcard()
    |> Enum.sort()
    |> Enum.map(&rows(File.read!(&1)))
    |> Enum.filter(&plain?/1)
    |> Enum.map(&card/1)
    |> Enum.filter(&(&1.kind == "unit"))
  end
  def find(id), do: Enum.find(pool(), &(&1.id == id)) || raise("no plain unit #{id}")
end

defmodule Cu.Gen do
  @hand 2
  def level({g, mana}, seed), do: draw(g, mana, seed, 0)
  def draw(g, mana, seed, attempt) do
    :rand.seed(:exsss, {seed, g * 10 + mana, 97 + attempt})
    pool = Cu.Cards.pool()
    board = %{mine: side(pool, g + @hand), field: g, theirs: side(pool, g), my_life: 10, their_life: 10, mana: mana}
    if winnable?(board), do: draw(g, mana, seed, attempt + 1), else: all_rights(board)
  end
  def all_rights(board), do: Map.put(board, :rights, Enum.map(board.mine, fn _ -> true end))
  def winnable?(board), do: (board.mine |> Enum.map(& &1.attack) |> Enum.sum()) - hd(board.theirs).defense >= board.their_life
  def side(pool, n) do
    partner = pool |> Enum.filter(&(&1.level <= 5)) |> Enum.random()
    copies = Enum.flat_map(pool, &List.duplicate(&1, 3)) -- [partner]
    [partner | Enum.take_random(copies, n)]
  end
  def board(mine, hand, theirs, mana) do
    cards = &Enum.map(&1, fn id -> Cu.Cards.find(id) end)
    all_rights(%{mine: cards.(mine ++ hand), field: length(mine) - 1, theirs: cards.(theirs), my_life: 10, their_life: 10, mana: mana})
  end
  def places(board), do: Enum.with_index(board.mine, 1)
  def in_hand(board), do: Enum.map(places(board), fn {_, i} -> i > board.field + 1 end)
  def retirable(board), do: Enum.map(places(board), fn {_, i} -> i > 1 and i <= board.field + 1 end)
  def shares(board), do: Enum.map(board.mine, fn c -> c.types -- hd(board.mine).types != c.types end)
  def list(xs), do: "[" <> Enum.map_join(xs, ", ", &to_string/1) <> "]"
  def render(board, w) do
    col = fn side, key -> list(Enum.map(side, &Map.fetch!(&1, key))) end
    """
    mine = #{length(board.mine)}; attack = #{col.(board.mine, :attack)}; defense = #{col.(board.mine, :defense)}; level = #{col.(board.mine, :level)};
    shares = #{list(shares(board))}; in_hand = #{list(in_hand(board))}; retirable = #{list(retirable(board))}; rights = #{list(board.rights)};
    theirs = #{length(board.theirs)}; their_attack = #{col.(board.theirs, :attack)}; their_defense = #{col.(board.theirs, :defense)}; their_level = #{col.(board.theirs, :level)};
    my_life = #{board.my_life}; their_life = #{board.their_life}; mana = #{board.mana};
    weight_damage = #{w.damage}; weight_kill = #{w.kill}; weight_board = #{w.board}; weight_life = #{w.life}; weight_bank = #{w.bank};
    """
  end
end

defmodule Cu.Rules do
  def play(board, plan) do
    start = %{mine: MapSet.new(1..(board.field + 1)), theirs: MapSet.new(1..length(board.theirs)), hit: 0, hurt: 0, mana: board.mana,
              shares: Cu.Gen.shares(board), retired: false, steps: []}
    phases = [&retire(&1, &2, &3, 1), &summon(&1, &2, &3, true), &battle/3, &retire(&1, &2, &3, 2), &summon(&1, &2, &3, false)]
    phases
    |> Enum.reduce_while({:ok, start}, fn phase, {:ok, st} -> halt_or_go(phase.(board, st, plan)) end)
    |> outcome(board)
  end
  def halt_or_go({:illegal, _} = bad), do: {:halt, bad}
  def halt_or_go(st), do: {:cont, {:ok, st}}
  def first_fault(checks, good), do: Enum.find_value(checks, good, fn {bad, reason} -> bad && {:illegal, reason} end)
  def level(board, i), do: Enum.at(board.mine, i - 1).level
  def note(st, step), do: %{st | steps: st.steps ++ [step]}

  def retire(board, st, plan, phase) do
    who = for {r, i} <- Enum.with_index(plan.retire, 1), r == phase, do: i
    gain = who |> Enum.map(&level(board, &1)) |> Enum.sum()
    done = %{st | mine: MapSet.difference(st.mine, MapSet.new(who)), mana: st.mana + gain, retired: st.retired or who != []}
    [
      {who != [] and st.retired, "a second retire in one turn"},
      {not Enum.all?(who, &Enum.at(Cu.Gen.retirable(board), &1 - 1)), "a unit that may not be retired"},
      {not Enum.all?(who, &MapSet.member?(st.mine, &1)), "a retired unit is not on the field"}
    ]
    |> first_fault(if(who == [], do: st, else: note(done, %{"kind" => "retire", "units" => who, "mana" => done.mana})))
  end
  def summon(_board, st, %{summon: 0}, _early), do: st
  def summon(_board, st, %{early: early}, phase) when early != phase, do: st
  def summon(board, _st, %{summon: card}, _phase) when card > length(board.mine) or card < 0, do: {:illegal, "a summon of a card outside the board"}
  def summon(board, st, plan, _phase) do
    cost = level(board, plan.summon)
    done = %{st | mine: MapSet.put(st.mine, plan.summon), mana: st.mana - cost}
    [
      {not Enum.at(Cu.Gen.in_hand(board), plan.summon - 1), "a summon of a card that is not in the hand"},
      {cost > st.mana, "a summon without the mana"}
    ]
    |> first_fault(note(done, %{"kind" => "summon", "unit" => plan.summon, "mana" => done.mana}))
  end
  def battle(board, st, plan) do
    Enum.reduce_while(1..length(board.mine), st, fn k, st ->
      halt_or_go(step(board, st, attackers(plan.slot, k), Enum.at(plan.target, k - 1))) |> unwrap()
    end)
  end
  def unwrap({:cont, {:ok, st}}), do: {:cont, st}
  def unwrap(halt), do: halt
  def attackers(slot, k), do: for({s, i} <- Enum.with_index(slot, 1), s == k, do: i)
  def step(_board, st, [], 0), do: st
  def step(board, st, who, tgt) do
    [
      {who == [] or tgt == 0, "a slot has attackers without a target or a target without attackers"},
      {not Enum.all?(who, &MapSet.member?(st.mine, &1)), "an attacker is not on the field"},
      {not MapSet.member?(st.theirs, tgt), "the target is not on the field"},
      {tgt == 1 and MapSet.size(st.theirs) > 1, "their partner is attacked while their units stand"},
      {length(who) > 1 and not combined?(st, who), "a combined attack without the partner or a shared type"},
      {Enum.any?(who, &(not Enum.at(board.rights, &1 - 1))), "an attacker has no attack right"}
    ]
    |> first_fault(:ok)
    |> then(fn verdict -> if verdict == :ok, do: fight(board, st, who, tgt), else: verdict end)
  end
  def combined?(st, who), do: 1 in who and Enum.all?(who, &Enum.at(st.shares, &1 - 1))
  def fight(board, st, who, tgt) do
    power = who |> Enum.map(&Enum.at(board.mine, &1 - 1).attack) |> Enum.sum()
    them = Enum.at(board.theirs, tgt - 1)
    base = %{"kind" => "attack", "units" => who, "target" => tgt, "power" => power}
    cond do
      tgt == 1 -> counter(board, %{st | hit: st.hit + max(0, power - them.defense)}, who, them, Map.put(base, "damage", max(0, power - them.defense)))
      power > them.defense -> note(%{st | theirs: MapSet.delete(st.theirs, tgt)}, Map.put(base, "destroyed", tgt))
      true -> counter(board, st, who, them, base)
    end
  end
  def counter(board, st, who, them, base) do
    lead = if 1 in who, do: 1, else: hd(who)
    defense = Enum.at(board.mine, lead - 1).defense
    cond do
      lead == 1 -> note(%{st | hurt: st.hurt + max(0, them.attack - defense)}, Map.put(base, "hurt", max(0, them.attack - defense)))
      them.attack > defense -> note(%{st | mine: MapSet.delete(st.mine, lead)}, Map.put(base, "lost", lead))
      true -> note(st, base)
    end
  end
  def outcome({:illegal, reason}, _board), do: {:illegal, reason}
  def outcome({:ok, st}, board) do
    levels = fn side, set -> for({c, i} <- Enum.with_index(side, 1), i > 1 and MapSet.member?(set, i), do: c.level) |> Enum.sum() end
    their_start = levels.(board.theirs, MapSet.new(1..length(board.theirs)))
    %{damage: min(board.their_life, st.hit), life_lost: min(board.my_life, st.hurt), kills: their_start - levels.(board.theirs, st.theirs),
      board: levels.(board.mine, st.mine), bank: min(5, min(5, st.mana) + 5 - level(board, 1)), steps: st.steps,
      lethal: st.hit >= board.their_life, mine_left: Enum.sort(MapSet.to_list(st.mine)), theirs_left: Enum.sort(MapSet.to_list(st.theirs)), mana_left: st.mana}
  end
  def value({:illegal, _}, _w), do: nil
  def value(o, w), do: -1000 * if(o.lethal, do: 1, else: 0) + w.life * o.life_lost - w.damage * o.damage - w.kill * o.kills - w.board * o.board - w.bank * o.bank
end

defmodule Cu.Solve do
  def ints(text, name) do
    case Regex.run(~r/^#{name} ?= ?(?:array1d\(1\.\.\d+,)?\[(.*?)\]\)?;$/m, text) do
      [_, body] -> body |> String.split(",", trim: true) |> Enum.map(&String.to_integer(String.trim(&1)))
      _ -> nil
    end
  end
  def word(text, name) do
    case Regex.run(~r/^#{name} ?= ?(-?\w+);$/m, text) do [_, v] -> v; _ -> nil end
  end
  def plan(text) do
    summon = word(text, "summon")
    %{retire: ints(text, "retire"), summon: summon && String.to_integer(summon), early: word(text, "early") == "true", slot: ints(text, "slot"), target: ints(text, "target")}
  end
  def whole?(plan), do: Enum.all?([plan.retire, plan.summon, plan.slot, plan.target])
  def mzn(args), do: System.cmd(Path.join(Cu.minizinc(), "bin/minizinc"), args, env: [{"LD_LIBRARY_PATH", Path.join(Cu.minizinc(), "lib")}], stderr_to_stdout: true)
  @tasklist "/mnt/c/Windows/System32/tasklist.exe"
  def vrchat? do
    now = System.monotonic_time(:second)
    case :persistent_term.get(:cu_vrchat, nil) do
      {at, value} when now - at < 15 -> value
      _ -> value = File.exists?(@tasklist) and windows_vrchat?(); :persistent_term.put(:cu_vrchat, {now, value}); value
    end
  end
  def windows_vrchat? do
    case System.cmd(@tasklist, ["/FI", "IMAGENAME eq VRChat.exe"], stderr_to_stdout: true) do
      {out, 0} -> String.contains?(out, "VRChat.exe")
      _ -> true
    end
  rescue
    _ -> true
  end
  def engine, do: "gpu"
  def duty, do: if(vrchat?(), do: System.get_env("CU_GPU_DUTY_VR", "10"), else: System.get_env("CU_GPU_DUTY", "50"))
  def engine_args("gpu", duty), do: ["--engine", "gpu", "--slice", "500", "--duty", duty, "--max-gpu", "100", "--blocks", System.get_env("CU_GPU_BLOCKS", "64")]
  def timed(name, fun) do
    {microseconds, result} = :timer.tc(fun)
    Process.put(:stages, Map.put(Process.get(:stages, %{}), name, div(microseconds, 1000)))
    result
  end
  def turbo(model, dzn) do
    Process.put(:stages, %{})
    dir = Cu.work()
    chosen = engine()
    duty = timed("vrchat_check", fn -> duty() end)
    scratch = Path.join([dir, "turbo_solve", "party"])
    [fzn, ozn, cp, ck] = for name <- ~w(x.fzn x.ozn party.cp ck.bin), do: Path.join(dir, name)
    for stale <- [ck, ck <> ".status", Path.join(scratch, "result.txt"), Path.join(scratch, "solution.mzn")], do: File.rm(stale)
    {_, 0} = timed("compile", fn -> mzn(["--solver", "org.minizinc.mzn-fzn", "-c", "--fzn", fzn, "--ozn", ozn, model, dzn]) end)
    {dump, 0} = timed("dump", fn -> System.cmd(Path.join(Cu.frontier(), ".lake/build/bin/frontier_frontend"), ["--dump", fzn]) end)
    File.write!(cp, dump)
    env = [{"TMPDIR", dir}, {"ELIXIR_ERL_OPTIONS", "+fnu"}]
    args = ["600", "elixir", "tools/turbo_player.exs", cp, "--fzn", fzn, "--checkpoint", ck] ++ engine_args(chosen, duty)
    {log, code} = timed("gpu", fn -> run_gpu(dump, fzn, scratch, dir, duty, args, env) end)
    result = read(scratch, ozn, code, log)
    equal = if System.get_env("CU_CHECK_FRONTEND") == "1", do: timed("oracle", fn -> frontend_equal?(fzn, dump) end)
    result |> Map.put(:frontend_equal, equal) |> Map.put(:engine, chosen) |> Map.put(:duty, duty) |> Map.put(:root, root?(dump)) |> Map.put(:stages, Process.get(:stages))
  end
  def driver, do: System.get_env("CU_DRIVER", "direct")
  def run_gpu(dump, fzn, scratch, dir, duty, args, env) do
    if driver() == "direct", do: Cu.Direct.solve(dump, fzn, scratch, dir, duty), else: System.cmd("timeout", args, cd: Cu.frontier(), env: env, stderr_to_stdout: true)
  end
  def root?(dump), do: String.starts_with?(dump, "bot 0\nvariables 0\n")
  def frontend_equal?(fzn, dump) do
    {theirs, code} = System.cmd(Cu.oracle(), ["-arch", "barebones", "-or", "1", "-sub", "0", fzn], stderr_to_stdout: false)
    code == 0 and theirs == dump
  end
  def printed(ozn, solution) do
    {text, 0} = System.cmd("sh", ["-c", "exec \"$0\" --ozn-file \"$1\" < \"$2\"", Path.join(Cu.minizinc(), "bin/minizinc"), ozn, solution], env: [{"LD_LIBRARY_PATH", Path.join(Cu.minizinc(), "lib")}])
    text
  end
  def read(_scratch, _ozn, code, log) when code != 0, do: %{exhaustive: false, bound: nil, nodes: nil, plan: plan(""), error: String.slice(log, -300, 300)}
  def read(scratch, ozn, 0, _log) do
    result = File.read!(Path.join(scratch, "result.txt"))
    blocks = Regex.scan(~r/bound (-?\d+) nodes (\d+) fails \d+ depth_max \d+ exhaustive (\d)/, result)
    [_, approx] = Regex.run(~r/approx (-?\d+)/, result)
    nodes = blocks |> Enum.map(fn [_, _, n, _] -> String.to_integer(n) end) |> Enum.sum()
    whole = case Regex.run(~r/exhaustive blocks (\d+) of (\d+)/, result) do
      [_, done, all] -> done == all
      nil -> blocks != [] and Enum.all?(blocks, fn [_, _, _, e] -> e == "1" end)
    end
    %{exhaustive: whole, bound: String.to_integer(approx), nodes: nodes, plan: plan(timed("print_solution", fn -> printed(ozn, Path.join(scratch, "solution.mzn")) end))}
  end
end

defmodule Cu.Run do
  @fault_from "sum(j in THEIRS where j > 1)(their_level[j] * (1 - bool2int(their_stands[mine + 1, j])))"
  @fault_to "sum(j in THEIRS)(their_level[j] * bool2int(not their_stands[mine + 1, j]))"
  def weights({d, k, b, f, m}), do: %{damage: d, kill: k, board: b, life: f, bank: m}
  def faulty_model do
    source = File.read!(Cu.model())
    if not String.contains?(source, @fault_from), do: raise("the fault target is missing from the model")
    path = Path.join(Cu.work(), "turn-dropped.mzn")
    File.write!(path, String.replace(source, @fault_from, @fault_to))
    path
  end
  def model_for("dropped"), do: faulty_model()
  def model_for(_), do: Cu.model()
  def dzn(board, w) do
    File.mkdir_p!(Cu.work())
    path = Path.join(Cu.work(), "board.dzn")
    File.write!(path, Cu.Gen.render(board, w))
    path
  end
  def solve(board, w, lane \\ "player", tries \\ 1) do
    path = dzn(board, w)
    r = judge(board, w, Cu.Solve.turbo(model_for(lane), path)) |> Map.put(:tries, tries)
    if lane == "player" and match?({:illegal, _}, r.outcome) and tries < 3, do: solve(board, w, lane, tries + 1), else: r
  end
  def judge(board, w, turbo) do
    outcome = if Cu.Solve.whole?(turbo.plan), do: Cu.Rules.play(board, turbo.plan), else: {:illegal, "no plan"}
    value = Cu.Rules.value(outcome, w)
    proved = value != nil and (turbo.root or (turbo.exhaustive and value == turbo.bound))
    %{proved: proved, outcome: outcome, value: value, turbo: turbo, weights: w}
  end
  def distinct?(a, b) do
    a.proved and b.proved and Cu.Rules.value(b.outcome, a.weights) > a.value and Cu.Rules.value(a.outcome, b.weights) > b.value
  end
  def show({:illegal, reason}), do: %{"illegal" => reason}
  def show(o), do: Map.new(o, fn {k, v} -> {to_string(k), v} end)
  def cards(board), do: %{"mine" => Enum.map(board.mine, & &1.id), "field" => board.field, "theirs" => Enum.map(board.theirs, & &1.id), "mana" => board.mana}
  def key({g, mana}), do: "g#{g}m#{mana}"
  def trace(level, seed, name, lane, board, r) do
    row = %{"level" => key(level), "seed" => seed, "player" => name, "lane" => lane, "weights" => show(r.weights), "proved" => r.proved,
            "outcome" => show(r.outcome), "value" => r.value, "turbo_bound" => r.turbo.bound, "turbo_nodes" => r.turbo.nodes,
            "turbo_exhaustive" => r.turbo.exhaustive, "solved_at_root" => r.turbo.root, "frontend_equal" => r.turbo.frontend_equal,
            "plan" => show(r.turbo.plan), "board" => cards(board), "engine" => r.turbo[:engine]}
    File.write!(Cu.traces(), Cu.json(row) <> "\n", [:append])
    r
  end
  def all(level, name, w, lane \\ "player") do
    for seed <- 1..8, into: %{} do
      board = Cu.Gen.level(level, seed)
      r = trace(level, seed, name, lane, board, solve(board, w, lane))
      IO.puts("  #{key(level)} seed=#{seed} #{name} #{lane} proved=#{r.proved} bound=#{inspect(r.turbo.bound)} value=#{inspect(r.value)} nodes=#{inspect(r.turbo.nodes)}")
      {seed, r}
    end
  end
  def successes(mine, kept), do: Enum.count(1..8, fn seed -> Enum.all?(kept, fn {_, rs} -> distinct?(mine[seed], rs[seed]) end) end)
end

defmodule Cu.Frontier do
  import Cu.Run
  @levels [{2, 1}, {2, 4}]
  @ladder [4, 8]
  @steady {2, 2, 2, 2, 1}
  @candidates [{"striker", 0}, {"hunter", 1}, {"keeper", 2}, {"warden", 3}, {"banker", 4}]
  def steady, do: @steady
  def raised(index, rung), do: weights(put_elem(@steady, index, elem(@steady, index) * rung))
  def doubled, do: @steady |> Tuple.to_list() |> Enum.map(&(&1 * 2)) |> List.to_tuple() |> weights()
  def calibrate(g, base) do
    clone = all(g, "clone", doubled(), "clone")
    dropped = all(g, "steady", weights(@steady), "dropped")
    %{"level" => key(g), "clone_found" => Enum.count(1..8, &(not distinct?(clone[&1], base[&1]))), "dropped_found" => Enum.count(1..8, &(not dropped[&1].proved))}
  end
  def calibrated?(lane), do: lane["clone_found"] == 8 and lane["dropped_found"] == 8
  def cells(name, w, kept, levels) do
    runs = Map.new(levels, &{&1, all(&1, name, w)})
    {runs, Map.new(runs, fn {g, rs} -> {g, successes(rs, Enum.map(kept, fn {n, by} -> {n, by[g]} end))} end)}
  end
  def total(scores), do: scores |> Map.values() |> Enum.sum()
  def climb(_name, _index, _kept, _levels, [], best, tried), do: {best, tried}
  def climb(name, index, kept, levels, [rung | rest], best, tried) do
    {runs, scores} = cells(name, raised(index, rung), kept, levels)
    IO.puts("#{name} rung #{rung}: #{inspect(scores)}")
    here = %{"rung" => rung, "scores" => scores, "runs" => runs}
    tried = tried ++ [strip(here)]
    best = if best == nil or total(scores) > total(best["scores"]), do: here, else: best
    climb(name, index, kept, levels, rest, best, tried)
  end
  def strip(here), do: %{"rung" => here["rung"], "scores" => Map.new(here["scores"], fn {g, s} -> {key(g), s} end)}
  def school?(best), do: Enum.any?(Map.values(best["scores"]), &(&1 == 8))
  def run do
    File.mkdir_p!(Path.dirname(Cu.traces()))
    base = Map.new(@levels, &{&1, all(&1, "steady", weights(@steady))})
    lanes = Enum.map(@levels, &calibrate(&1, base[&1]))
    levels = for {level, lane} <- Enum.zip(@levels, lanes), calibrated?(lane), do: level
    IO.puts("calibration: #{inspect(lanes)}; calibrated levels #{inspect(Enum.map(levels, &key/1))}")
    {_, report} = Enum.reduce(@candidates, {[{"steady", base}], []}, &candidate(&1, &2, levels))
    proved = Map.new(base, fn {g, rs} -> {key(g), Enum.count(rs, fn {_, r} -> r.proved end)} end)
    summary = %{"lanes" => lanes, "calibrated_levels" => Enum.map(levels, &key/1), "baseline_proved" => proved, "candidates" => Enum.reverse(report)}
    File.write!(Path.join(Cu.results(), "summary.json"), Cu.json(summary) <> "\n")
    IO.puts(Cu.json(summary))
  end
  def candidate(_, {kept, report}, []), do: {kept, report}
  def candidate({name, index}, {kept, report}, levels) do
    {best, tried} = climb(name, index, kept, levels, @ladder, nil, [])
    row = %{"name" => name, "rung" => best["rung"], "scores" => strip(best)["scores"], "tried" => tried, "school" => school?(best)}
    kept = if school?(best), do: kept ++ [{name, best["runs"]}], else: kept
    {kept, [row | report]}
  end
end

defmodule Cu.Match do
  @turns 6
  @view 3
  def turns, do: @turns
  def deal(seed) do
    :rand.seed(:exsss, {seed, 77, 3})
    pool = Cu.Cards.pool()
    Map.new([1, 2], fn seat -> {seat, seat(pool)} end)
  end
  def seat(pool) do
    partner = pool |> Enum.filter(&(&1.level <= 5)) |> Enum.random()
    deck = (Enum.flat_map(pool, &List.duplicate(&1, 3)) -- [partner]) |> Enum.take_random(29) |> Enum.shuffle()
    {field, rest} = Enum.split(deck, 2)
    {hand, deck} = Enum.split(rest, 2)
    %{partner: partner, field: field, hand: hand, deck: deck, life: 10, carried: 0}
  end
  def mana(side), do: min(5, min(5, side.carried) + 5 - side.partner.level)
  def draw(side, 1), do: side
  def draw(%{deck: [card | deck]} = side, _turn), do: %{side | hand: side.hand ++ [card], deck: deck}
  def view(side), do: Enum.take(side.hand, -@view)
  def board(me, them, turn) do
    if length(me.field) > 4, do: raise("a field of #{length(me.field)} units: the turn limit no longer keeps it under 5")
    mine = [me.partner | me.field] ++ view(me)
    %{mine: mine, field: length(me.field), theirs: [them.partner | them.field], my_life: me.life, their_life: them.life, mana: mana(me),
      rights: Enum.map(mine, fn _ -> turn > 1 end)}
  end
  def kept(cards, left, offset), do: for({c, i} <- Enum.with_index(cards, offset), i in left, do: c)
  def after_turn(me, them, board, plan, o) do
    seen = view(me)
    summoned = if plan.summon > 0, do: [Enum.at(board.mine, plan.summon - 1)], else: []
    field = kept(me.field, o.mine_left, 2) ++ kept(seen, o.mine_left, 2 + length(me.field))
    {%{me | field: field, hand: me.hand -- summoned, life: me.life - o.life_lost, carried: o.mana_left},
     %{them | field: kept(them.field, o.theirs_left, 2), life: them.life - o.damage}}
  end
  def ended(sides, turn) do
    cond do
      sides[1].life <= 0 and sides[2].life <= 0 -> {:draw, "both partners fell"}
      sides[1].life <= 0 -> {2, "life"}
      sides[2].life <= 0 -> {1, "life"}
      turn < @turns -> nil
      true -> at_cap(sides)
    end
  end
  def strength(side), do: side.field |> Enum.map(& &1.level) |> Enum.sum()
  def at_cap(sides) do
    cond do
      sides[1].life != sides[2].life -> {if(sides[1].life > sides[2].life, do: 1, else: 2), "more life"}
      strength(sides[1]) != strength(sides[2]) -> {if(strength(sides[1]) > strength(sides[2]), do: 1, else: 2), "more levels on the field"}
      true -> {:draw, "equal"}
    end
  end
  def pick(%{damage: _} = w, _context), do: w
  def pick({:split, predicate, when_true, otherwise}, context), do: if(holds?(predicate, context), do: when_true, else: otherwise)
  def holds?(:last_turn, context), do: context.turn + 2 > @turns
  def holds?(:behind, context), do: context.me.life < context.them.life
  def holds?(:first_turn, context), do: context.turn <= 2
  def play(sides, schools, tag, turn \\ 1, log \\ []) do
    seat = if rem(turn, 2) == 1, do: 1, else: 2
    other = 3 - seat
    {name, w} = schools[seat]
    me = draw(sides[seat], turn)
    board = board(me, sides[other], turn)
    w = pick(w, %{turn: turn, me: me, them: sides[other]})
    r = Cu.Run.solve(board, w)
    row = %{"match" => tag, "turn" => turn, "seat" => seat, "school" => name, "weights" => Cu.Run.show(w), "proved" => r.proved, "engine" => r.turbo[:engine], "duty" => r.turbo[:duty], "tries" => r[:tries], "stages" => r.turbo[:stages],
            "board" => Cu.Run.cards(board), "plan" => Cu.Run.show(r.turbo.plan), "outcome" => Cu.Run.show(r.outcome),
            "turbo_bound" => r.turbo.bound, "value" => r.value, "solved_at_root" => r.turbo.root}
    File.write!(Path.join(Cu.results(), "turns.jsonl"), Cu.json(row) <> "\n", [:append])
    next(sides, schools, tag, turn, log ++ [row], r, me, board, seat)
  end
  def next(_sides, _schools, _tag, turn, log, %{proved: false}, _me, _board, _seat), do: %{result: :unproved, reason: "turn #{turn}", log: log}
  def next(sides, schools, tag, turn, log, r, me, board, seat) do
    other = 3 - seat
    {me, them} = after_turn(me, sides[other], board, r.turbo.plan, r.outcome)
    sides = sides |> Map.put(seat, me) |> Map.put(other, them)
    case ended(sides, turn) do
      nil -> play(sides, schools, tag, turn + 1, log)
      {result, reason} -> %{result: result, reason: reason, log: log, life: {sides[1].life, sides[2].life}}
    end
  end
  def points(%{result: :draw}, _seat), do: 0.5
  def points(%{result: :unproved}, _seat), do: nil
  def points(%{result: seat}, seat), do: 1.0
  def points(_, _), do: 0.0
  @cache_version 1
  @fresh ~w(steady-mirror idle clone)
  def school_key({:split, predicate, a, b}), do: %{"split" => to_string(predicate), "when" => Cu.Run.show(a), "else" => Cu.Run.show(b)}
  def school_key(weights), do: Cu.Run.show(weights)
  def model_tag, do: "#{@cache_version}-" <> binary_part(Base.encode16(:crypto.hash(:sha256, File.read!(Cu.model())), case: :lower), 0, 12)
  def cache_key(a, b, seed), do: %{"a" => school_key(elem(a, 1)), "b" => school_key(elem(b, 1)), "seed" => seed, "model" => model_tag()}
  def cache do
    case :persistent_term.get({__MODULE__, :cache}, nil) do
      nil -> table = load_cache(); :persistent_term.put({__MODULE__, :cache}, table); table
      table -> table
    end
  end
  def load_cache do
    Path.join(Path.dirname(Cu.results()), "*/faceoffs.jsonl")
    |> Path.wildcard()
    |> Enum.flat_map(&Enum.to_list(File.stream!(&1)))
    |> Enum.map(&:json.decode/1)
    |> Enum.filter(&(is_map(&1["key"]) and is_float(&1["score_a"])))
    |> Map.new(&{&1["key"], &1})
  end
  def remember(row), do: :persistent_term.put({__MODULE__, :cache}, Map.put(cache(), row["key"], row))
  def fresh?(a, b), do: a in @fresh or b in @fresh
  def faceoff({a, wa}, {b, wb}, seed) do
    key = cache_key({a, wa}, {b, wb}, seed)
    case if(fresh?(a, b), do: nil, else: Map.get(cache(), key)) do
      nil -> play_faceoff({a, wa}, {b, wb}, seed, key)
      row -> reuse(row, a, b, seed)
    end
  end
  def reuse(row, a, b, seed) do
    File.write!(Path.join(Cu.results(), "faceoffs.jsonl"), Cu.json(Map.merge(row, %{"a" => a, "b" => b, "cached" => true})) <> "\n", [:append])
    IO.puts("  #{a} vs #{b} seed #{seed}: #{inspect(row["score_a"])} (cached)")
    row["score_a"]
  end
  def play_faceoff({a, wa}, {b, wb}, seed, key) do
    first = play(deal(seed), %{1 => {a, wa}, 2 => {b, wb}}, "#{a}-#{b}-#{seed}-a")
    second = play(deal(seed), %{1 => {b, wb}, 2 => {a, wa}}, "#{a}-#{b}-#{seed}-b")
    pa = [points(first, 1), points(second, 2)]
    score = if Enum.any?(pa, &is_nil/1), do: nil, else: Enum.sum(pa)
    row = %{"a" => a, "b" => b, "seed" => seed, "key" => key, "score_a" => score, "first" => %{"result" => to_string(first.result), "reason" => first.reason},
            "second" => %{"result" => to_string(second.result), "reason" => second.reason}}
    File.write!(Path.join(Cu.results(), "faceoffs.jsonl"), Cu.json(row) <> "\n", [:append])
    if score, do: remember(row)
    IO.puts("  #{a} vs #{b} seed #{seed}: #{inspect(score)} (#{first.result} #{first.reason}; #{second.result} #{second.reason})")
    score
  end
  def series(a, b), do: Map.new(1..8, &{&1, faceoff(a, b, &1)})
end

defmodule Cu.Faceoff do
  import Cu.Run
  @steady {2, 2, 2, 2, 1}
  @banker {2, 2, 2, 2, 8}
  @weights ~w(damage kill board life bank)
  def series(a, b), do: Cu.Match.series(a, b)
  def wins(scores), do: Enum.count(scores, fn {_, s} -> s != nil and s > 1 end)
  def total(scores), do: scores |> Map.values() |> Enum.reject(&is_nil/1) |> Enum.sum()
  def unproved(scores), do: Enum.count(scores, fn {_, s} -> s == nil end)
  def flip(scores), do: Map.new(scores, fn {seed, s} -> {seed, s && 2 - s} end)
  def mutant({name, tuple}, index), do: {"#{name}+#{Enum.at(@weights, index)}", put_elem(tuple, index, elem(tuple, index) * 2)}
  def mutant({name, tuple}, index, :half), do: {"#{name}-#{Enum.at(@weights, index)}", put_elem(tuple, index, div(elem(tuple, index), 2))}
  def mutant(school, index, :double), do: mutant(school, index)
  def as_player({name, {:split, predicate, a, b}}), do: {name, {:split, predicate, weights(a), weights(b)}}
  def as_player({name, tuple}), do: {name, weights(tuple)}
  @predicates [:last_turn, :behind, :first_turn]
  def splits({_, _} = a, {_, bank} = b) do
    hybrids = for predicate <- @predicates, {x, y} <- [{a, b}, {b, a}], do: {"#{elem(x, 0)}-if-#{predicate}-else-#{elem(y, 0)}", {:split, predicate, elem(x, 1), elem(y, 1)}}
    hybrids ++ [{"banker-no-bank-last", {:split, :last_turn, put_elem(bank, 4, 0), bank}}]
  end
  def split_candidate(candidate, steady, held) do
    name = elem(candidate, 0)
    vs_steady = series(as_player(candidate), as_player(steady))
    ties = Enum.count(vs_steady, fn {_, s} -> s == 1.0 end)
    IO.puts("#{name}: #{wins(vs_steady)} of 8 seeds won against steady, #{total(vs_steady)} points, #{ties} ties")
    entry = %{"candidate" => name, "against_steady" => row(vs_steady), "ties_with_steady" => ties, "frontier" => wins(vs_steady) in 1..4}
    if wins(vs_steady) >= 5 do
      vs_banker = series(as_player(candidate), as_player({"banker", @banker}))
      kept = total(vs_banker) >= held and unproved(vs_banker) == 0 and unproved(vs_steady) == 0
      IO.puts("#{name}: #{total(vs_banker)} points against banker (steady's #{held}); kept #{kept}")
      Map.merge(entry, %{"against_banker" => row(vs_banker), "kept" => kept})
    else
      Map.put(entry, "kept", false)
    end
  end
  def split_run(only \\ []) do
    File.mkdir_p!(Cu.results())
    steady = {"steady", @steady}
    banker = {"banker", @banker}
    lanes = if only == [], do: lanes(steady), else: %{"mirror_found" => 8, "idle_found" => 8, "reused_from" => "the first run of iteration 5 (it ended in a crash after four candidates)"}
    IO.puts("calibration: #{inspect(lanes)}")
    summary = if lanes["mirror_found"] == 8 and lanes["idle_found"] == 8, do: Map.put(split_round(steady, banker, only), "lanes", lanes), else: %{"lanes" => lanes, "round" => "not run: calibration under 8 of 8"}
    File.write!(Path.join(Cu.results(), "summary.json"), Cu.json(summary) <> "\n")
    IO.puts(Cu.json(summary))
  end
  def lanes(steady) do
    mirror = series(as_player(steady), {"steady-mirror", weights(@steady)})
    idle = series({"idle", weights({0, 0, 0, 0, 0})}, as_player(steady))
    %{"mirror_found" => Enum.count(mirror, fn {_, s} -> s == 1.0 end), "idle_found" => Enum.count(idle, fn {_, s} -> s != nil and s < 1 end)}
  end
  def styles_run(limit \\ 12) do
    File.mkdir_p!(Cu.results())
    steady = {"steady", @steady}
    lanes = lanes(steady)
    IO.puts("calibration: #{inspect(lanes)}")
    summary = if lanes["mirror_found"] == 8 and lanes["idle_found"] == 8, do: %{"lanes" => lanes, "styles" => style_entries(limit, steady)}, else: %{"lanes" => lanes, "round" => "not run: calibration under 8 of 8"}
    File.write!(Path.join(Cu.results(), "summary.json"), Cu.json(summary) <> "\n")
    IO.puts(Cu.json(summary))
  end
  def style_entries(limit, steady) do
    styles = Path.join(Path.dirname(Cu.results()), "iteration-6/summary.json") |> File.read!() |> :json.decode() |> Map.fetch!("styles")
    others = Enum.reject(styles, fn style -> Enum.any?(style["weightings"], &(&1 == Tuple.to_list(@steady))) end) |> Enum.take(limit)
    for {style, index} <- Enum.with_index(others, 1) do
      vector = List.to_tuple(style["representative"])
      against = series({"style#{index}", weights(vector)}, as_player(steady))
      ties = Enum.count(against, fn {_, s} -> s == 1.0 end)
      IO.puts("style#{index} #{inspect(vector)}: #{wins(against)} of 8 seeds won against steady, #{total(against)} points, #{ties} ties")
      %{"style" => index, "representative" => style["representative"], "members" => style["size"], "mean_outcome" => style["mean_outcome"], "against_steady" => row(against), "ties_with_steady" => ties, "kept" => wins(against) >= 5 and unproved(against) == 0}
    end
  end
  def split_round(steady, banker, only \\ []) do
    base = series(as_player(banker), as_player(steady))
    held = 16 - total(base)
    IO.puts("baseline banker against steady: #{wins(base)} of 8 seeds won, #{total(base)} points of 16")
    %{"baseline_banker_vs_steady" => row(base), "steady_points_against_banker" => held, "candidates" => splits(steady, banker) |> Enum.filter(fn {name, _} -> only == [] or name in only end) |> Enum.map(&split_candidate(&1, steady, held))}
  end
  def row(scores), do: %{"wins" => wins(scores), "points" => total(scores), "unproved" => unproved(scores), "by_seed" => Map.new(scores, fn {k, v} -> {to_string(k), v} end)}
  def improve(school, other, parent_vs_other, moves \\ [:double]) do
    options = for move <- moves, index <- 0..4, elem(mutant(school, index, move), 1) != elem(school, 1), do: {index, move}
    Enum.reduce_while(options, {school, []}, fn {index, move}, {_, tried} ->
      candidate = mutant(school, index, move)
      against_parent = series(as_player(candidate), as_player(school))
      entry = %{"mutant" => elem(candidate, 0), "weights" => Tuple.to_list(elem(candidate, 1)), "against_parent" => row(against_parent)}
      against_other = if wins(against_parent) >= 5, do: series(as_player(candidate), as_player(other)), else: nil
      entry = if against_other, do: Map.put(entry, "against_other", row(against_other)), else: entry
      better = against_other != nil and total(against_other) > total(parent_vs_other)
      IO.puts("#{elem(candidate, 0)}: #{wins(against_parent)} of 8 against its parent#{if against_other, do: ", #{total(against_other)} points against #{elem(other, 0)} (parent #{total(parent_vs_other)})", else: ""}#{if better, do: ", kept", else: ""}")
      if better, do: {:halt, {candidate, tried ++ [Map.put(entry, "kept", true)]}}, else: {:cont, {school, tried ++ [entry]}}
    end)
  end
  def distinct_after(schools) do
    runs = for {name, tuple} <- schools, into: %{}, do: {name, all({2, 1}, name, weights(tuple))}
    [{a, ra}, {b, rb}] = Map.to_list(runs)
    %{"pair" => [a, b], "distinct_on_g2m1" => Enum.count(1..8, &distinct?(ra[&1], rb[&1]))}
  end
  def run do
    File.mkdir_p!(Cu.results())
    steady = {"steady", @steady}
    banker = {"banker", @banker}
    mirror = series(as_player(steady), {"steady-mirror", weights(@steady)})
    idle = series({"idle", weights({0, 0, 0, 0, 0})}, as_player(steady))
    lanes = %{"mirror_found" => Enum.count(mirror, fn {_, s} -> s == 1.0 end), "idle_found" => Enum.count(idle, fn {_, s} -> s != nil and s < 1 end)}
    IO.puts("calibration: #{inspect(lanes)}")
    base = series(as_player(banker), as_player(steady))
    IO.puts("baseline banker against steady: #{wins(base)} of 8 seeds won, #{total(base)} points of 16")
    summary = %{"lanes" => lanes, "mirror" => row(mirror), "idle" => row(idle), "baseline_banker_vs_steady" => row(base)}
    summary = if lanes["mirror_found"] == 8 and lanes["idle_found"] == 8, do: Map.merge(summary, round(steady, banker, base)), else: Map.put(summary, "round", "not run: calibration under 8 of 8")
    File.write!(Path.join(Cu.results(), "summary.json"), Cu.json(summary) <> "\n")
    IO.puts(Cu.json(summary))
  end
  def round(steady, banker, base, moves \\ [:double]) do
    {new_steady, steady_tried} = improve(steady, banker, flip(base), moves)
    {new_banker, banker_tried} = improve(banker, steady, base, moves)
    changed = new_steady != steady or new_banker != banker
    finals = [new_steady, new_banker]
    %{"round" => %{"steady" => steady_tried, "banker" => banker_tried}, "schools_after" => Map.new(finals, fn {n, w} -> {n, Tuple.to_list(w)} end),
      "distinct_after" => if(changed, do: distinct_after(finals), else: "no change")}
  end
  def start do
    previous = Path.join(Path.dirname(Cu.results()), "iteration-3/summary.json")
    case File.read(previous) do
      {:ok, text} -> text |> :json.decode() |> Map.get("schools_after") |> after_schools()
      _ -> [{"steady", @steady}, {"banker", @banker}]
    end
  end
  def after_schools(nil), do: [{"steady", @steady}, {"banker", @banker}]
  def after_schools(map), do: map |> Enum.map(fn {name, list} -> {name, List.to_tuple(list)} end) |> Enum.sort_by(fn {n, _} -> if String.starts_with?(n, "steady"), do: 0, else: 1 end)
  def iterate(limit \\ 3) do
    File.mkdir_p!(Cu.results())
    [first, second] = start()
    mirror = series(as_player(first), {"#{elem(first, 0)}-mirror", weights(elem(first, 1))})
    idle = series({"idle", weights({0, 0, 0, 0, 0})}, as_player(first))
    lanes = %{"mirror_found" => Enum.count(mirror, fn {_, s} -> s == 1.0 end), "idle_found" => Enum.count(idle, fn {_, s} -> s != nil and s < 1 end)}
    IO.puts("calibration: #{inspect(lanes)}")
    rounds = if lanes["mirror_found"] == 8 and lanes["idle_found"] == 8, do: rounds(first, second, 1, limit, []), else: "not run: calibration under 8 of 8"
    summary = %{"start" => Map.new([first, second], fn {n, w} -> {n, Tuple.to_list(w)} end), "lanes" => lanes, "rounds" => rounds}
    File.write!(Path.join(Cu.results(), "summary.json"), Cu.json(summary) <> "\n")
    IO.puts(Cu.json(summary))
  end
  def rounds(_a, _b, n, limit, done) when n > limit, do: done
  def rounds(a, b, n, limit, done) do
    base = series(as_player(b), as_player(a))
    IO.puts("round #{n}: #{elem(b, 0)} against #{elem(a, 0)}: #{wins(base)} of 8 seeds won, #{total(base)} points of 16")
    r = round(a, b, base, [:double, :half])
    [a2, b2] = r["schools_after"] |> after_schools()
    entry = Map.merge(r, %{"round" => n, "baseline" => row(base)})
    if {a2, b2} == {a, b}, do: done ++ [entry], else: rounds(a2, b2, n + 1, limit, done ++ [entry])
  end
end

defmodule Cu.Screen do
  @values [0, 1, 2, 4, 8, 16]
  @metrics ~w(damage kills board life_lost bank)a
  def boards, do: for(level <- [{2, 1}, {2, 4}], seed <- 1..4, do: {level, seed})
  def normalize(vector) do
    divisor = vector |> Tuple.to_list() |> Enum.reduce(0, &Integer.gcd/2)
    if divisor == 0, do: vector, else: vector |> Tuple.to_list() |> Enum.map(&div(&1, divisor)) |> List.to_tuple()
  end
  def vectors(count) do
    :rand.seed(:exsss, {5, 11, 2026})
    corners = for index <- 0..4, do: put_elem({1, 1, 1, 1, 1}, index, 16)
    random = for _ <- 1..count, do: List.to_tuple(for _ <- 1..5, do: Enum.random(@values))
    ([{2, 2, 2, 2, 1}, {2, 2, 2, 2, 8}] ++ corners ++ random) |> Enum.map(&normalize/1) |> Enum.reject(&(&1 == {0, 0, 0, 0, 0})) |> Enum.uniq()
  end
  def signature(rows), do: Enum.map(rows, fn row -> Enum.map(@metrics, &row["outcome"][to_string(&1)]) end)
  def solve_board(vector, {level, seed}) do
    board = Cu.Gen.level(level, seed)
    r = Cu.Run.solve(board, Cu.Run.weights(vector))
    outcome = if match?({:illegal, _}, r.outcome), do: %{}, else: Map.take(r.outcome, @metrics) |> Map.new(fn {k, v} -> {to_string(k), v} end)
    row = %{"vector" => Tuple.to_list(vector), "level" => Cu.Run.key(level), "seed" => seed, "proved" => r.proved, "tries" => r[:tries], "duty" => r.turbo[:duty], "outcome" => outcome}
    File.write!(Path.join(Cu.results(), "screen.jsonl"), Cu.json(row) <> "\n", [:append])
    row
  end
  def run(count \\ 60) do
    File.mkdir_p!(Cu.results())
    all = vectors(count)
    IO.puts("screen: #{length(all)} weightings, #{length(boards())} boards each")
    results =
      for {vector, index} <- Enum.with_index(all, 1) do
        rows = Enum.map(boards(), &solve_board(vector, &1))
        IO.puts("  weighting #{index} of #{length(all)} #{inspect(vector)}: #{Enum.count(rows, & &1["proved"])} of #{length(rows)} boards proved")
        {vector, rows}
      end
    groups = results |> Enum.filter(fn {_, rows} -> Enum.all?(rows, & &1["proved"]) end) |> Enum.group_by(fn {_, rows} -> signature(rows) end)
    styles = for {sig, members} <- groups, do: style(sig, members)
    summary = %{"weightings" => length(all), "fully_proved" => Enum.sum(Enum.map(groups, fn {_, m} -> length(m) end)), "styles" => Enum.sort_by(styles, &(-&1["size"]))}
    File.write!(Path.join(Cu.results(), "summary.json"), Cu.json(summary) <> "\n")
    IO.puts("styles: #{length(styles)} distinct plays among #{summary["fully_proved"]} fully proved weightings")
  end
  def style(sig, members) do
    vectors = members |> Enum.map(fn {v, _} -> Tuple.to_list(v) end) |> Enum.sort_by(&{Enum.sum(&1), &1})
    mean = for {metric, column} <- Enum.zip(@metrics, 0..4), into: %{}, do: {to_string(metric), Float.round(Enum.sum(Enum.map(sig, &Enum.at(&1, column))) / length(sig), 2)}
    %{"size" => length(members), "representative" => hd(vectors), "weightings" => vectors, "mean_outcome" => mean}
  end
end

Code.require_file("direct.exs", __DIR__)
