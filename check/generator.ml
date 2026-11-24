(* Random programs the standard accepts, built as syntax trees (Building rule 12). Every program it makes is meant to
   be accepted: types match (chapter 7), only a `var` changes (D13), a value is never left unused (D120, D161),
   conditions are `Bool`s (D187), nothing follows an `if` that leaves (D9), calls nest at most two deep (D128), names
   are new and plain (D94, D99), and every loop ends. What it can still go wrong on at runtime, like overflow (D46) or
   dividing by zero (D72), is what's being compared. NOT_GENERATED.md lists what it doesn't make yet. *)

open Syntax

type variable = { v_name : string; v_type : ty; changeable : bool }

type scope = {
  variables : variable list;
  callable : procedure list;  (** procedures declared before this one, so calls never go round in a circle *)
  in_loop : bool;
  returning : ty option;
  in_main : bool;
}

type state = { random : Random.State.t; mutable counter : int }

let fresh st prefix =
  st.counter <- st.counter + 1;
  prefix ^ string_of_int st.counter

let pick st items = List.nth_opt items (Random.State.int st.random (max 1 (List.length items)))
let chance st percent = Random.State.int st.random 100 < percent

let small_whole st =
  match Random.State.int st.random 10 with
  | 0 -> Int64.of_int (Random.State.int st.random 1_000_000)
  | 1 -> Int64.sub Int64.max_int (Int64.of_int (Random.State.int st.random 3))
  | 2 -> Random.State.int64 st.random 3_000_000_000_000L
  | _ -> Int64.of_int (Random.State.int st.random 20)

let words = [ "Mia"; "go"; "score"; "hi there"; "win!"; "level 3"; "ok."; "x-y"; "A:B" ]

let plain_text st = match pick st words with Some w -> w | None -> "a"

let variables_of scope t = List.filter (fun v -> v.v_type = t) scope.variables

(* Text, sometimes filled in from the variables in use (D29, D200). A `Bool` in braces (D202) isn't generated, since
   Beta++ is from before it. *)
let text_pieces st scope =
  let fillable = variables_of scope Whole @ variables_of scope Text in
  let rec go n acc =
    if n = 0 then List.rev acc
    else
      let piece =
        if chance st 40 then match pick st fillable with Some v -> Name v.v_name | None -> Plain (plain_text st)
        else Plain (plain_text st)
      in
      go (n - 1) (piece :: Plain " " :: acc)
  in
  match go (1 + Random.State.int st.random 3) [] with [] -> [ Plain "a" ] | _ :: rest -> rest

let callable_giving scope t = List.filter (fun (p : procedure) -> p.gives = Some t) scope.callable

(* A value of type [t]. [depth] keeps it small; [calls] says whether a call may go here: a call's first argument is
   never a call itself, so no chain is three deep (D128). *)
let rec expression st scope t depth ~calls =
  let leaf () =
    match t with
    | Whole -> (
        match pick st (variables_of scope Whole) with
        | Some v when chance st 60 -> Variable v.v_name
        | _ -> if chance st 15 then Negate (Whole_literal (small_whole st)) else Whole_literal (small_whole st))
    | Bool -> (
        match pick st (variables_of scope Bool) with
        | Some v when chance st 60 -> Variable v.v_name
        | _ -> Bool_literal (chance st 50))
    | Text -> (
        match pick st (variables_of scope Text) with
        | Some v when chance st 50 -> Variable v.v_name
        | _ -> Text_literal (text_pieces st scope))
  in
  if depth <= 0 then leaf ()
  else
    let sub t' = expression st scope t' (depth - 1) ~calls:true in
    match t with
    | Whole -> (
        match Random.State.int st.random 10 with
        | 0 | 1 -> Binary (pick_op st [ Add; Subtract; Multiply ], sub Whole, sub Whole)
        | 2 -> Binary (pick_op st [ Divide_floor; Divide_trunc; Remainder_floor; Remainder_trunc; Divide ], sub Whole, sub Whole)
        | 3 -> Negate (sub Whole)
        | 4 when calls -> call_giving st scope Whole depth
        | 5 when calls ->
            let fallback = Whole_literal (Int64.of_int (Random.State.int st.random 10)) in
            Whole_or (text_for_whole st scope, fallback)
        | _ -> leaf ())
    | Bool -> (
        match Random.State.int st.random 10 with
        | 0 | 1 -> Binary (pick_op st [ Less; Greater; At_least; At_most; Equal; Not_equal ], sub Whole, sub Whole)
        | 2 -> Binary (pick_op st [ Equal; Not_equal ], sub Bool, sub Bool)
        | 3 -> Binary (pick_op st [ And; Or ], sub Bool, sub Bool)
        | 4 -> Not (sub Bool)
        | 5 when calls -> call_giving st scope Bool depth
        | _ -> leaf ())
    | Text -> (
        match Random.State.int st.random 8 with
        | 0 when calls -> Text_of (expression st scope Whole (depth - 1) ~calls:false)
        | 1 when calls -> Text_of (expression st scope Bool (depth - 1) ~calls:false)
        | 2 when calls -> call_giving st scope Text depth
        | _ -> leaf ())

and pick_op st ops = match pick st ops with Some op -> op | None -> Add

and text_for_whole st scope =
  match Random.State.int st.random 4 with
  | 0 -> Text_literal [ Plain (Int64.to_string (small_whole st)) ]
  | 1 -> Text_literal [ Plain (plain_text st) ]
  | 2 when scope.in_main -> Ask [ Plain "Number: " ]
  | _ -> ( match pick st (variables_of scope Text) with Some v -> Variable v.v_name | None -> Text_literal [ Plain " 7" ])

and call_giving st scope t depth =
  match pick st (callable_giving scope t) with
  | Some p -> Call (p.name, List.map (fun (_, pt) -> expression st scope pt (depth - 1) ~calls:false) p.parameters)
  | None -> expression st scope t 0 ~calls:false

let declare scope v = { scope with variables = v :: scope.variables }

(* A block of statements; [counter] is a loop's counter, which nothing else may change. *)
let rec block st scope length depth ~counter =
  let rec go n scope acc =
    if n = 0 then List.rev acc
    else
      let s, scope' = statement st scope depth ~counter in
      go (n - 1) scope' (List.rev_append s acc)
  in
  go length scope []

and statement st scope depth ~counter : statement list * scope =
  let changeable_vars = List.filter (fun v -> v.changeable && Some v.v_name <> counter) scope.variables in
  match Random.State.int st.random 12 with
  | 0 | 1 | 2 ->
      let t = match Random.State.int st.random 3 with 0 -> Whole | 1 -> Bool | _ -> Text in
      let n = fresh st "v" in
      let changeable = chance st 50 in
      let value = expression st scope t 2 ~calls:true in
      ([ Declare (changeable, n, t, value) ], declare scope { v_name = n; v_type = t; changeable })
  | 3 | 4 -> (
      match pick st changeable_vars with
      | Some v -> ([ Assign (v.v_name, expression st scope v.v_type 2 ~calls:true) ], scope)
      | None -> ([ Show (false, Text_literal (text_pieces st scope)) ], scope))
  | 5 | 6 ->
      let value = if chance st 60 then Text_literal (text_pieces st scope) else expression st scope Text 1 ~calls:true in
      ([ Show (chance st 20, value) ], scope)
  | 7 -> (
      match pick st (List.filter (fun (p : procedure) -> p.gives = None) scope.callable) with
      | Some p -> ([ Run (p.name, List.map (fun (_, pt) -> expression st scope pt 1 ~calls:false) p.parameters) ], scope)
      | None -> ([ Show (false, Text_literal [ Plain "no procedure" ]) ], scope))
  | 8 | 9 when depth > 0 ->
      let condition = expression st scope Bool 2 ~calls:true in
      let then_part = block st scope (1 + Random.State.int st.random 3) (depth - 1) ~counter in
      let else_part =
        if chance st 50 then Some (block st scope (1 + Random.State.int st.random 3) (depth - 1) ~counter) else None
      in
      ([ If (condition, then_part, else_part) ], scope)
  | 10 when depth > 0 ->
      (* trace: D19, D32, D149. A counted loop: it always ends. *)
      let i = fresh st "i" in
      let limit = Int64.of_int (Random.State.int st.random 6) in
      let loop_scope = { (declare scope { v_name = i; v_type = Whole; changeable = true }) with in_loop = true } in
      let body = block st loop_scope (1 + Random.State.int st.random 3) (depth - 1) ~counter:(Some i) in
      let step = Assign (i, Binary (Add, Variable i, Whole_literal 1L)) in
      let last =
        if chance st 30 then
          (* `break` as the last line of an `if` that's the body's last statement (D9, D32). *)
          [ If (expression st loop_scope Bool 1 ~calls:false, [ Show (false, Text_literal [ Plain "stop" ]); Break ], Some [ step ]) ]
        else [ step ]
      in
      ( [ Declare (true, i, Whole, Whole_literal 0L); While (Binary (Less, Variable i, Whole_literal limit), body @ last) ],
        declare scope { v_name = i; v_type = Whole; changeable = true } )
  | _ ->
      (* Not a call itself, so `show_msg(be.Text(...))` stays two deep (D128). *)
      let value = expression st scope Whole 2 ~calls:false in
      ([ Show (false, Text_of value) ], scope)

let procedure st callable index =
  let name = Printf.sprintf "p%d" index in
  let parameters =
    List.init (Random.State.int st.random 3) (fun _ ->
        (fresh st "a", match Random.State.int st.random 3 with 0 -> Whole | 1 -> Bool | _ -> Text))
  in
  let gives = match Random.State.int st.random 4 with 0 -> None | 1 -> Some Whole | 2 -> Some Bool | _ -> Some Text in
  let scope =
    {
      variables = List.map (fun (n, t) -> { v_name = n; v_type = t; changeable = false }) parameters;
      callable;
      in_loop = false;
      returning = gives;
      in_main = false;
    }
  in
  let body = block st scope (1 + Random.State.int st.random 4) 2 ~counter:None in
  (* trace: D57. A procedure giving a value ends in `return`, with nothing after it. *)
  let body =
    match gives with
    | Some t ->
        let scope' =
          List.fold_left
            (fun sc s ->
              match s with
              | Declare (c, n, ty, _) -> declare sc { v_name = n; v_type = ty; changeable = c }
              | _ -> sc)
            scope body
        in
        body @ [ Return (Some (expression st scope' t 2 ~calls:true)) ]
    | None -> body
  in
  { name; parameters; gives; body }

let program seed =
  let st = { random = Random.State.make [| seed |]; counter = 0 } in
  let count = Random.State.int st.random 4 in
  let procedures = List.fold_left (fun acc i -> acc @ [ procedure st acc i ]) [] (List.init count (fun i -> i + 1)) in
  let scope = { variables = []; callable = procedures; in_loop = false; returning = None; in_main = true } in
  let main = block st scope (2 + Random.State.int st.random 6) 2 ~counter:None in
  let input = List.init (Random.State.int st.random 4) (fun _ -> if chance st 60 then Int64.to_string (small_whole st) else plain_text st) in
  { procedures; main; input }
