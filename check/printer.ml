(* The one printer (Building rule 12): a program as Unio text, in one of two spellings. [Current] is Unio as decided
   now (D190 to D203); [Before_d190] is Unio as it was written before them, which Beta++ reads until it's brought up
   to date: names with `$` (D125), opening lines ending in `:` (D8), `==` and `!=` (D17), `returns` (D37), and braces
   filled only through `.fmt` (D29). The two print the same program, so their output can be compared. *)

open Syntax

type spelling = Current | Before_d190

let type_name = function Whole -> "Whole" | Bool -> "Bool" | Text -> "Text"

let name spelling n = match spelling with Current -> n | Before_d190 -> "$" ^ n

let binary_word spelling = function
  | Add -> "+"
  | Subtract -> "-"
  | Multiply -> "*"
  | Divide -> "/"
  | Divide_floor -> "div.floor"
  | Divide_trunc -> "div.trunc"
  | Remainder_floor -> "rem.floor"
  | Remainder_trunc -> "rem.trunc"
  | Equal -> ( match spelling with Current -> "eq" | Before_d190 -> "==")
  | Not_equal -> ( match spelling with Current -> "not_eq" | Before_d190 -> "!=")
  | Less -> "<"
  | Greater -> ">"
  | At_least -> "at_least"
  | At_most -> "at_most"
  | And -> "and"
  | Or -> "or"

let has_names pieces = List.exists (function Name _ -> true | Plain _ -> false) pieces

(* Text in double quotes; braces hold names (D29). *)
let quoted spelling pieces =
  "\""
  ^ String.concat "" (List.map (function Plain s -> s | Name n -> "{" ^ name spelling n ^ "}") pieces)
  ^ "\""

(* Text as a value: before D190 only `.fmt` filled braces, so text with names goes through `be.Text.fmt`. *)
let text_value spelling pieces =
  match spelling with
  | Before_d190 when has_names pieces -> "be.Text.fmt(" ^ quoted spelling pieces ^ ")"
  | _ -> quoted spelling pieces

let rec expression spelling e =
  match e with
  | Whole_literal n -> Int64.to_string n
  | Bool_literal b -> if b then "true" else "false"
  | Text_literal pieces -> text_value spelling pieces
  | Variable n -> name spelling n
  | Negate inner -> (
      (* trace: D27. A `-` with no space after it. *)
      match inner with
      | Whole_literal _ | Variable _ -> "-" ^ expression spelling inner
      | _ -> "-(" ^ expression spelling inner ^ ")")
  | Not inner -> "not " ^ operand spelling inner
  | Binary (op, a, b) -> operand spelling a ^ " " ^ binary_word spelling op ^ " " ^ operand spelling b
  | Bracketed inner -> "(" ^ expression spelling inner ^ ")"
  | Call (f, given) -> f ^ "(" ^ String.concat ", " (List.map (expression spelling) given) ^ ")"
  | Text_of inner -> "be.Text(" ^ expression spelling inner ^ ")"
  | Whole_or (text, fallback) -> "be.Whole(" ^ expression spelling text ^ ") ?? " ^ expression spelling fallback
  | Ask pieces -> "ask(" ^ text_value spelling pieces ^ ")"

(* Every operator's sides are bracketed when they're operators themselves, so no maths order is relied on. *)
and operand spelling e =
  match e with
  | Binary _ | Not _ | Whole_or _ -> "(" ^ expression spelling e ^ ")"
  | _ -> expression spelling e

let opener spelling text = match spelling with Current -> text | Before_d190 -> text ^ ":"
let indent depth = String.make (4 * depth) ' '

let rec statement spelling depth s =
  let line text = indent depth ^ text ^ "\n" in
  match s with
  | Declare (changeable, n, t, value) ->
      line
        (Printf.sprintf "%s %s: %s = %s;" (if changeable then "var" else "let") (name spelling n) (type_name t)
           (expression spelling value))
  | Assign (n, value) -> line (Printf.sprintf "%s = %s;" (name spelling n) (expression spelling value))
  | Show (same_line, Text_literal pieces) when spelling = Before_d190 && has_names pieces ->
      line (Printf.sprintf "show_msg.fmt%s(%s);" (if same_line then ".same_line" else "") (quoted spelling pieces))
  | Show (same_line, value) ->
      line (Printf.sprintf "show_msg%s(%s);" (if same_line then ".same_line" else "") (expression spelling value))
  | Run (f, given) -> line (Printf.sprintf "%s(%s);" f (String.concat ", " (List.map (expression spelling) given)))
  | If (condition, then_part, else_part) ->
      line (opener spelling ("if " ^ expression spelling condition))
      ^ block spelling (depth + 1) then_part
      ^ (match else_part with
        | Some body -> line (opener spelling "else") ^ block spelling (depth + 1) body
        | None -> "")
      ^ line "end if"
  | While (condition, body) ->
      line (opener spelling ("while " ^ expression spelling condition)) ^ block spelling (depth + 1) body ^ line "end while"
  | Break -> line "break;"
  | Return None -> line "return;"
  | Return (Some value) -> line ("return " ^ expression spelling value ^ ";")

and block spelling depth body = String.concat "" (List.map (statement spelling depth) body)

let procedure spelling p =
  let parameters =
    match p.parameters with
    | [] -> ""
    | ps -> "[" ^ String.concat ", " (List.map (fun (n, t) -> name spelling n ^ ": " ^ type_name t) ps) ^ "]"
  in
  let gives =
    match (p.gives, spelling) with
    | None, _ -> ""
    | Some t, Current -> " -> " ^ type_name t
    | Some t, Before_d190 -> " returns " ^ type_name t
  in
  opener spelling ("proc " ^ p.name ^ parameters ^ gives) ^ "\n" ^ block spelling 1 p.body ^ "end proc " ^ p.name ^ "\n"

let program spelling p =
  String.concat "\n" (List.map (procedure spelling) p.procedures)
  ^ (if p.procedures = [] then "" else "\n")
  ^ opener spelling "proc.main" ^ "\n" ^ block spelling 1 p.main ^ "end proc.main\n"
