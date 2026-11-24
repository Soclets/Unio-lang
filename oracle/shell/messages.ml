(* Messages, in D54's layout with D86's column:

   refused: game.unio:5:5, line 5 column 5
    5 |     $lives = $lives - 1;
      |     ^^^^^^
    what:    `$lives` can't be given a new value
    because: line 2 declares it with `let`
    2 |     let $lives: Whole = 3;
      |     ^^^
    why:     only a `var` can be given a new value.

   Every message goes to standard error (D104). *)

type kind = Refused | Check_failed | Failed | Not_built_yet | Not_designed_yet

(* Where a message points: a file of the program (D64), counted from 0, a line, and the columns to put `^` under, each
   a first column and a width. *)
type place = { file : int; line : int; carets : (int * int) list }

type message = {
  kind : kind;
  at : place;
  fix : string option;  (** the whole corrected line (D84, D101) *)
  what : string option;
  when_ : string option;
  because : (string * place option) option;
  why : string option;
}

let point ?(file = 0) line column width = { file; line; carets = [ (column, max 1 width) ] }

(* Puts a message made while reading one file into that file. *)
let in_file file m =
  {
    m with
    at = { m.at with file };
    because =
      Option.map
        (fun (sentence, p) -> (sentence, Option.map (fun p -> { p with file }) p))
        m.because;
  }

let message ?fix ?what ?when_ ?because ?why kind at = { kind; at; fix; what; when_; because; why }

let kind_word = function
  | Refused -> "refused"
  | Check_failed -> "check failed"
  (* trace: D152 *)
  | Failed -> "failed"
  | Not_built_yet -> "NotBuiltYet"
  | Not_designed_yet -> "NotDesignedYet"

let first_column place = match place.carets with (column, _) :: _ -> column | [] -> 1

(* Every label's text starts one space after the longest label, `because:` (D86). *)
let labelled label text = Printf.sprintf " %-8s %s\n" label text

(* [files] holds each file of the program: the name a message gives it, and its lines. *)
let render (files : (string * string array) array) (m : message) =
  let buffer = Buffer.create 256 in
  let name file = if file >= 0 && file < Array.length files then fst files.(file) else "" in
  let source_line (place : place) =
    if place.file >= 0 && place.file < Array.length files then
      let lines = snd files.(place.file) in
      if place.line >= 1 && place.line <= Array.length lines then lines.(place.line - 1) else ""
    else ""
  in
  let shown = m.at.line :: (match m.because with Some (_, Some p) -> [ p.line ] | _ -> []) in
  let gutter =
    List.fold_left (fun widest n -> max widest (String.length (string_of_int n))) 2 shown
  in
  let show place =
    Buffer.add_string buffer (Printf.sprintf "%*d | %s\n" gutter place.line (source_line place));
    let carets =
      Bytes.make (List.fold_left (fun far (c, w) -> max far (c - 1 + w)) 0 place.carets) ' '
    in
    List.iter (fun (c, w) -> Bytes.fill carets (c - 1) w '^') place.carets;
    Buffer.add_string buffer
      (Printf.sprintf "%s | %s\n" (String.make gutter ' ') (Bytes.to_string carets))
  in
  let column = first_column m.at in
  Buffer.add_string buffer
    (Printf.sprintf "%s: %s:%d:%d, line %d column %d\n" (kind_word m.kind) (name m.at.file)
       m.at.line column m.at.line column);
  show m.at;
  Option.iter (fun fix -> Buffer.add_string buffer (labelled "fix:" ("`" ^ fix ^ "`"))) m.fix;
  Option.iter (fun what -> Buffer.add_string buffer (labelled "what:" what)) m.what;
  Option.iter (fun when_ -> Buffer.add_string buffer (labelled "when:" when_)) m.when_;
  Option.iter
    (fun (sentence, place) ->
      (* trace: D161. A `because:` pointing into another file names it. *)
      let sentence =
        match place with
        | Some p when p.file <> m.at.file -> Printf.sprintf "%s, in `%s`" sentence (name p.file)
        | _ -> sentence
      in
      Buffer.add_string buffer (labelled "because:" sentence);
      Option.iter show place)
    m.because;
  Option.iter (fun why -> Buffer.add_string buffer (labelled "why:" why)) m.why;
  Buffer.contents buffer

(* Puts [insert] into [text] at [column], counted from 1. *)
let insert_at text column insert =
  let at = max 0 (min (String.length text) (column - 1)) in
  String.sub text 0 at ^ insert ^ String.sub text at (String.length text - at)

(* Replaces [width] characters of [text] from [column] with [replacement]. *)
let replace_at text column width replacement =
  let at = max 0 (min (String.length text) (column - 1)) in
  let stop = max at (min (String.length text) (at + width)) in
  String.sub text 0 at ^ replacement ^ String.sub text stop (String.length text - stop)

let report_address = "https://github.com/Soclets/Unio-lang/issues"

(* trace: D82, D92, D103 *)
let internal_error problem =
  Printf.sprintf "internal error: Ralph itself went wrong, not your program\n%s%s"
    (labelled "what:" problem)
    (labelled "why:"
       ("this is a bug in Ralph. Please report it at " ^ report_address
      ^ ", with the program that caused it."))

(* trace: D92, D103 *)
let cant_read file reason = Printf.sprintf "can't read: %s\n%s" file (labelled "what:" reason)
