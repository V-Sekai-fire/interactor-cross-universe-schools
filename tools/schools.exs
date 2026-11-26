# SPDX-FileCopyrightText: 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
# schools.exs  cards | check | probe [G MANA] | one G MANA SEED | run
Code.require_file("cu.exs", __DIR__)

defmodule Cu.Cli do
  import Cu.Run
  def tests do
    [
      {"t01 a unit clears the way, the partner hits for 1", ~w(CUU00034 CUU00043), [], ~w(CUU00217 CUU00074), 0, {2, 2, 2, 2, 1}, -8},
      {"t02 only a combined attack destroys their unit", ~w(CUU00034 CUU00043), [], ~w(CUU00217 CUU00237), 0, {2, 2, 2, 2, 1}, -16},
      {"t03 steady will not trade a unit for 2 damage", ~w(CUU00074 CUU00233), [], ~w(CUU00046), 0, {2, 2, 2, 2, 1}, -12},
      {"t04 a striker makes that trade", ~w(CUU00074 CUU00233), [], ~w(CUU00046), 0, {8, 2, 2, 2, 1}, -20},
      {"t05 an early summon joins a combined attack", ~w(CUU00043), ~w(CUU00233), ~w(CUU00074), 5, {2, 2, 2, 2, 1}, -28}
    ]
  end
  def main(["cards" | _]) do
    for c <- Cu.Cards.pool(), do: IO.puts("#{c.id} level #{c.level} attack #{c.attack} defense #{c.defense} #{Enum.join(c.types, ", ")}")
  end
  def main(["check" | _]) do
    results = for {name, mine, hand, theirs, mana, w, want} <- tests() do
      r = solve(Cu.Gen.board(mine, hand, theirs, mana), weights(w))
      ok = r.proved and r.value == want
      IO.puts("  #{if ok, do: "ok  ", else: "FAIL"} #{name}: turbo #{inspect(r.turbo.bound)} chuffed #{inspect(r.chuffed.objective)} rules #{inspect(r.value)} want #{want} front end equal #{r.turbo.frontend_equal} nodes #{inspect(r.turbo.nodes)}")
      ok
    end
    if Enum.all?(results), do: IO.puts("OK: #{length(results)} tests"), else: (IO.puts("FAILED"); System.halt(1))
  end
  def main(["probe" | rest]) do
    [g, mana] = Enum.map(rest ++ Enum.drop(["2", "1"], length(rest)), &String.to_integer/1)
    players = [Cu.Frontier.steady() | for(i <- 0..4, do: put_elem(Cu.Frontier.steady(), i, elem(Cu.Frontier.steady(), i) * 8))]
    for seed <- 1..8 do
      board = Cu.Gen.level({g, mana}, seed)
      plays = for w <- players do
        c = Cu.Solve.chuffed(Cu.model(), dzn(board, weights(w)))
        o = Cu.Rules.play(board, c.plan)
        agree = Cu.Rules.value(o, weights(w)) == c.objective
        "#{o.damage}/#{o.kills}/#{o.board}/#{o.life_lost}/#{o.bank}#{if agree, do: "", else: "!"}"
      end
      IO.puts("g=#{g}m#{mana} seed=#{seed} | #{Enum.join(plays, " ")}")
    end
  end
  def main(["one", g, mana, seed | _]) do
    level = {String.to_integer(g), String.to_integer(mana)}
    {us, r} = :timer.tc(fn -> solve(Cu.Gen.level(level, String.to_integer(seed)), weights(Cu.Frontier.steady())) end)
    IO.puts("#{key(level)} seed #{seed}: proved #{r.proved} turbo #{inspect(r.turbo.bound)} chuffed #{inspect(r.chuffed.objective)} rules #{inspect(r.value)} nodes #{inspect(r.turbo.nodes)} front end equal #{r.turbo.frontend_equal} #{Float.round(us / 1.0e6, 1)} s")
  end
  def main(["run" | _]), do: Cu.Frontier.run()
  def main(_), do: IO.puts("usage: schools.exs cards | check | probe [G MANA] | one G MANA SEED | run")
end

Cu.Cli.main(System.argv())
