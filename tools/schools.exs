# SPDX-FileCopyrightText: 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
# schools.exs  cards | check | one G MANA SEED | run | faceoff
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
      IO.puts("  #{if ok, do: "ok  ", else: "FAIL"} #{name}: turbo #{inspect(r.turbo.bound)} rules #{inspect(r.value)} want #{want} front end equal #{r.turbo.frontend_equal} nodes #{inspect(r.turbo.nodes)}")
      ok
    end
    results = results ++ match_tests()
    if Enum.all?(results), do: IO.puts("OK: #{length(results)} tests"), else: (IO.puts("FAILED"); System.halt(1))
  end
  def side(partner, field, hand, deck) do
    card = &Cu.Cards.find/1
    %{partner: card.(partner), field: Enum.map(field, card), hand: Enum.map(hand, card), deck: Enum.map(deck, card), life: 10, carried: 0}
  end
  def match_tests do
    steady = {"steady", weights(Cu.Frontier.steady())}
    sides = %{1 => side("CUU00074", [], [], ["CUU00043"]), 2 => side("CUU00034", ["CUU00233"], [], ["CUU00074"])}
    lethal = Cu.Match.play(sides, %{1 => steady, 2 => steady}, "m01")
    m01 = lethal.result == 2 and lethal.reason == "life" and length(lethal.log) == 2
    IO.puts("  #{if m01, do: "ok  ", else: "FAIL"} m01 a combined attack takes the last life on turn 2: #{inspect(lethal.result)} #{lethal.reason} after #{length(lethal.log)} turns")
    mirror = Cu.Match.faceoff(steady, {"steady-mirror", weights(Cu.Frontier.steady())}, 1)
    IO.puts("  #{if mirror == 1.0, do: "ok  ", else: "FAIL"} m02 the mirror scores exactly 1 of 2: #{inspect(mirror)}")
    [m01, mirror == 1.0]
  end
  def main(["faceoff" | _]), do: Cu.Faceoff.run()
  def main(["run" | _]), do: Cu.Frontier.run()
  def main(_), do: IO.puts("usage: schools.exs cards | check | one G MANA SEED | run | faceoff")
end

Cu.Cli.main(System.argv())
