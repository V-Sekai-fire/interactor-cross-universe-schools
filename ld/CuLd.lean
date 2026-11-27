-- SPDX-FileCopyrightText: 2026 K. S. Ernest (iFire) Lee
-- SPDX-License-Identifier: MIT
import YamlLd
open Lean

/-! The study's data is YAML-LD, written and read with `lean-yaml-ld`, called from Elixir as a NIF through `leanler`.
A result that starts with `!` is an error message. Every render is read back and must equal what was given. -/

def checked (j : Json) : Except String String :=
  let y := YamlLd.render j
  match YamlLd.parse y with
  | .error e => .error s!"does not read back: {e}"
  | .ok back => if back == j then .ok y else .error "reads back different"

def numberText (n : JsonNumber) : String :=
  if n.exponent == 0 then toString n.mantissa
  else
    let digits := toString n.mantissa.natAbs
    let padded := "".pushn '0' (n.exponent + 1 - digits.length) ++ digits
    let cut := padded.length - n.exponent
    (if n.mantissa < 0 then "-" else "") ++ (padded.take cut).toString ++ "." ++ (padded.drop cut).toString

partial def exact : Json → String
  | .num n => numberText n
  | .arr items => "[" ++ ",".intercalate (items.toList.map exact) ++ "]"
  | .obj fields => "{" ++ ",".intercalate (fields.toList.map fun (key, value) => (Json.str key).compress ++ ":" ++ exact value) ++ "}"
  | other => other.compress

@[export cu_ld_render]
def renderDocument (text : String) : String :=
  match Json.parse text with
  | .error e => s!"!not JSON: {e}"
  | .ok j => match checked j with
    | .error e => s!"!{e}"
    | .ok y => y

@[export cu_ld_read]
def readDocuments (text : String) : String :=
  match YamlLd.parseAll text with
  | .error e => s!"!{e}"
  | .ok docs => "".intercalate (docs.toList.map fun doc => exact doc ++ "\n")
