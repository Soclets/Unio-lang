(* Ralph, the oracle (D129, D141): `ralph program.unio` checks a Unio program and runs it.

   This is the shell around the proven core: it reads and decodes the file, parses it, has the core check it, words
   the messages (D54), and runs the core's evaluator, doing the real printing, reading and random numbers it asks for.
   Exit statuses are D56's and D82's. *)

module M = Messages

(* Far more steps than any program will take; a program still running after them stops as an internal error. *)
let fuel = max_int

(* How many calls may wait for one another (D154). How deep is too deep depends on the machine; Ralph's own stack holds
   a few million, using under a kilobyte each, so a million stays well inside it. *)
let call_limit = 1_000_000
let line_open = ref false

(* trace: D104. A message never starts mid-line: an open output line is ended on standard output first. *)
let end_open_line () =
  if !line_open then begin
    print_char '\n';
    line_open := false
  end;
  flush stdout

let finish status =
  flush stdout;
  flush stderr;
  exit status

let print_messages files messages = List.iter (fun m -> prerr_string (M.render files m)) messages

(* A whole number from [low] to [high], each equally likely (D26): random bits, tried again until they fall in
   range. The numbers stay Rocq's exact integers throughout. *)
let random_between low high =
  let width = Core.Z.sub high low in
  let bits =
    match width with Core.Zpos p -> Core.Coq_Pos.size_nat p | Core.Z0 | Core.Zneg _ -> 0
  in
  let rec draw () =
    let rec build n so_far =
      if n = 0 then so_far
      else
        build (n - 1) (if Random.bool () then Core.Z.succ_double so_far else Core.Z.double so_far)
    in
    let candidate = build bits Core.Z0 in
    if Core.Z.leb candidate width then Core.Z.add low candidate else draw ()
  in
  draw ()

(* trace: D20, D96, D144. One line of input, without its line break; `\r\n` is one line break. A last line with no
   line break after it still counts; no input at all gives [None]. *)
let read_answer () =
  let buffer = Buffer.create 80 in
  let rec go () =
    match In_channel.input_char stdin with
    | Some '\n' ->
        let line = Buffer.contents buffer in
        Some
          (if String.ends_with ~suffix:"\r" line then String.sub line 0 (String.length line - 1)
           else line)
    | Some c ->
        Buffer.add_char buffer c;
        go ()
    | None -> if Buffer.length buffer = 0 then None else Some (Buffer.contents buffer)
  in
  go ()

let arithmetic_symbol = function Core.Plus -> "+" | Core.Minus -> "-" | Core.Times -> "*"

(* trace: D56, D103. Something not decided, found only while running: the program stops with `NotDesignedYet`,
   status 3. *)
let undecided files p what =
  end_open_line ();
  print_messages files [ M.message M.Not_designed_yet (Wording.at p) ~what:(what ^ " isn't decided yet") ];
  finish 3

(* Walks the evaluator's tree of requests (core/Io.v), doing each one. *)
let rec walk files (tree : unit Core.io) =
  match tree with
  | Core.Done () -> finish 0
  | Core.Show (text, ends_line, next) ->
      print_string text;
      if ends_line then begin
        print_char '\n';
        line_open := false
      end
      else if text <> "" then line_open := true;
      flush stdout;
      walk files (next ())
  | Core.Ask (question, next) ->
      print_string question;
      flush stdout;
      if question <> "" then line_open := true;
      let answer = read_answer () in
      (* trace: D106. Typed at a terminal, the player's Enter has ended the line. *)
      if Unix.isatty Unix.stdin then line_open := false;
      walk files (next answer)
  | Core.Random (low, high, next) -> walk files (next (random_between low high))
  | Core.Stop reason -> (
      match reason with
      (* trace: D96 *)
      | Core.Input_ended -> finish 0
      (* trace: D46, D92 *)
      | Core.Overflow (p, too_big, Core.Operation_binary (a, operator, b)) ->
          end_open_line ();
          print_messages files
            [
              M.message M.Check_failed (Wording.at p)
                ~what:
                  (if too_big then "the result is too big for a `Whole`"
                   else "the result is too small for a `Whole`")
                ~when_:
                  (Printf.sprintf "%s %s %s" (Core.text_of_whole a) (arithmetic_symbol operator)
                     (Core.text_of_whole b))
                ~why:
                  "a `Whole` holds whole numbers from -9223372036854775808 to 9223372036854775807.";
            ];
          finish 4
      | Core.Overflow (p, too_big, Core.Operation_negate a) ->
          end_open_line ();
          let value = Core.text_of_whole a in
          (* trace: D142. The value is in brackets when it starts with `-`. *)
          let shown =
            if String.length value > 0 && value.[0] = '-' then "-(" ^ value ^ ")" else "-" ^ value
          in
          print_messages files
            [
              M.message M.Check_failed (Wording.at p)
                ~what:
                  (if too_big then "the result is too big for a `Whole`"
                   else "the result is too small for a `Whole`")
                ~when_:shown
                ~why:
                  "a `Whole` holds whole numbers from -9223372036854775808 to 9223372036854775807.";
            ];
          finish 4
      (* trace: D154 *)
      | Core.Calls_too_deep (p, depth, inside) ->
          end_open_line ();
          print_messages files
            [
              M.message M.Check_failed (Wording.at p) ~what:"calls went too deep"
                ~when_:(Printf.sprintf "%d calls deep, inside `%s`" depth inside)
                ~why:
                  "every call still waiting for another needs a little memory, and the room for \
                   them is limited; a procedure that keeps calling itself without stopping fills \
                   it.";
            ];
          finish 4
      (* trace: D160 *)
      | Core.Random_backwards (p, low, high) ->
          end_open_line ();
          print_messages files
            [
              M.message M.Check_failed (Wording.at p) ~what:"`random`'s `from:` is above its `to:`"
                ~when_:
                  (Printf.sprintf "from: %s, to: %s" (Core.text_of_whole low)
                     (Core.text_of_whole high))
                ~why:Wording.random_why;
            ];
          finish 4
      (* trace: D46, D70, D71, D72. Drafts, but for overflow (D92). *)
      | Core.Division_stopped (p, why, way, a, b) ->
          end_open_line ();
          let symbol =
            match way with
            | Core.Divide_exactly -> "/"
            | Core.Divide_floor -> "div.floor"
            | Core.Divide_trunc -> "div.trunc"
            | Core.Remainder_floor -> "rem.floor"
            | Core.Remainder_trunc -> "rem.trunc"
          in
          let when_ =
            Printf.sprintf "%s %s %s" (Core.text_of_whole a) symbol (Core.text_of_whole b)
          in
          let message =
            match why with
            | Core.By_zero ->
                M.message M.Check_failed (Wording.at p) ~what:"a `Whole` can't be divided by zero"
                  ~when_ ~why:"dividing by zero has no answer."
            | Core.Not_exact ->
                M.message M.Check_failed (Wording.at p)
                  ~what:
                    (Printf.sprintf "%s doesn't divide exactly by %s" (Core.text_of_whole a)
                       (Core.text_of_whole b))
                  ~when_
                  ~why:"`/` is for numbers that divide exactly; `div.floor` and `div.trunc` round."
            | Core.Quotient_too_big | Core.Divided _ ->
                M.message M.Check_failed (Wording.at p) ~what:"the result is too big for a `Whole`"
                  ~when_
                  ~why:
                    "a `Whole` holds whole numbers from -9223372036854775808 to \
                     9223372036854775807."
          in
          print_messages files [ message ];
          finish 4
      (* trace: D46, D75. A draft wording. *)
      | Core.Bad_position (p, index, from_one, length) ->
          end_open_line ();
          let label = if from_one then "pos" else "offset" in
          print_messages files
            [
              M.message M.Check_failed (Wording.at p)
                ~what:
                  (Printf.sprintf "this list has no item at `%s: %s`" label
                     (Core.text_of_whole index))
                ~when_:
                  (let n = Core.text_of_whole length in
                   if n = "1" then "the list holds 1 item"
                   else Printf.sprintf "the list holds %s items" n)
                ~why:
                  (if from_one then "`pos:` counts from 1 up to the list's length."
                   else "`offset:` counts from 0 up to one less than the list's length.");
            ];
          finish 4
      (* trace: D172. A draft wording. *)
      | Core.Range_never_ends (p, first, last, included, step) ->
          end_open_line ();
          print_messages files
            [
              M.message M.Check_failed (Wording.at p) ~what:"this `range` never reaches its end"
                ~when_:
                  (Printf.sprintf "from: %s, %s: %s, step_by: %s" (Core.text_of_whole first)
                     (if included then "to" else "before")
                     (Core.text_of_whole last) (Core.text_of_whole step))
                ~why:
                  "a range counts from `from:` toward its end, so `step_by:` points that way, and \
                   isn't 0.";
            ];
          finish 4
      (* trace: D152 *)
      | Core.Crashed (p, procedure, failure) ->
          end_open_line ();
          print_messages files
            [
              M.message M.Failed (Wording.at p)
                ~what:(Printf.sprintf "`%s` failed with `%s`" procedure failure)
                ~why:"`?? crash` stops the program when the call before it fails.";
            ];
          finish 5
      (* trace: D46, D177, D185. Drafts. *)
      | Core.Float_stopped (p, why, operation, x, y) -> (
          end_open_line ();
          let shown f = Core.text_of_float f in
          let symbol = function
            | Core.Float_plus -> "+"
            | Core.Float_minus -> "-"
            | Core.Float_times -> "*"
            | Core.Float_divide -> "/"
          in
          let when_ =
            match (operation, shown x, shown y) with
            | Some op, Some a, Some b -> Some (Printf.sprintf "%s %s %s" a (symbol op) b)
            | None, Some a, _ -> Some (Printf.sprintf "sqrt(%s)" a)
            | _ -> None
          in
          match when_ with
          | None -> undecided files p "where `~` goes on a negative number that isn't exact"
          | Some when_ ->
              let what, why =
                match why with
                | Core.Float_too_big ->
                    ( "the result is too big for a `Float`",
                      "a `Float` is always a real number, and this one is past the largest a `Float` holds." )
                | Core.Float_by_zero -> ("a `Float` can't be divided by zero", "dividing by zero has no answer.")
                | Core.Float_negative_root | Core.Float_fits _ ->
                    ( "a negative number has no square root",
                      "a `Float` is always a real number, and no real number squared is negative." )
              in
              print_messages files [ M.message M.Check_failed (Wording.at p) ~what ~when_ ~why ];
              finish 4)
      (* trace: D46, D178. A draft. *)
      | Core.Float_to_whole_too_big (p, way, x) -> (
          end_open_line ();
          let name =
            match way with
            | Core.Whole_floor -> "be.Whole.floor"
            | Core.Whole_trunc -> "be.Whole.trunc"
            | Core.Whole_ceil -> "be.Whole.ceil"
            | Core.Whole_nearest -> "be.Whole.nearest"
            | Core.Whole_nearest_even -> "be.Whole.nearest.even"
          in
          match Core.text_of_float x with
          | None -> undecided files p "where `~` goes on a negative number that isn't exact"
          | Some shown ->
              print_messages files
                [ M.message M.Check_failed (Wording.at p) ~what:"the result is too big for a `Whole`"
                    ~when_:(Printf.sprintf "%s(%s)" name shown)
                    ~why:"a `Whole` holds whole numbers from -9223372036854775808 to 9223372036854775807." ];
              finish 4)
      | Core.Undecided (p, what) -> undecided files p what
      | Core.Passing_up _ ->
          end_open_line ();
          prerr_string (M.internal_error "a failure passed up out of `proc.main`");
          finish 7
      | Core.Out_of_fuel ->
          end_open_line ();
          prerr_string (M.internal_error "the program ran more steps than Ralph can count");
          finish 7
      | Core.Stuck ->
          end_open_line ();
          prerr_string (M.internal_error "the evaluator met something it has no rule for");
          finish 7)

let position (m : M.message) = (m.at.file, m.at.line, M.first_column m.at)

(* trace: D55, D128. One chain of calls is one mistake: of the refusals for a chain and the chains inside it, only
   the outermost is kept. *)
let outermost_chains messages =
  let chain (m : M.message) = m.why = Some Wording.chain_why in
  let span (m : M.message) =
    match m.at.carets with
    | (column, width) :: _ -> (m.at.line, column, column + width)
    | [] -> (m.at.line, 0, 0)
  in
  let inside a b =
    let line_a, first_a, stop_a = span a and line_b, first_b, stop_b = span b in
    a.at.file = b.at.file && line_a = line_b && first_b <= first_a && stop_a <= stop_b
    && (first_a, stop_a) <> (first_b, stop_b)
  in
  List.filter
    (fun m -> not (chain m && List.exists (fun other -> chain other && inside m other) messages))
    messages

(* trace: D56, D92, D103 *)
let read file =
  if not (Filename.check_suffix file ".unio") then Error "a Unio file's name ends in `.unio`"
  else
    match In_channel.with_open_bin file In_channel.input_all with
    | exception Sys_error message ->
        let prefix = file ^ ": " in
        let reason =
          if String.starts_with ~prefix message then
            String.sub message (String.length prefix) (String.length message - String.length prefix)
          else message
        in
        Error reason
    | contents ->
        if String.is_valid_utf_8 contents then Ok contents else Error "it isn't UTF-8 text"

(* Everything said about a program before it runs, from its files (D64), each a name and its text: each file's name and
   lines, the definitions of all of them, and every message, in order. *)
let examine (files : (string * string) array) =
  let read_one index (_, contents) =
    let lines = Lexer.lines_of contents in
    let carriage_return =
      List.find_map
        (fun (l : Lexer.line) ->
          Option.map
            (fun i ->
              M.message M.Not_designed_yet
                (M.point l.number (i + 1) 1)
                ~what:"a `\\r` that isn't part of a line break isn't decided yet")
            (String.index_opt l.text '\r'))
        lines
    in
    let definitions, problems, stopped, stop_line = Parser.parse ~file:index lines in
    let messages =
      List.map (M.in_file index) (Option.to_list carriage_return @ problems @ Spacing.check lines)
    in
    ( Array.of_list (List.map (fun (l : Lexer.line) -> l.text) lines),
      definitions,
      messages,
      (stopped, stop_line) )
  in
  let read = Array.mapi read_one files in
  let source = Array.map (fun (lines, _, _, _) -> lines) read in
  let definitions = List.concat_map (fun (_, d, _, _) -> d) (Array.to_list read) in
  let any_stopped = Array.exists (fun (_, _, _, (stopped, _)) -> stopped) read in
  let core_problems =
    List.filter_map (Wording.diagnostic source) (Core.check_program definitions)
    |> List.filter (fun (m : M.message) ->
        let _, _, _, (stopped, stop_line) = read.(m.at.file) in
        ((not stopped) || m.at.line < stop_line)
        && not (any_stopped && m.what = Some "this program has no `proc.main`"))
  in
  let messages =
    List.stable_sort
      (fun a b -> compare (position a) (position b))
      (outermost_chains
         (List.concat_map (fun (_, _, m, _) -> m) (Array.to_list read) @ core_problems))
  in
  (Array.mapi (fun i lines -> (fst files.(i), lines)) source, definitions, messages)

(* trace: D55, D83, D102. Knock-on errors: the first error's one fix is applied in memory and the program checked
   again. Each later message that disappears follows from the first error, and says so in its `because:`. *)
let knock_ons (files : (string * string) array) messages =
  match messages with
  | ({ M.fix = Some fix; _ } as first) :: later ->
      let fixed =
        Array.mapi
          (fun index (name, contents) ->
            if index <> first.at.file then (name, contents)
            else
              let lines = String.split_on_char '\n' contents in
              ( name,
                String.concat "\n"
                  (List.mapi (fun i text -> if i + 1 = first.at.line then fix else text) lines) ))
          files
      in
      let _, _, again = examine fixed in
      (* A message on the fixed line may move along it, so there it's matched without its column. *)
      let same (a : M.message) (b : M.message) =
        a.kind = b.kind && a.what = b.what && a.why = b.why && a.at.file = b.at.file
        && a.at.line = b.at.line
        && ((a.at.file = first.at.file && a.at.line = first.at.line)
           || M.first_column a.at = M.first_column b.at)
      in
      let column = M.first_column first.at in
      first
      :: List.map
           (fun (m : M.message) ->
             if List.exists (same m) again then m
             else
               {
                 m with
                 because =
                   Some
                     ( Printf.sprintf "it follows from the error at line %d column %d" first.at.line
                         column,
                       Some first.at );
               })
           later
  | _ -> messages

(* trace: D64. The program is every `.unio` file in the given file's folder, in order of their names. Gives each one's
   name for messages and its text, and which one was given. *)
let program_files given =
  let folder = Filename.dirname given in
  let shown name = if String.contains given '/' then Filename.concat folder name else name in
  let others =
    match Sys.readdir folder with
    | names ->
        List.filter
          (fun name ->
            Filename.check_suffix name ".unio"
            && (not (Sys.is_directory (Filename.concat folder name)))
            && name <> Filename.basename given)
          (Array.to_list names)
    | exception Sys_error _ -> []
  in
  let names = List.sort compare (Filename.basename given :: others) in
  let rec gather acc = function
    | [] -> Ok (List.rev acc)
    | name :: rest -> (
        let path = if name = Filename.basename given then given else shown name in
        match read path with
        | Ok contents -> gather ((path, contents) :: acc) rest
        | Error reason -> Error (path, reason))
  in
  match gather [] names with
  | Ok files ->
      let files = Array.of_list files in
      let given_index = ref 0 in
      Array.iteri (fun i (path, _) -> if path = given then given_index := i) files;
      Ok (files, !given_index)
  | Error problem -> Error problem

let () =
  Random.self_init ();
  match Sys.argv with
  | [| _; file |] -> (
      match read file with
      | Error reason ->
          prerr_string (M.cant_read file reason);
          finish 2
      | Ok _ -> (
          match program_files file with
          | Error (path, reason) ->
              prerr_string (M.cant_read path reason);
              finish 2
          | Ok (texts, given) -> (
              Wording.given_file := given;
              let files, definitions, messages = examine texts in
              let messages = knock_ons texts messages in
              if messages <> [] then begin
                print_messages files messages;
                (* trace: D56, D148. Any refusal gives status 1; only limits alone give 3. *)
                let refused = List.exists (fun (m : M.message) -> m.kind = M.Refused) messages in
                finish (if refused then 1 else 3)
              end
              else if Core.check_program definitions <> [] then begin
                (* trace: D82. The checker passed a typed tree the second type checker refuses: Ralph's own bug. *)
                prerr_string
                  (M.internal_error
                     "the checker accepted this program, but its typed tree has a type the \
                      evaluator can't run");
                finish 7
              end
              else
                (* trace: D82, D103. Calls nested deeper than Ralph's own stack can hold are Ralph's limit, not the
                   program's mistake. *)
                match walk files (Core.run fuel call_limit definitions) with
                | () -> ()
                | exception Stack_overflow ->
                    end_open_line ();
                    prerr_string
                      (M.internal_error
                         "the program's calls are nested deeper than Ralph can follow");
                    finish 7)))
  | _ ->
      prerr_string "ralph: give it one Unio file, as in `ralph game.unio`\n";
      finish 6
