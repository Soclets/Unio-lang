(* The syntax tree check/ builds programs from, written from standard/ (Building rule 12), with nothing taken from
   Ralph's or Beta++'s source. It holds only what the generator makes; NOT_GENERATED.md lists the rest. *)

type ty = Whole | Bool | Text

type binary =
  | Add
  | Subtract
  | Multiply
  | Divide  (** `/`, exact (D70) *)
  | Divide_floor
  | Divide_trunc
  | Remainder_floor
  | Remainder_trunc
  | Equal
  | Not_equal
  | Less
  | Greater
  | At_least
  | At_most
  | And
  | Or

(* A piece of text: written as it is, or a variable's name in braces (D29, D200). *)
type piece = Plain of string | Name of string

type expression =
  | Whole_literal of int64  (** at least 0; a negative number is [Negate] of one (D27) *)
  | Bool_literal of bool
  | Text_literal of piece list
  | Variable of string
  | Negate of expression
  | Not of expression
  | Binary of binary * expression * expression
  | Bracketed of expression
  | Call of string * expression list  (** one of the program's own procedures, giving back a value *)
  | Text_of of expression  (** `be.Text` of a `Whole` or a `Bool` (D22, D153) *)
  | Whole_or of expression * expression  (** `be.Whole(text) ?? fallback` (D23, D95) *)
  | Ask of piece list  (** `ask(question)` (D20) *)

type statement =
  | Declare of bool * string * ty * expression  (** `var` when true, `let` otherwise (D13) *)
  | Assign of string * expression
  | Show of bool * expression  (** `show_msg`, or `show_msg.same_line` when true (D6) *)
  | Run of string * expression list  (** a procedure giving nothing, standing alone (D120) *)
  | If of expression * statement list * statement list option
  | While of expression * statement list
  | Break
  | Return of expression option

type procedure = { name : string; parameters : (string * ty) list; gives : ty option; body : statement list }

type program = { procedures : procedure list; main : statement list; input : string list }
