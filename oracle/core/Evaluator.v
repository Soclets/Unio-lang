(* The evaluator: what a Unio program does when it runs.

   It runs the typed tree (TypedTree.v) the checker gives back, and gives back a tree of requests (Io.v) for the shell
   to carry out. Rocq only accepts functions that finish, so every step uses up one unit of fuel, a counter the shell
   sets far higher than any real program needs; a program still running when it's used up stops with [Out_of_fuel].

   Whenever the evaluator meets something it has no rule for, like adding a `Bool`, it stops with [Stuck]. The second
   type checker refuses every such program before it runs: that's the type-safety theorem in Safety.v. *)

From Stdlib Require Import String List Bool ZArith.
From Ralph Require Import Syntax Whole Io TypedTree Checker.
Import ListNotations.
Import Typed.
Open Scope list_scope.

Inductive value :=
| Whole_value (n : Z)
| Bool_value (b : bool)
| Text_value (t : string).

(* The variables in use and their values, innermost first. *)
Definition environment := list (string * value).

Definition lookup (name : string) (env : environment) : option value :=
  match find (fun entry => String.eqb (fst entry) name) env with
  | Some (_, v) => Some v
  | None => None
  end.

(* Gives a variable a new value (D14), where it was declared. *)
Fixpoint assign (name : string) (v : value) (env : environment) : option environment :=
  match env with
  | [] => None
  | (n, old) :: rest =>
      if String.eqb n name then Some ((n, v) :: rest)
      else match assign name v rest with
           | Some rest' => Some ((n, old) :: rest')
           | None => None
           end
  end.

(* The variables a block declared end with it (D93): keeps only as many as were in use before it. *)
Definition restore (before after : environment) : environment :=
  skipn (length after - length before) after.

(* How a statement or block finished: carrying on, leaving the innermost loop with `break` (D32), or leaving the
   procedure with `return` and maybe a value (D57). *)
Inductive flow :=
| Continue (env : environment)
| Leave_loop (env : environment)
| Leave_procedure (result : option value).

Definition restore_flow (before : environment) (f : flow) : flow :=
  match f with
  | Continue after => Continue (restore before after)
  | Leave_loop after => Leave_loop (restore before after)
  | Leave_procedure result => Leave_procedure result
  end.

(* What a call gives back: a value, nothing, or a failure (D23). *)
Inductive outcome := Gave (v : value) | Gave_nothing | Failed.

(* trace: D46, D92 *)
Definition checked_whole {A : Type} (at_ : place) (result : checked) (operation : arithmetic_operation)
    (make : Z -> A) : io A :=
  match result with
  | Fits n => Done (make n)
  | Too_big => Stop (Overflow at_ true operation)
  | Too_small => Stop (Overflow at_ false operation)
  end.

(* trace: D17, D190. A comparison of two values already worked out. *)
Definition compare_values (operator : binary_operator) (a b : value) : io value :=
  match operator, a, b with
  | Equal, Whole_value x, Whole_value y => Done (Bool_value (Z.eqb x y))
  | Equal, Bool_value x, Bool_value y => Done (Bool_value (Bool.eqb x y))
  | Not_equal, Whole_value x, Whole_value y => Done (Bool_value (negb (Z.eqb x y)))
  | Not_equal, Bool_value x, Bool_value y => Done (Bool_value (negb (Bool.eqb x y)))
  | Less, Whole_value x, Whole_value y => Done (Bool_value (Z.ltb x y))
  | Greater, Whole_value x, Whole_value y => Done (Bool_value (Z.gtb x y))
  | At_least, Whole_value x, Whole_value y => Done (Bool_value (Z.geb x y))
  | At_most, Whole_value x, Whole_value y => Done (Bool_value (Z.leb x y))
  | _, _, _ => Stop Stuck
  end.

(* trace: D22, D153, D202. A `Whole` or a `Bool` as text. *)
Definition text_of (v : value) : io value :=
  match v with
  | Whole_value n => Done (Text_value (text_of_whole n))
  | Bool_value b => Done (Text_value (if b then "true" else "false")%string)
  | Text_value _ => Stop Stuck
  end.

Fixpoint join_texts (values : list value) : io value :=
  match values with
  | [] => Done (Text_value ""%string)
  | Text_value t :: rest =>
      bind (join_texts rest) (fun joined =>
        match joined with
        | Text_value u => Done (Text_value (t ++ u)%string)
        | _ => Stop Stuck
        end)
  | _ => Stop Stuck
  end.

(* A procedure's parameters, given the arguments' values in order; the last parameter comes first, innermost. *)
Fixpoint bind_parameters (parameters : list (string * type)) (values : list value) : option environment :=
  match parameters, values with
  | [], [] => Some []
  | (name, _) :: ps, v :: vs =>
      match bind_parameters ps vs with
      | Some env => Some (env ++ [(name, v)])
      | None => None
      end
  | _, _ => None
  end.

(* The library's procedures (chapter 9 and D6, D20, D22, D26, D95, D96, D160). *)
Definition apply_library (which : library) (values : list value) (at_ : place) : io outcome :=
  match which, values with
  | Show_message same_line, [Text_value t] => Show t (negb same_line) (fun _ => Done Gave_nothing)
  | Convert_to_whole, [Text_value t] =>
      match whole_of_text t with
      | Some n => Done (Gave (Whole_value n))
      | None => Done Failed
      end
  | Ask_for_line, [Text_value question] =>
      Ask question (fun answer =>
        match answer with
        | Some line => Done (Gave (Text_value line))
        | None => Stop Input_ended
        end)
  | Random_number, [Whole_value low; Whole_value high] =>
      if (low <=? high)%Z then Random low high (fun n => Done (Gave (Whole_value n)))
      else Stop (Random_backwards at_ low high)
  | _, _ => Stop Stuck
  end.

(* What a procedure of the program's own gives back, from how its body finished (D37, D38, D57). *)
Definition procedure_result (d : procedure) (f : flow) : io outcome :=
  match f, procedure_gives d with
  | Leave_procedure (Some v), Some _ => Done (Gave v)
  | Leave_procedure None, None => Done Gave_nothing
  | Continue _, None => Done Gave_nothing
  | _, _ => Stop Stuck
  end.

(* Picks a way by a `Bool`. Each way is given as a function, so the way not taken is never worked out: OCaml, which
   the core is extracted to, works out a function's arguments before calling it, and working out both ways of an `if`
   whose other way calls the procedure it's in would never end. *)
Definition need_bool {A : Type} (v : value) (then_ else_ : unit -> io A) : io A :=
  match v with
  | Bool_value true => then_ tt
  | Bool_value false => else_ tt
  | _ => Stop Stuck
  end.

(* Where a call is: how many calls are waiting for one another, the most there may be, and the procedure it's in. *)
Record frame := { frame_depth : nat; frame_limit : nat; frame_procedure : string }.

Definition enter (where_ : frame) (procedure : string) : frame :=
  {| frame_depth := S (frame_depth where_); frame_limit := frame_limit where_; frame_procedure := procedure |}.

Fixpoint evaluate (fuel : nat) (where_ : frame) (p : list procedure) (env : environment) (e : expression)
    {struct fuel} : io value :=
  match fuel with
  | O => Stop Out_of_fuel
  | S fuel' =>
      match e with
      | Whole_literal n => Done (Whole_value n)
      | Bool_literal b => Done (Bool_value b)
      | Text_literal t => Done (Text_value t)
      | Read name =>
          match lookup name env with
          | Some v => Done v
          | None => Stop Stuck
          end
      | Negate operand at_ =>
          bind (evaluate fuel' where_ p env operand) (fun v =>
            match v with
            | Whole_value n => checked_whole at_ (whole_negate n) (Operation_negate n) Whole_value
            | _ => Stop Stuck
            end)
      | Logic_not operand =>
          bind (evaluate fuel' where_ p env operand) (fun v =>
            need_bool v (fun _ => Done (Bool_value false)) (fun _ => Done (Bool_value true)))
      | Maths operator left_operand right_operand at_ =>
          bind (evaluate fuel' where_ p env left_operand) (fun a =>
            bind (evaluate fuel' where_ p env right_operand) (fun b =>
              match a, b with
              | Whole_value x, Whole_value y =>
                  checked_whole at_ (whole_arithmetic operator x y) (Operation_binary x operator y) Whole_value
              | _, _ => Stop Stuck
              end))
      | Compare operator _ left_operand right_operand =>
          bind (evaluate fuel' where_ p env left_operand) (fun a =>
            bind (evaluate fuel' where_ p env right_operand) (fun b => compare_values operator a b))
      (* trace: D34. `and` and `or` stop early: the right_operand side runs only if it can still change the answer. *)
      | Logic_and left_operand right_operand =>
          bind (evaluate fuel' where_ p env left_operand) (fun a =>
            need_bool a
              (fun _ => bind (evaluate fuel' where_ p env right_operand) (fun b =>
                 need_bool b (fun _ => Done (Bool_value true)) (fun _ => Done (Bool_value false))))
              (fun _ => Done (Bool_value false)))
      | Logic_or left_operand right_operand =>
          bind (evaluate fuel' where_ p env left_operand) (fun a =>
            need_bool a
              (fun _ => Done (Bool_value true))
              (fun _ => bind (evaluate fuel' where_ p env right_operand) (fun b =>
                 need_bool b (fun _ => Done (Bool_value true)) (fun _ => Done (Bool_value false)))))
      (* trace: D29, D200 *)
      | Join parts => bind (evaluate_all fuel' where_ p env parts) join_texts
      | Text_of _ operand => bind (evaluate fuel' where_ p env operand) text_of
      | Value_of c =>
          bind (perform fuel' where_ p env c) (fun o =>
            match o with
            | Gave v => Done v
            | _ => Stop Stuck
            end)
      (* trace: D23. `??` carries on with the value after it when the call fails. *)
      | Fallback c fallback =>
          bind (perform fuel' where_ p env c) (fun o =>
            match o with
            | Gave v => Done v
            | Failed => evaluate fuel' where_ p env fallback
            | Gave_nothing => Stop Stuck
            end)
      end
  end

(* Works out each value, left_operand to right_operand. *)
with evaluate_all (fuel : nat) (where_ : frame) (p : list procedure) (env : environment) (es : list expression)
    {struct fuel} : io (list value) :=
  match fuel with
  | O => Stop Out_of_fuel
  | S fuel' =>
      match es with
      | [] => Done []
      | e :: rest =>
          bind (evaluate fuel' where_ p env e) (fun v =>
            bind (evaluate_all fuel' where_ p env rest) (fun vs => Done (v :: vs)))
      end
  end

(* Works out a call's arguments, then runs it. *)
with perform (fuel : nat) (where_ : frame) (p : list procedure) (env : environment) (c : call) {struct fuel}
  : io outcome :=
  match fuel with
  | O => Stop Out_of_fuel
  | S fuel' =>
      match c with
      | Library_call which given at_ =>
          bind (evaluate_all fuel' where_ p env given) (fun values => apply_library which values at_)
      | Procedure_call name given at_ =>
          bind (evaluate_all fuel' where_ p env given) (fun values =>
            match find_procedure p name with
            | Some d => apply fuel' where_ p d values at_
            | None => Stop Stuck
            end)
      end
  end

(* Runs one of the program's own procedures with [values] as its arguments, in order. *)
with apply (fuel : nat) (where_ : frame) (p : list procedure) (d : procedure) (values : list value) (at_ : place)
    {struct fuel} : io outcome :=
  match fuel with
  | O => Stop Out_of_fuel
  | S fuel' =>
      match bind_parameters (procedure_parameters d) values with
      | Some locals =>
          (* trace: D154, D158 *)
          let depth := S (frame_depth where_) in
          if Nat.leb (frame_limit where_) depth then Stop (Calls_too_deep at_ depth (frame_procedure where_))
          else
            bind (execute_block fuel' (enter where_ (procedure_name d)) p locals (procedure_body d))
              (procedure_result d)
      | None => Stop Stuck
      end
  end

with execute (fuel : nat) (where_ : frame) (p : list procedure) (env : environment) (s : statement) {struct fuel}
  : io flow :=
  match fuel with
  | O => Stop Out_of_fuel
  | S fuel' =>
      match s with
      (* trace: D13 *)
      | Declare name _ value =>
          bind (evaluate fuel' where_ p env value) (fun v => Done (Continue ((name, v) :: env)))
      (* trace: D14 *)
      | Assign name value =>
          bind (evaluate fuel' where_ p env value) (fun v =>
            match assign name v env with
            | Some env' => Done (Continue env')
            | None => Stop Stuck
            end)
      (* trace: D120. A call standing alone gives nothing. *)
      | Run c =>
          bind (perform fuel' where_ p env c) (fun o =>
            match o with
            | Gave_nothing => Done (Continue env)
            | _ => Stop Stuck
            end)
      (* trace: D16 *)
      | If condition then_part else_part =>
          bind (evaluate fuel' where_ p env condition) (fun c =>
            need_bool c (fun _ => execute_block fuel' where_ p env then_part)
              (fun _ => execute_block fuel' where_ p env else_part))
      (* trace: D19, D32 *)
      | While condition body =>
          bind (evaluate fuel' where_ p env condition) (fun c =>
            need_bool c
              (fun _ => bind (execute_block fuel' where_ p env body) (fun f =>
                 match f with
                 | Continue env' => execute fuel' where_ p env' (While condition body)
                 | Leave_loop env' => Done (Continue env')
                 | Leave_procedure result => Done (Leave_procedure result)
                 end))
              (fun _ => Done (Continue env)))
      | Break => Done (Leave_loop env)
      (* trace: D57 *)
      | Return None => Done (Leave_procedure None)
      | Return (Some value) => bind (evaluate fuel' where_ p env value) (fun v => Done (Leave_procedure (Some v)))
      end
  end

(* Runs a block's statements in turn, until one leaves. *)
with execute_statements (fuel : nat) (where_ : frame) (p : list procedure) (env : environment) (b : block)
    {struct fuel} : io flow :=
  match fuel with
  | O => Stop Out_of_fuel
  | S fuel' =>
      match b with
      | Empty => Done (Continue env)
      | Then s rest =>
          bind (execute fuel' where_ p env s) (fun f =>
            match f with
            | Continue env' => execute_statements fuel' where_ p env' rest
            | other => Done other
            end)
      end
  end

(* A block: its statements, then its own variables end (D93). *)
with execute_block (fuel : nat) (where_ : frame) (p : list procedure) (env : environment) (b : block) {struct fuel}
  : io flow :=
  match fuel with
  | O => Stop Out_of_fuel
  | S fuel' => bind (execute_statements fuel' where_ p env b) (fun f => Done (restore_flow env f))
  end.

(* Runs a typed tree from `proc.main` (D4), with [fuel] steps at most, and at most [limit] calls waiting for one
   another (D154, D158). *)
Definition run_typed (fuel limit : nat) (p : program) : io unit :=
  let start := {| frame_depth := 0; frame_limit := limit; frame_procedure := "proc.main"%string |} in
  bind (execute_block fuel start (program_procedures p) [] (program_main p)) (fun f =>
    match f with
    | Continue _ | Leave_procedure None => Done tt
    | _ => Stop Stuck
    end).

(* THE EVALUATOR: runs a program, as the checker's typed tree of it. *)
Definition run (fuel limit : nat) (p : Syntax.program) : io unit := run_typed fuel limit (typed_program p).
