(* The parser: reads a Unio file's tokens into the core's syntax tree (core/Syntax.v).

   It refuses what's about how a program is written: `;` (D7), opening lines (D199), closers (D8), indentation (D10),
   text in single quotes (D21), `=` in a condition (D14), chains of comparisons (D81), names (D99, D192), the old
   spellings D190 and D201 replaced, and blank lines (D97). What a program means is the core's to judge
   (core/Checker.v).

   After a mistake it carries on with the next statement (D55), and a part it couldn't read becomes [Broken], which the
   checker passes over silently. When an opening line is too broken to tell what was meant, checking stops there
   (D55, rule 5). *)

open Lexer
module M = Messages

(* trace: D196. Unio's grammar words, chapter 3's table; `be`, `.same_line` and `.len` are built-ins, not keywords. *)
let keywords =
  [
    "proc";
    "end";
    "let";
    "var";
    "if";
    "else";
    "at_least";
    "at_most";
    "while";
    "break";
    "for";
    "each";
    "in";
    "true";
    "false";
    "and";
    "or";
    "not";
    "ignore";
    "crash";
    "otherwise";
    "case";
    "instead";
    "labels";
    "as";
    "extern";
    "eq";
    "not_eq";
    "return";
    "fam";
    "div";
    "rem";
    "handler";
    "include";
    "comment";
  ]

let is_keyword word = List.mem word keywords

type state = {
  tokens : token array;
  lines : Lexer.line array;
  mutable index : int;
  mutable problems : M.message list;
  mutable stopped : bool;  (** checking stopped at a broken opening line (D55, rule 5) *)
  mutable statement_line : int;  (** the line the statement being read starts on *)
  mutable spread_reported : bool;
  mutable closers : string list;  (** the closers of the blocks open now, innermost first *)
  mutable last_code_line : int;  (** the last line whose indentation was checked *)
  mutable handlers : Core.handler list;  (** the handlers read so far, last first (D42) *)
  mutable variables : string list;
      (** the names declared so far in this procedure, which a `.` or `[` after reads as a value's (D77, D79) *)
}

(* Every way a statement or expression can fail to read; the problem has already been recorded. *)
type 'a parsed = ('a, unit) result

let ( let* ) = Result.bind

let line_text st number =
  if number >= 1 && number <= Array.length st.lines then st.lines.(number - 1).text else ""

let report st m = st.problems <- m :: st.problems
let peek st = if st.index < Array.length st.tokens then Some st.tokens.(st.index) else None

let peek_ahead st k =
  if st.index + k < Array.length st.tokens then Some st.tokens.(st.index + k) else None

let previous st = if st.index > 0 then Some st.tokens.(st.index - 1) else None

(* Takes the next token, noting a statement that runs onto another line: how its later lines are indented isn't
   decided (chapter 2). *)
let advance st =
  match peek st with
  | None -> ()
  | Some t ->
      if t.line <> st.statement_line && not st.spread_reported then begin
        st.spread_reported <- true;
        report st
          (M.message M.Not_designed_yet (M.point t.line t.column t.width)
             ~what:"how a statement's later lines are indented isn't decided yet")
      end;
      st.index <- st.index + 1

let is_symbol s t = match t.kind with Symbol s' -> s = s' | _ -> false
let is_word w t = match t.kind with Word w' -> w = w' | _ -> false
let next_is st test = match peek st with Some t -> test t | None -> false
let next_is_after st k test = match peek_ahead st k with Some t -> test t | None -> false

type span = { line : int; first : int; stop : int }

let span_of (t : token) = { line = t.line; first = t.column; stop = t.column + t.width }

let join st a b =
  if a.line = b.line then { a with stop = b.stop }
  else { a with stop = String.length (line_text st a.line) + 1 }

(* Which of the program's files is being read (D64). *)
let current_file = ref 0

let place_of s =
  {
    Core.place_file = !current_file;
    place_line = s.line;
    place_column = s.first;
    place_width = s.stop - s.first;
  }

let place_of_token t = place_of (span_of t)

(* The end of the last token taken, where a missing `;` or `:` goes. *)
let after_previous st =
  match previous st with Some t -> (t.line, t.column + t.width) | None -> (1, 1)

(* trace: D92. The parser's own three messages, with no `why:`. *)
let expected st what =
  match peek st with
  | Some t when t.line = st.statement_line || st.statement_line = 0 ->
      report st
        (M.message M.Refused (M.point t.line t.column t.width)
           ~what:(Printf.sprintf "%s should be here, not `%s`" what (describe t.kind)))
  | Some _ ->
      let line, column = after_previous st in
      report st
        (M.message M.Refused (M.point line column 1)
           ~what:(Printf.sprintf "the line ends where %s should be" what))
  | None ->
      let line, column = after_previous st in
      report st
        (M.message M.Refused (M.point line column 1)
           ~what:(Printf.sprintf "the file ends where %s should be" what))

let not_built st (t : token) what =
  report st
    (M.message M.Not_built_yet (M.point t.line t.column t.width) ~what:(what ^ " aren't built yet"))

let not_built_is st (t : token) what =
  report st
    (M.message M.Not_built_yet (M.point t.line t.column t.width) ~what:(what ^ " isn't built yet"))

let not_designed st (t : token) what =
  report st
    (M.message M.Not_designed_yet (M.point t.line t.column t.width)
       ~what:(what ^ " isn't decided yet"))

(* Skips the rest of a statement that couldn't be read: up to its `;`, or the end of its line. *)
let skip_statement st =
  let rec go line =
    match peek st with
    | None -> ()
    | Some t when is_symbol ";" t -> st.index <- st.index + 1
    | Some t when t.line <> line -> ()
    | Some _ ->
        st.index <- st.index + 1;
        go line
  in
  match peek st with Some t -> go t.line | None -> ()

(* trace: D99, D102. A name: lowercase letters and digits, starting with a letter, with `_` only between words. *)
let check_name st (t : token) written name =
  let length = String.length name in
  let capital = String.exists (fun c -> c >= 'A' && c <= 'Z') name in
  if length = 0 then not_designed st t "a `$` with no name after it"
  else if capital then
    report st
      (M.message M.Refused (M.point t.line t.column t.width)
         ~what:(Printf.sprintf "`%s` has a capital letter, but names have none" written)
         ~why:
           "a name is lowercase letters and digits, starting with a letter, with `_` only between \
            words.")
  else
    (* trace: D142 *)
    let problem =
      if is_digit name.[0] then Some "starts with a digit, but names start with a letter"
      else if name.[0] = '_' then Some "starts with `_`, but names start with a letter"
      else if name.[length - 1] = '_' then Some "ends with `_`, but `_` only goes between words"
      else
        let rec doubled i =
          i + 1 < length && ((name.[i] = '_' && name.[i + 1] = '_') || doubled (i + 1))
        in
        if doubled 0 then Some "has two `_` in a row, but `_` only goes between words" else None
    in
    match problem with
    | Some problem ->
        report st
          (M.message M.Refused (M.point t.line t.column t.width)
             ~what:(Printf.sprintf "`%s` %s" written problem)
             ~why:
               "a name is lowercase letters and digits, starting with a letter, with `_` only \
                between words.")
    | None -> ()

(* ---------------------------------------------------------------------------------------------------------------- *)
(* Text *)

(* trace: D30. Text's value: `\` makes the next character literal. *)
let plain_value raw =
  let buffer = Buffer.create (String.length raw) in
  let rec go i =
    if i < String.length raw then
      if raw.[i] = '\\' && i + 1 < String.length raw then begin
        Buffer.add_char buffer raw.[i + 1];
        go (i + 2)
      end
      else begin
        Buffer.add_char buffer raw.[i];
        go (i + 1)
      end
  in
  go 0;
  Buffer.contents buffer

let all_word_characters s = String.length s > 0 && String.for_all is_word_character s

(* trace: D29, D30, D175, D200. Text's pieces: every text fills in its braces; [column] is where the text's first
   character is. Braces hold a name, or a name with `places:` (D175), as in `{speed, places: 2}`. *)
let pieces_of raw line column =
  let place_at i width =
    {
      Core.place_file = !current_file;
      place_line = line;
      place_column = column + i;
      place_width = width;
    }
  in
  let buffer = Buffer.create (String.length raw) in
  let flush pieces =
    if Buffer.length buffer = 0 then pieces
    else begin
      let text = Buffer.contents buffer in
      Buffer.clear buffer;
      Core.Piece_text text :: pieces
    end
  in
  let is_name s = all_word_characters s && is_letter s.[0] in
  let rec go i pieces =
    if i >= String.length raw then List.rev (flush pieces)
    else if raw.[i] = '\\' && i + 1 < String.length raw then begin
      Buffer.add_char buffer raw.[i + 1];
      go (i + 2) pieces
    end
    else if raw.[i] = '{' then
      match String.index_from_opt raw (i + 1) '}' with
      | None -> List.rev (Core.Piece_unclosed (place_at i 1) :: flush pieces)
      | Some j ->
          let inside = String.sub raw (i + 1) (j - i - 1) in
          let piece =
            if is_name inside then Core.Piece_name (inside, place_at (i + 1) (j - i - 1))
            else
              match String.index_opt inside ',' with
              | Some k
                when is_name (String.sub inside 0 k)
                     && String.starts_with ~prefix:", places: "
                          (String.sub inside k (String.length inside - k))
                     && String.length inside > k + 10
                     && String.for_all is_digit
                          (String.sub inside (k + 10) (String.length inside - k - 10)) ->
                  Core.Piece_places
                    ( String.sub inside 0 k,
                      place_at (i + 1) k,
                      String.sub inside (k + 10) (String.length inside - k - 10),
                      place_at (i + 1 + k + 2) (String.length inside - k - 2) )
              | _ -> Core.Piece_other (place_at (i + 1) (max 1 (j - i - 1)))
          in
          go (j + 1) (piece :: flush pieces)
    else begin
      Buffer.add_char buffer raw.[i];
      go (i + 1) pieces
    end
  in
  go 0 []

(* ---------------------------------------------------------------------------------------------------------------- *)
(* Expressions *)

(* trace: D17, D190 *)
let comparison_operator t =
  match t.kind with
  | Word "eq" -> Some Core.Equal
  | Word "not_eq" -> Some Core.Not_equal
  | Symbol "<" -> Some Core.Less
  | Symbol ">" -> Some Core.Greater
  | Word "at_least" -> Some Core.At_least
  | Word "at_most" -> Some Core.At_most
  | _ -> None

let source_of st s = String.sub (line_text st s.line) (s.first - 1) (s.stop - s.first)

(* A callee: a word and its narrowings (D18), as in `show_msg.same_line`. *)
let parse_callee st (word : token) name =
  advance st;
  let rec narrowings acc last =
    match (peek st, peek_ahead st 1) with
    | Some dot, Some ({ kind = Word n; _ } as t) when is_symbol "." dot ->
        advance st;
        advance st;
        narrowings ((n, place_of_token t) :: acc) (span_of t)
    | _ -> (List.rev acc, last)
  in
  let narrowings, last = narrowings [] (span_of word) in
  ( { Core.callee_word = name; callee_word_at = place_of_token word; callee_narrowings = narrowings },
    join st (span_of word) last )

let rec parse_expression st : (Core.expression * span) parsed = parse_slide st

(* trace: D5, D73. `|>` comes last, so a slide takes everything on its left. *)
and parse_slide st =
  let* start, start_span = parse_or st in
  if next_is st (is_symbol "|>") then
    let rec steps acc last =
      match peek st with
      | Some t when is_symbol "|>" t -> (
          advance st;
          match peek st with
          | Some ({ kind = Word name; _ } as word) when not (is_keyword name) -> (
              let callee, callee_span = parse_callee st word name in
              let* step =
                if next_is st (is_symbol "(") then (
                  let* given, close = parse_arguments st in
                  (match given with
                  | Core.No_arguments ->
                      report st
                        (M.message M.Refused
                           (M.point callee_span.line callee_span.stop (close.stop - callee_span.stop))
                           ~fix:
                             (M.replace_at (line_text st callee_span.line) callee_span.stop
                                (close.stop - callee_span.stop) "")
                           ~why:
                             "a step with nothing else to pass is written bare, since the slide \
                              gives it its value.")
                  | _ -> ());
                  Ok (callee, true, given, join st callee_span close))
                else Ok (callee, false, Core.No_arguments, callee_span)
              in
              let _, _, _, step_span = step in
              match peek st with
              (* trace: D81, D102, D128. An operator after a step goes outside the slide: brackets around a slide
                 of three calls or more, and a shorter one written as calls. *)
              | Some t when Option.is_some (binary_operator t) || is_symbol "??" t ->
                  let path =
                    List.fold_left
                      (fun rest (callee, bracketed, given, s) -> Core.Step (callee, bracketed, given, place_of s, rest))
                      Core.No_steps (step :: acc)
                  in
                  let whole = join st start_span step_span in
                  let slide = Core.Slide (start, path, place_of whole) in
                  let source = Array.make (!current_file + 1) [||] in
                  source.(!current_file) <- Array.map (fun (l : Lexer.line) -> l.text) st.lines;
                  let chain = Wording.flatten source slide in
                  let long = match chain with Some (_, links) -> List.length links >= 3 | None -> true in
                  let text = line_text st whole.line in
                  let written = String.sub text (whole.first - 1) (whole.stop - whole.first) in
                  if whole.line = start_span.line then
                    report st
                      (M.message M.Refused (M.point t.line t.column t.width)
                         ~fix:
                           (M.replace_at text whole.first (whole.stop - whole.first)
                              (if long then "(" ^ written ^ ")"
                               else match chain with Some c -> Wording.as_calls c | None -> written))
                         ~why:
                           (if long then
                              "a slide's step is a procedure, so an operator after it goes outside brackets around \
                               the slide."
                            else Wording.chain_why));
                  Error ()
              | _ -> steps (step :: acc) step_span)
          | _ ->
              expected st "a procedure";
              Error ())
      | _ ->
          let path =
            List.fold_left
              (fun rest (callee, bracketed, given, s) ->
                Core.Step (callee, bracketed, given, place_of s, rest))
              Core.No_steps acc
          in
          let whole = join st start_span last in
          Ok (Core.Slide (start, path, place_of whole), whole)
    in
    steps [] start_span
  else Ok (start, start_span)

and binary_operator t =
  match t.kind with
  | Symbol "+" -> Some Core.Add
  | Symbol "-" -> Some Core.Subtract
  | Symbol "*" -> Some Core.Multiply
  | Word "and" -> Some Core.And
  | Word "or" -> Some Core.Or
  | _ -> comparison_operator t

and left_to_right st operators next =
  let* first, first_span = next st in
  let rec loop left left_span =
    match peek st with
    | Some t -> (
        match List.assoc_opt t.kind operators with
        | Some operator ->
            advance st;
            let* right, right_span = next st in
            let whole = join st left_span right_span in
            loop (Core.Binary (operator, left, right, place_of_token t, place_of whole)) whole
        | None -> Ok (left, left_span))
    | None -> Ok (left, left_span)
  in
  loop first first_span

(* trace: D34. `not` first, then `and`, then `or`, with comparisons before all three. *)
and parse_or st = left_to_right st [ (Word "or", Core.Or) ] parse_and
and parse_and st = left_to_right st [ (Word "and", Core.And) ] parse_not

and parse_not st =
  match peek st with
  | Some t when is_word "not" t ->
      advance st;
      let* operand, operand_span = parse_not st in
      let whole = join st (span_of t) operand_span in
      Ok (Core.Not (operand, place_of whole), whole)
  | _ -> parse_comparison st

(* trace: D17, D81, D102. One comparison; two in a row are refused, with `and` as the fix. *)
and parse_comparison st =
  let* a, a_span = parse_additive st in
  match peek st with
  | Some t -> (
      match comparison_operator t with
      | None -> Ok (a, a_span)
      | Some operator -> (
          advance st;
          let* b, b_span = parse_additive st in
          let whole = join st a_span b_span in
          match peek st with
          | Some t2 when Option.is_some (comparison_operator t2) ->
              advance st;
              let* _, c_span = parse_additive st in
              if a_span.line = c_span.line then begin
                let text = line_text st a_span.line in
                let middle = source_of st b_span in
                let first_comparison =
                  String.sub text (a_span.first - 1) (b_span.stop - a_span.first)
                in
                let second_comparison =
                  middle ^ String.sub text (b_span.stop - 1) (c_span.stop - b_span.stop)
                in
                report st
                  (M.message M.Refused
                     (M.point t2.line t2.column t2.width)
                     ~fix:
                       (M.replace_at text a_span.first (c_span.stop - a_span.first)
                          (first_comparison ^ " and " ^ second_comparison))
                     ~why:
                       "a comparison sets two values against each other; `and` joins two \
                        comparisons, naming the middle value twice.")
              end;
              Error ()
          | _ -> Ok (Core.Binary (operator, a, b, place_of_token t, place_of whole), whole)))
  | None -> Ok (a, a_span)

(* trace: D27, D201. `+` and `-` read left to right. `&` isn't Unio's any more: text is joined by filling it in. *)
and parse_additive st =
  let* first, first_span =
    left_to_right st [ (Symbol "+", Core.Add); (Symbol "-", Core.Subtract) ] parse_multiplicative
  in
  match peek st with
  | Some t when is_symbol "&" t ->
      advance st;
      report st
        (M.message M.Refused (M.point t.line t.column 1) ~what:"`&` isn't how Unio joins text"
           ~why:"text is joined by filling it in with braces, as in `\"{first} {last}\"`.");
      let rec rest last =
        match parse_multiplicative st with
        | Ok (_, s) -> (
            match peek st with
            | Some u when is_symbol "&" u || is_symbol "+" u || is_symbol "-" u ->
                advance st;
                rest s
            | _ -> Ok s)
        | Error () -> Ok last
      in
      let* last = rest first_span in
      let whole = join st first_span last in
      Ok (Core.Broken (place_of whole), whole)
  | _ -> Ok (first, first_span)

(* trace: D59, D70, D71, D72. `*`, `/`, `div` and `rem`, left to right; `div` and `rem` say how they round. *)
and parse_multiplicative st =
  let* first, first_span = parse_unary st in
  let rec loop left left_span =
    let divide (t : token) way word width =
      let* right, right_span = parse_unary st in
      let whole = join st left_span right_span in
      loop
        (Core.Division
           ( way,
             word,
             left,
             right,
             { (place_of_token t) with Core.place_width = width },
             place_of whole ))
        whole
    in
    match peek st with
    | Some t when is_symbol "*" t ->
        advance st;
        let* right, right_span = parse_unary st in
        let whole = join st left_span right_span in
        loop (Core.Binary (Core.Multiply, left, right, place_of_token t, place_of whole)) whole
    | Some t when is_symbol "/" t ->
        advance st;
        divide t (Some Core.Divide_exactly) "/" 1
    | Some ({ kind = Word word; _ } as t) when word = "div" || word = "rem" -> (
        advance st;
        match (peek st, peek_ahead st 1) with
        | Some dot, Some ({ kind = Word n; _ } as nt) when is_symbol "." dot -> (
            advance st;
            advance st;
            let way =
              match (word, n) with
              | "div", "floor" -> Some Core.Divide_floor
              | "div", "trunc" -> Some Core.Divide_trunc
              | "rem", "floor" -> Some Core.Remainder_floor
              | "rem", "trunc" -> Some Core.Remainder_trunc
              | _ -> None
            in
            match way with
            | Some _ -> divide t way (word ^ "." ^ n) (nt.column + nt.width - t.column)
            | None ->
                (* trace: D102 *)
                report st
                  (M.message M.Refused
                     (M.point nt.line nt.column nt.width)
                     ~what:(Printf.sprintf "`%s` has no narrowing `.%s`" word n)
                     ~why:(Printf.sprintf "`%s`'s narrowings are `.floor` and `.trunc`." word));
                Error ())
        | _ -> divide t None word t.width)
    | _ -> Ok (left, left_span)
  in
  loop first first_span

(* trace: D27, D60. A `-` with nothing before it but an operator or a bracket negates. *)
and parse_unary st =
  match peek st with
  | Some t when is_symbol "-" t ->
      advance st;
      let* operand, operand_span = parse_unary st in
      let whole = join st (span_of t) operand_span in
      Ok (Core.Negate (operand, place_of whole), whole)
  | _ -> parse_postfix st

and parse_postfix st =
  let* value, value_span = parse_primary st in
  parse_after st value value_span

(* What may follow a value: `?`, `??` (D23, D81), a method or a fact after `.` (D77, D79), and an item in `[ ]`
   (D75). *)
and parse_after st value value_span =
  match peek st with
  | Some t when is_symbol "??" t -> (
      advance st;
      match peek st with
      | Some u when is_word "ignore" u ->
          advance st;
          let whole = join st value_span (span_of u) in
          Ok
            ( Core.Ignore_failure (value, place_of (join st (span_of t) (span_of u)), place_of whole),
              whole )
      | Some u when is_word "crash" u ->
          advance st;
          let whole = join st value_span (span_of u) in
          Ok
            ( Core.Crash_on_failure
                (value, place_of (join st (span_of t) (span_of u)), place_of whole),
              whole )
      | _ ->
          let* fallback, fallback_span =
            match peek st with
            | Some m when is_symbol "-" m ->
                advance st;
                let* operand, operand_span = parse_primary st in
                let whole = join st (span_of m) operand_span in
                Ok (Core.Negate (operand, place_of whole), whole)
            | _ -> parse_primary st
          in
          let whole = join st value_span fallback_span in
          Ok (Core.Fallback (value, fallback, place_of_token t, place_of whole), whole))
  | Some t when is_symbol "?" t ->
      advance st;
      let whole = join st value_span (span_of t) in
      parse_after st (Core.Pass_up (value, place_of_token t, place_of whole)) whole
  | Some t when is_symbol "." t -> (
      advance st;
      match peek st with
      | Some ({ kind = Word n; _ } as nt) ->
          advance st;
          if next_is st (is_symbol "(") then
            let* given, close = parse_arguments st in
            let whole = join st value_span close in
            parse_after st (Core.Method (value, n, place_of_token nt, given, place_of whole)) whole
          else
            let whole = join st value_span (span_of nt) in
            parse_after st (Core.Fact (value, n, place_of_token nt, place_of whole)) whole
      | _ ->
          expected st "a method or a fact";
          Error ())
  | Some t when is_symbol "[" t ->
      advance st;
      let label, label_at =
        match (peek st, peek_ahead st 1) with
        | Some ({ kind = Word w; _ } as l), Some colon when is_symbol ":" colon ->
            advance st;
            advance st;
            (w, place_of_token l)
        | Some u, _ -> ("", place_of_token u)
        | None, _ -> ("", place_of_token t)
      in
      let* index, _ = parse_expression st in
      let* close = expect_closing st "]" in
      let whole = join st value_span close in
      parse_after st (Core.Item (value, label, label_at, index, place_of whole)) whole
  | _ -> Ok (value, value_span)

and parse_primary st =
  match peek st with
  | None ->
      expected st "a value";
      Error ()
  | Some t -> (
      match t.kind with
      | Number digits ->
          advance st;
          Ok (Core.Whole_literal (digits, place_of_token t), span_of t)
      (* trace: D155, D180 *)
      | Decimal (before, after) ->
          advance st;
          Ok (Core.Float_literal (before, after, false, place_of_token t), span_of t)
      | Symbol "~" -> (
          advance st;
          match peek st with
          | Some ({ kind = Decimal (before, after); _ } as d) ->
              advance st;
              let whole = join st (span_of t) (span_of d) in
              Ok (Core.Float_literal (before, after, true, place_of whole), whole)
          | _ ->
              expected st "a number with a point";
              Error ())
      | Text raw ->
          advance st;
          Ok (Core.Text_literal (pieces_of raw t.line (t.column + 1), place_of_token t), span_of t)
      | Single_quoted raw ->
          advance st;
          report st
            (M.message M.Refused (M.point t.line t.column t.width)
               ~fix:(M.replace_at (line_text st t.line) t.column t.width ("\"" ^ raw ^ "\""))
               ~why:"text is written in double quotes, never single ones like `'hi'`.");
          Ok (Core.Broken (place_of_token t), span_of t)
      | Unclosed_text _ ->
          advance st;
          let line, column = (t.line, t.column + t.width) in
          report st
            (M.message M.Refused (M.point line column 1) ~what:"the line ends where `\"` should be");
          Error ()
      | Word "true" ->
          advance st;
          Ok (Core.Bool_literal (true, place_of_token t), span_of t)
      | Word "false" ->
          advance st;
          Ok (Core.Bool_literal (false, place_of_token t), span_of t)
      (* trace: D170 *)
      | Word "range" when next_is_after st 1 (is_symbol "[") ->
          advance st;
          let* given, close = parse_arguments_until st "]" in
          let whole = join st (span_of t) close in
          Ok (Core.Range (given, place_of whole), whole)
      | Word name when (not (is_keyword name)) && List.mem name st.variables ->
          advance st;
          Ok (Core.Variable_value (name, place_of_token t), span_of t)
      | Word name when not (is_keyword name) -> (
          let callee, callee_span = parse_callee st t name in
          if next_is st (is_symbol "(") then
            let* given, close = parse_arguments st in
            let whole = join st callee_span close in
            Ok (Core.Call (callee, given, place_of whole), whole)
          else
            match callee.callee_narrowings with
            | [] -> Ok (Core.Variable_value (name, place_of_token t), span_of t)
            | [ (n, n_at) ] when not (List.mem name [ "show_msg"; "be"; "ask"; "random"; "sqrt" ])
              ->
                Ok
                  ( Core.Fact
                      (Core.Variable_value (name, place_of_token t), n, n_at, place_of callee_span),
                    callee_span )
            | _ -> Ok (Core.Bare_word (name, place_of callee_span), callee_span))
      | Symbol "(" ->
          advance st;
          let* inner, _ = parse_expression st in
          let* close = expect_closing st ")" in
          let whole = join st (span_of t) close in
          Ok (Core.Bracketed (inner, place_of whole), whole)
      (* trace: D75, D76, D169 *)
      | Symbol "[" -> (
          match (peek_ahead st 1, peek_ahead st 2) with
          | Some { kind = Word "all"; _ }, Some colon when is_symbol ":" colon ->
              advance st;
              advance st;
              advance st;
              let* value, _ = parse_expression st in
              let* close = expect_closing st "]" in
              let whole = join st (span_of t) close in
              Ok (Core.All_literal (value, place_of whole), whole)
          | _ ->
              let* items, close = parse_arguments_until st "]" in
              let whole = join st (span_of t) close in
              Ok (Core.List_literal (items, place_of whole), whole))
      (* trace: D64. A package's name in front of a procedure's; the manifest packages are listed in isn't decided. *)
      | Symbol "::" ->
          not_designed st t "the manifest that lists packages";
          Error ()
      | _ ->
          expected st "a value";
          Error ())

and expect_closing st symbol =
  match peek st with
  | Some t when is_symbol symbol t ->
      advance st;
      Ok (span_of t)
  | _ ->
      expected st ("`" ^ symbol ^ "`");
      Error ()

(* A call's arguments, each with its label if it's written with one (D24). Gives the closing bracket's place. *)
and parse_arguments st = parse_arguments_until st ")"

(* Values separated by commas, each with its label if it has one, up to [close]: a call's `( )`, or a list's or a
   range's `[ ]` (D24, D75, D170). *)
and parse_arguments_until st close =
  advance st;
  if next_is st (is_symbol close) then
    match peek st with
    | Some t ->
        advance st;
        Ok (Core.No_arguments, span_of t)
    | None -> Error ()
  else
    let rec loop acc =
      let label =
        match (peek st, peek_ahead st 1) with
        | Some ({ kind = Word w; _ } as t), Some colon
          when is_symbol ":" colon && not (is_keyword w) ->
            advance st;
            advance st;
            Some (w, place_of_token t)
        | _ -> None
      in
      let* value, _ = parse_expression st in
      match peek st with
      | Some t when is_symbol "," t ->
          advance st;
          loop ((label, value) :: acc)
      | _ ->
          let* closing = expect_closing st close in
          let given =
            List.fold_left
              (fun rest (label, value) -> Core.Argument (label, value, rest))
              Core.No_arguments ((label, value) :: acc)
          in
          Ok (given, closing)
    in
    loop []

(* ---------------------------------------------------------------------------------------------------------------- *)
(* Lines and blocks *)

(* trace: D10. Checks that a statement, opening line or closer starts its line, indented [depth] levels of 4 spaces. *)
let begin_line st (t : token) depth =
  st.statement_line <- t.line;
  st.spread_reported <- false;
  let text = line_text st t.line in
  let first_on_line =
    match st.lines.(t.line - 1).tokens with first :: _ -> first.column = t.column | [] -> false
  in
  if not first_on_line then
    (* trace: D146 *)
    report st
      (M.message M.Refused
         (M.point t.line t.column (String.length text - t.column + 1))
         ~what:"this line has two statements" ~why:"each statement goes on a line of its own.")
  else begin
    (* Lines holding only a comment, since the last line checked. *)
    for number = st.last_code_line + 1 to t.line - 1 do
      let l = st.lines.(number - 1) in
      if l.tokens = [] && l.comment && not l.hidden then begin
        (* trace: D145. Indented like the line after it, or one level in right before a closer or `else`. *)
        let content = String.trim l.text in
        let indent = String.length l.text - String.length content in
        let levels = if is_word "end" t || is_word "else" t then depth + 1 else depth in
        let wanted = String.make (4 * levels) ' ' in
        if String.sub l.text 0 indent <> wanted then
          report st
            (M.message M.Refused (M.point number 1 indent) ~fix:(wanted ^ content)
               ~why:"each level of indentation is 4 spaces, and tabs aren't used.")
      end
    done;
    st.last_code_line <- t.line;
    let indentation = String.sub text 0 (t.column - 1) in
    if indentation <> String.make (4 * depth) ' ' then
      report st
        (M.message M.Refused
           (M.point t.line 1 (String.length indentation))
           ~fix:
             (String.make (4 * depth) ' '
             ^ String.sub text (t.column - 1) (String.length text - t.column + 1))
           ~why:"each level of indentation is 4 spaces, and tabs aren't used.")
  end

(* trace: D7. Every statement ends with `;`; a missing one is refused with the place it goes as the fix. *)
let expect_semicolon st =
  match peek st with
  | Some t when is_symbol ";" t -> advance st
  | Some t when t.line = st.statement_line ->
      expected st "`;`";
      skip_statement st
  | _ ->
      let line, column = after_previous st in
      report st
        (M.message M.Refused (M.point line column 1)
           ~fix:(M.insert_at (line_text st line) column ";")
           ~why:"every statement ends with `;`.")

(* trace: D55, D199. An opening line ends with nothing. One ending with `:`, as Python writes it, is refused with the
   line without it as the fix, and checking carries on into the body, since it's clear what was meant; anything else
   after the opening line stops checking there. *)
let expect_opener_end st =
  match peek st with
  | Some t
    when is_symbol ":" t && t.line = st.statement_line
         && not (next_is_after st 1 (fun u -> u.line = t.line)) ->
      advance st;
      let text = line_text st t.line in
      let rec spaces_before i = if i > 0 && text.[i - 1] = ' ' then spaces_before (i - 1) else i in
      let from = spaces_before (t.column - 1) in
      report st
        (M.message M.Refused (M.point t.line t.column 1)
           ~fix:(M.replace_at text (from + 1) (t.column - from) "")
           ~why:"a block's opening line ends with nothing; `end` shows where the block ends.")
  | Some t when t.line = st.statement_line ->
      expected st "the end of the line";
      st.stopped <- true
  | _ -> ()

(* The words of a closer, as in ["end"; "proc"; "."; "main"]. *)
let closer_words st =
  let rec go line acc =
    match peek_ahead st (List.length acc) with
    | Some t when t.line = line && not (is_symbol ";" t) -> go line (describe t.kind :: acc)
    | _ -> List.rev acc
  in
  match peek st with Some t -> go t.line [] | None -> []

(* A closer's words as written, with no spaces around a `.`, as in `end fam.proc show_msg`. *)
let closer_text words =
  let rec go acc = function
    | [] -> acc
    | "." :: next :: rest -> go (acc ^ "." ^ next) rest
    | w :: rest -> go (if acc = "" then w else acc ^ " " ^ w) rest
  in
  go "" words

(* trace: D8, D85, D87. Reads the closer [wanted] at [depth]. *)
let parse_closer st depth wanted =
  match peek st with
  | None ->
      let last = Array.length st.lines in
      report st
        (M.message M.Refused
           (M.point last (String.length (line_text st last) + 1) 1)
           ~what:(Printf.sprintf "the file ends before `%s`" wanted)
           ~why:"every block ends with `end` and what it closes.")
  | Some t ->
      let found = closer_text (closer_words st) in
      if found = wanted then begin
        begin_line st t depth;
        List.iter (fun _ -> advance st) (closer_words st);
        match peek st with
        | Some semicolon when is_symbol ";" semicolon && semicolon.line = t.line ->
            advance st;
            report st
              (M.message M.Refused
                 (M.point semicolon.line semicolon.column 1)
                 ~fix:(M.replace_at (line_text st t.line) semicolon.column 1 "")
                 ~why:"a closer stands alone, with no `;`.")
        | _ -> ()
      end
      else if List.mem found st.closers then
        (* The closer of a block further out: this block's own closer is missing. *)
        report st
          (M.message M.Refused (M.point t.line t.column t.width)
             ~what:(Printf.sprintf "`%s` is missing before this line" wanted)
             ~why:"every block ends with `end` and what it closes.")
      else begin
        begin_line st t depth;
        let text = line_text st t.line in
        report st
          (M.message M.Refused
             (M.point t.line t.column (String.length text - t.column + 1))
             ~fix:(String.make (4 * depth) ' ' ^ wanted)
             ~why:"a closer is `end` and what it closes.");
        let rec skip () =
          match peek st with
          | Some u when u.line = t.line ->
              advance st;
              skip ()
          | _ -> ()
        in
        skip ()
      end

(* A whole number written plainly, as a type's setting (D167). *)
let plain_whole st =
  match peek st with
  | Some { kind = Number digits; _ } -> (
      advance st;
      match Core.whole_of_literal digits with Some n -> Ok n | None -> Error ())
  | _ ->
      expected st "a whole number";
      Error ()

(* trace: D74. `comment name`, its hidden lines (Lexer.hide_comment_blocks), and `end comment name`. *)
let parse_comment_block st (t : token) depth =
  advance st;
  match peek st with
  | Some ({ kind = Word name; _ } as n) when n.line = t.line ->
      advance st;
      check_name st n name name;
      expect_opener_end st;
      st.closers <- ("end comment " ^ name) :: st.closers;
      if not st.stopped then parse_closer st depth ("end comment " ^ name);
      st.closers <- (match st.closers with _ :: rest -> rest | [] -> [])
  | _ ->
      expected st "the comment's name";
      st.stopped <- true

(* trace: D13, D15, D21, D33, D75, D161, D167 *)
let rec parse_type st : Core.type0 parsed =
  match peek st with
  | Some { kind = Word "Whole"; _ } ->
      advance st;
      Ok Core.Whole
  | Some { kind = Word "Bool"; _ } ->
      advance st;
      Ok Core.Bool
  | Some { kind = Word "Text"; _ } ->
      advance st;
      Ok Core.Text
  | Some ({ kind = Word (("List" | "Array") as which); _ } as t) ->
      advance st;
      let* _ = expect_closing st "<" in
      let* item = parse_type st in
      let* _ = expect_closing st ">" in
      let setting name =
        match (peek st, peek_ahead st 1) with
        | Some l, Some c when is_word name l && is_symbol ":" c ->
            advance st;
            advance st;
            Ok ()
        | Some l, Some d when name = "len.max" && is_word "len" l && is_symbol "." d -> (
            match (peek_ahead st 2, peek_ahead st 3) with
            | Some m, Some c when is_word "max" m && is_symbol ":" c ->
                advance st;
                advance st;
                advance st;
                advance st;
                Ok ()
            | _ ->
                expected st "`len.max:`";
                Error ())
        | _ ->
            expected st (Printf.sprintf "`%s:`" name);
            Error ()
      in
      if which = "List" then
        if next_is st (is_symbol "[") then begin
          advance st;
          let* () = setting "len.max" in
          let* most = plain_whole st in
          let* _ = expect_closing st "]" in
          Ok (Core.List_of (item, Some most))
        end
        else Ok (Core.List_of (item, None))
      else if next_is st (is_symbol "[") then begin
        advance st;
        let* () = setting "len" in
        let* length = plain_whole st in
        let* _ = expect_closing st "]" in
        Ok (Core.Array_of (item, length))
      end
      else begin
        (* trace: D167. A draft wording. *)
        report st
          (M.message M.Refused (M.point t.line t.column t.width)
             ~what:"an `Array` says how many items it holds, as in `Array<Whole>[len: 4]`"
             ~why:"an array always holds the same number of items, written in its type.");
        Error ()
      end
  | Some { kind = Word "Float"; _ } ->
      advance st;
      Ok Core.Float
  | Some ({ kind = Word w; _ } as t) when String.length w > 0 && w.[0] >= 'A' && w.[0] <= 'Z' ->
      (* trace: D161 *)
      report st
        (M.message M.Refused (M.point t.line t.column t.width)
           ~what:(Printf.sprintf "there's no type named `%s`" w)
           ~why:"a type is one Unio has, like `Whole`, `Float`, `Bool` or `Text`.");
      Error ()
  | _ ->
      expected st "a type";
      Error ()

let statement_span st (t : token) =
  let last =
    match previous st with
    | Some p when p.line = t.line -> p.column + p.width
    | _ -> t.column + t.width
  in
  { line = t.line; first = t.column; stop = last }

(* trace: D58, D87, D192. A keyword where a name goes: refused, and read on as if it were a name. *)
let keyword_as_name st (t : token) name =
  report st
    (M.message M.Refused (M.point t.line t.column t.width)
       ~what:(Printf.sprintf "`%s` is a keyword, so it can't be a name" name)
       ~why:"a name can't be one of Unio's own words.")

(* trace: D13. `let` or `var`, the name, `:`, the type, `=` and the first value. *)
let parse_declaration st (keyword : token) changeable : Core.statement parsed =
  advance st;
  match peek st with
  | Some ({ kind = Word name; _ } as name_token)
    when not
           (String.length name > 0
           && name.[0] >= 'A'
           && name.[0] <= 'Z'
           && next_is_after st 1 (fun u -> not (is_symbol ":" u))) ->
      advance st;
      if is_keyword name then keyword_as_name st name_token name
      else check_name st name_token name name;
      let* written =
        match peek st with
        | Some t when is_symbol ":" t ->
            advance st;
            parse_type st
        | Some ({ kind = Word w; _ } as t) when w = "Whole" || w = "Bool" || w = "Text" ->
            report st
              (M.message M.Refused
                 (M.point t.line (name_token.column + name_token.width) 1)
                 ~fix:(M.insert_at (line_text st t.line) (name_token.column + name_token.width) ":")
                 ~why:"a declaration writes `:` between the variable's name and its type.");
            parse_type st
        | Some t when is_symbol "=" t ->
            report st
              (M.message M.Refused
                 (M.point name_token.line name_token.column name_token.width)
                 ~what:(Printf.sprintf "`%s` needs its type, written after a `:`" name)
                 ~why:"a declaration always writes the variable's type.");
            Error ()
        | _ ->
            expected st "`:`";
            Error ()
      in
      let* () =
        match peek st with
        | Some t when is_symbol "=" t ->
            advance st;
            Ok ()
        | Some t when is_symbol ";" t ->
            not_designed st t "declaring a variable without a first value";
            Error ()
        | Some t when t.line = keyword.line ->
            let column = match previous st with Some p -> p.column + p.width | None -> t.column in
            report st
              (M.message M.Refused (M.point t.line column 1)
                 ~fix:(M.insert_at (line_text st t.line) column " =")
                 ~why:"a declaration gives its variable a first value after `=`.");
            Ok ()
        | _ ->
            expected st "`=`";
            Error ()
      in
      let value =
        match parse_expression st with
        | Ok (value, _) -> value
        | Error () -> Core.Broken (place_of_token keyword)
      in
      st.variables <- name :: st.variables;
      (match value with
      | Core.Broken _ -> skip_statement st
      | _ -> if not (next_is st (is_word "otherwise")) then expect_semicolon st);
      Ok
        (Core.Declare
           ( changeable,
             name,
             place_of_token name_token,
             place_of_token keyword,
             written,
             value,
             place_of (statement_span st keyword) ))
  | _ ->
      expected st "a variable's name";
      Error ()

(* The condition of `if`, `else if` or `while`: `=` in it is refused, with `eq` as the fix (D14, D190). *)
let parse_condition st : Core.expression =
  match parse_expression st with
  | Ok (condition, _) -> (
      match peek st with
      | Some t when is_symbol "=" t && t.line = st.statement_line ->
          report st
            (M.message M.Refused (M.point t.line t.column 1)
               ~fix:(M.replace_at (line_text st t.line) t.column 1 "eq")
               ~why:"`=` gives a variable a value, and is never part of a condition; `eq` compares.");
          advance st;
          let _ = parse_expression st in
          Core.Broken (place_of_token t)
      | _ -> condition)
  | Error () ->
      let rec skip () =
        match peek st with
        | Some t when t.line = st.statement_line ->
            advance st;
            skip ()
        | _ -> ()
      in
      skip ();
      Core.Broken
        {
          Core.place_file = !current_file;
          place_line = st.statement_line;
          place_column = 1;
          place_width = 1;
        }

let rec parse_block st depth : Core.block =
  let rec statements acc =
    if st.stopped then List.rev acc
    else
      match peek st with
      | None -> List.rev acc
      | Some t when is_word "end" t || is_word "else" t || is_word "case" t || is_word "include" t
        ->
          List.rev acc
      | Some t when is_word "comment" t ->
          begin_line st t depth;
          parse_comment_block st t depth;
          statements acc
      | Some t -> (
          begin_line st t depth;
          match parse_statement st t depth with
          | Ok statement -> statements (statement :: acc)
          | Error () ->
              skip_statement st;
              statements acc)
  in
  List.fold_right (fun statement rest -> Core.Then (statement, rest)) (statements []) Core.Empty

and parse_statement st (t : token) depth : Core.statement parsed =
  match t.kind with
  | Word "let" ->
      let* declared = parse_declaration st t false in
      with_otherwise st depth t declared
  | Word "var" ->
      let* declared = parse_declaration st t true in
      with_otherwise st depth t declared
  | Word "if" -> parse_if st t depth
  | Word "while" ->
      advance st;
      let condition = parse_condition st in
      expect_opener_end st;
      let at = place_of (statement_span st t) in
      st.closers <- "end while" :: st.closers;
      let body = parse_block st (depth + 1) in
      st.closers <- (match st.closers with _ :: rest -> rest | [] -> []);
      if not st.stopped then parse_closer st depth "end while";
      Ok (Core.While (condition, body, at))
  | Word "break" ->
      advance st;
      let at = place_of (statement_span st t) in
      expect_semicolon st;
      Ok (Core.Break at)
  | Word "return" ->
      advance st;
      if next_is st (is_symbol ";") then begin
        let at = place_of (statement_span st t) in
        advance st;
        Ok (Core.Return (None, at))
      end
      else
        let* value, _ = parse_expression st in
        let at = place_of (statement_span st t) in
        expect_semicolon st;
        Ok (Core.Return (Some value, at))
  | Word "labels" -> parse_labels st t
  | Word ("otherwise" | "case" | "include") ->
      expected st "a statement";
      Error ()
  (* trace: D40 *)
  | Word "instead" ->
      advance st;
      let* value, _ = parse_expression st in
      let at = place_of (statement_span st t) in
      expect_semicolon st;
      Ok (Core.Instead (value, at))
  | Word "for" -> parse_for st t depth
  (* trace: D80. `list[pos: n] = value;` *)
  | Word name when List.mem name st.variables && next_is_after st 1 (is_symbol "[") && sets_item st
    ->
      advance st;
      advance st;
      let label, label_at =
        match (peek st, peek_ahead st 1) with
        | Some ({ kind = Word w; _ } as l), Some colon when is_symbol ":" colon ->
            advance st;
            advance st;
            (w, place_of_token l)
        | Some u, _ -> ("", place_of_token u)
        | None, _ -> ("", place_of_token t)
      in
      let* index, _ = parse_expression st in
      let* _ = expect_closing st "]" in
      let operator = peek st in
      advance st;
      let* value, _ = parse_expression st in
      let at = place_of (statement_span st t) in
      expect_semicolon st;
      let operator_at =
        match operator with Some o -> place_of_token o | None -> place_of_token t
      in
      Ok (Core.Set_item (name, place_of_token t, label, label_at, index, value, operator_at, at))
  | Word name
    when (not (is_keyword name))
         && match peek_ahead st 1 with Some u -> is_symbol "=" u | None -> false ->
      advance st;
      let operator = peek st in
      advance st;
      let* value, _ = parse_expression st in
      let at = place_of (statement_span st t) in
      if not (next_is st (is_word "otherwise")) then expect_semicolon st;
      let operator_at =
        match operator with Some o -> place_of_token o | None -> place_of_token t
      in
      with_otherwise st depth t (Core.Assign (name, place_of_token t, value, operator_at, at))
  | _ ->
      let* action, _ = parse_expression st in
      let at = place_of (statement_span st t) in
      if not (next_is st (is_word "otherwise")) then expect_semicolon st;
      with_otherwise st depth t (Core.Run (action, at))

(* Whether the tokens ahead are `name[…] =`, setting an item (D80). *)
and sets_item st =
  let rec scan i depth =
    match peek_ahead st i with
    | None -> false
    | Some u when is_symbol "[" u -> scan (i + 1) (depth + 1)
    | Some u when is_symbol "]" u ->
        if depth = 1 then
          match peek_ahead st (i + 1) with Some e -> is_symbol "=" e | None -> false
        else scan (i + 1) (depth - 1)
    | Some u when is_symbol ";" u -> false
    | Some _ -> scan (i + 1) depth
  in
  scan 1 0

(* trace: D23, D40, D186. A statement followed by `otherwise`: its call's failures handled case by case. *)
and with_otherwise st depth (start : token) attempt : Core.statement parsed =
  match peek st with
  | Some o when is_word "otherwise" o -> (
      advance st;
      match peek st with
      | Some h when h.line = o.line -> (
          (* trace: D42, D44. `otherwise family.handler;`, its cases used as if written there. *)
          match handler_use st with
          | Some (name, name_at, jump, given, use_at) ->
              let at = place_of (statement_span st start) in
              expect_semicolon st;
              Ok (Core.Handled (attempt, Core.Included (name, name_at, jump, given, use_at, Core.No_cases), place_of_token o, at))
          | None ->
              st.stopped <- true;
              Error ())
      | _ ->
          let at = place_of (statement_span st start) in
          st.closers <- "end otherwise" :: st.closers;
          let rec cases acc =
            if st.stopped then List.rev acc
            else
              match peek st with
              | Some c when is_word "case" c -> (
                  begin_line st c (depth + 1);
                  advance st;
                  match peek st with
                  | Some ({ kind = Word f; _ } as ft) ->
                      advance st;
                      let case_at = place_of (statement_span st c) in
                      expect_opener_end st;
                      let body = parse_block st (depth + 2) in
                      cases (`Case (f, place_of_token ft, body, case_at) :: acc)
                  | _ ->
                      expected st "a failure's name";
                      st.stopped <- true;
                      List.rev acc)
              (* trace: D43 *)
              | Some c when is_word "include" c -> (
                  begin_line st c (depth + 1);
                  advance st;
                  match handler_use st with
                  | Some use ->
                      expect_semicolon st;
                      cases (`Include use :: acc)
                  | None ->
                      st.stopped <- true;
                      List.rev acc)
              | _ -> List.rev acc
          in
          let found = cases [] in
          st.closers <- (match st.closers with _ :: rest -> rest | [] -> []);
          if not st.stopped then parse_closer st depth "end otherwise";
          Ok (Core.Handled (attempt, fold_cases found, place_of_token o, at)))
  | _ -> Ok attempt

and fold_cases found =
  List.fold_right
    (fun one rest ->
      match one with
      | `Case (f, f_at, body, case_at) -> Core.Case (f, f_at, body, case_at, rest)
      | `Include (name, name_at, jump, given, use_at) -> Core.Included (name, name_at, jump, given, use_at, rest))
    found Core.No_cases

(* trace: D42, D44. A handler where it's used: `family.handler`, `family.*handler` for one that can jump, and its
   arguments in `( )`. *)
and handler_use st =
  match (peek st, peek_ahead st 1, peek_ahead st 2) with
  | Some ({ kind = Word word; _ } as w), Some d, Some ({ kind = Word name; _ } as n)
    when is_symbol "." d || is_symbol ".*" d -> (
      advance st;
      advance st;
      advance st;
      let full = word ^ "." ^ name in
      let name_at = place_of (join st (span_of w) (span_of n)) in
      let given = if next_is st (is_symbol "(") then parse_arguments st else Ok (Core.No_arguments, span_of n) in
      match given with
      | Ok (given, close) -> Some (full, name_at, is_symbol ".*" d, given, place_of (join st (span_of w) close))
      | Error () -> None)
  | _ ->
      expected st "a handler, as in `word_failed.use_placeholder`";
      None

(* trace: D171, D174. `for each item at pos i in source`, its body, and `end for`. *)
and parse_for st (t : token) depth =
  advance st;
  let* () =
    match peek st with
    | Some e when is_word "each" e ->
        advance st;
        Ok ()
    | _ ->
        expected st "`each`";
        st.stopped <- true;
        Error ()
  in
  let name_of () =
    match peek st with
    | Some ({ kind = Word n; _ } as nt) ->
        advance st;
        if is_keyword n then keyword_as_name st nt n else check_name st nt n n;
        st.variables <- n :: st.variables;
        Ok (n, place_of_token nt)
    | _ ->
        expected st "a name";
        st.stopped <- true;
        Error ()
  in
  let* item, item_at = name_of () in
  let* position, from_one =
    match (peek st, peek_ahead st 1) with
    | Some a, Some { kind = Word (("pos" | "offset") as which); _ } when is_word "at" a ->
        advance st;
        advance st;
        let* i = name_of () in
        Ok (Some i, which = "pos")
    | _ -> Ok (None, true)
  in
  let* () =
    match peek st with
    | Some i when is_word "in" i ->
        advance st;
        Ok ()
    | _ ->
        expected st "`in`";
        st.stopped <- true;
        Error ()
  in
  let* source, _ = parse_expression st in
  let at = place_of (statement_span st t) in
  expect_opener_end st;
  st.closers <- "end for" :: st.closers;
  let body = parse_block st (depth + 1) in
  st.closers <- (match st.closers with _ :: rest -> rest | [] -> []);
  if not st.stopped then parse_closer st depth "end for";
  Ok (Core.For_each (item, item_at, position, from_one, source, body, at))

(* trace: D16, D102. `if`, any number of `else if`, at most one `else:`, and one `end if`. *)
and parse_if st (t : token) depth =
  advance st;
  let condition = parse_condition st in
  expect_opener_end st;
  let at = place_of (statement_span st t) in
  st.closers <- "end if" :: st.closers;
  let then_part = parse_block st (depth + 1) in
  let rec rest () =
    if st.stopped then Core.No_else
    else
      match peek st with
      | Some e when is_word "else" e -> (
          begin_line st e depth;
          advance st;
          match peek st with
          | Some i when is_word "if" i ->
              advance st;
              let condition = parse_condition st in
              expect_opener_end st;
              let at = place_of (statement_span st e) in
              let body = parse_block st (depth + 1) in
              let others = rest () in
              Core.Else_if (condition, body, others, at)
          | _ ->
              expect_opener_end st;
              let at = place_of (statement_span st e) in
              let body = parse_block st (depth + 1) in
              (match peek st with
              | Some extra when is_word "else" extra ->
                  report st
                    (M.message M.Refused
                       (M.point extra.line extra.column extra.width)
                       ~what:"nothing can follow an `if`'s `else` part but `end if`"
                       ~why:"an `if` has at most one `else`, and it comes last.");
                  st.stopped <- true
              | _ -> ());
              Core.Else (body, at))
      | _ -> Core.No_else
  in
  let otherwise = rest () in
  st.closers <- (match st.closers with _ :: rest -> rest | [] -> []);
  if not st.stopped then parse_closer st depth "end if";
  Ok (Core.If (condition, then_part, otherwise, at))

(* trace: D25, D195. `labels [parameter as label, ...];`. Without its `[ ]` it's refused, with them as the fix, and
   read on. *)
and parse_labels st (t : token) =
  advance st;
  let bracketed = next_is st (is_symbol "[") in
  if bracketed then advance st;
  let rec pairs acc =
    match (peek st, peek_ahead st 1, peek_ahead st 2) with
    | Some ({ kind = Word parameter; _ } as p), Some a, Some ({ kind = Word label; _ } as l)
      when is_word "as" a && not (is_keyword parameter) -> (
        advance st;
        advance st;
        advance st;
        check_name st l label label;
        let pair =
          {
            Core.pair_parameter = parameter;
            pair_parameter_at = place_of_token p;
            pair_label = label;
            pair_label_at = place_of_token l;
          }
        in
        match peek st with
        | Some c when is_symbol "," c ->
            advance st;
            pairs (pair :: acc)
        | _ -> Ok (List.rev (pair :: acc)))
    | _ ->
        expected st "a parameter and its label, as in `low as from`";
        Error ()
  in
  let* found = pairs [] in
  let* () =
    if bracketed then (
      match peek st with
      | Some c when is_symbol "]" c ->
          advance st;
          Ok ()
      | _ ->
          expected st "`]`";
          Error ())
    else
      match previous st with
      | Some last when last.line = t.line ->
          let text = line_text st t.line in
          let first = t.column + t.width + 1 in
          let stop = last.column + last.width in
          report st
            (M.message M.Refused
               (M.point t.line first (stop - first))
               ~fix:(M.insert_at (M.insert_at text stop "]") first "[")
               ~why:"a `labels` line puts its pairs in `[ ]`.");
          Ok ()
      | _ -> Ok ()
  in
  let at = place_of (statement_span st t) in
  expect_semicolon st;
  Ok (Core.Labels (found, at))

(* trace: D4, D88, D126, D165. A definition's parameters in `[ ]`, each its name, `:` and its type. *)
let parse_parameters st (open_bracket : token) : Core.parameter list parsed =
  advance st;
  match peek st with
  | Some close when is_symbol "]" close ->
      advance st;
      report st
        (M.message M.Refused
           (M.point open_bracket.line open_bracket.column 2)
           ~fix:(M.replace_at (line_text st open_bracket.line) open_bracket.column 2 "")
           ~why:"a definition writes `[ ]` only when it has parameters.");
      Ok []
  | Some ({ kind = Word w; _ } as t)
    when String.length w > 0
         && w.[0] >= 'A'
         && w.[0] <= 'Z'
         && not (next_is_after st 1 (is_symbol ":")) -> (
      (* trace: D61, D126, D132. A type written once in front, as in `[Whole a, b]`: refused, with each parameter
         writing its own type as the fix, and read on as that. *)
      let type_start = t.column in
      match parse_type st with
      | Error () -> Error ()
      | Ok written ->
          let type_text =
            match previous st with
            | Some last when last.line = t.line -> String.sub (line_text st t.line) (type_start - 1) (last.column + last.width - type_start)
            | _ -> describe t.kind
          in
          let rec names acc =
            match peek st with
            | Some ({ kind = Word n; _ } as nt) -> (
                advance st;
                check_name st nt n n;
                let acc = { Core.parameter_name = n; parameter_at = place_of_token nt; parameter_type = written } :: acc in
                match peek st with
                | Some c when is_symbol "," c ->
                    advance st;
                    names acc
                | Some c when is_symbol "]" c ->
                    advance st;
                    Ok (List.rev acc, c)
                | _ ->
                    expected st "`]`";
                    Error ())
            | _ ->
                expected st "a parameter's name";
                Error ()
          in
          let* parameters, close = names [] in
          if close.line = open_bracket.line then begin
            let inside =
              String.concat ", " (List.map (fun (x : Core.parameter) -> x.parameter_name ^ ": " ^ type_text) parameters)
            in
            report st
              (M.message M.Refused (M.point t.line t.column (String.length type_text))
                 ~fix:
                   (M.replace_at (line_text st open_bracket.line) (open_bracket.column + 1)
                      (close.column - open_bracket.column - 1) inside)
                 ~why:"each parameter writes its own type after its name, as a declaration does.")
          end;
          Ok parameters)
  | _ ->
      let rec loop acc =
        match peek st with
        | Some ({ kind = Word name; _ } as t) when next_is_after st 1 (is_symbol ":") -> (
            advance st;
            if is_keyword name then keyword_as_name st t name else check_name st t name name;
            let* () =
              if next_is st (is_symbol ":") then begin
                advance st;
                Ok ()
              end
              else begin
                expected st "`:`";
                Error ()
              end
            in
            let* written = parse_type st in
            let parameter =
              {
                Core.parameter_name = name;
                parameter_at = place_of_token t;
                parameter_type = written;
              }
            in
            match peek st with
            | Some c when is_symbol "," c ->
                advance st;
                loop (parameter :: acc)
            | Some c when is_symbol "]" c ->
                advance st;
                Ok (List.rev (parameter :: acc))
            | _ ->
                expected st "`]`";
                Error ())
        | _ ->
            expected st "a parameter, as in `score: Whole`";
            Error ()
      in
      loop []

(* trace: D4, D8, D37, D38, D58, D132, D165, D190, D199. `proc name[parameters] -> Type`, its body, and
   `end proc name`. *)
let parse_definition ?(starts_line = true) st (keyword : token) depth (family : string option) : Core.definition option =
  if starts_line then begin_line st keyword depth;
  advance st;
  let header =
    match peek st with
    | Some dot when is_symbol "." dot -> (
        advance st;
        match peek st with
        | Some ({ kind = Word "main"; _ } as main) ->
            advance st;
            Some (Core.Main, main, "end proc.main")
        | _ ->
            expected st "`main`";
            None)
    | Some ({ kind = Word name; _ } as t) ->
        advance st;
        if is_keyword name then
          report st
            (M.message M.Refused (M.point t.line t.column t.width)
               ~what:(Printf.sprintf "`%s` is a keyword, so it can't be a procedure's name" name)
               ~why:"a procedure's name can't be one of Unio's own words.")
        else check_name st t name name;
        (* trace: D41. `word.kind` names a kind of `word`, declared inside `fam.proc word`. *)
        let name, span =
          match (peek st, peek_ahead st 1) with
          | Some d, Some ({ kind = Word kind; _ } as k) when is_symbol "." d ->
              advance st;
              advance st;
              check_name st k kind kind;
              (name ^ "." ^ kind, join st (span_of t) (span_of k))
          | _ -> (name, span_of t)
        in
        let word = match String.index_opt name '.' with Some i -> String.sub name 0 i | None -> name in
        (match family with
        | Some f when f <> word -> report st (Wording.refusal [||] (Core.Member_of_other_family (name, f, place_of span)))
        | None when word <> name -> report st (Wording.refusal [||] (Core.Narrowed_outside_family (name, place_of span)))
        | _ -> ());
        Some (Core.Named name, { t with width = span.stop - span.first }, "end proc " ^ name)
    | _ ->
        expected st "a procedure's name";
        None
  in
  match header with
  | None ->
      st.stopped <- true;
      None
  | Some (name, name_token, closer) -> (
      (* trace: D166. Parameters in `( )`, as before D165: refused with the `[ ]` form as the fix, and read on as if
         written in `[ ]`. Empty `( )` and `proc.main`'s get the messages `[ ]` would. *)
      (match peek st with
      | Some o when is_symbol "(" o -> (
          let rec find_close i depth =
            if i >= Array.length st.tokens || st.tokens.(i).line <> o.line then None
            else
              let t = st.tokens.(i) in
              if is_symbol "(" t then find_close (i + 1) (depth + 1)
              else if is_symbol ")" t then
                if depth = 1 then Some i else find_close (i + 1) (depth - 1)
              else find_close (i + 1) depth
          in
          match find_close st.index 0 with
          | Some j ->
              let c = st.tokens.(j) in
              (match name with
              | Core.Named _ when j > st.index + 1 ->
                  let text = line_text st o.line in
                  report st
                    (M.message M.Refused (M.point o.line o.column 1)
                       ~fix:(M.replace_at (M.replace_at text c.column 1 "]") o.column 1 "[")
                       ~why:"a definition writes its parameters in `[ ]`; `( )` calls a procedure.")
              | _ -> ());
              st.tokens.(st.index) <- { o with kind = Symbol "[" };
              st.tokens.(j) <- { c with kind = Symbol "]" }
          | None -> ())
      | _ -> ());
      let parameters =
        match peek st with
        | Some o when is_symbol "[" o -> (
            match name with
            | Core.Main ->
                let rec close () =
                  match peek st with
                  | Some c when is_symbol "]" c ->
                      advance st;
                      Some c
                  | Some c when c.line = o.line ->
                      advance st;
                      close ()
                  | _ -> None
                in
                (match close () with
                | Some c when c.column = o.column + 1 ->
                    report st
                      (M.message M.Refused (M.point o.line o.column 2)
                         ~fix:(M.replace_at (line_text st o.line) o.column 2 "")
                         ~why:"a definition writes `[ ]` only when it has parameters.")
                | Some c ->
                    report st
                      (M.message M.Refused
                         (M.point o.line o.column (c.column + 1 - o.column))
                         ~what:"`proc.main` takes nothing"
                         ~why:
                           "only the program's start runs `proc.main`, so it's never given \
                            anything.")
                | None -> expected st "`]`");
                Ok []
            | Core.Named _ -> parse_parameters st o)
        | _ -> Ok []
      in
      match parameters with
      | Error () ->
          st.stopped <- true;
          None
      | Ok parameters -> (
          let returns =
            match peek st with
            | Some r when is_symbol "->" r -> (
                advance st;
                match parse_type st with Ok t -> Ok (Some t) | Error () -> Error ())
            | _ -> Ok None
          in
          (* trace: D39, D190. The failures it can give, after `!`, in `[ ]`. *)
          let failures =
            match peek st with
            | Some f when is_symbol "!" f -> (
                advance st;
                match name with
                | Core.Main ->
                    not_designed st f "listing failures on `proc.main`";
                    st.stopped <- true;
                    []
                | Core.Named _ -> (
                    match peek st with
                    | Some o when is_symbol "[" o ->
                        advance st;
                        let rec names acc =
                          match peek st with
                          | Some ({ kind = Word n; _ } as nt) -> (
                              advance st;
                              check_name st nt n n;
                              let acc = (n, place_of_token nt) :: acc in
                              match peek st with
                              | Some c when is_symbol "," c ->
                                  advance st;
                                  names acc
                              | Some c when is_symbol "]" c ->
                                  advance st;
                                  List.rev acc
                              | _ ->
                                  expected st "`]`";
                                  st.stopped <- true;
                                  List.rev acc)
                          | _ ->
                              expected st "a failure's name";
                              st.stopped <- true;
                              List.rev acc
                        in
                        names []
                    | _ ->
                        expected st "`[`";
                        st.stopped <- true;
                        []))
            | _ -> []
          in
          match returns with
          | Error () ->
              st.stopped <- true;
              None
          | Ok returns ->
              if not st.stopped then expect_opener_end st;
              if st.stopped then None
              else begin
                let outer = st.closers in
                st.closers <- closer :: outer;
                st.variables <- List.map (fun (x : Core.parameter) -> x.parameter_name) parameters;
                let body = parse_block st (depth + 1) in
                st.closers <- outer;
                if not st.stopped then parse_closer st depth closer;
                Some
                  {
                    Core.definition_name = name;
                    definition_name_at = place_of_token name_token;
                    definition_parameters = parameters;
                    definition_returns = returns;
                    definition_failures = failures;
                    definition_extern = false;
                    definition_body = body;
                    definition_at = place_of_token keyword;
                  }
              end))

(* trace: D42, D43, D44. `handler word.kind[parameters]`, its `labels` line, its cases, and `end handler word.kind`. *)
let parse_handler st (t : token) depth word =
  begin_line st t depth;
  advance st;
  match (peek st, peek_ahead st 1, peek_ahead st 2) with
  | Some ({ kind = Word w; _ } as wt), Some d, Some ({ kind = Word kind; _ } as k) when is_symbol "." d -> (
      advance st;
      advance st;
      advance st;
      check_name st k kind kind;
      let name = w ^ "." ^ kind in
      let name_at = place_of (join st (span_of wt) (span_of k)) in
      if w <> word then report st (Wording.refusal [||] (Core.Member_of_other_family (name, word, name_at)));
      let parameters = match peek st with Some o when is_symbol "[" o -> parse_parameters st o | _ -> Ok [] in
      match parameters with
      | Error () -> st.stopped <- true
      | Ok parameters ->
          let at = place_of (statement_span st t) in
          expect_opener_end st;
          st.variables <- List.map (fun (x : Core.parameter) -> x.parameter_name) parameters;
          let closer = "end handler " ^ name in
          let outer = st.closers in
          st.closers <- closer :: outer;
          let pairs =
            match peek st with
            | Some l when is_word "labels" l -> (
                begin_line st l (depth + 1);
                match parse_labels st l with Ok (Core.Labels (pairs, _)) -> pairs | _ -> [])
            | _ -> []
          in
          let rec cases acc =
            if st.stopped then List.rev acc
            else
              match peek st with
              | Some c when is_word "case" c -> (
                  begin_line st c (depth + 1);
                  advance st;
                  match peek st with
                  | Some ({ kind = Word f; _ } as ft) ->
                      advance st;
                      let case_at = place_of (statement_span st c) in
                      expect_opener_end st;
                      let body = parse_block st (depth + 2) in
                      cases (`Case (f, place_of_token ft, body, case_at) :: acc)
                  | _ ->
                      expected st "a failure's name";
                      st.stopped <- true;
                      List.rev acc)
              | Some c when is_word "include" c -> (
                  begin_line st c (depth + 1);
                  advance st;
                  match handler_use st with
                  | Some use ->
                      expect_semicolon st;
                      cases (`Include use :: acc)
                  | None ->
                      st.stopped <- true;
                      List.rev acc)
              | _ -> List.rev acc
          in
          let found = cases [] in
          st.closers <- outer;
          if not st.stopped then parse_closer st depth closer;
          st.handlers <-
            {
              Core.handler_name = name;
              handler_name_at = name_at;
              handler_parameters = parameters;
              handler_labels = pairs;
              handler_cases = fold_cases found;
              handler_at = at;
            }
            :: st.handlers)
  | _ ->
      expected st "a handler's name, as in `word_failed.use_placeholder`";
      st.stopped <- true

(* trace: D41, D42. `fam.proc word` or `fam.handler word`, its members, and `end fam.proc word`. *)
let parse_family st (t : token) =
  begin_line st t 0;
  advance st;
  match (peek st, peek_ahead st 1, peek_ahead st 2) with
  | Some d, Some { kind = Word (("proc" | "handler") as which); _ }, Some ({ kind = Word word; _ } as wt)
    when is_symbol "." d ->
      advance st;
      advance st;
      advance st;
      check_name st wt word word;
      expect_opener_end st;
      let closer = "end fam." ^ which ^ " " ^ word in
      st.closers <- [ closer ];
      let rec members acc =
        if st.stopped then List.rev acc
        else
          match peek st with
          | Some m when is_word "proc" m && which = "proc" -> (
              match parse_definition st m 1 (Some word) with
              | Some def ->
                  st.closers <- [ closer ];
                  members (def :: acc)
              | None -> List.rev acc)
          | Some m when is_word "handler" m && which = "handler" ->
              parse_handler st m 1 word;
              st.closers <- [ closer ];
              members acc
          | Some m when is_word "comment" m ->
              begin_line st m 1;
              parse_comment_block st m 1;
              members acc
          | _ -> List.rev acc
      in
      let found = members [] in
      st.closers <- [];
      if not st.stopped then parse_closer st 0 closer;
      found
  | _ ->
      expected st "`proc` or `handler`, as in `fam.proc show_msg`";
      st.stopped <- true;
      []

(* trace: D97, D101, D102. Two or more blank lines in a row. *)
let check_blank_lines st =
  let count = Array.length st.lines in
  let rec go i =
    if i < count then
      if String.trim st.lines.(i).text = "" && (not st.lines.(i).comment) && not st.lines.(i).hidden then begin
        let rec run_end j =
          if j < count && String.trim st.lines.(j).text = "" then run_end (j + 1) else j
        in
        let stop = run_end i in
        let extra = stop - i - 1 in
        if extra >= 1 then
          report st
            (M.message M.Refused
               (M.point (i + 2) 1 1)
               ~what:
                 (Printf.sprintf "%d extra blank line%s, after the one on line %d" extra
                    (if extra = 1 then "" else "s")
                    (i + 1))
               ~why:"one blank line is enough to separate the parts of a program.");
        go stop
      end
      else go (i + 1)
  in
  go 0

(* trace: D190, D192. The old spellings: a name after `$`, and `==` and `!=`. Each line with any is refused once, with
   them all corrected as the fix (D100's one message per line), and its tokens read on as the new spellings. *)
let old_spellings (l : Lexer.line) : Lexer.line * M.message option =
  let changed (t : token) =
    match t.kind with Dollar name -> name <> "" | Symbol ("==" | "!=") -> true | _ -> false
  in
  match List.filter changed l.tokens with
  | [] -> (l, None)
  | first :: _ as found ->
      let fixed =
        List.fold_left
          (fun text (t : token) ->
            match t.kind with
            | Dollar _ -> M.replace_at text t.column 1 ""
            | Symbol s ->
                let word = if s = "==" then "eq" else "not_eq" in
                let before = if t.column > 1 && text.[t.column - 2] <> ' ' then " " else "" in
                let after =
                  if
                    t.column - 1 + t.width < String.length text
                    && text.[t.column - 1 + t.width] <> ' '
                  then " "
                  else ""
                in
                M.replace_at text t.column t.width (before ^ word ^ after)
            | _ -> text)
          l.text (List.rev found)
      in
      let dollar = match first.kind with Dollar _ -> true | _ -> false in
      let message =
        M.message M.Refused
          (M.point l.number first.column (if dollar then 1 else first.width))
          ~fix:fixed
          ~why:
            (if dollar then "a name is a plain word, with no `$`."
             else "`eq` and `not_eq` compare two values; Unio has no `==` or `!=`.")
      in
      let tokens =
        List.map
          (fun (t : token) ->
            match t.kind with
            | Dollar name when name <> "" ->
                { t with kind = Word name; column = t.column + 1; width = t.width - 1 }
            | Symbol "==" -> { t with kind = Word "eq" }
            | Symbol "!=" -> { t with kind = Word "not_eq" }
            | _ -> t)
          l.tokens
      in
      ({ l with tokens }, Some message)

(* Reads a whole file: gives the definitions read, the problems found, and whether checking stopped early. *)
let parse ~file (lines : Lexer.line list) =
  current_file := file;
  let read = List.map old_spellings lines in
  let lines = Array.of_list (List.map fst read) in
  let tokens =
    Array.of_list (List.concat_map (fun (l : Lexer.line) -> l.tokens) (Array.to_list lines))
  in
  let st =
    {
      tokens;
      lines;
      index = 0;
      problems = [];
      stopped = false;
      statement_line = 0;
      spread_reported = false;
      closers = [];
      last_code_line = 0;
      variables = [];
      handlers = [];
    }
  in
  List.iter (fun (_, m) -> Option.iter (report st) m) read;
  check_blank_lines st;
  (* trace: D74. A `///` doc comment goes on the lines right before a declaration. *)
  let count = Array.length lines in
  Array.iteri
    (fun i (l : Lexer.line) ->
      match l.doc_comment with
      | Some column -> (
          let rec next j =
            if j >= count then None
            else
              let m = lines.(j) in
              if m.tokens = [] && m.doc_comment <> None then next (j + 1) else Some m
          in
          let starts word (m : Lexer.line) = match m.tokens with first :: _ -> is_word word first | [] -> false in
          match next (i + 1) with
          | Some m when starts "let" m || starts "var" m || starts "proc" m -> ()
          | Some m when starts "fam" m || starts "handler" m || starts "extern" m ->
              report st
                (M.message M.Not_designed_yet (M.point l.number column 3)
                   ~what:"which declarations take a `///` doc comment isn't decided yet")
          | _ ->
              (* A draft wording. *)
              report st
                (M.message M.Refused (M.point l.number column 3)
                   ~fix:(M.replace_at l.text column 3 "//")
                   ~why:"a `///` describes the declaration on the line right after it; any other comment is written \
                         with `//`."))
      | None -> ())
    lines;
  let rec definitions acc =
    if st.stopped then List.rev acc
    else
      match peek st with
      | None -> List.rev acc
      | Some t when is_word "proc" t -> (
          match parse_definition st t 0 None with Some d -> definitions (d :: acc) | None -> List.rev acc)
      (* trace: D36, D131. `extern.cpp` in front of `proc`: a procedure written in C++, whose body holds nothing or
         only a `labels` line. Ralph can't run C++, and where its code lives isn't decided, so the program stops
         there. *)
      | Some t when is_word "extern" t -> (
          begin_line st t 0;
          advance st;
          match (peek st, peek_ahead st 1, peek_ahead st 2) with
          | Some d, Some ({ kind = Word "cpp"; _ } as c), Some ({ kind = Word "proc"; _ } as k) when is_symbol "." d -> (
              advance st;
              advance st;
              match parse_definition ~starts_line:false st k 0 None with
              | Some def ->
                  (match def.definition_body with
                  | Core.Empty | Core.Then (Core.Labels _, Core.Empty) -> ()
                  | _ ->
                      (* A draft wording. *)
                      report st
                        (M.message M.Refused (M.point k.line k.column 4)
                           ~what:"an `extern.cpp` procedure's body is in C++, so here it holds nothing but a `labels` line"
                           ~why:"`extern.cpp` says the procedure is written in C++, outside the Unio file."));
                  report st
                    (M.message M.Not_designed_yet
                       (M.point t.line t.column (c.column + c.width - t.column))
                       ~what:"where an `extern.cpp` procedure's C++ code lives, and how it's built and linked, isn't decided yet");
                  definitions ({ def with Core.definition_extern = true } :: acc)
              | None -> List.rev acc)
          | Some d, Some ({ kind = Word n; _ } as nt), _ when is_symbol "." d ->
              report st
                (M.message M.Refused (M.point nt.line nt.column nt.width)
                   ~what:(Printf.sprintf "`extern` has no narrowing `.%s`" n)
                   ~why:"`extern`'s only narrowing is `.cpp`.");
              st.stopped <- true;
              List.rev acc
          | _ ->
              expected st "`.cpp`";
              st.stopped <- true;
              List.rev acc)
      | Some t when is_word "fam" t -> definitions (List.rev_append (parse_family st t) acc)
      | Some t when is_word "comment" t ->
          begin_line st t 0;
          parse_comment_block st t 0;
          definitions acc
      | Some t ->
          (* trace: D161. Each statement outside a procedure is refused, and reading carries on. *)
          begin_line st t 0;
          report st
            (M.message M.Refused
               (M.point t.line t.column (String.length (line_text st t.line) - t.column + 1))
               ~what:"this line isn't inside a procedure"
               ~why:"a program is made of procedures, and every statement goes inside one.");
          skip_statement st;
          definitions acc
  in
  let found = definitions [] in
  (* Comment lines after the last closer. *)
  (match peek st with
  | None when not st.stopped ->
      for number = st.last_code_line + 1 to Array.length lines do
        let l = lines.(number - 1) in
        if
          l.tokens = [] && l.comment
          && String.length l.text > 0
          && (l.text.[0] = ' ' || l.text.[0] = '\t')
        then
          report st
            (M.message M.Not_designed_yet (M.point number 1 1)
               ~what:"how a comment after the last line of code is indented isn't decided yet")
      done
  | _ -> ());
  let stop_line = match peek st with Some t when st.stopped -> t.line | _ -> max_int in
  (found, List.rev st.handlers, List.rev st.problems, st.stopped, stop_line)
