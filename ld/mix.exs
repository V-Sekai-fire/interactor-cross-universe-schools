# SPDX-FileCopyrightText: 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: MIT
defmodule CuLd.MixProject do
  use Mix.Project

  def project do
    [app: :cu_ld, version: "0.1.0", elixir: "~> 1.18", compilers: [:leanler] ++ Mix.compilers(),
     deps: [{:leanler, github: "V-Sekai-fire/leanler"}],
     leanler: [mode: :nif, module: CuLd.Native, package: "cu-ld", modules: ["CuLd"],
       exports: [render_document: [symbol: "cu_ld_render", args: [:string], returns: :string],
                 read_documents: [symbol: "cu_ld_read", args: [:string], returns: :string]]]]
  end
end
