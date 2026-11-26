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
  def work, do: System.get_env("CU_WORK", Path.join(@root, ".work"))
  def model, do: Path.join(@root, "model/turn.mzn")
  def traces, do: Path.join(@root, "results/traces.jsonl")
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
    if winnable?(board), do: draw(g, mana, seed, attempt + 1), else: board
  end
  def winnable?(board), do: (board.mine |> Enum.map(& &1.attack) |> Enum.sum()) - hd(board.theirs).defense >= board.their_life
  def side(pool, n) do
    partner = pool |> Enum.filter(&(&1.level <= 5)) |> Enum.random()
    copies = Enum.flat_map(pool, &List.duplicate(&1, 3)) -- [partner]
    [partner | Enum.take_random(copies, n)]
  end
  def board(mine, hand, theirs, mana) do
    cards = &Enum.map(&1, fn id -> Cu.Cards.find(id) end)
    %{mine: cards.(mine ++ hand), field: length(mine) - 1, theirs: cards.(theirs), my_life: 10, their_life: 10, mana: mana}
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
    shares = #{list(shares(board))}; in_hand = #{list(in_hand(board))}; retirable = #{list(retirable(board))};
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
      {length(who) > 1 and not combined?(st, who), "a combined attack without the partner or a shared type"}
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
      board: levels.(board.mine, st.mine), bank: min(5, min(5, st.mana) + 5 - level(board, 1)), steps: st.steps}
  end
  def value({:illegal, _}, _w), do: nil
  def value(o, w), do: w.life * o.life_lost - w.damage * o.damage - w.kill * o.kills - w.board * o.board - w.bank * o.bank
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
  def chuffed(model, dzn) do
    {out, _} = mzn(["--solver", "chuffed", "-t", "120000", model, dzn])
    objective = word(out, "objective")
    %{optimal: String.contains?(out, "=========="), objective: objective && String.to_integer(objective), plan: plan(out)}
  end
  def turbo(model, dzn) do
    dir = Cu.work()
    scratch = Path.join([dir, "turbo_solve", "party"])
    [fzn, ozn, cp, ck] = for name <- ~w(x.fzn x.ozn party.cp ck.bin), do: Path.join(dir, name)
    for stale <- [ck, ck <> ".status", Path.join(scratch, "result.txt"), Path.join(scratch, "solution.mzn")], do: File.rm(stale)
    {_, 0} = mzn(["--solver", "org.minizinc.mzn-fzn", "-c", "--fzn", fzn, "--ozn", ozn, model, dzn])
    {dump, 0} = System.cmd(Path.join(Cu.frontier(), ".lake/build/bin/frontier_frontend"), ["--dump", fzn])
    File.write!(cp, dump)
    env = [{"TMPDIR", dir}, {"ELIXIR_ERL_OPTIONS", "+fnu"}]
    args = ["600", "elixir", "tools/turbo_player.exs", cp, "--fzn", fzn, "--checkpoint", ck, "--max-gpu", "100", "--slice", "2000"]
    {log, code} = System.cmd("timeout", args, cd: Cu.frontier(), env: env, stderr_to_stdout: true)
    Map.put(read(scratch, ozn, code, log), :frontend_equal, frontend_equal?(fzn, dump))
  end
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
    [_, bound, nodes, exhaustive] = Regex.run(~r/bound (-?\d+) nodes (\d+) fails \d+ depth_max \d+ exhaustive (\d)/, result)
    %{exhaustive: exhaustive == "1", bound: String.to_integer(bound), nodes: String.to_integer(nodes), plan: plan(printed(ozn, Path.join(scratch, "solution.mzn")))}
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
  def solve(board, w, lane \\ "player") do
    path = dzn(board, w)
    judge(board, w, Cu.Solve.turbo(model_for(lane), path), Cu.Solve.chuffed(Cu.model(), path))
  end
  def judge(board, w, turbo, chuffed) do
    outcome = if Cu.Solve.whole?(turbo.plan), do: Cu.Rules.play(board, turbo.plan), else: {:illegal, "no plan"}
    value = Cu.Rules.value(outcome, w)
    proved = turbo.exhaustive and chuffed.optimal and turbo.bound == chuffed.objective and value == turbo.bound
    %{proved: proved, outcome: outcome, value: value, turbo: turbo, chuffed: chuffed, weights: w}
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
            "turbo_exhaustive" => r.turbo.exhaustive, "chuffed_objective" => r.chuffed.objective, "frontend_equal" => r.turbo.frontend_equal,
            "plan" => show(r.turbo.plan), "board" => cards(board)}
    File.write!(Cu.traces(), Cu.json(row) <> "\n", [:append])
    r
  end
  def all(level, name, w, lane \\ "player") do
    for seed <- 1..8, into: %{} do
      board = Cu.Gen.level(level, seed)
      r = trace(level, seed, name, lane, board, solve(board, w, lane))
      IO.puts("  #{key(level)} seed=#{seed} #{name} #{lane} proved=#{r.proved} bound=#{inspect(r.turbo.bound)} chuffed=#{inspect(r.chuffed.objective)} nodes=#{inspect(r.turbo.nodes)}")
      {seed, r}
    end
  end
  def successes(mine, kept), do: Enum.count(1..8, fn seed -> Enum.all?(kept, fn {_, rs} -> distinct?(mine[seed], rs[seed]) end) end)
end

defmodule Cu.Frontier do
  import Cu.Run
  @levels [{2, 1}, {2, 4}]
  @ladder [2, 4, 8]
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
  def frontier?(scores), do: Enum.any?(Map.values(scores), &(&1 > 0 and &1 < 8))
  def climb(_name, _index, _kept, _levels, [], best, tried), do: {best, tried}
  def climb(name, index, kept, levels, [rung | rest], best, tried) do
    {runs, scores} = cells(name, raised(index, rung), kept, levels)
    IO.puts("#{name} rung #{rung}: #{inspect(scores)}")
    here = %{"rung" => rung, "scores" => scores, "runs" => runs}
    tried = tried ++ [strip(here)]
    cond do
      best != nil and total(scores) <= total(best["scores"]) -> {best, tried}
      frontier?(scores) -> climb(name, index, kept, levels, rest, here, tried)
      true -> {here, tried}
    end
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
    File.write!(Path.join(Cu.root(), "results/summary.json"), Cu.json(summary) <> "\n")
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
