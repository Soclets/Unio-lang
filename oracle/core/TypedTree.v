(* The typed tree: a program as the checker hands it to the evaluator (standard chapter 10's "typed tree").

   The checker (Checker.v) reads the syntax tree, refuses what Unio refuses, and gives back this smaller tree, with
   everything a message needed taken away and everything running needs made plain: every name is resolved, every type
   is known, slides are calls, labels are gone, text's braces are joins, and a method that changes a list is a new
   value for its variable.

   [program_ok] below is a second type checker, for this tree alone. It's small on purpose: the checker that words
   Unio's refusals is large and grows with every message, while this one only says whether each part of the tree has
   the type the evaluator needs. Ralph runs a program only when both agree (Checker.v, [check_program]), and the
   type-safety theorem (Safety.v) is proven about this one, so it stays the size of the language rather than the size
   of its messages. *)

From Stdlib Require Import String List Bool ZArith.
From Ralph Require Import Whole Syntax.
Import ListNotations.
Open Scope list_scope.
Set Warnings "-register-all".

(* The procedures every program has, written into Unio rather than in it (chapter 9, D196), and the list methods
   (D80). `be.Text` isn't here: it can't fail and does nothing outside the program, so the typed tree writes it as
   [Text_of]. Each list method gives back the changed list, which the typed tree puts back in its variable. *)
Inductive library :=
(* trace: D6 *)
| Show_message (same_line : bool)
(* trace: D20 *)
| Ask_for_line
(* trace: D26 *)
| Random_number
(* trace: D22, D95, D156 *)
| Convert_to_whole
(* trace: D80, D168: `.add(item)` on a list *)
| Add_item (container : type)
(* trace: D80, D168: `.add(item, pos: n)` or `offset: n` on a list *)
| Insert_item (container : type) (from_one : bool)
(* trace: D80: `.remove(pos: n)` or `offset: n` on a list *)
| Remove_item (container : type) (from_one : bool)
(* trace: D80, D167: `list[pos: n] = value` on a list or an array *)
| Replace_item (container : type) (from_one : bool).

(* A list with a most it may hold can fail to grow with `full` (D168). *)
Definition full_if (most : option Z) : list string :=
  match most with Some _ => ["full"%string] | None => [] end.

(* What a library procedure takes, what it gives back, and the failures it can give (D23). *)
Definition library_signature (which : library) : option (list type * option type * list string) :=
  match which with
  | Show_message _ => Some ([Text], None, [])
  | Ask_for_line => Some ([Text], Some Text, [])
  | Random_number => Some ([Whole; Whole], Some Whole, [])
  | Convert_to_whole => Some ([Text], Some Whole, ["not_a_whole"%string])
  | Add_item (List_of item most as t) => Some ([t; item], Some t, full_if most)
  | Insert_item (List_of item most as t) _ => Some ([t; item; Whole], Some t, full_if most)
  | Remove_item (List_of _ _ as t) _ => Some ([t; Whole], Some t, [])
  | Replace_item t _ =>
      match item_of t with
      | Some item => Some ([t; Whole; item], Some t, [])
      | None => None
      end
  | _ => None
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
(* trace: D70, D71, D72 *)
| Divide (way : division) (left_operand right_operand : expression) (at_ : place)
(* A comparison between two values of the type [compared] (D17, D190). *)
| Compare (operator : binary_operator) (compared : type) (left_operand right_operand : expression)
(* `and` and `or`, which stop early (D34). *)
| Logic_and (left_operand right_operand : expression)
| Logic_or (left_operand right_operand : expression)
(* Text filled in from its pieces, each a `Text` (D29, D200). *)
| Join (parts : list expression)
(* A `Whole` or a `Bool` as text, as `be.Text` and braces give it (D22, D153, D202). *)
| Text_of (from : type) (operand : expression)
(* A list or an array written out, of the type [container] (D75, D76, D167). *)
| List_literal (container : type) (items : list expression)
(* `[all: value]`: an array whose every item is [value] (D169). *)
| All_literal (container : type) (value : expression)
(* An item, counting from 1 or from 0 (D75), with its place for the position check (D46). *)
| Item (from_one : bool) (container index : expression) (at_ : place)
(* `.len` (D79) *)
| Length (container : expression)
(* A call that gives back a value and can't fail. *)
| Value_of (c : call)
(* `call ?? fallback` (D23). *)
| Fallback (c : call) (fallback : expression)
with call :=
| Library_call (which : library) (given : list expression) (at_ : place)
| Procedure_call (name : string) (given : list expression) (at_ : place)
(* `call ?? crash`: a failure stops the program (D152); [name] is the procedure's name for the message. *)
| Crashing (c : call) (name : string) (at_ : place)
(* `call?`: a failure leaves this procedure, which lists it (D23). *)
| Passing (c : call).

(* Where a handled call's value goes. *)
Inductive destination :=
| Into_new (name : string) (written : type)
| Into (name : string)
| Nowhere.

Inductive statement :=
| Declare (name : string) (written : type) (value : expression)
| Assign (name : string) (value : expression)
(* A call that gives nothing back, standing alone (D120). *)
| Run (c : call)
| If (condition : expression) (then_part else_part : block)
| While (condition : expression) (body : block)
(* `for each` through a list or an array (D171), its position counted from 1 or 0 if it's named (D174). *)
| For_each (item : string) (position : option string) (from_one : bool) (source : expression) (body : block)
(* `for each` through `range[…]` (D170, D172): its first number, its end, whether that's included (`to:`), and its
   step, with its place for the check that it can reach its end. *)
| For_range (item : string) (position : option string) (from_one : bool) (first last : expression)
    (included : bool) (step : expression) (at_ : place) (body : block)
| Break
| Return (value : option expression)
(* A call whose failures are handled (D40, D186), its value going to [where_]; with [ignore], a failure with no case
   is ignored (`?? ignore`, D121). *)
| Handle (where_ : destination) (c : call) (handlers : cases) (ignore : bool)
(* `instead value;` in a case (D40). *)
| Instead (value : expression)
with cases :=
| No_cases
| Case (failure : string) (body : block) (rest : cases)
with block :=
| Empty
| Then (first : statement) (rest : block).

Record procedure := {
  procedure_name : string;
  procedure_parameters : list (string * type);
  procedure_gives : option type;
  procedure_failures : list string;
  procedure_body : block }.

Record program := { program_procedures : list procedure; program_main : block }.

Definition find_procedure (procedures : list procedure) (name : string) : option procedure :=
  find (fun d => String.eqb (procedure_name d) name) procedures.

Fixpoint find_case (failure : string) (handlers : cases) : option block :=
  match handlers with
  | No_cases => None
  | Case f body rest => if String.eqb f failure then Some body else find_case failure rest
  end.

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

Definition shown (t : type) : bool := match t with Whole | Bool => true | _ => false end.

Definition within (failures up : list string) : bool :=
  forallb (fun f => existsb (String.eqb f) up) failures.

(* Whether [f] holds for each pair of items, the two lists being as long as each other. *)
Fixpoint pairwise {A B : Type} (f : A -> B -> bool) (xs : list A) (ys : list B) : bool :=
  match xs, ys with
  | [], [] => true
  | x :: xs', y :: ys' => f x y && pairwise f xs' ys'
  | _, _ => false
  end.

(* An expression's type, in a procedure whose `?` may pass up the failures [up], where [ctx] says the variables. *)
Fixpoint type_of (procedures : list procedure) (up : list string) (ctx : context) (e : expression) {struct e}
  : option type :=
  match e with
  | Whole_literal _ => Some Whole
  | Bool_literal _ => Some Bool
  | Text_literal _ => Some Text
  | Read name => find_type name ctx
  | Negate operand _ => if is_type (type_of procedures up ctx operand) Whole then Some Whole else None
  | Logic_not operand => if is_type (type_of procedures up ctx operand) Bool then Some Bool else None
  | Maths _ l r _ | Divide _ l r _ =>
      if is_type (type_of procedures up ctx l) Whole && is_type (type_of procedures up ctx r) Whole
      then Some Whole else None
  | Compare operator compared l r =>
      if comparable operator compared && is_type (type_of procedures up ctx l) compared
         && is_type (type_of procedures up ctx r) compared
      then Some Bool else None
  | Logic_and l r | Logic_or l r =>
      if is_type (type_of procedures up ctx l) Bool && is_type (type_of procedures up ctx r) Bool
      then Some Bool else None
  | Join parts =>
      if forallb (fun part => is_type (type_of procedures up ctx part) Text) parts then Some Text else None
  | Text_of from operand =>
      if shown from && is_type (type_of procedures up ctx operand) from then Some Text else None
  | List_literal container items =>
      match item_of container with
      | Some item =>
          if forallb (fun i => is_type (type_of procedures up ctx i) item) items then Some container else None
      | None => None
      end
  | All_literal container value =>
      match container with
      | Array_of item _ => if is_type (type_of procedures up ctx value) item then Some container else None
      | _ => None
      end
  | Item _ container index _ =>
      match type_of procedures up ctx container with
      | Some t => if is_type (type_of procedures up ctx index) Whole then item_of t else None
      | None => None
      end
  | Length container =>
      match type_of procedures up ctx container with
      | Some t => match item_of t with Some _ => Some Whole | None => None end
      | None => None
      end
  | Value_of c =>
      match call_type procedures up ctx c with
      | Some (Some t, []) => Some t
      | _ => None
      end
  | Fallback c fallback =>
      match call_type procedures up ctx c with
      | Some (Some t, _) => if is_type (type_of procedures up ctx fallback) t then Some t else None
      | _ => None
      end
  end

(* What a call gives back, and the failures it can give, when its arguments have the types its procedure takes. *)
with call_type (procedures : list procedure) (up : list string) (ctx : context) (c : call) {struct c}
  : option (option type * list string) :=
  match c with
  | Library_call which given _ =>
      match library_signature which with
      | Some (takes, gives, failures) =>
          if pairwise (fun e t => is_type (type_of procedures up ctx e) t) given takes then Some (gives, failures)
          else None
      | None => None
      end
  | Procedure_call name given _ =>
      match find_procedure procedures name with
      | Some d =>
          if pairwise (fun e t => is_type (type_of procedures up ctx e) t) given (map snd (procedure_parameters d))
          then Some (procedure_gives d, procedure_failures d) else None
      | None => None
      end
  | Crashing inner _ _ =>
      match call_type procedures up ctx inner with
      | Some (gives, _) => Some (gives, [])
      | None => None
      end
  | Passing inner =>
      match call_type procedures up ctx inner with
      | Some (gives, failures) => if within failures up then Some (gives, []) else None
      | None => None
      end
  end.

(* What surrounds a statement: whether it's inside a loop, what its procedure gives back, the failures its procedure
   lists, and the type an `instead` gives, inside a case. *)
Record around := {
  inside_loop : bool;
  gives_back : option type;
  passes_up : list string;
  instead_type : option type }.

Definition in_a_loop (a : around) : around :=
  {| inside_loop := true; gives_back := gives_back a; passes_up := passes_up a; instead_type := instead_type a |}.

Definition in_a_case (a : around) (t : option type) : around :=
  {| inside_loop := inside_loop a; gives_back := gives_back a; passes_up := passes_up a; instead_type := t |}.

(* Whether a statement or block never carries on to the next line: it always leaves by `return`, `break` or
   `instead` (D40, D57); a loop never counts (D149). *)
Fixpoint always_leaves (s : statement) : bool :=
  match s with
  | Return _ | Break | Instead _ => true
  | If _ then_part else_part => always_leaves_block then_part && always_leaves_block else_part
  | _ => false
  end
with always_leaves_block (b : block) : bool :=
  match b with
  | Empty => false
  | Then s rest => always_leaves s || always_leaves_block rest
  end.

Fixpoint covered (failures : list string) (handlers : cases) : bool :=
  match failures with
  | [] => true
  | f :: rest => match find_case f handlers with Some _ => true | None => false end && covered rest handlers
  end.

(* The variables a `for each` makes for each pass: the item, then its position, if it's named (D171, D174). *)
Definition loop_context (item : string) (item_type : type) (position : option string) (ctx : context) : context :=
  (item, item_type) :: match position with Some i => [(i, Whole)] | None => [] end ++ ctx.

(* A statement's check; gives the variables in use after it. *)
Fixpoint statement_ok (procedures : list procedure) (a : around) (ctx : context) (s : statement) {struct s}
  : option context :=
  let up := passes_up a in
  match s with
  | Declare name written value =>
      if is_type (type_of procedures up ctx value) written then Some ((name, written) :: ctx) else None
  | Assign name value =>
      match find_type name ctx with
      | Some t => if is_type (type_of procedures up ctx value) t then Some ctx else None
      | None => None
      end
  | Run c =>
      match call_type procedures up ctx c with
      | Some (None, []) => Some ctx
      | _ => None
      end
  | If condition then_part else_part =>
      if is_type (type_of procedures up ctx condition) Bool && block_ok procedures a ctx then_part
         && block_ok procedures a ctx else_part
      then Some ctx else None
  | While condition body =>
      if is_type (type_of procedures up ctx condition) Bool && block_ok procedures (in_a_loop a) ctx body
      then Some ctx else None
  | For_each item position _ source body =>
      match type_of procedures up ctx source with
      | Some t =>
          match item_of t with
          | Some item_type =>
              if block_ok procedures (in_a_loop a) (loop_context item item_type position ctx) body then Some ctx
              else None
          | None => None
          end
      | None => None
      end
  | For_range item position _ first last _ step _ body =>
      if is_type (type_of procedures up ctx first) Whole && is_type (type_of procedures up ctx last) Whole
         && is_type (type_of procedures up ctx step) Whole
         && block_ok procedures (in_a_loop a) (loop_context item Whole position ctx) body
      then Some ctx else None
  | Break => if inside_loop a then Some ctx else None
  | Return None => match gives_back a with None => Some ctx | Some _ => None end
  | Return (Some value) =>
      match gives_back a with
      | Some t => if is_type (type_of procedures up ctx value) t then Some ctx else None
      | None => None
      end
  | Handle where_ c handlers ignore =>
      match call_type procedures up ctx c with
      | Some (gives, failures) =>
          if (ignore || covered failures handlers) then
            match where_, gives with
            | Into_new name written, Some t =>
                if type_eqb t written && negb ignore && cases_ok procedures (in_a_case a gives) ctx true handlers
                then Some ((name, written) :: ctx) else None
            | Into name, Some t =>
                if is_type (find_type name ctx) t && cases_ok procedures (in_a_case a gives) ctx false handlers
                then Some ctx else None
            | Nowhere, None => if cases_ok procedures (in_a_case a None) ctx false handlers then Some ctx else None
            | _, _ => None
            end
          else None
      | None => None
      end
  | Instead value =>
      match instead_type a with
      | Some t => if is_type (type_of procedures up ctx value) t then Some ctx else None
      | None => None
      end
  end
(* Each case's body; with [must_leave], none may carry on to after the block (D40). *)
with cases_ok (procedures : list procedure) (a : around) (ctx : context) (must_leave : bool) (handlers : cases)
    {struct handlers} : bool :=
  match handlers with
  | No_cases => true
  | Case _ body rest =>
      block_ok procedures a ctx body && (negb must_leave || always_leaves_block body)
      && cases_ok procedures a ctx must_leave rest
  end
with block_ok (procedures : list procedure) (a : around) (ctx : context) (b : block) {struct b} : bool :=
  match b with
  | Empty => true
  | Then s rest =>
      match statement_ok procedures a ctx s with
      | Some ctx' => block_ok procedures a ctx' rest
      | None => false
      end
  end.

Definition procedure_around (d : procedure) : around :=
  {| inside_loop := false; gives_back := procedure_gives d; passes_up := procedure_failures d;
     instead_type := None |}.

Definition main_around : around :=
  {| inside_loop := false; gives_back := None; passes_up := []; instead_type := None |}.

Definition procedure_ok (procedures : list procedure) (d : procedure) : bool :=
  block_ok procedures (procedure_around d) (rev (procedure_parameters d)) (procedure_body d)
  && match procedure_gives d with
     | Some _ => always_leaves_block (procedure_body d)
     | None => true
     end.

(* THE SECOND TYPE CHECKER: every procedure, and `proc.main`'s body, have the types the evaluator needs. *)
Definition program_ok (p : program) : bool :=
  forallb (procedure_ok (program_procedures p)) (program_procedures p)
  && block_ok (program_procedures p) main_around [] (program_main p).

End Typed.
