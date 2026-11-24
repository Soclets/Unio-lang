(* Spacing (D18, D27, D98, D100, D102, D132, D190): spacing is fixed, and anything else is refused with the corrected line.

   Every gap between two tokens on a line has one right width, worked out from the two tokens:
   - none before `;`, `,`, `)`, `]` and `:`, none after `(` and `[`, and none on either side of a narrowing's `.`;
   - none after a negating `-`, which is a `-` with nothing before it but an operator, a bracket or a keyword (D27,
     D60);
   - none before a call's `(`, which is a `(` right after a procedure's name, nor before the `[` after a name or a
     type (D165);
   - one everywhere else: around operators, after `,` and `:`, and between words.
   A line never ends with spaces, and a blank line has none. All of a line's mistakes give one message, with a `^`
   under each gap and the whole line fixed (D100). *)

open Lexer
module M = Messages

type mistake = {
  column : int;  (** where the gap starts *)
  width : int;  (** how wide it is now *)
  right : int;  (** how wide it should be *)
  before : token option;
  after : token option;
}

let operators = [ "="; "=="; "!="; "<"; ">"; "+"; "-"; "*"; "/"; "&"; "|>"; "??"; "->"; "!" ]
let word_operators = [ "and"; "or"; "not"; "at_least"; "at_most"; "div"; "rem"; "eq"; "not_eq" ]

(* Words after which a `-` negates, as after an operator. *)
let leads_into_value =
  [
    "return"; "and"; "or"; "not"; "if"; "while"; "at_least"; "at_most"; "else"; "eq"; "not_eq"; "in";
  ]

let is_operator t =
  match t.kind with
  | Symbol s -> List.mem s operators
  | Word w -> List.mem w word_operators
  | _ -> false

let symbol_is s t = match t.kind with Symbol s' -> s = s' | _ -> false

(* Whether the `-` at [index] negates (D60): it has nothing before it on the line but an operator, a bracket, `,`,
   `:` or a keyword that a value follows. *)
let negates tokens index =
  index = 0
  ||
  let before = tokens.(index - 1) in
  match before.kind with
  | Symbol s -> List.mem s operators || List.mem s [ "("; "["; ","; ":" ]
  | Word w -> (
      List.mem w leads_into_value || List.mem w word_operators
      (* `div.floor -2`: the narrowing of `div` or `rem` ends an operator (D70, D71) *)
      || index >= 3
         && (w = "floor" || w = "trunc")
         && symbol_is "." tokens.(index - 2)
         && match tokens.(index - 3).kind with Word ("div" | "rem") -> true | _ -> false)
  | _ -> false

(* trace: D3, D17. Which `<` and `>` on a line are a type's brackets, as in `List<Text>`, rather than comparisons: a
   `<` right after a type's name, which starts with a capital, and the `>` that closes it. *)
let type_brackets tokens =
  let marks = Array.make (Array.length tokens) false in
  let depth = ref 0 in
  Array.iteri
    (fun i t ->
      match t.kind with
      | Symbol "<"
        when i > 0
             && (match tokens.(i - 1).kind with
               | Word w -> w <> "" && w.[0] >= 'A' && w.[0] <= 'Z'
               | _ -> false)
             && tokens.(i - 1).column + tokens.(i - 1).width = t.column ->
          marks.(i) <- true;
          incr depth
      | Symbol ">" when !depth > 0 ->
          marks.(i) <- true;
          decr depth
      | _ -> ())
    tokens;
  marks

let right_gap ?(types = [||]) tokens index =
  let a = tokens.(index) and b = tokens.(index + 1) in
  let type_bracket i = i < Array.length types && types.(i) in
  if type_bracket index && symbol_is "<" a then 0
  else if type_bracket (index + 1) then 0
  else if type_bracket index && symbol_is ">" a && symbol_is "[" b then 0
  else
    let symbol_in list t = match t.kind with Symbol s -> List.mem s list | _ -> false in
    (* trace: D23. `?` touches the call before it. *)
    if symbol_in [ ";"; ","; ")"; "]"; ":"; "."; "?" ] b then 0
    else if symbol_in [ "("; "["; "." ] a then 0
    else if symbol_is "-" a && negates tokens index then 0
    else if symbol_is "(" b then
      match a.kind with Word w when (not (Parser.is_keyword w)) || w = "be" -> 0 | _ -> 1
      (* trace: D165. No space before the `[` after a name or a type. *)
    else if symbol_is "[" b then
      match a.kind with Word w when not (Parser.is_keyword w) -> 0 | Dollar _ -> 0 | _ -> 1
    else 1

let quoted t = "`" ^ describe t.kind ^ "`"

(* trace: D85, D89, D102, D132. The `why:` for a line with one mistake. *)
let one_why m =
  match (m.before, m.after) with
  | None, _ -> "a line never ends with spaces."
  | Some a, Some b when symbol_is "." a || symbol_is "." b ->
      "a narrowing's `.` touches the words on both sides."
  | Some a, Some _ when symbol_is "-" a && m.right = 0 ->
      "a `-` that makes a value negative has no space after it."
  | Some a, Some b when m.right = 0 ->
      Printf.sprintf "no space goes between %s and %s." (quoted a) (quoted b)
  | Some _, Some _ when m.width >= 2 -> "spaces never come two in a row, outside indentation."
  | Some a, Some b ->
      if is_operator a then
        Printf.sprintf "%s between two values has one space on each side." (quoted a)
      else if is_operator b then
        Printf.sprintf "%s between two values has one space on each side." (quoted b)
      else Printf.sprintf "%s and %s have one space between them." (quoted a) (quoted b)
  | Some _, None -> "spaces never come two in a row, outside indentation."

let several_why =
  "spacing follows one rule: one space around operators and after `,` and `:`, none inside \
   brackets or before a call's `(`, never two in a row, and none at the end of a line."

(* Checks one line; gives its message, if it has any mistakes. *)
let check_line (l : Lexer.line) : M.message option =
  let text = l.text in
  let rec last_non_space i =
    if i > 0 && (text.[i - 1] = ' ' || text.[i - 1] = '\t') then last_non_space (i - 1) else i
  in
  let stop = last_non_space (String.length text) in
  if l.tokens = [] then
    if (not l.comment) && text <> "" then
      (* trace: D98, D102 *)
      Some
        (M.message M.Refused
           (M.point l.number 1 (String.length text))
           ~fix:"" ~why:"a blank line has no spaces on it.")
    else if l.comment && stop < String.length text then
      Some
        (M.message M.Refused
           (M.point l.number (stop + 1) (String.length text - stop))
           ~fix:(String.sub text 0 stop) ~why:"a line never ends with spaces.")
    else None
  else if
    List.exists
      (fun t -> match t.kind with Unknown _ | Unclosed_text _ -> true | _ -> false)
      l.tokens
  then None
  else
    let tokens = Array.of_list l.tokens in
    let types = type_brackets tokens in
    let count = Array.length tokens in
    let gap_mistakes =
      List.concat
        (List.init (count - 1) (fun i ->
             let a = tokens.(i) and b = tokens.(i + 1) in
             let start = a.column + a.width in
             let width = b.column - start in
             let gap = String.sub text (start - 1) width in
             let right = right_gap ~types tokens i in
             if gap = String.make right ' ' then []
             else [ { column = start; width; right; before = Some a; after = Some b } ]))
    in
    (* After the last token: a comment may follow, but never two spaces in a row, and nothing at the end. *)
    let last = tokens.(count - 1) in
    let after_last = last.column + last.width in
    let end_mistakes =
      if stop < String.length text then
        [
          {
            column = stop + 1;
            width = String.length text - stop;
            right = 0;
            before = None;
            after = None;
          };
        ]
      else []
    in
    let comment_mistakes =
      if l.comment && stop > after_last then
        let comment_at =
          let rec find i =
            if i + 1 < String.length text && text.[i] = '/' && text.[i + 1] = '/' then i
            else find (i + 1)
          in
          find (after_last - 1)
        in
        let width = comment_at + 1 - after_last in
        if width >= 2 || String.contains (String.sub text (after_last - 1) width) '\t' then
          [ { column = after_last; width; right = 1; before = Some last; after = None } ]
        else []
      else []
    in
    match gap_mistakes @ comment_mistakes @ end_mistakes with
    | [] -> None
    | mistakes ->
        (* The fixed line, gaps replaced from the last to the first so earlier columns still hold. *)
        let fixed =
          List.fold_left
            (fun line m -> M.replace_at line m.column m.width (String.make m.right ' '))
            text
            (List.sort (fun a b -> compare b.column a.column) mistakes)
        in
        let carets =
          List.map
            (fun m -> if m.width = 0 then (m.column, 1) else (m.column, m.width))
            (List.sort (fun a b -> compare a.column b.column) mistakes)
        in
        (* Gaps on both sides of one operator, or of one narrowing's `.`, are one mistake (D102). *)
        let same (t : token) (u : token option) =
          match u with Some (u : token) -> u.column = t.column | None -> false
        in
        let shared =
          match mistakes with
          | [ a; b ] -> (
              match (a.after, b.before) with
              | Some t, Some _ when same t b.before -> Some t
              | _ -> None)
          | _ -> None
        in
        let why =
          match (mistakes, shared) with
          | [ m ], _ -> one_why m
          | _, Some t when symbol_is "." t -> "a narrowing's `.` touches the words on both sides."
          | _, Some t when is_operator t ->
              Printf.sprintf "%s between two values has one space on each side." (quoted t)
          | _ -> several_why
        in
        Some (M.message M.Refused { M.file = 0; line = l.number; carets } ~fix:fixed ~why)

let check (lines : Lexer.line list) = List.filter_map check_line lines
