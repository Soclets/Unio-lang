(* Turns Ralph's core into OCaml, for the shell to run.

   This file is the one list of how Ralph's core becomes OCaml (Building rule 14). Ralph's theorems rest on nothing,
   or only on Flocq's four axioms about real numbers, listed with their reasons in assumptions/axioms.txt (D189); the
   test run checks `Print Assumptions` against that list. What's trusted beyond that is how extraction turns Rocq's
   types into OCaml's, each believed for the reason given:

   - ExtrOcamlBasic: Rocq's [bool], [option], [list], pairs and [unit] become OCaml's own, which have the same
     constructors and mean the same thing.
   - ExtrOcamlNativeString: Rocq's [string] and [ascii] become OCaml's [string] and [char]. Both are sequences of
     bytes, and the mapped operations (joining, comparing, converting to and from lists of characters) do the same on
     both sides.
   - ExtrOcamlNatInt: Rocq's natural numbers, used only for places in the source, counts and fuel, become OCaml's
     [int]. They would differ only past 4611686018427387903, which no line number, column or count reaches, and fuel
     only ever counts down from the number the shell picks.

   `Whole` values are never OCaml integers: they stay Rocq's own exact integers ([Z]), extracted as Rocq's binary
   representation, with no mapping and so nothing to trust. `Float` values are Flocq's binary floats, worked on with
   Flocq's own integer arithmetic, also with no mapping: OCaml's floats are never used. *)

From Stdlib Require Import ZArith Extraction ExtrOcamlBasic ExtrOcamlNativeString ExtrOcamlNatInt.
From Ralph Require Import Syntax Whole Io Diagnostics Procedures Checker Evaluator.

Set Extraction Output Directory ".".

Extraction "core.ml"
  check_program run text_of_whole callee_name
  Z.add Z.sub Z.leb Z.ltb Z.double Z.succ_double Pos.size_nat.
