(* The lexer: splits each line of a Unio file into tokens, each with its line and its columns.

   Columns are counted in bytes from 1, which is the same as characters for plain English letters; how they're counted
   beyond those isn't decided (D54). A token never runs over two lines: text in quotes can't hold a line break (D30). *)

type kind =
  | Word of string  (** a keyword, a name, a narrowing or a type *)
  | Dollar of string
      (** a name written after a `$`, which names no longer have (D192), so it can be refused *)
  | Number of string  (** a whole number's digits (D15) *)
  | Decimal of string * string  (** a number with a point: the digits before it and after it (D155, D180) *)
  | Text of string
      (** text in double quotes, as written between them, with its `\` escapes (D21, D30) *)
  | Unclosed_text of string  (** text whose closing double quote never comes on its line *)
  | Single_quoted of string  (** text in single quotes, which is refused (D21) *)
  | Symbol of string  (** one of Unio's symbols, the longest that fits (D60) *)
  | Unknown of string  (** a character Unio has no use for *)

type token = { kind : kind; line : int; column : int; width : int }

(* One line of the file: its number, its text, and the tokens on it. *)
type line = {
  number : int;
  text : string;
  tokens : token list;
  comment : bool;  (** whether it ends in a `//` comment (D74) *)
  doc_comment : int option;  (** the column of a `///` doc comment, if there is one *)
}

let is_letter c = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
let is_digit c = c >= '0' && c <= '9'
let is_word_character c = is_letter c || is_digit c || c = '_'

(* The longest symbol first, so `->` is never read as `-` and `>` (D60). `==`, `!=` and `&` aren't Unio's any more
   (D190, D201), but are read whole so they can be refused with their fix. *)
let symbols =
  [
    "|>";
    "->";
    "==";
    "!=";
    "??";
    "::";
    "//";
    "(";
    ")";
    "[";
    "]";
    ",";
    ":";
    ";";
    ".";
    "=";
    "<";
    ">";
    "+";
    "-";
    "*";
    "/";
    "&";
    "!";
    "?";
    "{";
    "}";
    "~";
  ]

let starts_with text at prefix =
  let length = String.length prefix in
  at + length <= String.length text && String.sub text at length = prefix

let lex_line number text =
  let length = String.length text in
  let token kind start stop = { kind; line = number; column = start + 1; width = stop - start } in
  (* Reads text in quotes from [start], the opening quote; gives its token and where it ends. *)
  let read_quoted quote start make =
    let rec scan at =
      if at >= length then
        (token (Unclosed_text (String.sub text (start + 1) (at - start - 1))) start at, at)
      else if text.[at] = '\\' && at + 1 < length then scan (at + 2)
      else if text.[at] = quote then
        (token (make (String.sub text (start + 1) (at - start - 1))) start (at + 1), at + 1)
      else scan (at + 1)
    in
    scan (start + 1)
  in
  let rec scan at tokens =
    if at >= length then (List.rev tokens, false, None)
    else
      let c = text.[at] in
      if c = ' ' || c = '\t' then scan (at + 1) tokens
      else if starts_with text at "///" then (List.rev tokens, true, Some (at + 1))
      else if starts_with text at "//" then (List.rev tokens, true, None)
      else if c = '"' then
        let t, next = read_quoted '"' at (fun inside -> Text inside) in
        scan next (t :: tokens)
      else if c = '\'' then
        let t, next = read_quoted '\'' at (fun inside -> Single_quoted inside) in
        scan next (t :: tokens)
      else if c = '$' then
        let rec stop i = if i < length && is_word_character text.[i] then stop (i + 1) else i in
        let finish = stop (at + 1) in
        scan finish (token (Dollar (String.sub text (at + 1) (finish - at - 1))) at finish :: tokens)
      else if is_digit c then
        let rec stop i = if i < length && is_digit text.[i] then stop (i + 1) else i in
        let finish = stop at in
        if finish + 1 < length && text.[finish] = '.' && is_digit text.[finish + 1] then
          let after = stop (finish + 1) in
          scan after
            (token (Decimal (String.sub text at (finish - at), String.sub text (finish + 1) (after - finish - 1))) at after
            :: tokens)
        else scan finish (token (Number (String.sub text at (finish - at))) at finish :: tokens)
      else if is_letter c || c = '_' then
        let rec stop i = if i < length && is_word_character text.[i] then stop (i + 1) else i in
        let finish = stop at in
        scan finish (token (Word (String.sub text at (finish - at))) at finish :: tokens)
      else
        match List.find_opt (starts_with text at) symbols with
        | Some symbol ->
            let finish = at + String.length symbol in
            scan finish (token (Symbol symbol) at finish :: tokens)
        | None ->
            (* One whole UTF-8 character, so a message never cuts one in half. *)
            let code = Char.code c in
            let size =
              if code >= 0xF0 then 4 else if code >= 0xE0 then 3 else if code >= 0xC0 then 2 else 1
            in
            let finish = min length (at + size) in
            scan finish (token (Unknown (String.sub text at (finish - at))) at finish :: tokens)
  in
  let tokens, comment, doc_comment = scan 0 [] in
  { number; text; tokens; comment; doc_comment }

(* Splits a file into lines; a line break at the very end doesn't start another line. A `\r` right before a line
   break is part of the break (D144). *)
let lines_of contents =
  let pieces = String.split_on_char '\n' contents in
  let last = List.length pieces - 1 in
  let pieces =
    List.mapi
      (fun i piece ->
        if i < last && String.ends_with ~suffix:"\r" piece then
          String.sub piece 0 (String.length piece - 1)
        else piece)
      pieces
  in
  let pieces = match List.rev pieces with "" :: rest -> List.rev rest | _ -> pieces in
  List.mapi (fun index text -> lex_line (index + 1) text) pieces

let describe kind =
  match kind with
  | Word w -> w
  | Dollar name -> "$" ^ name
  | Number digits -> digits
  | Decimal (before, after) -> before ^ "." ^ after
  | Text inside -> "\"" ^ inside ^ "\""
  | Unclosed_text inside -> "\"" ^ inside
  | Single_quoted inside -> "'" ^ inside ^ "'"
  | Symbol s -> s
  | Unknown s -> s
