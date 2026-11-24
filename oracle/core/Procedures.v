(* Which procedure a call names, shared by the checker and the evaluator so that both always agree.

   The built-in procedures (D6, D20, D22, D26, D196) are known by their word: `show_msg`, `be`, `ask` and `random`.
   Any other word names one of the program's own procedures. *)

From Stdlib Require Import String Ascii List Bool.
From Ralph Require Import Syntax Diagnostics TypedTree Float.
Import ListNotations.
Open Scope string_scope.

(* `be.Text` is a target of its own, since it takes a `Whole` or a `Bool` (D22, D153). *)
Inductive target :=
| Library (which : library)
| Convert_to_text
(* trace: D162 *)
| Convert_to_float
(* trace: D178: `be.Whole.floor` and the rest *)
| Round_to_whole (way : to_whole)
| User (procedure : definition).

Inductive resolution := Resolved (to : target) | Unresolved (problems : list diagnostic).

Definition library_words : list string := ["show_msg"; "be"; "ask"; "random"; "sqrt"].

Definition is_library_word (word : string) : bool := existsb (String.eqb word) library_words.

Definition named (name : string) (d : definition) : bool :=
  match definition_name d with
  | Named n => String.eqb n name
  | Main => false
  end.

Definition is_main (d : definition) : bool :=
  match definition_name d with Main => true | Named _ => false end.

Definition find_definition (p : program) (name : string) : option definition := find (named name) (program_definitions p).

Definition find_main (p : program) : option definition := find is_main (program_definitions p).

Definition find_handler (p : program) (name : string) : option handler :=
  find (fun h => String.eqb (handler_name h) name) (program_handlers p).

(* The word of a name, before its first `.`, as `show_msg` in `show_msg.same_line` (D41). *)
Fixpoint word_of (name : string) : string :=
  match name with
  | EmptyString => EmptyString
  | String c rest => if Ascii.eqb c "."%char then EmptyString else String c (word_of rest)
  end.

(* trace: D41. The kinds a family's word has among the program's procedures, as `same_line` for `show_msg`. *)
Definition kinds_of (p : program) (word : string) : list string :=
  flat_map
    (fun d =>
       match definition_name d with
       | Named n =>
           if String.eqb (word_of n) word && negb (String.eqb n word)
           then [substring (String.length word + 1) (String.length n) n] else []
       | Main => []
       end)
    (program_definitions p).

(* Whether a word names one of the program's own procedures, or a family of them. *)
Definition is_procedure_word (p : program) (word : string) : bool :=
  existsb (fun d => match definition_name d with Named n => String.eqb (word_of n) word | Main => false end)
    (program_definitions p).

(* A word that can't be narrowed: every library word but `show_msg` and `be`, and every procedure of the program's
   own, since families aren't built (D41). *)
Definition plain (c : callee) (t : target) : resolution :=
  match callee_narrowings c with
  | [] => Resolved t
  | (narrowing, at_) :: _ => Unresolved [Refused (Unknown_narrowing (callee_word c) narrowing at_ [])]
  end.

Fixpoint count_narrowing (name : string) (narrowings : list (string * place)) : nat :=
  match narrowings with
  | [] => 0
  | (n, _) :: rest => (if String.eqb n name then 1 else 0) + count_narrowing name rest
  end.

(* The second time a narrowing is written, if it is. *)
Fixpoint written_twice (seen : list string) (narrowings : list (string * place)) : option (string * place) :=
  match narrowings with
  | [] => None
  | (n, at_) :: rest =>
      if existsb (String.eqb n) seen then Some (n, at_) else written_twice (n :: seen) rest
  end.

(* A callee's name as written, as in `show_msg.same_line`, for messages. *)
Definition callee_name (c : callee) : string :=
  fold_left (fun so_far narrowing => so_far ++ "." ++ fst narrowing) (callee_narrowings c) (callee_word c).

(* trace: D6, D102 *)
Definition resolve_show (c : callee) : resolution :=
  let narrowings := callee_narrowings c in
  let unknown :=
    flat_map
      (fun '(n, at_) =>
         if String.eqb n "same_line" then [] else [Refused (Unknown_narrowing "show_msg" n at_ ["same_line"])])
      narrowings in
  match unknown with
  | _ :: _ => Unresolved unknown
  | [] =>
      match written_twice [] narrowings with
      | Some (n, at_) => Unresolved [Refused (Narrowing_twice n at_)]
      | None => Resolved (Library (Show_message (Nat.eqb (count_narrowing "same_line" narrowings) 1)))
      end
  end.

(* trace: D22, D87, D102, D103, D162, D178 *)
Definition resolve_be (c : callee) : resolution :=
  match callee_narrowings c with
  | [] => Unresolved [Refused (Be_without_type (callee_word_at c))]
  | (type_name, type_at) :: rest =>
      if String.eqb type_name "Text" then
        match rest with
        | [] => Resolved Convert_to_text
        | (n, at_) :: _ => Unresolved [Refused (Narrowing_on_narrowed "be.Text" n at_)]
        end
      else if String.eqb type_name "Float" then
        match rest with
        | [] => Resolved Convert_to_float
        | (n, at_) :: _ => Unresolved [Refused (Narrowing_on_narrowed "be.Float" n at_)]
        end
      else if String.eqb type_name "Whole" then
        match rest with
        | [] => Resolved (Library Convert_to_whole)
        | (n, at_) :: further =>
            let plain_way (way : to_whole) :=
              match further with
              | [] => Resolved (Round_to_whole way)
              | (m, at') :: _ => Unresolved [Refused (Narrowing_on_narrowed ("be.Whole." ++ n) m at')]
              end in
            if String.eqb n "floor" then plain_way Whole_floor
            else if String.eqb n "trunc" then plain_way Whole_trunc
            else if String.eqb n "ceil" then plain_way Whole_ceil
            else if String.eqb n "nearest" then
              match further with
              | [] => Resolved (Round_to_whole Whole_nearest)
              | [(m, at')] =>
                  if String.eqb m "even" then Resolved (Round_to_whole Whole_nearest_even)
                  else Unresolved [Refused (Unknown_narrowing "be.Whole.nearest" m at' ["even"])]
              | _ :: (m, at') :: _ => Unresolved [Refused (Narrowing_on_narrowed "be.Whole.nearest.even" m at')]
              end
            else Unresolved [Refused (Unknown_narrowing "be.Whole" n at_ ["floor"; "trunc"; "ceil"; "nearest"])]
        end
      else Unresolved [Not_designed_yet Converting type_at]
  end.

Definition resolve (p : program) (c : callee) : resolution :=
  let word := callee_word c in
  if String.eqb word "show_msg" then resolve_show c
  else if String.eqb word "be" then resolve_be c
  else if String.eqb word "ask" then plain c (Library Ask_for_line)
  else if String.eqb word "random" then plain c (Library Random_number)
  (* trace: D185 *)
  else if String.eqb word "sqrt" then plain c (Library Square_root)
  else
    (* trace: D41. A narrowed call names a member of its word's family by its full name. *)
    match callee_narrowings c with
    | [] =>
        match find_definition p word with
        | Some d => Resolved (User d)
        | None => Unresolved [Refused (Unknown_procedure word (callee_word_at c))]
        end
    | (n, at_) :: _ =>
        match find_definition p (callee_name c) with
        | Some d => Resolved (User d)
        | None =>
            if is_procedure_word p word then Unresolved [Refused (Unknown_narrowing word n at_ (kinds_of p word))]
            else Unresolved [Refused (Unknown_procedure word (callee_word_at c))]
        end
    end.

(* A procedure's name for messages: `proc.main`, or its own name. *)
Definition procedure_label (d : definition) : string :=
  match definition_name d with Main => "proc.main" | Named n => n end.


(* A procedure's labels, from the `labels` line that's the first line of its body (D25). *)
Definition definition_labels (d : definition) : list label_pair :=
  match definition_body d with
  | Then (Labels pairs _) _ => pairs
  | _ => []
  end.

Definition label_of (pairs : list label_pair) (parameter : string) : option string :=
  match find (fun p => String.eqb (pair_parameter p) parameter) pairs with
  | Some p => Some (pair_label p)
  | None => None
  end.

(* What a call has to give, parameter by parameter: each one's type and label (D24, D25). *)
Definition user_parameters (d : definition) : list (type * option string) :=
  map (fun parameter => (parameter_type parameter, label_of (definition_labels d) (parameter_name parameter)))
      (definition_parameters d).

(* The place an expression covers. *)
Definition expression_at (e : expression) : place :=
  match e with
  | Whole_literal _ at_ | Float_literal _ _ _ at_ | Text_literal _ at_ | Bool_literal _ at_ | Variable_value _ at_
  | Bare_word _ at_ | Negate _ at_ | Not _ at_ | Binary _ _ _ _ at_ | Division _ _ _ _ _ at_ | List_literal _ at_
  | All_literal _ at_ | Item _ _ _ _ at_ | Fact _ _ _ at_ | Method _ _ _ _ at_ | Range _ at_ | Pass_up _ _ at_
  | Ignore_failure _ _ at_ | Crash_on_failure _ _ at_ | Bracketed _ at_ | Call _ _ at_
  | Fallback _ _ _ at_ | Slide _ _ at_ | Broken at_ => at_
  end.

Definition statement_at (s : statement) : place :=
  match s with
  | Declare _ _ _ _ _ _ at_ | Assign _ _ _ _ at_ | Run _ at_ | If _ _ _ at_ | While _ _ at_ | Break at_
  | Return _ at_ | Labels _ at_ | Set_item _ _ _ _ _ _ _ at_ | For_each _ _ _ _ _ _ at_ | Handled _ _ _ at_
  | Instead _ at_ => at_
  end.
