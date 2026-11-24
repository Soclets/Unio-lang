(* The wording of the core's refusals and stops, as the decisions give it (D85, D87, D88, D89, D92, D102, D103, D117,
   D120, D121, D132, D161), in D54's layout. Names and types are filled in from the program. Where a decision's
   wording names something a later decision replaced, like `returns` (D190) or `otherwise:` (D199), it says what Unio
   writes now; wordings no decision gives yet are drafts, listed in PROGRESS.md. *)

module M = Messages

(* A type as it's written (D75, D167). *)
let rec type_name = function
  | Core.Whole -> "Whole"
  | Core.Bool -> "Bool"
  | Core.Text -> "Text"
  | Core.Float -> "Float"
  | Core.List_of (item, None) -> "List<" ^ type_name item ^ ">"
  | Core.List_of (item, Some most) ->
      "List<" ^ type_name item ^ ">[len.max: " ^ Core.text_of_whole most ^ "]"
  | Core.Array_of (item, length) ->
      "Array<" ^ type_name item ^ ">[len: " ^ Core.text_of_whole length ^ "]"

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

let expression_place (e : Core.expression) : Core.place = Core.expression_at e

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
  (* trace: D81, D102; the forms for `?`, `?? crash`, `?? ignore` and `otherwise` are drafts. *)
  | Core.Without_failing_call (word, p) ->
      refused p
        ~what:(Printf.sprintf "%s here doesn't follow a call that can fail" (quoted word))
        ~why:
          (match word with
          | "?" -> "`?` passes up the failure of the call right before it."
          | "otherwise" -> "`otherwise` deals with the failures of the call right before it."
          | _ ->
              Printf.sprintf "%s deals with the failure of the call right before it." (quoted word))
  (* trace: D23. A draft wording. *)
  | Core.Failure_not_listed (procedure, failure, p, header) ->
      refused p
        ~what:
          (Printf.sprintf "%s can fail with %s, which this procedure doesn't list"
             (quoted procedure) (quoted failure))
        ~because:("its failures are listed here", Some (at header))
        ~why:"`?` passes a failure up to the caller, so the procedure lists it after `!`."
  (* trace: D121 *)
  | Core.Ignore_value (procedure, given, variable, p) ->
      refused p
        ~what:
          (match variable with
          | Some v ->
              Printf.sprintf "%s gives back a %s, so `?? ignore` leaves %s with nothing if it fails"
                (quoted procedure) (a_type given) (quoted v)
          | None ->
              Printf.sprintf
                "%s gives back a %s, so `?? ignore` leaves nothing to carry on with if it fails"
                (quoted procedure) (a_type given))
        ~why:
          "`?? ignore` is for a call that gives nothing; after one that gives a value, `?? value` \
           says what to carry on with."
  (* trace: D40. Drafts. *)
  | Core.Case_missing (procedure, failure, p) ->
      refused p
        ~what:
          (Printf.sprintf "%s can fail with %s, and no case here deals with it" (quoted procedure)
             (quoted failure))
        ~why:"an `otherwise` has a case for every failure its call can give."
  | Core.Case_not_possible (procedure, failure, p) ->
      refused p
        ~what:(Printf.sprintf "%s can't fail with %s" (quoted procedure) (quoted failure))
        ~why:"an `otherwise` has a case for each failure its call can give, and no others."
  | Core.Case_twice (failure, p, first) ->
      refused p
        ~what:(Printf.sprintf "there's already a case for %s" (quoted failure))
        ~because:("the first is here", Some (at first))
        ~why:"each failure has one case."
  | Core.Case_falls_off p ->
      refused p ~what:"this case can reach its end without `instead`, `return` or `break`"
        ~why:
          "after a call that gives back a value, each case ends with `instead` a value, `return` \
           or `break`, so there's always a value to carry on with."
  | Core.Instead_outside_case p ->
      refused p ~what:"this `instead` isn't in a case of an `otherwise`"
        ~why:"`instead` gives the value to carry on with when a call fails."
  | Core.Instead_without_value (procedure, p) ->
      refused p
        ~what:
          (Printf.sprintf "%s gives back nothing, so there's nothing for `instead` to stand for"
             (quoted procedure))
        ~why:
          "`instead` gives the value to carry on with when a call fails; after one that gives \
           nothing, a case just ends."
  (* trace: D41, D42, D43. Drafts. *)
  | Core.Unknown_handler (name, p) ->
      refused p
        ~what:(Printf.sprintf "there's no handler named %s" (quoted name))
        ~why:"a handler is declared with `handler`, inside a `fam.handler` block."
  | Core.Handler_jump_unmarked (name, p) ->
      let word, kind = match String.index_opt name '.' with Some i -> (String.sub name 0 i, String.sub name (i + 1) (String.length name - i - 1)) | None -> (name, "") in
      refused p
        ~fix:(M.replace_at (line_of source p) p.place_column p.place_width (word ^ ".*" ^ kind))
        ~why:"a handler that can `return` or `break` is marked `.*` where it's used, so the jump shows at the call."
  | Core.Handler_jump_marked (name, p) ->
      refused p
        ~fix:(M.replace_at (line_of source p) p.place_column p.place_width name)
        ~why:"only a handler that can `return` or `break` is marked `.*`."
  | Core.Narrowed_outside_family (name, p) ->
      let word = match String.index_opt name '.' with Some i -> String.sub name 0 i | None -> name in
      refused p
        ~what:(Printf.sprintf "%s is a kind of %s, so it's declared inside %s" (quoted name) (quoted word) (quoted ("fam.proc " ^ word)))
        ~why:"a narrowed procedure is declared inside its word's family, so every kind of it is in one place."
  | Core.Member_of_other_family (name, family, p) ->
      refused p
        ~what:(Printf.sprintf "%s isn't %s or a kind of it" (quoted name) (quoted family))
        ~why:"a family holds its word and the kinds of it."
  (* trace: D155. The fix adds the `~`; its `why:` is a draft. *)
  | Core.Approximate_literal p ->
      let w = Option.value (written source p) ~default:"" in
      refused p
        ~fix:(M.insert_at (line_of source p) p.place_column "~")
        ~why:
          (Printf.sprintf "%s can't be stored exactly in a `Float`, so it's written %s, to show it's approximate."
             (quoted w) (quoted ("~" ^ w)))
  | Core.Exact_literal_marked p ->
      let w = Option.value (written source p) ~default:"~" in
      refused p
        ~fix:(M.replace_at (line_of source p) p.place_column 1 "")
        ~why:(Printf.sprintf "%s is stored exactly, so it takes no `~`." (quoted (String.sub w 1 (String.length w - 1))))
  (* trace: D180. The fix gives or takes away the point; the `why:` is a draft. *)
  | Core.Literal_point (to_float, p) ->
      let w = Option.value (written source p) ~default:"" in
      let fixed =
        if to_float then w ^ ".0" else match String.index_opt w '.' with Some i -> String.sub w 0 i | None -> w
      in
      refused p
        ~fix:(M.replace_at (line_of source p) p.place_column p.place_width fixed)
        ~why:"a number written with a point is a `Float`, and one without is a `Whole`."
  (* trace: D162. A draft wording. *)
  | Core.Mixed_numbers (_, whole_at, _) ->
      let w = Option.value (written source whole_at) ~default:"" in
      refused whole_at
        ~fix:(M.replace_at (line_of source whole_at) whole_at.place_column whole_at.place_width ("be.Float(" ^ w ^ ")"))
        ~why:"a `Whole` and a `Float` don't mix in one calculation; `be.Float` makes the `Whole` a `Float`."
  (* trace: D178. A draft wording. *)
  | Core.Bare_whole_of_float p ->
      refused p
        ~what:
          "`be.Whole` on a `Float` says how the fraction goes: `.floor`, `.trunc`, `.ceil`, `.nearest` or \
           `.nearest.even`"
        ~why:"each gives a different whole number for a `Float` with a fraction, so the program says which."
  (* trace: D184. A draft wording. *)
  | Core.Float_equality_in_while (operator, p) ->
      refused p
        ~what:(Printf.sprintf "this `while` condition compares two `Float`s with %s" (quoted (operator_name operator)))
        ~why:
          "a `Float` that changes each pass rarely lands exactly on a value, so the loop could pass it and never stop; \
           `<`, `>`, `at_least` or `at_most` say \"until it reaches\"."
  (* trace: D70, D71, D89 *)
  | Core.Division_types (word, left, right, p) ->
      refused p
        ~what:
          (Printf.sprintf "%s works on two `Whole`s, but this is a %s and a %s" (quoted word)
             (a_type left) (a_type right))
        ~why:"`/`, `div` and `rem` are only for numbers."
  (* trace: D70, D71. A draft wording. *)
  | Core.Bare_division (word, p) ->
      refused p
        ~what:
          (Printf.sprintf "%s needs to say how it rounds: %s or %s" (quoted word)
             (quoted (word ^ ".floor"))
             (quoted (word ^ ".trunc")))
        ~why:
          "`.floor` rounds down and `.trunc` cuts the fraction off; they differ for negative \
           numbers."
  (* Lists and arrays: drafts *)
  | Core.Item_type (item, found, p) ->
      refused p
        ~what:(Printf.sprintf "this holds %ss, but this item is a %s" (a_type item) (a_type found))
        ~why:"a list's items are all of one type."
  | Core.Too_many_items (count, most, p) ->
      refused p
        ~what:
          (Printf.sprintf "this list has %s items, but it holds at most %s"
             (Core.text_of_whole count) (Core.text_of_whole most))
        ~why:"`len.max` is the most a list may hold."
  | Core.Array_length (count, length, p) ->
      refused p
        ~what:
          (Printf.sprintf "this has %s items, but the array holds exactly %s"
             (Core.text_of_whole count) (Core.text_of_whole length))
        ~why:"an array always holds the number of items its `len:` says."
  | Core.Empty_list_for (expected, p) ->
      refused p
        ~what:(Printf.sprintf "`[]` is an empty list, but a %s goes here" (a_type expected))
        ~why:same_type_why
  | Core.All_needs_array p ->
      refused p ~what:"`[all: …]` goes where an `Array` goes"
        ~why:
          "`[all: value]` takes its length from the array's type, and a list's length isn't part \
           of its type."
  | Core.Not_a_list (what, found, p) ->
      refused p
        ~what:
          (Printf.sprintf "%s works on a list or an array, but this is a %s" (quoted what)
             (a_type found))
        ~why:"only lists and arrays have items."
  | Core.Item_without_label (label, p) ->
      refused p
        ~what:
          (if label = "" then "an item is reached with `pos:` or `offset:`"
           else
             Printf.sprintf "an item is reached with `pos:` or `offset:`, not %s"
               (quoted (label ^ ":")))
        ~why:"`pos:` counts from 1 and `offset:` from 0, so the label says which."
  | Core.Position_type (found, p) ->
      refused p
        ~what:(Printf.sprintf "a position is a `Whole`, but this is a %s" (a_type found))
        ~why:same_type_why
  | Core.Bad_plain_position (label, index, length, p) ->
      refused p
        ~what:
          (match length with
          | Some l ->
              Printf.sprintf "`%s: %s` is past this array's %s items" label
                (Core.text_of_whole index) (Core.text_of_whole l)
          | None ->
              Printf.sprintf "no list has an item at `%s: %s`" label (Core.text_of_whole index))
        ~why:"`pos:` counts from 1 and `offset:` from 0, up to the list's length."
  | Core.List_cannot_change (name, p, declared, by_let) ->
      refused p
        ~what:(Printf.sprintf "%s can't change" (quoted name))
        ~because:
          (if by_let then
             ( Printf.sprintf "line %d declares it with `let`" declared.place_line,
               Some (at declared) )
           else (Printf.sprintf "%s is a parameter" (quoted name), Some (at declared)))
        ~why:"only a `var`'s value can change, its items included."
  | Core.Array_cannot_grow (meth, p) ->
      refused p
        ~what:(Printf.sprintf "an array has no %s" (quoted ("." ^ meth)))
        ~why:"an array always holds the same number of items; a `List` can grow and shrink."
  (* trace: D173. A draft wording. *)
  | Core.Going_through (name, p, loop_at) ->
      refused p
        ~what:
          (Printf.sprintf "%s can't change here, since this `for each` is going through it"
             (quoted name))
        ~because:("the `for each` is here", Some (at loop_at))
        ~why:
          "a `for each` can't change the list it's going through; to change it while looping, use \
           `while`."
  | Core.Loop_variable_cannot_change (name, p, loop_at) ->
      refused p
        ~what:(Printf.sprintf "%s can't be given a new value" (quoted name))
        ~because:
          ( Printf.sprintf "the `for each` on line %d gives it each item in turn" loop_at.place_line,
            Some (at loop_at) )
        ~why:"a `for each`'s names are new for each pass, like a `let`."
  | Core.For_each_source (found, p) ->
      refused p
        ~what:
          (Printf.sprintf "`for each` goes through a list, an array or a `range`, but this is a %s"
             (a_type found))
        ~why:"`for each` runs its body once for each item."
  | Core.Range_labels p ->
      refused p
        ~what:"`range` takes `from:` and one of `to:` or `before:`, then `step_by:` if it isn't 1"
        ~why:"`to:` includes its end and `before:` stops short of it."
  | Core.Range_never_ends_plain p ->
      refused p ~what:"this `range` never reaches its end"
        ~why:
          "a range counts from `from:` toward its end, so `step_by:` points that way, and isn't 0."
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
      | Core.Float, Some _ ->
          refused p
            ~fix:(M.insert_at (line_of source p) (p.place_column + p.place_width) " not_eq 0.0")
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
  | Core.Empty_list_unknown -> "`[]` where nothing says what type of list it is"
  | Core.List_limits_differ -> "a list with one `len.max` where a list with another, or none, goes"
  | Core.Other_facts -> "facts besides a list's `.len`"
  | Core.Other_methods -> "methods besides a list's `.add` and `.remove`"
  | Core.Method_on_value ->
      "a method that changes a value, called on something that isn't a variable"
  | Core.Range_elsewhere -> "`range[…]` anywhere but in `for each`"
  | Core.Failure_leaving_main -> "a failure passed up out of `proc.main`"
  | Core.After_instead -> "a line after `instead` in the same block"
  | Core.Going_through_text -> "going through text with `for each`"
  | Core.Comparing_lists -> "comparing lists or arrays"
  | Core.Float_literal_out_of_range -> "writing a number too big for a `Float`"
  | Core.Handler_including_handler -> "a handler that includes another"
  | Core.Handler_arguments_calling -> "when a handler's arguments are worked out, when they call a procedure"

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
