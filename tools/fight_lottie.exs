# SPDX-FileCopyrightText: 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
# fight_lottie.exs LEVEL SEED PLAYER OUT.lot [video] : one traced turn as a Lottie animation of shapes (no card art, names or text); `video` also renders OUT.mp4
Code.require_file("cu.exs", __DIR__)

defmodule Cu.Lottie do
  @rate 30
  @intro 30
  @step 48
  @hit 14
  @tints %{"steady" => [0.6, 0.6, 0.6], "striker" => [0.9, 0.25, 0.25], "hunter" => [0.65, 0.4, 0.9], "keeper" => [0.3, 0.75, 0.4],
           "warden" => [0.3, 0.55, 0.95], "banker" => [0.95, 0.78, 0.25]}
  @segments %{0 => ~w(a b c d e f), 1 => ~w(b c), 2 => ~w(a b g e d), 3 => ~w(a b g c d), 4 => ~w(f g b c), 5 => ~w(a f g c d),
              6 => ~w(a f g e d c), 7 => ~w(a b c), 8 => ~w(a b c d e f g), 9 => ~w(a b c d f g)}
  @bars %{"a" => {6, 1.5, 10, 3}, "b" => {10.5, 6.5, 3, 9}, "c" => {10.5, 15.5, 3, 9}, "d" => {6, 20.5, 10, 3},
          "e" => {1.5, 15.5, 3, 9}, "f" => {1.5, 6.5, 3, 9}, "g" => {6, 11, 10, 3}}

  def fixed(value), do: %{"a" => 0, "k" => value}
  def moving([{_, value}]), do: fixed(value)
  def moving(keys) do
    ease = %{"i" => %{"x" => [0.4], "y" => [1]}, "o" => %{"x" => [0.6], "y" => [0]}}
    %{"a" => 1, "k" => Enum.map(keys, fn {frame, value} -> Map.merge(ease, %{"t" => frame, "s" => value}) end)}
  end
  def tidy(keys), do: keys |> Enum.sort_by(&elem(&1, 0)) |> Enum.reverse() |> Enum.uniq_by(&elem(&1, 0)) |> Enum.reverse()
  def fill(color), do: %{"ty" => "fl", "c" => fixed(color ++ [1]), "o" => fixed(100)}
  def stroke(color, width), do: %{"ty" => "st", "c" => fixed(color ++ [1]), "o" => fixed(100), "w" => fixed(width)}
  def still, do: %{"ty" => "tr", "p" => fixed([0, 0]), "a" => fixed([0, 0]), "s" => fixed([100, 100]), "r" => fixed(0), "o" => fixed(100)}
  def box({x, y}, {w, h}, round), do: %{"ty" => "rc", "p" => fixed([x, y]), "s" => fixed([w, h]), "r" => fixed(round)}
  def group(items), do: %{"ty" => "gr", "it" => items ++ [still()]}
  def digit(value, {x, y}, k) do
    for name <- @segments[value], {cx, cy, w, h} = @bars[name], do: box({x + cx * k, y + cy * k}, {w * k, h * k}, 0)
  end
  def number(value, {x, y}, k, color) do
    bars = value |> Integer.digits() |> Enum.with_index() |> Enum.flat_map(fn {d, i} -> digit(d, {x + i * 15 * k, y}, k) end)
    group(bars ++ [fill(color)])
  end
  def layer(name, shapes, position, opacity, scale, span \\ nil) do
    {first, last} = span || {0, 100_000}
    look = %{"o" => moving(tidy(opacity)), "r" => fixed(0), "p" => moving(tidy(position)), "a" => fixed([0, 0, 0]), "s" => moving(tidy(scale))}
    %{"ty" => 4, "nm" => name, "ip" => first, "op" => last, "st" => 0, "ks" => look, "shapes" => shapes}
  end
  def plain(name, shapes, span \\ nil), do: layer(name, shapes, [{0, [0, 0, 0]}], [{0, 100}], [{0, [100, 100, 100]}], span)

  def token(card, color, partner?) do
    edge = if partner?, do: [stroke([0.98, 0.85, 0.35], 5)], else: []
    [
      number(card.level, {-54, -34}, 0.7, [1, 1, 1]),
      number(card.attack, {-44, -10}, 1.2, [1, 0.5, 0.45]),
      number(card.defense, {14, -10}, 1.2, [0.6, 0.8, 1]),
      number(String.to_integer(String.slice(card.id, -3, 3)), {-12, 22}, 0.5, [0.85, 0.85, 0.85]),
      group([box({0, 0}, {124, 80}, 10)] ++ edge ++ [fill(color)])
    ]
  end
  def rows(count, k), do: 300 + (k - (count + 1) / 2) * 92
  def home(_board, 1), do: {170, 300}
  def home(board, i), do: {330, rows(board.field + 1, min(i - 1, board.field + 1))}
  def hand(board, i), do: {110 + 140 * (i - board.field - 2), 492}
  def theirs(_board, 1), do: {790, 300}
  def theirs(board, j), do: {630, rows(length(board.theirs) - 1, j - 1)}
  def point({x, y}), do: [x, y, 0]
  def toward({ax, ay}, {bx, by}), do: {ax + (bx - ax) * 0.62, ay + (by - ay) * 0.62}
  def size(percent), do: [percent, percent, 100]

  def start(board) do
    mine = for {_, i} <- Cu.Gen.places(board), into: %{} do
      held = i > board.field + 1
      {i, %{at: if(held, do: hand(board, i), else: home(board, i)), position: [], opacity: [{0, if(held, do: 40, else: 100)}], scale: [{0, size(if(held, do: 70, else: 100))}]}}
    end
    them = for {_, j} <- Enum.with_index(board.theirs, 1), into: %{}, do: {j, %{at: theirs(board, j), position: [], opacity: [{0, 100}], scale: [{0, size(100)}]}}
    %{mine: mine, them: them, mana: [{0, board.mana}], my_life: [{0, board.my_life}], their_life: [{0, board.their_life}]}
  end
  def add(tokens, i, field, keys), do: Map.update!(tokens, i, &Map.update!(&1, field, fn old -> old ++ keys end))
  def act(st, %{"kind" => "retire", "units" => units, "mana" => mana}, t, _board) do
    mine = Enum.reduce(units, st.mine, fn i, acc -> acc |> add(i, :opacity, [{t, 100}, {t + 22, 0}]) |> add(i, :scale, [{t, size(100)}, {t + 22, size(55)}]) end)
    %{st | mine: mine, mana: st.mana ++ [{t + 22, mana}]}
  end
  def act(st, %{"kind" => "summon", "unit" => i, "mana" => mana}, t, board) do
    mine = st.mine |> add(i, :position, [{t, point(hand(board, i))}, {t + 20, point(home(board, i))}]) |> add(i, :opacity, [{t, 40}, {t + 14, 100}]) |> add(i, :scale, [{t, size(70)}, {t + 20, size(100)}])
    %{st | mine: put_in(mine[i].at, home(board, i)), mana: st.mana ++ [{t + 14, mana}]}
  end
  def act(st, %{"kind" => "attack", "units" => units, "target" => j} = step, t, _board) do
    goal = st.them[j].at
    lunge = fn acc, i -> add(acc, i, :position, [{t, point(acc[i].at)}, {t + @hit, point(toward(acc[i].at, goal))}, {t + 34, point(acc[i].at)}]) end
    them = add(st.them, j, :scale, [{t + @hit - 2, size(100)}, {t + @hit + 3, size(116)}, {t + @hit + 10, size(100)}])
    st = %{st | mine: Enum.reduce(units, st.mine, &lunge.(&2, &1)), them: them}
    st |> destroyed(step, t) |> lost(step, t) |> damaged(step, t) |> hurt(step, t)
  end
  def fade(tokens, i, t), do: add(tokens, i, :opacity, [{t + @hit, 100}, {t + @hit + 12, 0}])
  def destroyed(st, %{"destroyed" => j}, t), do: %{st | them: fade(st.them, j, t)}
  def destroyed(st, _, _), do: st
  def lost(st, %{"lost" => i}, t), do: %{st | mine: fade(st.mine, i, t)}
  def lost(st, _, _), do: st
  def damaged(st, %{"damage" => d}, t) when d > 0, do: %{st | their_life: st.their_life ++ [{t + @hit, max(0, elem(List.last(st.their_life), 1) - d)}]}
  def damaged(st, _, _), do: st
  def hurt(st, %{"hurt" => d}, t) when d > 0, do: %{st | my_life: st.my_life ++ [{t + @hit, max(0, elem(List.last(st.my_life), 1) - d)}]}
  def hurt(st, _, _), do: st

  def placed(%{position: []} = tk), do: [{0, point(tk.at_start)}]
  def placed(tk), do: [{0, point(tk.at_start)} | tk.position]
  def tokens(board, st, first) do
    mine = for {card, i} <- Cu.Gen.places(board), tk = Map.put(st.mine[i], :at_start, first.mine[i].at) do
      layer("mine #{i} #{card.id}", token(card, [0.1, 0.45, 0.5], i == 1), placed(tk), tk.opacity, tk.scale)
    end
    them = for {card, j} <- Enum.with_index(board.theirs, 1), tk = Map.put(st.them[j], :at_start, first.them[j].at) do
      layer("theirs #{j} #{card.id}", token(card, [0.68, 0.33, 0.12], j == 1), placed(tk), tk.opacity, tk.scale)
    end
    mine ++ them
  end
  def spans(changes, last), do: changes |> Enum.chunk_every(2, 1) |> Enum.map(fn [{from, v}, {to, _}] -> {v, from, to}; [{from, v}] -> {v, from, last} end)
  def counter(name, changes, place, k, color, last) do
    for {value, from, to} <- spans(changes, last), to > from, do: plain("#{name} #{value}", [number(value, place, k, color)], {from, to})
  end
  def bar(name, changes, x, color, last) do
    width = fn life -> 36 * life end
    sizes = for {frame, life} <- changes, do: {frame, [width.(life), 14]}
    places = for {frame, life} <- changes, do: {frame, [x + width.(life) / 2, 44]}
    shape = %{"ty" => "rc", "p" => moving(tidy(places)), "s" => moving(tidy(sizes)), "r" => fixed(4)}
    [plain(name, [group([shape, fill(color)])])] ++ counter(name, changes, {x, 62}, 0.8, color, last)
  end
  def document(board, outcome, player) do
    first = start(board)
    {st, _} = Enum.reduce(outcome.steps, {first, @intro}, fn step, {st, t} -> {act(st, step, t, board), t + @step} end)
    last = @intro + @step * length(outcome.steps) + 45
    back = plain("ground", [group([box({480, 270}, {960, 540}, 0), fill([0.07, 0.08, 0.11])])])
    band = plain("school #{player}", [group([box({480, 6}, {960, 12}, 0), fill(Map.get(@tints, player, [0.6, 0.6, 0.6]))])])
    mana = counter("mana", st.mana, {60, 392}, 1.4, [0.95, 0.78, 0.25], last)
    life = bar("my life", st.my_life, 60, [0.3, 0.75, 0.7], last) ++ bar("their life", st.their_life, 540, [0.9, 0.5, 0.3], last)
    layers = [band] ++ mana ++ life ++ tokens(board, st, first) ++ [back]
    %{"v" => "5.7.0", "fr" => @rate, "ip" => 0, "op" => last, "w" => 960, "h" => 540, "nm" => "Cross Universe turn, unofficial, #{player}", "ddd" => 0, "assets" => [],
      "layers" => layers |> Enum.with_index(1) |> Enum.map(fn {l, n} -> l |> Map.put("ind", n) |> Map.update!("op", &min(&1, last)) end)}
  end

  def row(level, seed, player) do
    Cu.traces()
    |> File.stream!()
    |> Stream.map(&:json.decode/1)
    |> Enum.filter(&(&1["level"] == level and &1["seed"] == seed and &1["player"] == player and &1["lane"] == "player" and &1["proved"]))
    |> List.last()
  end
  def renderer, do: System.get_env("THORVG_LOTTIE2GIF", "/mnt/fire/6-datasource/thorvg-1.1.4-linux/build/tools/lottie2gif/tvg-lottie2gif")
  def video(lot) do
    base = Path.rootname(lot)
    File.cp!(lot, base <> ".json")
    {_, 0} = System.cmd(renderer(), [Path.basename(base) <> ".json", "-r", "960x540", "-f", "30"], cd: Path.dirname(lot), stderr_to_stdout: true)
    {_, 0} = System.cmd("ffmpeg", ["-y", "-loglevel", "error", "-i", base <> ".gif", "-movflags", "+faststart", "-pix_fmt", "yuv420p", base <> ".mp4"], stderr_to_stdout: true)
    for spare <- [base <> ".json", base <> ".gif"], do: File.rm!(spare)
    IO.puts(base <> ".mp4")
  end
  def main([level, seed, player, out, "video"]) do
    main([level, seed, player, out])
    video(out)
  end
  def main([level, seed, player, out]) do
    [_, g, mana] = Regex.run(~r/^g(\d+)m(\d+)$/, level)
    board = Cu.Gen.level({String.to_integer(g), String.to_integer(mana)}, String.to_integer(seed))
    p = row(level, String.to_integer(seed), player)["plan"]
    plan = %{retire: p["retire"], summon: p["summon"], early: p["early"], slot: p["slot"], target: p["target"]}
    outcome = Cu.Rules.play(board, plan)
    File.write!(out, Cu.json(document(board, outcome, player)))
    IO.puts("#{out}: #{length(outcome.steps)} steps, damage #{outcome.damage} kills #{outcome.kills} board #{outcome.board} life lost #{outcome.life_lost} bank #{outcome.bank}")
  end
end

Cu.Lottie.main(System.argv())
