(* The evaluator: what a Unio program does when it runs.

   It runs the typed tree (TypedTree.v) the checker gives back, and gives back a tree of requests (Io.v) for the shell
   to carry out. Rocq only accepts functions that finish, so every step uses up one unit of fuel, a counter the shell
   sets far higher than any real program needs; a program still running when it's used up stops with [Out_of_fuel].

   Whenever the evaluator meets something it has no rule for, like adding a `Bool`, it stops with [Stuck]. The second
   type checker refuses every such program before it runs: that's the type-safety theorem in Safety.v. *)

From Stdlib Require Import String List Bool ZArith.
From Flocq Require Import IEEE754.BinarySingleNaN.
From Ralph Require Import Syntax Whole Float Io TypedTree Checker.
Import ListNotations.
Import Typed.
Open Scope list_scope.
Set Warnings "-register-all".

Inductive value :=
| Whole_value (n : Z)
| Bool_value (b : bool)
| Text_value (t : string)
(* trace: D157 *)
| Float_value (f : float)
(* A list's or an array's items, in order (D75, D167). *)
| List_value (items : list value).

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

(* How a statement or block finished: carrying on, leaving the innermost loop with `break` (D32), leaving the
   procedure with `return` and maybe a value (D57), or leaving a case with `instead` and a value (D40). *)
Inductive flow :=
| Continue (env : environment)
| Leave_loop (env : environment)
| Leave_procedure (result : option value)
| Leave_case (env : environment) (result : value).

Definition restore_flow (before : environment) (f : flow) : flow :=
  match f with
  | Continue after => Continue (restore before after)
  | Leave_loop after => Leave_loop (restore before after)
  | Leave_procedure result => Leave_procedure result
  | Leave_case after result => Leave_case (restore before after) result
  end.

(* What a call gives back: a value, nothing, or a failure, by its name (D23, D39). *)
Inductive outcome := Gave (v : value) | Gave_nothing | Failed (failure : string).

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
  (* trace: D183, D184. Exact, as IEEE 754 compares; the two zeros are equal. *)
  | _, Float_value x, Float_value y =>
      match Bcompare x y, operator with
      | Some c, Equal => Done (Bool_value (match c with Eq => true | _ => false end))
      | Some c, Not_equal => Done (Bool_value (match c with Eq => false | _ => true end))
      | Some c, Less => Done (Bool_value (match c with Lt => true | _ => false end))
      | Some c, Greater => Done (Bool_value (match c with Gt => true | _ => false end))
      | Some c, At_least => Done (Bool_value (match c with Lt => false | _ => true end))
      | Some c, At_most => Done (Bool_value (match c with Gt => false | _ => true end))
      | _, _ => Stop Stuck
      end
  | _, _, _ => Stop Stuck
  end.

(* trace: D22, D153, D155, D202. A `Whole`, a `Bool` or a `Float` as text. *)
Definition text_of (v : value) (at_ : place) : io value :=
  match v with
  | Whole_value n => Done (Text_value (text_of_whole n))
  | Bool_value b => Done (Text_value (if b then "true" else "false")%string)
  | Float_value f =>
      match text_of_float f with
      | Some t => Done (Text_value t)
      | None => Stop (Undecided at_ "where `~` goes on a negative number that isn't exact"%string)
      end
  | _ => Stop Stuck
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

(* trace: D70, D71, D72 *)
Definition divide_values (way : division) (a b : value) (at_ : place) : io value :=
  match a, b with
  | Whole_value x, Whole_value y =>
      match whole_divide way x y with
      | Divided n => Done (Whole_value n)
      | other => Stop (Division_stopped at_ other way x y)
      end
  | _, _ => Stop Stuck
  end.

(* trace: D46, D75. Where a position written [index], counting from 1 or 0, falls in a list of [length] items,
   counted from 0, if it's in the list. *)
Definition offset_of (from_one : bool) (index length : Z) : option nat :=
  let offset := if from_one then (index - 1)%Z else index in
  if (0 <=? offset)%Z && (offset <? length)%Z then Some (Z.to_nat offset) else None.

Definition item_at {A : Type} (from_one : bool) (items : list value) (index : Z) (at_ : place) (k : nat -> io A)
  : io A :=
  let length := Z.of_nat (List.length items) in
  match offset_of from_one index length with
  | Some n => k n
  | None => Stop (Bad_position at_ index from_one length)
  end.

(* trace: D80. Where `.add(item, pos: n)` may put an item: anywhere from the first place to just after the last. *)
Definition insert_offset (from_one : bool) (index length : Z) : option nat :=
  let offset := if from_one then (index - 1)%Z else index in
  if (0 <=? offset)%Z && (offset <=? length)%Z then Some (Z.to_nat offset) else None.

Fixpoint replace_nth (n : nat) (v : value) (items : list value) : list value :=
  match n, items with
  | O, _ :: rest => v :: rest
  | S n', x :: rest => x :: replace_nth n' v rest
  | _, [] => []
  end.

Fixpoint remove_nth (n : nat) (items : list value) : list value :=
  match n, items with
  | O, _ :: rest => rest
  | S n', x :: rest => x :: remove_nth n' rest
  | _, [] => []
  end.

(* trace: D168. Whether a list may grow by one. *)
Definition has_room (container : type) (items : list value) : bool :=
  match container with
  | List_of _ (Some most) => (Z.of_nat (List.length items) <? most)%Z
  | _ => true
  end.

(* trace: D46, D177, D179, D185 *)
Definition checked_float (at_ : place) (result : float_checked) (operation : option float_operation) (x y : float)
  : io value :=
  match result with
  | Float_fits z => Done (Float_value z)
  | other => Stop (Float_stopped at_ other operation x y)
  end.

(* The library's procedures and list methods (chapter 9 and D6, D20, D22, D26, D80, D95, D96, D160, D168). *)
Definition apply_library (which : library) (values : list value) (at_ : place) : io outcome :=
  match which, values with
  | Show_message same_line, [Text_value t] => Show t (negb same_line) (fun _ => Done Gave_nothing)
  | Convert_to_whole, [Text_value t] =>
      match whole_of_text t with
      | Some n => Done (Gave (Whole_value n))
      | None => Done (Failed "not_a_whole"%string)
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
  (* trace: D185 *)
  | Square_root, [Float_value x] =>
      bind (checked_float at_ (float_sqrt x) None x x) (fun v => Done (Gave v))
  | Add_item container, [List_value items; item] =>
      if has_room container items then Done (Gave (List_value (items ++ [item]))) else Done (Failed "full"%string)
  | Insert_item container from_one, [List_value items; item; Whole_value index] =>
      match insert_offset from_one index (Z.of_nat (List.length items)) with
      | Some n =>
          if has_room container items then Done (Gave (List_value (firstn n items ++ item :: skipn n items)))
          else Done (Failed "full"%string)
      | None => Stop (Bad_position at_ index from_one (Z.of_nat (List.length items)))
      end
  | Remove_item _ from_one, [List_value items; Whole_value index] =>
      item_at from_one items index at_ (fun n => Done (Gave (List_value (remove_nth n items))))
  | Replace_item _ from_one, [List_value items; Whole_value index; item] =>
      item_at from_one items index at_ (fun n => Done (Gave (List_value (replace_nth n item items))))
  | _, _ => Stop Stuck
  end.

(* trace: D172. A range that can never reach its end: a step of 0, or one pointing away from it. *)
Definition never_ends (first last step : Z) : bool :=
  (step =? 0)%Z || ((0 <? step)%Z && (last <? first)%Z) || ((step <? 0)%Z && (first <? last)%Z).

(* Whether counting has gone past a range's end. *)
Definition past_end (current last step : Z) (included : bool) : bool :=
  if (0 <? step)%Z then (if included then (last <? current)%Z else (last <=? current)%Z)
  else (if included then (current <? last)%Z else (current <=? last)%Z).

(* The variables a `for each` makes for one pass (D171, D174). *)
Definition loop_locals (item : string) (v : value) (position : option string) (from_one : bool) (pass : Z)
    (env : environment) : environment :=
  (item, v) :: match position with
               | Some i => [(i, Whole_value (if from_one then pass + 1 else pass)%Z)]
               | None => []
               end ++ env.

(* What a procedure of the program's own gives back, from how its body finished (D37, D38, D57). *)
Definition procedure_result (d : procedure) (f : flow) : io outcome :=
  match f, procedure_gives d with
  | Leave_procedure (Some v), Some _ => Done (Gave v)
  | Leave_procedure None, None => Done Gave_nothing
  | Continue _, None => Done Gave_nothing
  | _, _ => Stop Stuck
  end.

(* Where a handled call's value goes (D40). *)
Definition deliver (destination : destination) (v : value) (env : environment) : io flow :=
  match destination with
  | Into_new name _ => Done (Continue ((name, v) :: env))
  | Into name =>
      match assign name v env with
      | Some env' => Done (Continue env')
      | None => Stop Stuck
      end
  | Nowhere => Stop Stuck
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
      | Divide way left_operand right_operand at_ =>
          bind (evaluate fuel' where_ p env left_operand) (fun a =>
            bind (evaluate fuel' where_ p env right_operand) (fun b => divide_values way a b at_))
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
      | Text_of _ operand at_ => bind (evaluate fuel' where_ p env operand) (fun v => text_of v at_)
      | Float_literal f => Done (Float_value f)
      (* trace: D177, D179 *)
      | Float_maths operator left_operand right_operand at_ =>
          bind (evaluate fuel' where_ p env left_operand) (fun a =>
            bind (evaluate fuel' where_ p env right_operand) (fun b =>
              match a, b with
              | Float_value x, Float_value y => checked_float at_ (float_arithmetic operator x y) (Some operator) x y
              | _, _ => Stop Stuck
              end))
      | Float_negate operand =>
          bind (evaluate fuel' where_ p env operand) (fun v =>
            match v with
            | Float_value x => Done (Float_value (float_negate x))
            | _ => Stop Stuck
            end)
      (* trace: D162 *)
      | Float_of operand =>
          bind (evaluate fuel' where_ p env operand) (fun v =>
            match v with
            | Whole_value n =>
                let f := float_of_whole n in
                if is_finite f then Done (Float_value f)
                else Stop (Float_stopped {| place_file := 0; place_line := 0; place_column := 0; place_width := 0 |}
                             Float_too_big None f f)
            | _ => Stop Stuck
            end)
      (* trace: D178 *)
      | Whole_of_float way operand at_ =>
          bind (evaluate fuel' where_ p env operand) (fun v =>
            match v with
            | Float_value x =>
                match float_to_whole way x with
                | Some n => Done (Whole_value n)
                | None => Stop (Float_to_whole_too_big at_ way x)
                end
            | _ => Stop Stuck
            end)
      (* trace: D175, D176 *)
      | Text_places places operand =>
          bind (evaluate fuel' where_ p env operand) (fun v =>
            match v with
            | Float_value x => Done (Text_value (text_with_places x places))
            | _ => Stop Stuck
            end)
      (* trace: D75, D167 *)
      | List_literal _ items => bind (evaluate_all fuel' where_ p env items) (fun vs => Done (List_value vs))
      (* trace: D169 *)
      | All_literal container value =>
          match container with
          | Array_of _ length => bind (evaluate fuel' where_ p env value) (fun v => Done (List_value (repeat v (Z.to_nat length))))
          | _ => Stop Stuck
          end
      (* trace: D46, D75 *)
      | Item from_one container index at_ =>
          bind (evaluate fuel' where_ p env container) (fun c =>
            bind (evaluate fuel' where_ p env index) (fun i =>
              match c, i with
              | List_value items, Whole_value k =>
                  item_at from_one items k at_ (fun n =>
                    match nth_error items n with
                    | Some v => Done v
                    | None => Stop Stuck
                    end)
              | _, _ => Stop Stuck
              end))
      (* trace: D79 *)
      | Length container =>
          bind (evaluate fuel' where_ p env container) (fun c =>
            match c with
            | List_value items => Done (Whole_value (Z.of_nat (List.length items)))
            | _ => Stop Stuck
            end)
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
            | Failed _ => evaluate fuel' where_ p env fallback
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
      (* trace: D152 *)
      | Crashing inner name at_ =>
          bind (perform fuel' where_ p env inner) (fun o =>
            match o with
            | Failed failure => Stop (Crashed at_ name failure)
            | other => Done other
            end)
      (* trace: D23 *)
      | Passing inner =>
          bind (perform fuel' where_ p env inner) (fun o =>
            match o with
            | Failed failure => Stop (Passing_up failure)
            | other => Done other
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
            (* trace: D23. A failure passed up inside it is what the call gives back. *)
            catch_failure
              (bind (execute_block fuel' (enter where_ (procedure_name d)) p locals (procedure_body d))
                 (procedure_result d))
              (fun failure => Done (Failed failure))
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
                 | other => Done other
                 end))
              (fun _ => Done (Continue env)))
      (* trace: D171, D174 *)
      | For_each item position from_one source body =>
          bind (evaluate fuel' where_ p env source) (fun v =>
            match v with
            | List_value items => go_through fuel' where_ p env item position from_one body items 0
            | _ => Stop Stuck
            end)
      (* trace: D170, D172 *)
      | For_range item position from_one first last included step at_ body =>
          bind (evaluate fuel' where_ p env first) (fun f =>
            bind (evaluate fuel' where_ p env last) (fun l =>
              bind (evaluate fuel' where_ p env step) (fun s =>
                match f, l, s with
                | Whole_value a, Whole_value b, Whole_value c =>
                    if never_ends a b c then Stop (Range_never_ends at_ a b included c)
                    else count_through fuel' where_ p env item position from_one body a b included c 0
                | _, _, _ => Stop Stuck
                end)))
      | Break => Done (Leave_loop env)
      (* trace: D57 *)
      | Return None => Done (Leave_procedure None)
      | Return (Some value) => bind (evaluate fuel' where_ p env value) (fun v => Done (Leave_procedure (Some v)))
      (* trace: D23, D40, D121, D186 *)
      | Handle destination c handlers ignore =>
          bind (perform fuel' where_ p env c) (fun o =>
            match o with
            | Gave v => deliver destination v env
            | Gave_nothing => match destination with Nowhere => Done (Continue env) | _ => Stop Stuck end
            | Failed failure =>
                match find_case failure handlers with
                | Some body =>
                    bind (execute_block fuel' where_ p env body) (fun f =>
                      match f, destination with
                      | Leave_case env' v, _ => deliver destination v env'
                      | Continue _, Into_new _ _ => Stop Stuck
                      | other, _ => Done other
                      end)
                | None => if ignore then Done (Continue env) else Stop Stuck
                end
            end)
      | Instead value => bind (evaluate fuel' where_ p env value) (fun v => Done (Leave_case env v))
      end
  end

(* One pass of a `for each` per item, until one leaves the loop (D171). *)
with go_through (fuel : nat) (where_ : frame) (p : list procedure) (env : environment) (item : string)
    (position : option string) (from_one : bool) (body : block) (items : list value) (pass : Z) {struct fuel}
  : io flow :=
  match fuel with
  | O => Stop Out_of_fuel
  | S fuel' =>
      match items with
      | [] => Done (Continue env)
      | v :: rest =>
          bind (execute_block fuel' where_ p (loop_locals item v position from_one pass env) body) (fun f =>
            match f with
            | Continue env' => go_through fuel' where_ p (restore env env') item position from_one body rest (pass + 1)
            | Leave_loop env' => Done (Continue (restore env env'))
            | other => Done other
            end)
      end
  end

(* One pass of a `for each` per number of a range, until it's past its end or a pass leaves the loop (D170, D172). *)
with count_through (fuel : nat) (where_ : frame) (p : list procedure) (env : environment) (item : string)
    (position : option string) (from_one : bool) (body : block) (current last : Z) (included : bool) (step : Z)
    (pass : Z) {struct fuel} : io flow :=
  match fuel with
  | O => Stop Out_of_fuel
  | S fuel' =>
      if past_end current last step included then Done (Continue env)
      else
        bind (execute_block fuel' where_ p (loop_locals item (Whole_value current) position from_one pass env) body)
          (fun f =>
             match f with
             | Continue env' =>
                 count_through fuel' where_ p (restore env env') item position from_one body (current + step) last
                   included step (pass + 1)
             | Leave_loop env' => Done (Continue (restore env env'))
             | other => Done other
             end)
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
