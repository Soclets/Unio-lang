(* The typed tree: a program as the checker hands it to the evaluator (standard chapter 10's "typed tree").

   The checker (Checker.v) reads the syntax tree, refuses what Unio refuses, and gives back this smaller tree, with
   everything a message needed taken away and everything running needs made plain: every name is resolved, every type
   is known, slides are calls, labels are gone, and text's braces are joins. The evaluator (Evaluator.v) runs it.

   [program_ok] below is a second type checker, for this tree alone. It's small on purpose: the checker that words
   Unio's refusals is large and grows with every message, while this one only says whether each part of the tree has
   the type the evaluator needs. Ralph runs a program only when both agree (Checker.v, [check_program]), and the
   type-safety theorem (Safety.v) is proven about this one, so it stays the size of the language rather than the size
   of its messages. *)

From Stdlib Require Import String List Bool ZArith.
From Ralph Require Import Syntax Whole.
Import ListNotations.
Open Scope list_scope.
Set Warnings "-register-all".

(* The procedures every program has, written into Unio rather than in it (chapter 9, D196). `be.Text` isn't here:
   it can't fail and does nothing outside the program, so the typed tree writes it as [Text_of]. *)
Inductive library :=
(* trace: D6 *)
| Show_message (same_line : bool)
(* trace: D20 *)
| Ask_for_line
(* trace: D26 *)
| Random_number
(* trace: D22, D95, D156 *)
| Convert_to_whole.

(* What a library procedure takes, what it gives back, and whether it can fail (D23). *)
Definition library_signature (which : library) : list type * option type * bool :=
  match which with
  | Show_message _ => ([Text], None, false)
  | Ask_for_line => ([Text], Some Text, false)
  | Random_number => ([Whole; Whole], Some Whole, false)
  | Convert_to_whole => ([Text], Some Whole, true)
  end.

Module Typed.

Inductive expression :=
| Whole_literal (n : Z)
| Bool_literal (b : bool)
| Text_literal (t : string)
| Read (name : string)
(* `-` in front of a `Whole` (D27), with its place for the overflow check (D46). *)
| Negate (operand : expression) (at_ : place)
| Logic_not (operand : expression)
| Maths (operator : arithmetic) (left_operand right_operand : expression) (at_ : place)
(* A comparison between two values of the type [compared] (D17, D190). *)
| Compare (operator : binary_operator) (compared : type) (left_operand right_operand : expression)
(* `and` and `or`, which stop early (D34). *)
| Logic_and (left_operand right_operand : expression)
| Logic_or (left_operand right_operand : expression)
(* Text filled in from its pieces, each a `Text` (D29, D200). *)
| Join (parts : list expression)
(* A `Whole` or a `Bool` as text, as `be.Text` and braces give it (D22, D153, D202). *)
| Text_of (from : type) (operand : expression)
(* A call that gives back a value and can't fail. *)
| Value_of (c : call)
(* `call ?? fallback` (D23). *)
| Fallback (c : call) (fallback : expression)
with call :=
| Library_call (which : library) (given : list expression) (at_ : place)
| Procedure_call (name : string) (given : list expression) (at_ : place).

Inductive statement :=
| Declare (name : string) (written : type) (value : expression)
| Assign (name : string) (value : expression)
(* A call that gives nothing back, standing alone (D120). *)
| Run (c : call)
| If (condition : expression) (then_part else_part : block)
| While (condition : expression) (body : block)
| Break
| Return (value : option expression)
with block :=
| Empty
| Then (first : statement) (rest : block).

Record procedure := {
  procedure_name : string;
  procedure_parameters : list (string * type);
  procedure_gives : option type;
  procedure_body : block }.

Record program := { program_procedures : list procedure; program_main : block }.

Definition find_procedure (procedures : list procedure) (name : string) : option procedure :=
  find (fun d => String.eqb (procedure_name d) name) procedures.

(* ---------------------------------------------------------------------------------------------------------------- *)
(* The second type checker *)

(* The variables in use and their types, innermost first. *)
Definition context := list (string * type).

Definition find_type (name : string) (ctx : context) : option type :=
  match find (fun entry => String.eqb (fst entry) name) ctx with
  | Some (_, t) => Some t
  | None => None
  end.

Definition is_type (found : option type) (expected : type) : bool :=
  match found with
  | Some t => type_eqb t expected
  | None => false
  end.

Definition comparable (operator : binary_operator) (t : type) : bool :=
  match operator, t with
  | (Equal | Not_equal), (Whole | Bool) => true
  | (Less | Greater | At_least | At_most), Whole => true
  | _, _ => false
  end.

Definition shown (t : type) : bool := match t with Whole | Bool => true | Text => false end.

Definition procedure_signature (d : procedure) : list type * option type * bool :=
  (map snd (procedure_parameters d), procedure_gives d, false).

Definition call_signature (procedures : list procedure) (c : call) : option (list type * option type * bool) :=
  match c with
  | Library_call which _ _ => Some (library_signature which)
  | Procedure_call name _ _ => option_map procedure_signature (find_procedure procedures name)
  end.

Definition call_given (c : call) : list expression :=
  match c with Library_call _ given _ | Procedure_call _ given _ => given end.

(* Whether [f] holds for each pair of items, the two lists being as long as each other. *)
Fixpoint pairwise {A B : Type} (f : A -> B -> bool) (xs : list A) (ys : list B) : bool :=
  match xs, ys with
  | [], [] => true
  | x :: xs', y :: ys' => f x y && pairwise f xs' ys'
  | _, _ => false
  end.

Fixpoint type_of (procedures : list procedure) (ctx : context) (e : expression) {struct e} : option type :=
  match e with
  | Whole_literal _ => Some Whole
  | Bool_literal _ => Some Bool
  | Text_literal _ => Some Text
  | Read name => find_type name ctx
  | Negate operand _ => if is_type (type_of procedures ctx operand) Whole then Some Whole else None
  | Logic_not operand => if is_type (type_of procedures ctx operand) Bool then Some Bool else None
  | Maths _ left_operand right_operand _ =>
      if is_type (type_of procedures ctx left_operand) Whole && is_type (type_of procedures ctx right_operand) Whole
      then Some Whole else None
  | Compare operator compared left_operand right_operand =>
      if comparable operator compared && is_type (type_of procedures ctx left_operand) compared
         && is_type (type_of procedures ctx right_operand) compared
      then Some Bool else None
  | Logic_and left_operand right_operand | Logic_or left_operand right_operand =>
      if is_type (type_of procedures ctx left_operand) Bool && is_type (type_of procedures ctx right_operand) Bool
      then Some Bool else None
  | Join parts =>
      if forallb (fun part => is_type (type_of procedures ctx part) Text) parts then Some Text else None
  | Text_of from operand =>
      if shown from && is_type (type_of procedures ctx operand) from then Some Text else None
  | Value_of c =>
      match call_type procedures ctx c with
      | Some (Some t, false) => Some t
      | _ => None
      end
  | Fallback c fallback =>
      match call_type procedures ctx c with
      | Some (Some t, true) => if is_type (type_of procedures ctx fallback) t then Some t else None
      | _ => None
      end
  end

(* What a call gives back, and whether it can fail, when its arguments have the types its procedure takes. *)
with call_type (procedures : list procedure) (ctx : context) (c : call) {struct c} : option (option type * bool) :=
  match call_signature procedures c with
  | Some (takes, gives, can_fail) =>
      if pairwise (fun e t => is_type (type_of procedures ctx e) t) (call_given c) takes
      then Some (gives, can_fail) else None
  | None => None
  end.

(* Whether every way through a block ends in `return` with a value (D57); a `while` never counts (D149). *)
Fixpoint always_returns (s : statement) : bool :=
  match s with
  | Return (Some _) => true
  | If _ then_part else_part => always_returns_block then_part && always_returns_block else_part
  | _ => false
  end
with always_returns_block (b : block) : bool :=
  match b with
  | Empty => false
  | Then s rest => always_returns s || always_returns_block rest
  end.

(* A statement's check: in [ctx], inside a loop or not, in a procedure giving back [gives]; gives the variables in
   use after it. *)
Fixpoint statement_ok (procedures : list procedure) (ctx : context) (in_loop : bool) (gives : option type)
    (s : statement) {struct s} : option context :=
  match s with
  | Declare name written value =>
      if is_type (type_of procedures ctx value) written then Some ((name, written) :: ctx) else None
  | Assign name value =>
      match find_type name ctx with
      | Some t => if is_type (type_of procedures ctx value) t then Some ctx else None
      | None => None
      end
  | Run c =>
      match call_type procedures ctx c with
      | Some (None, false) => Some ctx
      | _ => None
      end
  | If condition then_part else_part =>
      if is_type (type_of procedures ctx condition) Bool && block_ok procedures ctx in_loop gives then_part
         && block_ok procedures ctx in_loop gives else_part
      then Some ctx else None
  | While condition body =>
      if is_type (type_of procedures ctx condition) Bool && block_ok procedures ctx true gives body
      then Some ctx else None
  | Break => if in_loop then Some ctx else None
  | Return None => match gives with None => Some ctx | Some _ => None end
  | Return (Some value) =>
      match gives with
      | Some t => if is_type (type_of procedures ctx value) t then Some ctx else None
      | None => None
      end
  end
with block_ok (procedures : list procedure) (ctx : context) (in_loop : bool) (gives : option type) (b : block)
    {struct b} : bool :=
  match b with
  | Empty => true
  | Then s rest =>
      match statement_ok procedures ctx in_loop gives s with
      | Some ctx' => block_ok procedures ctx' in_loop gives rest
      | None => false
      end
  end.

Definition procedure_ok (procedures : list procedure) (d : procedure) : bool :=
  block_ok procedures (rev (procedure_parameters d)) false (procedure_gives d) (procedure_body d)
  && match procedure_gives d with
     | Some _ => always_returns_block (procedure_body d)
     | None => true
     end.

(* THE SECOND TYPE CHECKER: every procedure, and `proc.main`'s body, have the types the evaluator needs. *)
Definition program_ok (p : program) : bool :=
  forallb (procedure_ok (program_procedures p)) (program_procedures p)
  && block_ok (program_procedures p) [] false None (program_main p).

End Typed.
