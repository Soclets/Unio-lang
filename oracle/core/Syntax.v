(* The syntax tree: a Unio program as the parser hands it to the core.

   Every part carries the place it was written, so a refusal or a failed check can point at it (D54). The shell's
   parser builds this tree; the checker (Checker.v) reads it and gives back the typed tree (TypedTree.v) that the
   evaluator runs. *)

From Stdlib Require Import String List ZArith.

(* A place in the source: which of the program's files (D64), counted from 0, its line, its first column and how many
   columns it covers, counted from 1. The width is how many `^` a message puts under it (D54). *)
Record place := { place_file : nat; place_line : nat; place_column : nat; place_width : nat }.

(* The types of the subset (D15, D21, D33). The parser stops with `NotBuiltYet` or `NotDesignedYet` on any other. *)
Inductive type := Whole | Bool | Text.

Definition type_eqb (a b : type) : bool :=
  match a, b with
  | Whole, Whole | Bool, Bool | Text, Text => true
  | _, _ => false
  end.

(* An operator between two values (D17, D27, D34, D59, D190). *)
Inductive binary_operator :=
| Add | Subtract | Multiply
| Equal | Not_equal | Less | Greater | At_least | At_most
| And | Or.

(* One piece of text, as the parser reads it (D29, D30, D175, D200): plain text with its escapes taken out, a name in
   braces, a name in braces with a `places:` setting, braces holding anything else, or a `{` that's never closed. *)
Inductive piece :=
| Piece_text (text : string)
| Piece_name (name : string) (at_ : place)
| Piece_places (name : string) (at_ : place) (places : string) (places_at : place)
| Piece_other (at_ : place)
| Piece_unclosed (at_ : place).

(* The word a call names, with its narrowings (D18): `show_msg.same_line` is the word `show_msg` with the narrowing
   `same_line`. *)
Record callee := {
  callee_word : string;
  callee_word_at : place;
  callee_narrowings : list (string * place) }.

(* The place covering a callee's whole name, from its word to its last narrowing. *)
Definition callee_at (c : callee) : place :=
  let first := callee_word_at c in
  let last := fold_left (fun _ narrowing => snd narrowing) (callee_narrowings c) first in
  {| place_file := place_file first;
     place_line := place_line first;
     place_column := place_column first;
     place_width := place_column last + place_width last - place_column first |}.

Inductive expression :=
(* A whole number as written: its digits (D15). *)
| Whole_literal (digits : string) (at_ : place)
(* Text in double quotes (D21), as its pieces: every text fills in its braces (D200). *)
| Text_literal (pieces : list piece) (at_ : place)
| Bool_literal (value : bool) (at_ : place)
(* A plain word where a value goes: a variable's name (D192), or a procedure's written without `( )`. *)
| Variable_value (name : string) (at_ : place)
(* A word with narrowings and no `( )` after it, as `be.Text` in `x |> be.Text` but where a value goes. *)
| Bare_word (word : string) (at_ : place)
(* `-` right before a value (D27). *)
| Negate (operand : expression) (at_ : place)
| Not (operand : expression) (at_ : place)
| Binary (operator : binary_operator) (left right : expression) (operator_at at_ : place)
(* `( )` around a value (D3). *)
| Bracketed (inner : expression) (at_ : place)
| Call (name : callee) (given : arguments) (at_ : place)
(* `attempt ?? fallback` (D23, D81). *)
| Fallback (attempt fallback : expression) (operator_at at_ : place)
(* `start |> step |> step` (D5). *)
| Slide (start : expression) (path : steps) (at_ : place)
(* Something the parser already refused; the checker passes it over silently (D55). *)
| Broken (at_ : place)
with arguments :=
| No_arguments
(* One argument, with its label and the label's place if it's written with one (D24). *)
| Argument (label : option (string * place)) (value : expression) (rest : arguments)
with steps :=
| No_steps
(* One step: the procedure it names, and its own arguments if it's written with `( )` (D5). *)
| Step (name : callee) (bracketed : bool) (given : arguments) (at_ : place) (rest : steps).

(* One pair on a `labels` line (D25): a parameter's name and the label callers write for it. *)
Record label_pair := {
  pair_parameter : string;
  pair_parameter_at : place;
  pair_label : string;
  pair_label_at : place }.

Inductive statement :=
(* `let` or `var` (D13): whether it can change, its name, its type and first value. *)
| Declare (changeable : bool) (name : string) (name_at keyword_at : place) (written : type)
    (value : expression) (at_ : place)
(* `name = value;` (D14). *)
| Assign (name : string) (name_at : place) (value : expression) (operator_at at_ : place)
(* A call or a slide standing alone (D120). *)
| Run (action : expression) (at_ : place)
(* `if`, its `else if` parts and `else` (D16). *)
| If (condition : expression) (then_part : block) (rest : else_part) (at_ : place)
| While (condition : expression) (body : block) (at_ : place)
| Break (at_ : place)
| Return (value : option expression) (at_ : place)
| Labels (pairs : list label_pair) (at_ : place)
with block :=
| Empty
| Then (first : statement) (rest : block)
with else_part :=
| No_else
| Else (body : block) (at_ : place)
| Else_if (condition : expression) (body : block) (rest : else_part) (at_ : place).

(* A procedure's name: `proc.main` (D4), or a name of its own. *)
Inductive procedure_name := Main | Named (name : string).

Record parameter := {
  parameter_name : string;
  parameter_at : place;
  parameter_type : type }.

(* A procedure's definition (D4, D37, D38, D126). *)
Record definition := {
  definition_name : procedure_name;
  definition_name_at : place;
  definition_parameters : list parameter;
  definition_returns : option type;
  definition_body : block;
  definition_at : place }.

Definition program := list definition.

(* The induction principles Rocq makes by itself cover one type at a time; these cover the types that refer to each
   other. *)
Scheme expression_mutual := Induction for expression Sort Prop
  with arguments_mutual := Induction for arguments Sort Prop
  with steps_mutual := Induction for steps Sort Prop.
Combined Scheme expression_induction from expression_mutual, arguments_mutual, steps_mutual.

Scheme statement_mutual := Induction for statement Sort Prop
  with block_mutual := Induction for block Sort Prop
  with else_part_mutual := Induction for else_part Sort Prop.
Combined Scheme statement_induction from statement_mutual, block_mutual, else_part_mutual.
