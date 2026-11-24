(* The wording of the core's refusals and stops, as the decisions give it (D85, D87, D88, D89, D92, D102, D103, D117,
   D120, D121, D132, D161), in D54's layout. Names and types are filled in from the program. Where a decision's
   wording names something a later decision replaced, like `returns` (D190) or `otherwise:` (D199), it says what Unio
   writes now; wordings no decision gives yet are drafts, listed in PROGRESS.md. *)

module M = Messages

let type_name = function Core.Whole -> "Whole" | Core.Bool -> "Bool" | Core.Text -> "Text"

let operator_name = function
  | Core.Add -> "+"
  | Core.Subtract -> "-"
  | Core.Multiply -> "*"
  | Core.Equal -> "eq"
  | Core.Not_equal -> "not_eq"
  | Core.Less -> "<"
  | Core.Greater -> ">"
  | Core.At_least -> "at_least"
  | Core.At_most -> "at_most"
  | Core.And -> "and"
  | Core.Or -> "or"

(* The file Ralph was given, where a message about the whole program points (D64). *)
let given_file = ref 0
let at (p : Core.place) = M.point ~file:p.place_file p.place_line p.place_column p.place_width
let quoted s = "`" ^ s ^ "`"
let variable name = quoted name
let a_type t = quoted (type_name t)

(* "`.a`", "`.a` and `.b`", "`.a`, `.b` and `.c`" *)
let listed narrowings =
  let names = List.map (fun n -> quoted ("." ^ n)) narrowings in
  match List.rev names with
  | [] -> ""
  | [ only ] -> only
  | last :: rest -> String.concat ", " (List.rev rest) ^ " and " ^ last

let refused ?fix ?what ?because ?why p = M.message M.Refused (at p) ?fix ?what ?because ?why

(* [source] holds each file's lines (D64). *)
let line_of (source : string array array) (p : Core.place) =
  if p.place_file >= 0 && p.place_file < Array.length source then
    let lines = source.(p.place_file) in
    if p.place_line >= 1 && p.place_line <= Array.length lines then lines.(p.place_line - 1) else ""
  else ""

let same_type_why = "a value's type has to match where it's used."

(* ---------------------------------------------------------------------------------------------------------------- *)
(* D128's fixes (D142): a chain of calls written again as calls, or as one slide. *)

let expression_place (e : Core.expression) : Core.place =
  match e with
  | Core.Whole_literal (_, p)
  | Core.Text_literal (_, p)
  | Core.Bool_literal (_, p)
  | Core.Variable_value (_, p)
  | Core.Bare_word (_, p)
  | Core.Negate (_, p)
  | Core.Not (_, p)
  | Core.Binary (_, _, _, _, p)
  | Core.Bracketed (_, p)
  | Core.Call (_, _, p)
  | Core.Fallback (_, _, _, p)
  | Core.Slide (_, _, p)
  | Core.Broken p ->
      p

(* What's written at a place, on its line. *)
let written source (p : Core.place) =
  let text = line_of source p in
  if p.place_column >= 1 && p.place_column - 1 + p.place_width <= String.length text then
    Some (String.sub text (p.place_column - 1) p.place_width)
  else None

let ( let* ) = Option.bind

(* Each argument as written, its label included. *)
let rec arguments_written source (given : Core.arguments) =
  match given with
  | Core.No_arguments -> Some []
  | Core.Argument (label, value, rest) ->
      let vp = expression_place value in
      let* this =
        match label with
        | Some (_, lp) ->
            written source
              {
                Core.place_file = lp.place_file;
                place_line = lp.place_line;
                place_column = lp.place_column;
                place_width = vp.place_column + vp.place_width - lp.place_column;
              }
        | None -> written source vp
      in
      let* others = arguments_written source rest in
      Some (this :: others)

(* A chain as its first value and its links, innermost first: each link a procedure and its other arguments. *)
type link = { procedure : string; others : string list }

(* trace: D128, D142. A chain flattened all the way: the innermost call's one value starts the slide, as `points`
   starts `points |> double`; an innermost call taking no value, or more than one, starts it whole, as
   `larger(3, 9) |> be.Text |> show_msg` (D128). *)
let rec flatten source (e : Core.expression) : (string * link list) option =
  match e with
  | Core.Call (name, Core.Argument (None, (Core.Call _ as inner), rest), _) ->
      let* start, links = flatten source inner in
      let* others = arguments_written source rest in
      Some (start, links @ [ { procedure = Core.callee_name name; others } ])
  | Core.Call (name, Core.Argument (None, first, Core.No_arguments), _) ->
      let* start = written source (expression_place first) in
      Some (start, [ { procedure = Core.callee_name name; others = [] } ])
  | Core.Call (_, _, p) ->
      let* start = written source p in
      Some (start, [])
  | Core.Slide (start, path, _) ->
      let* first, links = flatten source start in
      let rec steps (path : Core.steps) =
        match path with
        | Core.No_steps -> Some []
        | Core.Step (name, _, given, _, rest) ->
            let* others = arguments_written source given in
            let* later = steps rest in
            Some ({ procedure = Core.callee_name name; others } :: later)
      in
      let* later = steps path in
      Some (first, links @ later)
  | other ->
      let* start = written source (expression_place other) in
      Some (start, [])

let as_slide (start, links) =
  String.concat " |> "
    (start
    :: List.map
         (fun l ->
           if l.others = [] then l.procedure
           else l.procedure ^ "(" ^ String.concat ", " l.others ^ ")")
         links)

let as_calls (start, links) =
  List.fold_left
    (fun inner l -> l.procedure ^ "(" ^ String.concat ", " (inner :: l.others) ^ ")")
    start links

(* trace: D160 *)
let random_why =
  "`random` gives a whole number from `from:` up to `to:`, so `from:` can't be above `to:`."

let chain_why = "one or two calls are written as calls; a chain of three or more is a slide."

let chain_refusal source (whole : Core.expression) (fixed : string option) =
  let p = expression_place whole in
  match fixed with
  | Some text ->
      refused p
        ~fix:(M.replace_at (line_of source p) p.place_column p.place_width text)
        ~why:chain_why
  (* Only when the chain runs over several lines, which is already stopped as undecided. *)
  | None -> refused p ~why:chain_why

let refusal source (r : Core.refusal) : M.message =
  match r with
  | Core.Unknown_variable (name, p, ended) ->
      refused p
        ~what:(Printf.sprintf "there's no variable named %s here" (variable name))
        ?because:
          (Option.map
             (fun e ->
               ( Printf.sprintf "%s is declared inside a block that has ended" (variable name),
                 Some (at e) ))
             ended)
        ~why:"a variable is declared with `let` or `var` before it's used."
  | Core.Name_in_use (name, p, first) ->
      refused p
        ~what:(Printf.sprintf "%s is already in use here" (variable name))
        ~because:(Printf.sprintf "%s is declared here" (variable name), Some (at first))
        ~why:"a name in use can't be declared again; two things get two names."
  | Core.Let_cannot_change (name, p, keyword) ->
      refused p
        ~what:(Printf.sprintf "%s can't be given a new value" (variable name))
        ~because:
          (Printf.sprintf "line %d declares it with `let`" keyword.place_line, Some (at keyword))
        ~why:"only a `var` can be given a new value."
  | Core.Parameter_cannot_change (name, p, parameter) ->
      refused p
        ~what:(Printf.sprintf "%s can't be given a new value" (variable name))
        ~because:(Printf.sprintf "%s is a parameter" (variable name), Some (at parameter))
        ~why:"a parameter can't be given a new value; to change a copy, declare a `var` from it."
  | Core.Two_parameters_one_name (name, p) ->
      refused p
        ~what:(Printf.sprintf "two parameters are named %s" (variable name))
        ~why:"each parameter needs its own name."
  | Core.Wrong_value_type (name, expected, found, p) ->
      refused p
        ~what:
          (Printf.sprintf "%s is a %s, but this value is a %s" (variable name) (a_type expected)
             (a_type found))
        ~why:same_type_why
  | Core.Argument_type (procedure, expected, found, p) ->
      refused p
        ~what:
          (Printf.sprintf "%s takes a %s here, but this is a %s" (quoted procedure)
             (a_type expected) (a_type found))
        ~why:same_type_why
  | Core.Slid_value_type (procedure, expected, found, p) ->
      refused p
        ~what:
          (Printf.sprintf "%s takes a %s first, but the slid value is a %s" (quoted procedure)
             (a_type expected) (a_type found))
        ~why:"a slide passes the value on its left in as the step's first argument."
  | Core.Fallback_type (expected, found, p) ->
      refused p
        ~what:
          (Printf.sprintf "the call gives a %s, so the value after `??` must be one too, not a %s"
             (a_type expected) (a_type found))
        ~why:same_type_why
  | Core.Compare_types (operator, left, right, p) ->
      refused p
        ~what:
          (Printf.sprintf "%s compares two values of one type, but this is a %s and a %s"
             (quoted (operator_name operator))
             (a_type left) (a_type right))
        ~why:"a comparison is between two values of the same type."
  | Core.Arithmetic_types (operator, left, right, p) ->
      refused p
        ~what:
          (Printf.sprintf "%s works on two `Whole`s, but this is a %s and a %s"
             (quoted (operator_name operator))
             (a_type left) (a_type right))
        ~why:"`+`, `-` and `*` are only for numbers."
  (* trace: D28, D87, D201. Fixed by one text filled in with braces, when each side is text in quotes or a name. *)
  | Core.Plus_on_text (p, left, right) -> (
      let as_text (e : Core.expression) =
        match e with
        | Core.Text_literal (_, tp) ->
            let* w = written source tp in
            if String.length w >= 2 then Some (String.sub w 1 (String.length w - 2)) else None
        | Core.Variable_value (name, _) -> Some ("{" ^ name ^ "}")
        | _ -> None
      in
      let why = "`+` is only for numbers; text is joined by filling it in with braces." in
      let lp = expression_place left and rp = expression_place right in
      match (as_text left, as_text right) with
      | Some a, Some b when lp.place_line = rp.place_line ->
          let line = line_of source p in
          refused p
            ~fix:
              (M.replace_at line lp.place_column
                 (rp.place_column + rp.place_width - lp.place_column)
                 ("\"" ^ a ^ b ^ "\""))
            ~why
      | _ -> refused p ~what:"`+` works on two `Whole`s, but this is a `Text` and a `Text`" ~why)
  | Core.Negate_non_number (found, p) ->
      refused p
        ~what:(Printf.sprintf "`-` makes a number negative, but this is a %s" (a_type found))
        ~why:"a `-` with no space after it makes a number negative."
  | Core.Convert_to_same (target, p) ->
      refused p
        ~what:
          (Printf.sprintf "this value is already a %s, so %s does nothing" (a_type target)
             (quoted ("be." ^ type_name target)))
        ~why:"converting a value to the type it already is does nothing, so it's refused."
  | Core.Be_without_type p ->
      refused p ~what:"`be` needs the type the value becomes, as in `be.Text`"
        ~why:"a value is converted with `be` narrowed by the type it becomes."
  | Core.Unknown_narrowing (word, narrowing, p, narrowings) ->
      refused p
        ~what:(Printf.sprintf "%s has no narrowing %s" (quoted word) (quoted ("." ^ narrowing)))
        ~why:
          (match narrowings with
          | [] -> Printf.sprintf "%s has no narrowings." (quoted word)
          | [ only ] ->
              Printf.sprintf "%s's only narrowing is %s." (quoted word) (quoted ("." ^ only))
          | _ -> Printf.sprintf "%s's narrowings are %s." (quoted word) (listed narrowings))
  | Core.Narrowing_on_narrowed (word, narrowing, p) ->
      refused p
        ~what:(Printf.sprintf "%s has no narrowing %s" (quoted word) (quoted ("." ^ narrowing)))
        ~why:(Printf.sprintf "%s can't be narrowed further." (quoted word))
  | Core.Narrowing_twice (narrowing, p) ->
      refused p
        ~what:(Printf.sprintf "%s is written twice" (quoted ("." ^ narrowing)))
        ~why:"each narrowing is written once."
  | Core.Unknown_procedure (name, p) ->
      refused p
        ~what:(Printf.sprintf "there's no procedure named %s" (quoted name))
        ~why:"a call names a procedure the program or the library has."
  (* trace: D92 *)
  | Core.Variable_called (name, p) ->
      refused p
        ~what:(Printf.sprintf "%s is a variable, not a procedure" (quoted name))
        ~why:"only a procedure can be called."
  (* trace: D94, D102, D192 *)
  | Core.Name_is_procedure (name, p, declared) ->
      refused p
        ~what:(Printf.sprintf "%s is already a procedure's name" (quoted name))
        ?because:
          (Option.map
             (fun d ->
               (Printf.sprintf "the procedure %s is declared here" (quoted name), Some (at d)))
             declared)
        ~why:
          (Printf.sprintf
             "a variable can't take a procedure's name, since %s and %s would look alike."
             (quoted name)
             (quoted (name ^ "()")))
  | Core.Procedure_without_brackets (name, p) ->
      refused p
        ~what:
          (Printf.sprintf "%s is a procedure, so using it writes `( )` with its arguments"
             (quoted name))
        ~why:"a call writes the procedure's name and `( )`."
  | Core.Gives_nothing_used p ->
      refused p ~what:"this call gives nothing back, so it can't be used as a value"
        ~why:"a procedure with no `->` gives nothing back."
  | Core.Value_unused (procedure, given, p) ->
      refused p
        ~what:
          (Printf.sprintf "%s gives back a %s, but nothing uses it" (quoted procedure)
             (a_type given))
        ~why:"a call that gives back a value is used: kept in a variable, passed on, or compared."
  | Core.Failure_unhandled p ->
      refused p ~what:"this call can fail, and nothing here deals with the failure"
        ~why:"every call that can fail deals with its failure, with `?`, `??` or `otherwise`."
  | Core.Fallback_without_failing_call p ->
      refused p ~what:"`??` here doesn't follow a call that can fail"
        ~why:"`??` deals with the failure of the call right before it."
  | Core.Missing_label (label, value) ->
      refused value
        ~fix:(M.insert_at (line_of source value) value.place_column (label ^ ": "))
        ~why:"every call writes the labels its procedure chose."
  | Core.Label_where_none (label, value) ->
      refused label
        ~fix:
          (M.replace_at (line_of source label) label.place_column
             (value.place_column - label.place_column)
             "")
        ~why:"a call writes only the labels its procedure chose."
  | Core.Wrong_label (expected, found, p) ->
      refused p
        ~what:
          (Printf.sprintf "this argument's label is %s, not %s" (quoted expected) (quoted found))
        ~why:"every call writes the labels its procedure chose."
  | Core.Argument_count (procedure, expected, given, p, declared) ->
      let values n = if n = 1 then "1 value" else Printf.sprintf "%d values" n in
      refused p
        ~what:
          (Printf.sprintf "%s takes %s, but this call gives %s" (quoted procedure) (values expected)
             (values given))
        ?because:
          (Option.map
             (fun d -> (Printf.sprintf "%s is declared here" (quoted procedure), Some (at d)))
             declared)
        ~why:"a call gives every parameter a value, with its label if it has one."
  | Core.Brace_not_variable (name, p) ->
      refused p
        ~what:(Printf.sprintf "there's no variable named %s here" (variable name))
        ~why:"braces in text hold a variable's name, checked at compile time."
  | Core.Brace_calculation p ->
      refused p ~what:"braces in text hold only a variable's name"
        ~why:"text never hides a calculation or a call; work it out into a variable first."
  (* trace: D175. A draft wording. *)
  | Core.Places_on_non_float (name, found, p) ->
      refused p
        ~what:
          (Printf.sprintf "`places:` rounds a `Float`, but %s is a %s" (quoted name) (a_type found))
        ~why:"`places:` says how many digits after the point a `Float` shows."
  (* trace: D187. A draft wording: a `Whole` gets `not_eq 0` as its fix. *)
  | Core.Condition_not_bool (found, p) -> (
      let why = "a condition is a `Bool`; a number or text doesn't stand for true or false." in
      match (found, written source p) with
      | Core.Whole, Some _ ->
          refused p
            ~fix:(M.insert_at (line_of source p) (p.place_column + p.place_width) " not_eq 0")
            ~why
      | _ ->
          refused p
            ~what:
              (Printf.sprintf "this condition is a %s, but a condition is a `Bool`" (a_type found))
            ~why)
  | Core.Return_value_without_returns (procedure, p) ->
      refused p
        ~what:(Printf.sprintf "%s has no `->`, so it gives nothing back" (quoted procedure))
        ~why:"only a procedure with `->` gives back a value."
  | Core.Bare_return_with_returns (procedure, t, p) ->
      refused p
        ~what:
          (Printf.sprintf "%s gives back a %s, so `return` needs one" (quoted procedure) (a_type t))
        ~why:"in a procedure with `->`, `return` gives back a value of that type."
  | Core.Missing_return (procedure, t, p) ->
      refused p
        ~what:
          (Printf.sprintf "some way through %s reaches its end without `return` giving back a %s"
             (quoted procedure) (a_type t))
        ~why:"every way through a procedure with `->` ends in `return` and a value."
  | Core.After_leaving (by_return, p, leave) ->
      let word = if by_return then "`return`" else "`break`" in
      refused p
        ~what:
          (Printf.sprintf "this line comes after a %s in the same block, so it can never run" word)
        ~because:(Printf.sprintf "the %s is here" word, Some (at leave))
        ~why:(Printf.sprintf "nothing may follow %s in the same block." word)
  | Core.Bare_return_last p ->
      refused p ~what:"a bare `return;` as a procedure's last line does nothing"
        ~why:"a procedure ends there anyway; `return;` is for leaving early."
  | Core.After_if_that_leaves (p, if_at) ->
      refused p ~what:"this line follows an `if` that can leave"
        ~because:(Printf.sprintf "the `if` on line %d can leave" if_at.place_line, Some (at if_at))
        ~why:
          "when any way through an `if` leaves, nothing may follow its `end if`; code that should \
           run afterwards goes in the ways that don't leave."
  | Core.Break_outside_loop p ->
      refused p ~what:"this `break` isn't inside a loop"
        ~why:"`break` leaves the innermost loop it's in."
  | Core.Labels_not_first p ->
      refused p ~what:"a `labels` line can only be the first line of a procedure's body"
        ~why:"a procedure declares its labels on the first line of its body."
  | Core.Label_for_missing_parameter (procedure, name, p) ->
      refused p
        ~what:(Printf.sprintf "%s has no parameter named %s" (quoted procedure) (variable name))
        ~why:"a `labels` line gives labels to the procedure's own parameters."
  | Core.Two_labels_one_parameter (name, p) ->
      refused p
        ~what:(Printf.sprintf "%s already has a label" (variable name))
        ~why:"each parameter has at most one label."
  | Core.One_label_two_parameters (label, p) ->
      refused p
        ~what:(Printf.sprintf "two parameters have the label %s" (quoted label))
        ~why:"each label names one parameter, so a call can say which value is which."
  | Core.Two_mains (p, first) ->
      refused p ~what:"this program has two `proc.main`s"
        ~because:("the first is here", Some (at first))
        ~why:"a program has exactly one `proc.main`, where it starts."
  | Core.Two_procedures_one_name (name, p, first) ->
      refused p
        ~what:(Printf.sprintf "there's already a procedure named %s" (quoted name))
        ~because:("the first is here", Some (at first))
        ~why:
          "every procedure in a program needs its own name, since a call has to know which one it \
           means."
  | Core.Slide_as_calls whole ->
      (* The start of a short slide stays as written, as in `show_msg(larger(3, 9))`. *)
      let fixed =
        match whole with
        | Core.Slide (start, path, _) ->
            let* first = written source (expression_place start) in
            let* _, links =
              flatten source
                (Core.Slide (Core.Broken (expression_place start), path, expression_place whole))
            in
            Some (as_calls (first, links))
        | _ -> None
      in
      chain_refusal source whole fixed
  | Core.Calls_as_slide whole ->
      chain_refusal source whole (Option.map as_slide (flatten source whole))
  | Core.Random_backwards_plain (p, low, high) ->
      (* The two values swapped, the later first so the earlier column still holds. *)
      let text = line_of source p in
      let fixed =
        match (written source low, written source high) with
        | Some l, Some h ->
            M.replace_at
              (M.replace_at text high.place_column high.place_width l)
              low.place_column low.place_width h
        | _ -> text
      in
      refused p ~fix:fixed ~why:random_why
  | Core.Value_only_line (p, given) ->
      refused p
        ~what:
          (Printf.sprintf "`%s` works out a %s, but nothing uses it"
             (Option.value (written source p) ~default:"this")
             (a_type given))
        ~why:
          "a line that only works out a value does nothing; keep the value with `let` or `var`, or \
           give it to a variable with `=`."
  | Core.Not_on_non_bool (found, p) ->
      refused p
        ~what:(Printf.sprintf "`not` works on a `Bool`, but this is a %s" (a_type found))
        ~why:"`not`, `and` and `or` work on `Bool`s."
  | Core.Logic_on_non_bool (operator, found, p) ->
      refused p
        ~what:
          (Printf.sprintf "%s joins two `Bool`s, but this is a %s"
             (quoted (operator_name operator))
             (a_type found))
        ~why:"`not`, `and` and `or` work on `Bool`s."
  | Core.No_main ->
      refused
        { Core.place_file = !given_file; place_line = 1; place_column = 1; place_width = 1 }
        ~what:"this program has no `proc.main`" ~why:"a program starts with `proc.main`."

let not_designed (what : Core.not_designed) =
  match what with
  | Core.Whole_literal_out_of_range -> "writing a whole number too big or too small for a `Whole`"
  | Core.Comparing_text -> "comparing two pieces of text"
  | Core.Ordering_bools -> "comparing `Bool`s with `<`, `>`, `at_least` or `at_most`"
  | Core.Converting -> "what may be converted to what"
  | Core.Format_unclosed -> "a `{` that's never closed in text"
  | Core.Bare_word_not_procedure -> "a narrowed word with no `( )` that isn't a procedure"
  | Core.Library_name_taken -> "a procedure with the name of one of the library's"
  | Core.Label_order -> "writing labels in a different order from the parameters"
  | Core.Return_type_wording -> "the message for `return` with a value of the wrong type"
  | Core.Main_returns -> "`proc.main` with `->`"

(* Every core diagnostic as a message; [None] for a part the parser has already refused. *)
let diagnostic source (d : Core.diagnostic) : M.message option =
  match d with
  | Core.Refused r -> Some (refusal source r)
  | Core.Not_designed_yet (what, p) ->
      Some (M.message M.Not_designed_yet (at p) ~what:(not_designed what ^ " isn't decided yet"))
  | Core.Not_built_yet (what, p) -> Some (M.message M.Not_built_yet (at p) ~what)
  | Core.Already_refused _ -> None
  (* Handled by the shell as an internal error before wording. *)
  | Core.Typed_tree_refused -> None
