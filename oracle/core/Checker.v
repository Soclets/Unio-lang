(* The checker: what makes a program refused at compile time (D90), as data for the shell to word, and the typed tree
   (TypedTree.v) the evaluator runs.

   It goes through every procedure, statement and expression, keeping track of the variables in use, and gives back
   every refusal it finds, in the order it meets them (D54, "every error is shown"). After an error it carries on
   (D55): a refused declaration still creates its variable with its written type, and a refused expression's type
   becomes unknown ([None] here), so nothing more is said about what uses it.

   Alongside, it builds the typed tree. Where something is refused the tree holds a stand-in, which never runs: a
   program runs only when there are no refusals at all, and the second type checker agrees (see [check_program]). *)

From Stdlib Require Import String List Bool ZArith.
From Ralph Require Import Whole Float Syntax Diagnostics TypedTree Procedures.
Import ListNotations.
Open Scope string_scope.
Open Scope list_scope.

Inductive kind_of_variable := Let_variable | Var_variable | Parameter_variable | Loop_variable.

(* What the checker knows about a variable in use. *)
Record variable_info := {
  variable_name : string;
  variable_type : type;
  variable_kind : kind_of_variable;
  variable_name_at : place;
  variable_keyword_at : place }.

(* Where the checker is. *)
Record setting := {
  setting_program : program;
  (* the variables in use, innermost first *)
  setting_scope : list variable_info;
  (* variables declared in blocks that have ended, for D93's `because:` *)
  setting_ended : list (string * place);
  setting_in_loop : bool;
  setting_procedure : string;
  setting_returns : option type;
  (* the failures the procedure lists after `!`, and where its name is; [None] in `proc.main` *)
  setting_failures : option (list string * place);
  (* the lists `for each` loops are going through here, and where each loop is (D173) *)
  setting_going_through : list (string * place);
  (* inside a case: the type `instead` gives, if any, and the procedure whose failure it handles *)
  setting_case : option (option type * string) }.

Definition change_setting (s : setting) (scope : list variable_info) (ended : list (string * place)) (in_loop : bool)
    (going_through : list (string * place)) (case : option (option type * string)) : setting :=
  {| setting_program := setting_program s; setting_scope := scope; setting_ended := ended;
     setting_in_loop := in_loop; setting_procedure := setting_procedure s; setting_returns := setting_returns s;
     setting_failures := setting_failures s; setting_going_through := going_through; setting_case := case |}.

Definition with_scope (s : setting) (scope : list variable_info) : setting :=
  change_setting s scope (setting_ended s) (setting_in_loop s) (setting_going_through s) (setting_case s).

Definition with_ended (s : setting) (ended : list (string * place)) : setting :=
  change_setting s (setting_scope s) ended (setting_in_loop s) (setting_going_through s) (setting_case s).

Definition in_loop (s : setting) : setting :=
  change_setting s (setting_scope s) (setting_ended s) true (setting_going_through s) (setting_case s).

Definition in_case (s : setting) (gives : option type) (procedure : string) : setting :=
  change_setting s (setting_scope s) (setting_ended s) (setting_in_loop s) (setting_going_through s)
    (Some (gives, procedure)).

Definition find_variable (name : string) (scope : list variable_info) : option variable_info :=
  find (fun info => String.eqb (variable_name info) name) scope.

Definition find_ended (name : string) (ended : list (string * place)) : option place :=
  match find (fun entry => String.eqb (fst entry) name) ended with
  | Some (_, at_) => Some at_
  | None => None
  end.

(* A stand-in for a refused part of the typed tree; it never runs. *)
Definition stand_in : Typed.expression := Typed.Whole_literal 0.

(* What a call gives back (D37, D38), and the failures it can give (D23). *)
Inductive gives := Gives_value (t : type) | Gives_nothing | Gives_unknown.

(* A call in the typed tree: a call proper, or `be.Text`, which the tree writes as [Text_of]. *)
Inductive called := Called (c : Typed.call) | Pure (e : Typed.expression) | Not_called.

Record call_check := {
  call_gives : gives;
  call_failures : list string;
  call_diagnostics : list diagnostic;
  call_tree : called }.

Definition unknown_call (diagnostics : list diagnostic) : call_check :=
  {| call_gives := Gives_unknown; call_failures := []; call_diagnostics := diagnostics; call_tree := Not_called |}.

Definition make_call (gives : gives) (failures : list string) (diagnostics : list diagnostic) (tree : called)
  : call_check :=
  {| call_gives := gives; call_failures := failures; call_diagnostics := diagnostics; call_tree := tree |}.

Definition called_value (c : called) : Typed.expression :=
  match c with
  | Called tree => Typed.Value_of tree
  | Pure e => e
  | Not_called => stand_in
  end.

Definition called_tree (c : called) : Typed.call :=
  match c with
  | Called tree => tree
  | _ => Typed.Library_call Ask_for_line [] {| place_file := 0; place_line := 0; place_column := 0; place_width := 0 |}
  end.

(* How deep a chain of calls goes, each the first argument of the next, as `f(g(h(x)))` is 3 deep (D128). *)
Fixpoint chain_depth (e : expression) : nat :=
  match e with
  | Call _ (Argument _ first _) _ => S (chain_depth first)
  | Call _ No_arguments _ => 1
  | _ => 0
  end.

Definition parameter_labels (parameters : list (type * option string)) : list string :=
  map (fun p => match snd p with Some label => label | None => "" end) parameters.

Definition same_labels (a b : list string) : bool :=
  (length a =? length b)%nat && forallb (fun label => (count_occ string_dec a label =? count_occ string_dec b label)%nat) (a ++ b).

Definition arithmetic_of (operator : binary_operator) : arithmetic :=
  match operator with Subtract => Minus | Multiply => Times | _ => Plus end.

Definition is_list (t : type) : bool := match item_of t with Some _ => true | None => false end.

(* trace: D162, D180. A `Whole` beside a `Float`: a plain number gets its point, anything else `be.Float`. *)
Definition mixing (operator : binary_operator) (whole_side : expression) (operator_at : place) : diagnostic :=
  match whole_side with
  | Whole_literal _ at_ => Refused (Literal_point true at_)
  | _ =>
      Refused (Mixed_numbers (match operator with Subtract => "-" | Multiply => "*" | _ => "+" end)
                 (expression_at whole_side) operator_at)
  end.

Definition comparing_numbers (operator : binary_operator) (a b : type) (whole_side : expression) (operator_at : place)
  : diagnostic :=
  match whole_side with
  | Whole_literal _ at_ => Refused (Literal_point true at_)
  | _ => Refused (Compare_types operator a b operator_at)
  end.

(* The type of an operator's result from its sides' types, its tree, or why it's refused. *)
Definition binary_type (operator : binary_operator) (a b : type) (left_operand right_operand : expression)
    (left_tree right_tree : Typed.expression) (operator_at at_ : place)
  : option type * Typed.expression * list diagnostic :=
  match operator with
  | Add | Subtract | Multiply =>
      match a, b with
      | Whole, Whole => (Some Whole, Typed.Maths (arithmetic_of operator) left_tree right_tree at_, [])
      (* trace: D177 *)
      | Float, Float =>
          (Some Float,
           Typed.Float_maths (match operator with Subtract => Float_minus | Multiply => Float_times | _ => Float_plus end)
             left_tree right_tree at_, [])
      (* trace: D162, D180 *)
      | Whole, Float => (None, stand_in, [mixing operator left_operand operator_at])
      | Float, Whole => (None, stand_in, [mixing operator right_operand operator_at])
      | Text, Text =>
          match operator with
          (* trace: D28, D201 *)
          | Add => (None, stand_in, [Refused (Plus_on_text operator_at left_operand right_operand)])
          | _ => (None, stand_in, [Refused (Arithmetic_types operator a b operator_at)])
          end
      | _, _ => (None, stand_in, [Refused (Arithmetic_types operator a b operator_at)])
      end
  | Equal | Not_equal =>
      match a, b with
      | Whole, Whole | Bool, Bool | Float, Float => (Some Bool, Typed.Compare operator a left_tree right_tree, [])
      | Whole, Float => (None, stand_in, [comparing_numbers operator a b left_operand operator_at])
      | Float, Whole => (None, stand_in, [comparing_numbers operator a b right_operand operator_at])
      | Text, Text => (None, stand_in, [Not_designed_yet Comparing_text operator_at])
      | _, _ =>
          if is_list a && is_list b then (None, stand_in, [Not_designed_yet Comparing_lists operator_at])
          else (None, stand_in, [Refused (Compare_types operator a b operator_at)])
      end
  | Less | Greater | At_least | At_most =>
      match a, b with
      | Whole, Whole => (Some Bool, Typed.Compare operator Whole left_tree right_tree, [])
      (* trace: D184 *)
      | Float, Float => (Some Bool, Typed.Compare operator Float left_tree right_tree, [])
      | Whole, Float => (None, stand_in, [comparing_numbers operator a b left_operand operator_at])
      | Float, Whole => (None, stand_in, [comparing_numbers operator a b right_operand operator_at])
      | Text, Text => (None, stand_in, [Not_designed_yet Comparing_text operator_at])
      | Bool, Bool => (None, stand_in, [Not_designed_yet Ordering_bools operator_at])
      | _, _ =>
          if is_list a && is_list b then (None, stand_in, [Not_designed_yet Comparing_lists operator_at])
          else (None, stand_in, [Refused (Compare_types operator a b operator_at)])
      end
  (* trace: D34, D161 *)
  | And | Or =>
      match a, b with
      | Bool, Bool =>
          (Some Bool,
           match operator with And => Typed.Logic_and left_tree right_tree | _ => Typed.Logic_or left_tree right_tree end,
           [])
      | Bool, other => (None, stand_in, [Refused (Logic_on_non_bool operator other (expression_at right_operand))])
      | other, _ => (None, stand_in, [Refused (Logic_on_non_bool operator other (expression_at left_operand))])
      end
  end.

(* Whether two types differ only in their lists' `len.max`, which isn't decided (D167). *)
Fixpoint same_but_limits (a b : type) : bool :=
  match a, b with
  | List_of x _, List_of y _ => same_but_limits x y
  | Array_of x m, Array_of y n => same_but_limits x y && Z.eqb m n
  | _, _ => type_eqb a b
  end.

(* An expression where a value of type [expected] goes, as in a declaration or an argument. *)
Definition expect (found : option type) (expected : type) (problem : type -> diagnostic) (at_ : place)
  : list diagnostic :=
  match found with
  | Some t =>
      if type_eqb t expected then []
      else if same_but_limits t expected then [Not_designed_yet List_limits_differ at_]
      else [problem t]
  | None => []
  end.

(* A call standing where a value goes (D38, D23). *)
Definition as_value (c : call_check) (at_ : place) : option type * Typed.expression * list diagnostic :=
  match call_gives c, call_failures c with
  | Gives_value t, [] => (Some t, called_value (call_tree c), call_diagnostics c)
  | Gives_value _, _ :: _ => (None, stand_in, call_diagnostics c ++ [Refused (Failure_unhandled at_)])
  | Gives_nothing, _ => (None, stand_in, call_diagnostics c ++ [Refused (Gives_nothing_used at_)])
  | Gives_unknown, _ => (None, stand_in, call_diagnostics c)
  end.

Fixpoint count_steps (path : steps) : nat :=
  match path with
  | No_steps => 0
  | Step _ _ _ _ rest => S (count_steps rest)
  end.

(* trace: D128. A slide is for a chain of three calls or more, written as a slide all the way. *)
Definition slide_shape (start : expression) (path : steps) (at_ : place) : list diagnostic :=
  let depth := chain_depth start in
  if (2 <=? depth)%nat then [Refused (Calls_as_slide (Slide start path at_))]
  else if (depth + count_steps path <? 3)%nat then [Refused (Slide_as_calls (Slide start path at_))]
  else [].

(* trace: D29, D200, D202. One piece of text, filled in: a name in braces becomes its value as text. *)
Definition check_piece (s : setting) (p : piece) : Typed.expression * list diagnostic :=
  match p with
  | Piece_text t => (Typed.Text_literal t, [])
  | Piece_name name at_ =>
      match find_variable name (setting_scope s) with
      | Some info =>
          match variable_type info with
          | Text => (Typed.Read name, [])
          | Whole => (Typed.Text_of Whole (Typed.Read name) at_, [])
          | Bool => (Typed.Text_of Bool (Typed.Read name) at_, [])
          (* trace: D155 *)
          | Float => (Typed.Text_of Float (Typed.Read name) at_, [])
          | _ => (stand_in, [Not_designed_yet Converting at_])
          end
      | None => (stand_in, [Refused (Brace_not_variable name at_)])
      end
  (* trace: D175 *)
  | Piece_places name at_ places _ =>
      match find_variable name (setting_scope s) with
      | Some info =>
          match variable_type info, whole_of_literal places with
          | Float, Some n => (Typed.Text_places n (Typed.Read name), [])
          | Float, None => (stand_in, [Already_refused at_])
          | other, _ => (stand_in, [Refused (Places_on_non_float name other at_)])
          end
      | None => (stand_in, [Refused (Brace_not_variable name at_)])
      end
  | Piece_other at_ => (stand_in, [Refused (Brace_calculation at_)])
  | Piece_unclosed at_ => (stand_in, [Not_designed_yet Format_unclosed at_])
  end.

Definition check_text (s : setting) (pieces : list piece) : Typed.expression * list diagnostic :=
  let checked := map (check_piece s) pieces in
  let diagnostics := flat_map snd checked in
  match checked with
  | [] => (Typed.Text_literal "", diagnostics)
  | [(Typed.Text_literal t, _)] => (Typed.Text_literal t, diagnostics)
  | _ => (Typed.Join (map fst checked), diagnostics)
  end.

(* An argument, already checked by its own lights. *)
Record checked_argument := {
  argument_label : option (string * place);
  argument_value : expression;
  argument_type : option type;
  argument_tree : Typed.expression;
  argument_diagnostics : list diagnostic }.

Definition argument_at (a : checked_argument) : place := expression_at (argument_value a).

Definition values_diagnostics (given : list checked_argument) : list diagnostic :=
  flat_map argument_diagnostics given.

Definition trees (given : list checked_argument) : list Typed.expression := map argument_tree given.

Definition argument_labels (given : list checked_argument) : list string :=
  map (fun a => match argument_label a with Some (label, _) => label | None => "" end) given.

(* Labels written in another order than the procedure's parameters, which isn't decided (D24, D25). *)
Definition labels_reordered (parameters : list (type * option string)) (given : list checked_argument) : bool :=
  let written := argument_labels given in
  let expected := parameter_labels parameters in
  (if list_eq_dec string_dec written expected then false else true) && same_labels written expected.

(* Checks arguments against parameters, each a type and a label, the counts already known to match (D24). *)
Fixpoint check_pairs (procedure : string) (parameters : list (type * option string)) (given : list checked_argument)
  : list diagnostic :=
  match given, parameters with
  | a :: rest, (expected, wanted) :: others =>
      let label_problems :=
        match wanted, argument_label a with
        | Some w, None => [Refused (Missing_label w (argument_at a))]
        | None, Some (_, label_at) => [Refused (Label_where_none label_at (argument_at a))]
        | Some w, Some (l, label_at) => if String.eqb w l then [] else [Refused (Wrong_label w l label_at)]
        | None, None => []
        end in
      argument_diagnostics a ++ label_problems
        ++ expect (argument_type a) expected
             (fun found => Refused (Argument_type procedure expected found (argument_at a))) (argument_at a)
        ++ check_pairs procedure others rest
  | _, _ => []
  end.

(* Checks a call against a procedure's parameters, counting first (D24, D88). *)
Definition check_against (procedure : string) (parameters : list (type * option string))
    (given : list checked_argument) (at_ : place) (declared_at : option place) : list diagnostic :=
  if negb (Nat.eqb (length given) (length parameters)) then
    values_diagnostics given
      ++ [Refused (Argument_count procedure (length parameters) (length given) at_ declared_at)]
  else if labels_reordered parameters given then values_diagnostics given ++ [Not_designed_yet Label_order at_]
  else check_pairs procedure parameters given.

(* `be.Text` and `be.Whole` take one value without a label (D22): gives its type, place and tree. *)
Definition check_single (procedure : string) (given : list checked_argument) (at_ : place)
  : option (type * place * Typed.expression) * list diagnostic :=
  match given with
  | [a] =>
      match argument_label a with
      | None =>
          match argument_type a with
          | Some t => (Some (t, argument_at a, argument_tree a), argument_diagnostics a)
          | None => (None, argument_diagnostics a)
          end
      | Some (_, label_at) =>
          (None, argument_diagnostics a ++ [Refused (Label_where_none label_at (argument_at a))])
      end
  | _ => (None, values_diagnostics given ++ [Refused (Argument_count procedure 1 (length given) at_ None)])
  end.

(* A whole number written plainly in the code, as `6` or `-1`. *)
Definition plain_number (e : expression) : option Z :=
  match e with
  | Whole_literal digits _ => whole_of_literal digits
  | Negate (Whole_literal digits _) _ => option_map Z.opp (whole_of_literal digits)
  | _ => None
  end.

(* trace: D160. `random` given two plain numbers with `from:` above `to:` is refused, with them swapped as the fix. *)
Definition random_backwards (given : list checked_argument) (at_ : place) : list diagnostic :=
  match given with
  | [low; high] =>
      match plain_number (argument_value low), plain_number (argument_value high) with
      | Some l, Some h =>
          if (h <? l)%Z then [Refused (Random_backwards_plain at_ (argument_at low) (argument_at high))] else []
      | _, _ => []
      end
  | _ => []
  end.

Definition gives_of (d : definition) : gives :=
  match definition_returns d with Some t => Gives_value t | None => Gives_nothing end.

Definition failures_of (d : definition) : list string := map fst (definition_failures d).

Definition library_call (which : library) (given : list Typed.expression) (at_ : place) : called :=
  Called (Typed.Library_call which given at_).

(* A call of [target], once its arguments are checked. *)
Definition check_target (procedure : string) (target : target) (given : list checked_argument) (at_ : place)
  : call_check :=
  match target with
  | Library (Show_message same_line) =>
      make_call Gives_nothing [] (check_against procedure [(Text, None)] given at_ None)
        (library_call (Show_message same_line) (trees given) at_)
  | Convert_to_text =>
      match check_single procedure given at_ with
      (* trace: D22, D153 *)
      | (Some (Whole, _, tree), d) => make_call (Gives_value Text) [] d (Pure (Typed.Text_of Whole tree at_))
      | (Some (Bool, _, tree), d) => make_call (Gives_value Text) [] d (Pure (Typed.Text_of Bool tree at_))
      | (Some (Float, _, tree), d) => make_call (Gives_value Text) [] d (Pure (Typed.Text_of Float tree at_))
      | (Some (Text, value_at, _), d) => unknown_call (d ++ [Refused (Convert_to_same Text value_at)])
      | (Some (_, value_at, _), d) => unknown_call (d ++ [Not_designed_yet Converting value_at])
      | (None, d) => unknown_call d
      end
  | Library Convert_to_whole =>
      match check_single procedure given at_ with
      | (Some (Text, _, tree), d) =>
          make_call (Gives_value Whole) ["not_a_whole"] d (library_call Convert_to_whole [tree] at_)
      | (Some (Whole, value_at, _), d) => unknown_call (d ++ [Refused (Convert_to_same Whole value_at)])
      (* trace: D178 *)
      | (Some (Float, _, _), d) => unknown_call (d ++ [Refused (Bare_whole_of_float at_)])
      | (Some (_, value_at, _), d) => unknown_call (d ++ [Not_designed_yet Converting value_at])
      | (None, d) => unknown_call d
      end
  (* trace: D162 *)
  | Convert_to_float =>
      match check_single procedure given at_ with
      | (Some (Whole, _, tree), d) => make_call (Gives_value Float) [] d (Pure (Typed.Float_of tree))
      | (Some (Float, value_at, _), d) => unknown_call (d ++ [Refused (Convert_to_same Float value_at)])
      | (Some (_, value_at, _), d) => unknown_call (d ++ [Not_designed_yet Converting value_at])
      | (None, d) => unknown_call d
      end
  (* trace: D178 *)
  | Round_to_whole way =>
      match check_single procedure given at_ with
      | (Some (Float, _, tree), d) => make_call (Gives_value Whole) [] d (Pure (Typed.Whole_of_float way tree at_))
      | (Some (_, value_at, _), d) => unknown_call (d ++ [Not_designed_yet Converting value_at])
      | (None, d) => unknown_call d
      end
  (* trace: D185 *)
  | Library Square_root =>
      make_call (Gives_value Float) [] (check_against procedure [(Float, None)] given at_ None)
        (library_call Square_root (trees given) at_)
  | Library Ask_for_line =>
      make_call (Gives_value Text) [] (check_against procedure [(Text, None)] given at_ None)
        (library_call Ask_for_line (trees given) at_)
  | Library Random_number =>
      make_call (Gives_value Whole) []
        (check_against procedure [(Whole, Some "from"); (Whole, Some "to")] given at_ None
           ++ random_backwards given at_)
        (library_call Random_number (trees given) at_)
  | Library _ => unknown_call (values_diagnostics given)
  | User d =>
      make_call (gives_of d) (failures_of d)
        (check_against procedure (user_parameters d) given at_ (Some (definition_name_at d)))
        (Called (Typed.Procedure_call (procedure_label d) (trees given) at_))
  end.

(* The types a call's arguments should have, as far as its procedure says, for `[]` and other lists (D76). *)
Definition expected_arguments (p : program) (name : callee) : list (option type) :=
  match resolve p name with
  | Resolved (User d) => map (fun x => Some (fst x)) (user_parameters d)
  | Resolved (Library (Show_message _)) | Resolved (Library Ask_for_line) => [Some Text]
  | Resolved (Library Random_number) => [Some Whole; Some Whole]
  | Resolved (Library Square_root) => [Some Float]
  | _ => []
  end.

(* trace: D4, D24, D38, D92, D128 *)
Definition check_call (s : setting) (name : callee) (given : list checked_argument) (at_ : place) : call_check :=
  match resolve (setting_program s) name with
  | Unresolved problems =>
      match callee_narrowings name, find_variable (callee_word name) (setting_scope s) with
      | [], Some _ =>
          unknown_call (values_diagnostics given ++ [Refused (Variable_called (callee_word name) (callee_word_at name))])
      | _, _ => unknown_call (problems ++ values_diagnostics given)
      end
  | Resolved target => check_target (callee_name name) target given at_
  end.

(* trace: D128, D142. Three or more calls nested, each the first argument of the next, are written as a slide. The
   shell keeps only the outermost of a chain's refusals (D55). *)
Definition chain_problem (e : expression) : list diagnostic :=
  if (3 <=? chain_depth e)%nat then [Refused (Calls_as_slide e)] else [].

(* A slide's step: [target] called with the slid value first, then the step's own arguments (D5). *)
Definition check_step_target (procedure : string) (target : target) (slid : option type) (slid_tree : Typed.expression)
    (given : list checked_argument) (at_ : place) : call_check :=
  let all_trees := slid_tree :: trees given in
  let one_more (parameters : list (type * option string)) (gives : gives) (failures : list string) (tree : called) :=
    match parameters with
    | [] =>
        unknown_call (values_diagnostics given ++ [Refused (Argument_count procedure 0 (S (length given)) at_ None)])
    | (first, _) :: others =>
        make_call gives failures
          (expect slid first (fun found => Refused (Slid_value_type procedure first found at_)) at_
             ++ check_against procedure others given at_ None)
          tree
    end in
  match target with
  | Library (Show_message same_line) =>
      one_more [(Text, None)] Gives_nothing [] (library_call (Show_message same_line) all_trees at_)
  | Convert_to_text =>
      match slid with
      | Some Text => unknown_call (values_diagnostics given ++ [Refused (Convert_to_same Text at_)])
      | Some Bool => one_more [(Bool, None)] (Gives_value Text) [] (Pure (Typed.Text_of Bool slid_tree at_))
      | Some Float => one_more [(Float, None)] (Gives_value Text) [] (Pure (Typed.Text_of Float slid_tree at_))
      | Some Whole | None => one_more [(Whole, None)] (Gives_value Text) [] (Pure (Typed.Text_of Whole slid_tree at_))
      | Some _ => unknown_call (values_diagnostics given ++ [Not_designed_yet Converting at_])
      end
  | Library Convert_to_whole =>
      match slid with
      | Some Whole => unknown_call (values_diagnostics given ++ [Refused (Convert_to_same Whole at_)])
      | Some Float => unknown_call (values_diagnostics given ++ [Refused (Bare_whole_of_float at_)])
      | Some Text | None =>
          one_more [(Text, None)] (Gives_value Whole) ["not_a_whole"] (library_call Convert_to_whole all_trees at_)
      | Some _ => unknown_call (values_diagnostics given ++ [Not_designed_yet Converting at_])
      end
  | Library Ask_for_line =>
      one_more [(Text, None)] (Gives_value Text) [] (library_call Ask_for_line all_trees at_)
  | Library Random_number =>
      one_more [(Whole, Some "from"); (Whole, Some "to")] (Gives_value Whole) []
        (library_call Random_number all_trees at_)
  | Library Square_root => one_more [(Float, None)] (Gives_value Float) [] (library_call Square_root all_trees at_)
  | Convert_to_float =>
      match slid with
      | Some Float => unknown_call (values_diagnostics given ++ [Refused (Convert_to_same Float at_)])
      | Some Whole | None => one_more [(Whole, None)] (Gives_value Float) [] (Pure (Typed.Float_of slid_tree))
      | Some _ => unknown_call (values_diagnostics given ++ [Not_designed_yet Converting at_])
      end
  | Round_to_whole way =>
      match slid with
      | Some Float | None =>
          one_more [(Float, None)] (Gives_value Whole) [] (Pure (Typed.Whole_of_float way slid_tree at_))
      | Some _ => unknown_call (values_diagnostics given ++ [Not_designed_yet Converting at_])
      end
  | Library _ => unknown_call (values_diagnostics given)
  | User d =>
      one_more (user_parameters d) (gives_of d) (failures_of d)
        (Called (Typed.Procedure_call (procedure_label d) all_trees at_))
  end.

Definition check_step (s : setting) (name : callee) (slid : option type) (slid_tree : Typed.expression)
    (given : list checked_argument) (at_ : place) : call_check :=
  match resolve (setting_program s) name with
  | Unresolved problems => unknown_call (problems ++ values_diagnostics given)
  | Resolved target => check_step_target (callee_name name) target slid slid_tree given at_
  end.

(* A word that names a procedure, the program's own or a built-in, or a family of them (D41). *)
Definition procedure_named (p : program) (word : string) : bool :=
  is_library_word word || is_procedure_word p word.

Fixpoint argument_count (given : arguments) : Z :=
  match given with
  | No_arguments => 0
  | Argument _ _ rest => 1 + argument_count rest
  end.

(* trace: D46, D75. A position written as a plain number that no list has, or past an array's length. *)
Definition plain_position (label : string) (index : expression) (container : type) (at_ : place) : list diagnostic :=
  match plain_number index with
  | Some n =>
      let lowest := if String.eqb label "pos" then 1%Z else 0%Z in
      let length := match container with Array_of _ l => Some l | _ => None end in
      let beyond := match length with Some l => (lowest + l <=? n)%Z | None => false end in
      if (n <? lowest)%Z || beyond then [Refused (Bad_plain_position label n length at_)] else []
  | None => []
  end.

(* The failures of a call that the procedure it's in doesn't list, for `?` (D23). *)
Definition unlisted (s : setting) (failures : list string) : list string :=
  match setting_failures s with
  | Some (listed, _) => filter (fun f => negb (existsb (String.eqb f) listed)) failures
  | None => failures
  end.

(* trace: D23. `?` after a call: its failures pass up, so its procedure must list them; `proc.main` has no caller. *)
Definition pass_up_problems (s : setting) (procedure : string) (failures : list string) (at_ : place)
  : list diagnostic :=
  match setting_failures s with
  | None => [Not_designed_yet Failure_leaving_main at_]
  | Some (_, header_at) =>
      map (fun f => Refused (Failure_not_listed procedure f at_ header_at)) (unlisted s failures)
  end.

Definition callee_of_attempt (e : expression) : string :=
  match e with
  | Call name _ _ => callee_name name
  | _ => ""
  end.

Fixpoint check_expression (s : setting) (expected : option type) (e : expression) {struct e}
  : option type * Typed.expression * list diagnostic :=
  match e with
  (* trace: D180. A number without a point is a `Whole`; where a `Float` goes, it's refused with its point as the
     fix. *)
  | Whole_literal digits at_ =>
      match expected with
      | Some Float => (Some Float, stand_in, [Refused (Literal_point true at_)])
      | _ =>
          match whole_of_literal digits with
          | Some n =>
              if (whole_minimum <=? n)%Z && (n <=? whole_maximum)%Z then (Some Whole, Typed.Whole_literal n, [])
              else (None, stand_in, [Not_designed_yet Whole_literal_out_of_range at_])
          | None => (None, stand_in, [Already_refused at_])
          end
      end
  (* trace: D155, D180 *)
  | Float_literal before after approximate at_ =>
      match float_of_decimal before after with
      | Some (f, exact) =>
          match expected, exact && negb approximate && match whole_of_literal after with Some Z0 => true | _ => false end with
          | Some Whole, true => (Some Whole, stand_in, [Refused (Literal_point false at_)])
          | _, _ =>
              (Some Float, Typed.Float_literal f,
               if exact && approximate then [Refused (Exact_literal_marked at_)]
               else if negb exact && negb approximate then [Refused (Approximate_literal at_)]
               else [])
          end
      | None => (None, stand_in, [Not_designed_yet Float_literal_out_of_range at_])
      end
  | Text_literal pieces _ => let (tree, ds) := check_text s pieces in (Some Text, tree, ds)
  | Bool_literal b _ => (Some Bool, Typed.Bool_literal b, [])
  | Variable_value name at_ =>
      match find_variable name (setting_scope s) with
      | Some info => (Some (variable_type info), Typed.Read name, [])
      | None =>
          if procedure_named (setting_program s) name then (None, stand_in, [Refused (Procedure_without_brackets name at_)])
          else (None, stand_in, [Refused (Unknown_variable name at_ (find_ended name (setting_ended s)))])
      end
  | Bare_word word at_ =>
      if procedure_named (setting_program s) word then (None, stand_in, [Refused (Procedure_without_brackets word at_)])
      else (None, stand_in, [Not_designed_yet Bare_word_not_procedure at_])
  | Negate operand at_ =>
      let '(t, tree, ds) := check_expression s None operand in
      match t with
      | Some Whole => (Some Whole, Typed.Negate tree at_, ds)
      | Some Float => (Some Float, Typed.Float_negate tree, ds)
      | Some other => (None, stand_in, ds ++ [Refused (Negate_non_number other at_)])
      | None => (None, stand_in, ds)
      end
  | Not operand _ =>
      let '(t, tree, ds) := check_expression s None operand in
      match t with
      | Some Bool => (Some Bool, Typed.Logic_not tree, ds)
      (* trace: D161 *)
      | Some other => (None, stand_in, ds ++ [Refused (Not_on_non_bool other (expression_at operand))])
      | None => (None, stand_in, ds)
      end
  | Binary operator left_operand right_operand operator_at at_ =>
      let '(a, left_tree, dl) := check_expression s None left_operand in
      let '(b, right_tree, dr) := check_expression s None right_operand in
      match a, b with
      | Some a', Some b' =>
          let '(t, tree, d) := binary_type operator a' b' left_operand right_operand left_tree right_tree operator_at at_ in
          (t, tree, dl ++ dr ++ d)
      | _, _ => (None, stand_in, dl ++ dr)
      end
  (* trace: D70, D71, D72 *)
  | Division way word left_operand right_operand operator_at at_ =>
      let '(a, left_tree, dl) := check_expression s None left_operand in
      let '(b, right_tree, dr) := check_expression s None right_operand in
      match way with
      | None => (None, stand_in, dl ++ dr ++ [Refused (Bare_division word operator_at)])
      | Some w =>
          match a, b with
          | Some Whole, Some Whole => (Some Whole, Typed.Divide w left_tree right_tree at_, dl ++ dr)
          (* trace: D179 *)
          | Some Float, Some Float =>
              match w with
              | Divide_exactly => (Some Float, Typed.Float_maths Float_divide left_tree right_tree at_, dl ++ dr)
              | _ => (None, stand_in, dl ++ dr ++ [Refused (Division_types word Float Float operator_at)])
              end
          | Some Whole, Some Float =>
              (None, stand_in, dl ++ dr ++ [match left_operand with
                                            | Whole_literal _ l_at => Refused (Literal_point true l_at)
                                            | _ => Refused (Mixed_numbers word (expression_at left_operand) operator_at)
                                            end])
          | Some Float, Some Whole =>
              (None, stand_in, dl ++ dr ++ [match right_operand with
                                            | Whole_literal _ r_at => Refused (Literal_point true r_at)
                                            | _ => Refused (Mixed_numbers word (expression_at right_operand) operator_at)
                                            end])
          | Some a', Some b' => (None, stand_in, dl ++ dr ++ [Refused (Division_types word a' b' operator_at)])
          | _, _ => (None, stand_in, dl ++ dr)
          end
      end
  (* trace: D75, D76, D167 *)
  | List_literal items at_ =>
      let checked := check_list_items s (match expected with Some t => item_of t | None => None end) items in
      let diagnostics := flat_map argument_diagnostics checked in
      let count := argument_count items in
      let first_type := match checked with a :: _ => argument_type a | [] => None end in
      let item_problems (item : type) :=
        flat_map (fun a => expect (argument_type a) item (fun found => Refused (Item_type item found (argument_at a)))
                             (argument_at a)) checked in
      match expected, checked with
      | Some (List_of item most), _ =>
          (Some (List_of item most), Typed.List_literal (List_of item most) (trees checked),
           diagnostics ++ item_problems item
             ++ match most with
                | Some m => if (m <? count)%Z then [Refused (Too_many_items count m at_)] else []
                | None => []
                end)
      | Some (Array_of item length), _ =>
          (Some (Array_of item length), Typed.List_literal (Array_of item length) (trees checked),
           diagnostics ++ item_problems item
             ++ if Z.eqb count length then [] else [Refused (Array_length count length at_)])
      | Some other, [] => (None, stand_in, [Refused (Empty_list_for other at_)])
      | _, [] => (None, stand_in, [Not_designed_yet Empty_list_unknown at_])
      | _, _ =>
          match first_type with
          | Some item =>
              (Some (List_of item None), Typed.List_literal (List_of item None) (trees checked),
               diagnostics ++ item_problems item)
          | None => (None, stand_in, diagnostics)
          end
      end
  (* trace: D169 *)
  | All_literal value at_ =>
      match expected with
      | Some (Array_of item length) =>
          let '(t, tree, d) := check_expression s (Some item) value in
          (Some (Array_of item length), Typed.All_literal (Array_of item length) tree,
           d ++ expect t item (fun found => Refused (Item_type item found (expression_at value))) (expression_at value))
      | _ => let '(_, _, d) := check_expression s None value in (None, stand_in, d ++ [Refused (All_needs_array at_)])
      end
  (* trace: D46, D75 *)
  | Item container label label_at index at_ =>
      let '(c, container_tree, dc) := check_expression s None container in
      let '(i, index_tree, di) := check_expression s None index in
      let label_problems :=
        if String.eqb label "pos" || String.eqb label "offset" then [] else [Refused (Item_without_label label label_at)] in
      let index_problems :=
        match i with
        | Some Whole | None => []
        | Some other => [Refused (Position_type other (expression_at index))]
        end in
      match c with
      | Some t =>
          match item_of t with
          | Some item =>
              let problems := label_problems ++ index_problems
                                ++ (if String.eqb label "pos" || String.eqb label "offset"
                                    then plain_position label index t (expression_at index) else []) in
              (match problems with [] => Some item | _ => None end,
               Typed.Item (String.eqb label "pos") container_tree index_tree at_, dc ++ di ++ problems)
          | None => (None, stand_in, dc ++ di ++ [Refused (Not_a_list "[ ]" t (expression_at container))])
          end
      | None => (None, stand_in, dc ++ di ++ label_problems)
      end
  (* trace: D79 *)
  | Fact value name name_at _ =>
      let '(t, tree, d) := check_expression s None value in
      if String.eqb name "len" then
        match t with
        | Some t' =>
            if is_list t' then (Some Whole, Typed.Length tree, d) else (None, stand_in, d ++ [Not_designed_yet Other_facts name_at])
        | None => (None, stand_in, d)
        end
      else (None, stand_in, d ++ [Not_designed_yet Other_facts name_at])
  (* A method changing a list gives nothing back, so it can't be used as a value (D38, D80). *)
  | Method _ name name_at _ at_ =>
      if String.eqb name "add" || String.eqb name "remove" then (None, stand_in, [Refused (Gives_nothing_used at_)])
      else (None, stand_in, [Not_designed_yet Other_methods name_at])
  | Range _ at_ => (None, stand_in, [Not_designed_yet Range_elsewhere at_])
  | Bracketed inner _ => check_expression s expected inner
  | Call name given at_ =>
      let '(t, tree, d) :=
        as_value (check_call s name (check_arguments s (expected_arguments (setting_program s) name) given) at_) at_ in
      (t, tree, d ++ chain_problem (Call name given at_))
  (* trace: D23 *)
  | Pass_up attempt operator_at _ =>
      match attempt with
      | Call name given call_at =>
          let c := check_call s name (check_arguments s (expected_arguments (setting_program s) name) given) call_at in
          let chain := chain_problem attempt in
          match call_gives c, call_failures c, call_tree c with
          | Gives_value t, _ :: _, Called tree =>
              (Some t, Typed.Value_of (Typed.Passing tree),
               call_diagnostics c ++ chain ++ pass_up_problems s (callee_name name) (call_failures c) operator_at)
          | Gives_nothing, _ :: _, _ => (None, stand_in, call_diagnostics c ++ chain ++ [Refused (Gives_nothing_used call_at)])
          | Gives_unknown, _, _ => (None, stand_in, call_diagnostics c ++ chain)
          | _, _, _ => (None, stand_in, call_diagnostics c ++ chain ++ [Refused (Without_failing_call "?" operator_at)])
          end
      | _ =>
          let '(_, _, da) := check_expression s None attempt in
          (None, stand_in, da ++ [Refused (Without_failing_call "?" operator_at)])
      end
  (* trace: D152 *)
  | Crash_on_failure attempt operator_at _ =>
      match attempt with
      | Call name given call_at =>
          let c := check_call s name (check_arguments s (expected_arguments (setting_program s) name) given) call_at in
          let chain := chain_problem attempt in
          match call_gives c, call_failures c, call_tree c with
          | Gives_value t, _ :: _, Called tree =>
              (Some t, Typed.Value_of (Typed.Crashing tree (callee_name name) operator_at), call_diagnostics c ++ chain)
          | Gives_nothing, _ :: _, _ => (None, stand_in, call_diagnostics c ++ chain ++ [Refused (Gives_nothing_used call_at)])
          | Gives_unknown, _, _ => (None, stand_in, call_diagnostics c ++ chain)
          | _, _, _ =>
              (None, stand_in, call_diagnostics c ++ chain ++ [Refused (Without_failing_call "?? crash" operator_at)])
          end
      | _ =>
          let '(_, _, da) := check_expression s None attempt in
          (None, stand_in, da ++ [Refused (Without_failing_call "?? crash" operator_at)])
      end
  (* trace: D121. `?? ignore` where a value goes. *)
  | Ignore_failure attempt operator_at _ =>
      match attempt with
      | Call name given call_at =>
          let c := check_call s name (check_arguments s (expected_arguments (setting_program s) name) given) call_at in
          match call_gives c with
          | Gives_value t => (None, stand_in, call_diagnostics c ++ [Refused (Ignore_value (callee_name name) t None operator_at)])
          | Gives_nothing => (None, stand_in, call_diagnostics c ++ [Refused (Gives_nothing_used call_at)])
          | Gives_unknown => (None, stand_in, call_diagnostics c)
          end
      | _ =>
          let '(_, _, da) := check_expression s None attempt in
          (None, stand_in, da ++ [Refused (Without_failing_call "?? ignore" operator_at)])
      end
  | Fallback attempt fallback operator_at _ =>
      match attempt with
      | Call name given call_at =>
          let c := check_call s name (check_arguments s (expected_arguments (setting_program s) name) given) call_at in
          let chain := chain_problem (Call name given call_at) in
          let fallback_expected := match call_gives c with Gives_value t => Some t | _ => None end in
          let '(f, fallback_tree, df) := check_expression s fallback_expected fallback in
          match call_gives c, call_failures c, call_tree c with
          | Gives_value t, _ :: _, Called tree =>
              (Some t, Typed.Fallback tree fallback_tree,
               call_diagnostics c ++ chain ++ df
                 ++ expect f t (fun found => Refused (Fallback_type t found (expression_at fallback))) (expression_at fallback))
          | Gives_unknown, _, _ => (None, stand_in, call_diagnostics c ++ chain ++ df)
          | _, _, _ =>
              (None, stand_in, call_diagnostics c ++ chain ++ df ++ [Refused (Without_failing_call "??" operator_at)])
          end
      | _ =>
          let '(_, _, da) := check_expression s None attempt in
          let '(_, _, df) := check_expression s None fallback in
          (None, stand_in, da ++ df ++ [Refused (Without_failing_call "??" operator_at)])
      end
  | Slide start path at_ =>
      let '(t, start_tree, ds) := check_expression s None start in
      let '(result, tree, dc) := as_value (check_steps s t start_tree path) at_ in
      (result, tree, ds ++ slide_shape start path at_ ++ dc)
  | Broken at_ => (None, stand_in, [Already_refused at_])
  end

(* Checks each argument by its own lights, each given the type its parameter has, if known. *)
with check_arguments (s : setting) (expectations : list (option type)) (given : arguments) {struct given}
  : list checked_argument :=
  match given with
  | No_arguments => []
  | Argument label value rest =>
      let '(this, others) := match expectations with x :: xs => (x, xs) | [] => (None, []) end in
      let '(t, tree, d) := check_expression s this value in
      {| argument_label := label; argument_value := value; argument_type := t; argument_tree := tree;
         argument_diagnostics := d |}
        :: check_arguments s others rest
  end

(* A list's items, each of the type [item] if it's known. *)
with check_list_items (s : setting) (item : option type) (given : arguments) {struct given}
  : list checked_argument :=
  match given with
  | No_arguments => []
  | Argument label value rest =>
      let '(t, tree, d) := check_expression s item value in
      {| argument_label := label; argument_value := value; argument_type := t; argument_tree := tree;
         argument_diagnostics := d |}
        :: check_list_items s item rest
  end

(* A slide's steps, each given the value slid into it as its first argument (D5); gives the last step's call. *)
with check_steps (s : setting) (slid : option type) (slid_tree : Typed.expression) (path : steps) {struct path}
  : call_check :=
  match path with
  | No_steps => unknown_call []
  | Step name _ given at_ rest =>
      let expectations := match expected_arguments (setting_program s) name with _ :: xs => xs | [] => [] end in
      let this := check_step s name slid slid_tree (check_arguments s expectations given) at_ in
      match rest with
      | No_steps => this
      | Step _ _ _ _ _ =>
          let '(next, next_tree, d) := as_value this at_ in
          let later := check_steps s next next_tree rest in
          make_call (call_gives later) (call_failures later) (d ++ call_diagnostics later) (call_tree later)
      end
  end.

(* ---------------------------------------------------------------------------------------------------------------- *)
(* Methods on lists *)

(* What a list method needs: the list's variable, its type, and the call that gives the changed list. *)
Record method_check := {
  method_variable : string;
  method_failures : list string;
  method_tree : option Typed.call;
  method_diagnostics : list diagnostic }.

Definition no_method (diagnostics : list diagnostic) : method_check :=
  {| method_variable := ""; method_failures := []; method_tree := None; method_diagnostics := diagnostics |}.

(* trace: D77, D173. Whether a variable's list may change here: only a `var`'s, and not while a `for each` goes
   through it. *)
Definition list_may_change (s : setting) (name : string) (at_ : place) : list diagnostic :=
  match find_variable name (setting_scope s) with
  | Some info =>
      match variable_kind info with
      | Let_variable => [Refused (List_cannot_change name at_ (variable_keyword_at info) true)]
      | Parameter_variable => [Refused (List_cannot_change name at_ (variable_name_at info) false)]
      | Loop_variable => [Refused (Loop_variable_cannot_change name at_ (variable_keyword_at info))]
      | Var_variable =>
          match find (fun entry => String.eqb (fst entry) name) (setting_going_through s) with
          | Some (_, loop_at) => [Refused (Going_through name at_ loop_at)]
          | None => []
          end
      end
  | None => []
  end.

(* A position given to `.add` or `.remove`, as `pos: n` or `offset: n` (D80). *)
Definition position_argument (a : checked_argument) : option bool :=
  match argument_label a with
  | Some (label, _) =>
      if String.eqb label "pos" then Some true else if String.eqb label "offset" then Some false else None
  | None => None
  end.

(* trace: D77, D80, D167, D168. `list.add(item)`, `list.add(item, pos: n)` and `list.remove(pos: n)`. *)
Definition check_method (s : setting) (target : expression) (name : string) (name_at : place) (given : arguments)
    (at_ : place) : method_check :=
  match target with
  | Variable_value variable variable_at =>
      match find_variable variable (setting_scope s) with
      | None => no_method [Refused (Unknown_variable variable variable_at (find_ended variable (setting_ended s)))]
      | Some info =>
          let t := variable_type info in
          let change := list_may_change s variable variable_at in
          let item_expected := item_of t in
          let checked := check_arguments s [item_expected; Some Whole] given in
          let ds := values_diagnostics checked in
          let typed_item (a : checked_argument) (item : type) :=
            expect (argument_type a) item (fun found => Refused (Argument_type (variable ++ "." ++ name) item found (argument_at a)))
              (argument_at a) in
          let typed_position (a : checked_argument) :=
            match argument_type a with
            | Some Whole | None => []
            | Some other => [Refused (Position_type other (argument_at a))]
            end in
          let make (failures : list string) (tree : Typed.call) (problems : list diagnostic) :=
            {| method_variable := variable; method_failures := failures;
               method_tree := Some tree; method_diagnostics := ds ++ change ++ problems |} in
          match t with
          | List_of item most =>
              if String.eqb name "add" then
                match checked with
                | [a] =>
                    make (full_if most) (Typed.Library_call (Add_item t) [Typed.Read variable; argument_tree a] at_)
                      (match argument_label a with
                       | Some (_, label_at) => [Refused (Label_where_none label_at (argument_at a))]
                       | None => []
                       end ++ typed_item a item)
                | [a; position] =>
                    match position_argument position with
                    | Some from_one =>
                        make (full_if most)
                          (Typed.Library_call (Insert_item t from_one)
                             [Typed.Read variable; argument_tree a; argument_tree position] at_)
                          (typed_item a item ++ typed_position position)
                    | None => no_method (ds ++ [Refused (Item_without_label (match argument_labels [position] with x :: _ => x | [] => "" end) (argument_at position))])
                    end
                | _ => no_method (ds ++ [Refused (Argument_count (variable ++ ".add") 1 (length checked) at_ None)])
                end
              else if String.eqb name "remove" then
                match checked with
                | [position] =>
                    match position_argument position with
                    | Some from_one =>
                        make []
                          (Typed.Library_call (Remove_item t from_one) [Typed.Read variable; argument_tree position] at_)
                          (typed_position position)
                    | None => no_method (ds ++ [Refused (Item_without_label "" (argument_at position))])
                    end
                | _ => no_method (ds ++ [Refused (Argument_count (variable ++ ".remove") 1 (length checked) at_ None)])
                end
              else no_method (ds ++ [Not_designed_yet Other_methods name_at])
          | Array_of _ _ =>
              if String.eqb name "add" || String.eqb name "remove" then
                no_method (ds ++ [Refused (Array_cannot_grow name name_at)])
              else no_method (ds ++ [Not_designed_yet Other_methods name_at])
          | other => no_method (ds ++ [Refused (Not_a_list ("." ++ name) other variable_at)])
          end
      end
  | _ =>
      let '(_, _, d) := check_expression s None target in
      no_method (d ++ [Not_designed_yet Method_on_value at_])
  end.

(* ---------------------------------------------------------------------------------------------------------------- *)
(* Statements *)

(* A call or a slide standing alone as a statement (D120). *)
Definition check_run_call (c : call_check) (procedure : string) (at_ : place) : list diagnostic :=
  match call_gives c, call_failures c with
  | _, _ :: _ => call_diagnostics c ++ [Refused (Failure_unhandled at_)]
  | Gives_value t, [] => call_diagnostics c ++ [Refused (Value_unused procedure t at_)]
  | _, [] => call_diagnostics c
  end.

Fixpoint last_step_name (path : steps) : string :=
  match path with
  | No_steps => ""
  | Step name _ _ _ No_steps => callee_name name
  | Step _ _ _ _ rest => last_step_name rest
  end.

(* A stand-in statement for a refused one; it never runs. *)
Definition stand_in_statement : Typed.statement := Typed.Break.

(* A call standing alone, its failures handled by [handle] (`??`, `?` or `otherwise`, or [None]). *)
Definition run_tree (c : called) : Typed.statement :=
  match c with
  | Called tree => Typed.Run tree
  | _ => stand_in_statement
  end.

Definition method_statement (m : method_check) : Typed.statement :=
  match method_tree m with
  | Some tree => Typed.Assign (method_variable m) (Typed.Value_of tree)
  | None => stand_in_statement
  end.

Definition check_run (s : setting) (action : expression) : Typed.statement * list diagnostic :=
  match action with
  | Call name given at_ =>
      let c := check_call s name (check_arguments s (expected_arguments (setting_program s) name) given) at_ in
      (run_tree (call_tree c), check_run_call c (callee_name name) at_ ++ chain_problem action)
  | Slide start path at_ =>
      let '(t, start_tree, ds) := check_expression s None start in
      let c := check_steps s t start_tree path in
      (run_tree (call_tree c), ds ++ slide_shape start path at_ ++ check_run_call c (last_step_name path) at_)
  (* trace: D77, D80 *)
  | Method target name name_at given at_ =>
      let m := check_method s target name name_at given at_ in
      (method_statement m,
       method_diagnostics m ++ match method_failures m with _ :: _ => [Refused (Failure_unhandled at_)] | [] => [] end)
  (* trace: D23 *)
  | Pass_up (Call name given call_at) operator_at _ =>
      let c := check_call s name (check_arguments s (expected_arguments (setting_program s) name) given) call_at in
      match call_gives c, call_failures c, call_tree c with
      | Gives_nothing, (_ :: _) as failures, Called tree =>
          (Typed.Run (Typed.Passing tree), call_diagnostics c ++ pass_up_problems s (callee_name name) failures operator_at)
      | Gives_value t, _ :: _, _ => (stand_in_statement, call_diagnostics c ++ [Refused (Value_unused (callee_name name) t call_at)])
      | Gives_unknown, _, _ => (stand_in_statement, call_diagnostics c)
      | _, _, _ => (stand_in_statement, call_diagnostics c ++ [Refused (Without_failing_call "?" operator_at)])
      end
  | Pass_up (Method target name name_at given at_) operator_at _ =>
      let m := check_method s target name name_at given at_ in
      match method_tree m, method_failures m with
      | Some tree, (_ :: _) as failures =>
          (Typed.Assign (method_variable m) (Typed.Value_of (Typed.Passing tree)),
           method_diagnostics m ++ pass_up_problems s ("." ++ name) failures operator_at)
      | None, _ => (stand_in_statement, method_diagnostics m)
      | _, [] => (stand_in_statement, method_diagnostics m ++ [Refused (Without_failing_call "?" operator_at)])
      end
  (* trace: D152 *)
  | Crash_on_failure (Call name given call_at) operator_at _ =>
      let c := check_call s name (check_arguments s (expected_arguments (setting_program s) name) given) call_at in
      match call_gives c, call_failures c, call_tree c with
      | Gives_nothing, _ :: _, Called tree =>
          (Typed.Run (Typed.Crashing tree (callee_name name) operator_at), call_diagnostics c)
      | Gives_value t, _ :: _, _ => (stand_in_statement, call_diagnostics c ++ [Refused (Value_unused (callee_name name) t call_at)])
      | Gives_unknown, _, _ => (stand_in_statement, call_diagnostics c)
      | _, _, _ => (stand_in_statement, call_diagnostics c ++ [Refused (Without_failing_call "?? crash" operator_at)])
      end
  | Crash_on_failure (Method (Variable_value variable _ as target) name name_at given at_) operator_at _ =>
      let m := check_method s target name name_at given at_ in
      match method_tree m, method_failures m with
      | Some tree, _ :: _ =>
          (Typed.Assign (method_variable m) (Typed.Value_of (Typed.Crashing tree (variable ++ "." ++ name) operator_at)),
           method_diagnostics m)
      | None, _ => (stand_in_statement, method_diagnostics m)
      | _, [] => (stand_in_statement, method_diagnostics m ++ [Refused (Without_failing_call "?? crash" operator_at)])
      end
  (* trace: D121 *)
  | Ignore_failure (Call name given call_at) operator_at _ =>
      let c := check_call s name (check_arguments s (expected_arguments (setting_program s) name) given) call_at in
      match call_gives c, call_failures c, call_tree c with
      | Gives_nothing, _ :: _, Called tree => (Typed.Handle Typed.Nowhere tree Typed.No_cases true, call_diagnostics c)
      | Gives_value t, _ :: _, _ => (stand_in_statement, call_diagnostics c ++ [Refused (Value_unused (callee_name name) t call_at)])
      | Gives_unknown, _, _ => (stand_in_statement, call_diagnostics c)
      | _, _, _ => (stand_in_statement, call_diagnostics c ++ [Refused (Without_failing_call "?? ignore" operator_at)])
      end
  | Ignore_failure (Method target name name_at given at_) operator_at _ =>
      let m := check_method s target name name_at given at_ in
      match method_tree m, method_failures m with
      | Some tree, _ :: _ =>
          (Typed.Handle (Typed.Into (method_variable m)) tree Typed.No_cases true, method_diagnostics m)
      | None, _ => (stand_in_statement, method_diagnostics m)
      | _, [] => (stand_in_statement, method_diagnostics m ++ [Refused (Without_failing_call "?? ignore" operator_at)])
      end
  | Fallback (Call name _ _) _ _ at_ =>
      let '(t, _, ds) := check_expression s None action in
      (stand_in_statement,
       match t with
       | Some t' => ds ++ [Refused (Value_unused (callee_name name) t' at_)]
       | None => ds
       end)
  | Broken at_ => (stand_in_statement, [Already_refused at_])
  (* trace: D161. A line that only works out a value; a refused one has had its say already (D55). *)
  | _ =>
      let '(t, _, ds) := check_expression s None action in
      (stand_in_statement,
       ds ++ [match t with
              | Some t' => Refused (Value_only_line (expression_at action) t')
              | None => Already_refused (expression_at action)
              end])
  end.

(* trace: D33, D187. A condition, for `if` and `while`, is a `Bool`. *)
Definition check_condition (s : setting) (condition : expression) : Typed.expression * list diagnostic :=
  let '(t, tree, ds) := check_expression s None condition in
  match t with
  | Some Bool | None => (tree, ds)
  | Some other => (tree, ds ++ [Refused (Condition_not_bool other (expression_at condition))])
  end.

(* trace: D184. `eq` and `not_eq` between two `Float`s anywhere in a `while` condition. *)
Fixpoint float_equalities (s : setting) (condition : expression) : list diagnostic :=
  match condition with
  | Binary ((Equal | Not_equal) as operator) left_operand _ operator_at _ =>
      let '(t, _, _) := check_expression s None left_operand in
      match t with
      | Some Float => [Refused (Float_equality_in_while operator operator_at)]
      | _ => []
      end
  | Binary (And | Or) left_operand right_operand _ _ => float_equalities s left_operand ++ float_equalities s right_operand
  | Not operand _ | Bracketed operand _ => float_equalities s operand
  | _ => []
  end.

(* Whether a statement leaves the block it's in: by `return`, or by `break` when it isn't inside a loop of its own
   ([in_inner_loop]). *)
Fixpoint can_leave (in_inner_loop : bool) (st : statement) : bool :=
  match st with
  | Return _ _ => true
  | Break _ => negb in_inner_loop
  | If _ then_part rest _ => can_leave_block in_inner_loop then_part || can_leave_else in_inner_loop rest
  | While _ body _ | For_each _ _ _ _ _ body _ => can_leave_block true body
  | Handled _ handlers _ _ => can_leave_cases in_inner_loop handlers
  | _ => false
  end
with can_leave_cases (in_inner_loop : bool) (handlers : cases) : bool :=
  match handlers with
  | No_cases => false
  | Case _ _ body _ rest => can_leave_block in_inner_loop body || can_leave_cases in_inner_loop rest
  | Included _ _ _ _ _ rest => can_leave_cases in_inner_loop rest
  | Expanded _ _ _ _ _ _ _ inlined rest => can_leave_cases in_inner_loop inlined || can_leave_cases in_inner_loop rest
  end
with can_leave_block (in_inner_loop : bool) (b : block) : bool :=
  match b with
  | Empty => false
  | Then st rest => can_leave in_inner_loop st || can_leave_block in_inner_loop rest
  end
with can_leave_else (in_inner_loop : bool) (e : else_part) : bool :=
  match e with
  | No_else => false
  | Else body _ => can_leave_block in_inner_loop body
  | Else_if _ body rest _ => can_leave_block in_inner_loop body || can_leave_else in_inner_loop rest
  end.

(* trace: D9, D57, D117. What's refused about [next] coming after [st] in the same block. *)
Definition follows (st next : statement) : list diagnostic :=
  match st with
  | Return _ at_ => [Refused (After_leaving true (statement_at next) at_)]
  | Break at_ => [Refused (After_leaving false (statement_at next) at_)]
  | Instead _ _ => [Not_designed_yet After_instead (statement_at next)]
  | If _ _ _ at_ => if can_leave false st then [Refused (After_if_that_leaves (statement_at next) at_)] else []
  | _ => []
  end.

(* Whether every way through ends in `return` with a value (D57, D149). *)
Fixpoint always_returns (st : statement) : bool :=
  match st with
  | Return (Some _) _ => true
  | If _ then_part rest _ => always_returns_block then_part && always_returns_else rest
  | _ => false
  end
with always_returns_block (b : block) : bool :=
  match b with
  | Empty => false
  | Then st Empty => always_returns st
  | Then _ rest => always_returns_block rest
  end
with always_returns_else (e : else_part) : bool :=
  match e with
  | No_else => false
  | Else body _ => always_returns_block body
  | Else_if _ body rest _ => always_returns_block body && always_returns_else rest
  end.

(* Whether every way through a case ends in `instead`, `return` or `break`, so none falls off its end (D40). *)
Fixpoint always_ends_case (st : statement) : bool :=
  match st with
  | Return _ _ | Break _ | Instead _ _ => true
  | If _ then_part rest _ => always_ends_case_block then_part && always_ends_case_else rest
  | _ => false
  end
with always_ends_case_block (b : block) : bool :=
  match b with
  | Empty => false
  | Then st Empty => always_ends_case st
  | Then _ rest => always_ends_case_block rest
  end
with always_ends_case_else (e : else_part) : bool :=
  match e with
  | No_else => false
  | Else body _ => always_ends_case_block body
  | Else_if _ body rest _ => always_ends_case_block body && always_ends_case_else rest
  end.

Definition declare (s : setting) (info : variable_info) : setting := with_scope s (info :: setting_scope s).

Definition parameter_info (p : parameter) : variable_info :=
  {| variable_name := parameter_name p; variable_type := parameter_type p; variable_kind := Parameter_variable;
     variable_name_at := parameter_at p; variable_keyword_at := parameter_at p |}.


(* The names a block declared, for D93's `because:` once it's ended. *)
Definition declared_in (st : statement) : list (string * place) :=
  match st with
  | Declare _ name name_at _ _ _ _ | Handled (Declare _ name name_at _ _ _ _) _ _ _ => [(name, name_at)]
  | _ => []
  end.

(* trace: D41, D94, D102, D192. A variable or parameter can't take a procedure's name, or its family's word. *)
Definition procedure_name_taken (p : program) (name : string) (at_ : place) : list diagnostic :=
  match find (fun d => match definition_name d with Named n => String.eqb (word_of n) name | Main => false end)
          (program_definitions p) with
  | Some d => [Refused (Name_is_procedure name at_ (Some (definition_name_at d)))]
  | None => if is_library_word name then [Refused (Name_is_procedure name at_ None)] else []
  end.

(* ---------------------------------------------------------------------------------------------------------------- *)
(* Handlers (D42, D43, D44): each `include` and `otherwise family.handler` gets its handler's parameters, `labels` and
   cases written in, so the checker reads them as if written there. A handler's own cases aren't expanded: a handler
   including another isn't decided. *)

Fixpoint expand_statement (p : program) (st : statement) {struct st} : statement :=
  match st with
  | If condition then_part rest at_ => If condition (expand_block p then_part) (expand_else p rest) at_
  | While condition body at_ => While condition (expand_block p body) at_
  | For_each item item_at position from_one source body at_ =>
      For_each item item_at position from_one source (expand_block p body) at_
  | Handled attempt handlers otherwise_at at_ => Handled attempt (expand_cases p handlers) otherwise_at at_
  | other => other
  end
with expand_cases (p : program) (handlers : cases) {struct handlers} : cases :=
  match handlers with
  | No_cases => No_cases
  | Case failure failure_at body at_ rest => Case failure failure_at (expand_block p body) at_ (expand_cases p rest)
  | Included name name_at jump given at_ rest =>
      match find_handler p name with
      | Some h =>
          Expanded name name_at jump given at_ (handler_parameters h) (handler_labels h) (handler_cases h)
            (expand_cases p rest)
      | None => Included name name_at jump given at_ (expand_cases p rest)
      end
  | Expanded name name_at jump given at_ parameters pairs inlined rest =>
      Expanded name name_at jump given at_ parameters pairs inlined (expand_cases p rest)
  end
with expand_block (p : program) (b : block) {struct b} : block :=
  match b with
  | Empty => Empty
  | Then st rest => Then (expand_statement p st) (expand_block p rest)
  end
with expand_else (p : program) (e : else_part) {struct e} : else_part :=
  match e with
  | No_else => No_else
  | Else body at_ => Else (expand_block p body) at_
  | Else_if condition body rest at_ => Else_if condition (expand_block p body) (expand_else p rest) at_
  end.

Fixpoint append_cases (a b : Typed.cases) : Typed.cases :=
  match a with
  | Typed.No_cases => b
  | Typed.Case f body rest => Typed.Case f body (append_cases rest b)
  end.

Fixpoint before_block (first : list Typed.statement) (b : Typed.block) : Typed.block :=
  match first with
  | [] => b
  | st :: rest => Typed.Then st (before_block rest b)
  end.

(* Each case of an included handler starts by giving its parameters their arguments (D44). *)
Fixpoint with_parameters (declarations : list Typed.statement) (handlers : Typed.cases) : Typed.cases :=
  match handlers with
  | Typed.No_cases => Typed.No_cases
  | Typed.Case f body rest => Typed.Case f (before_block declarations body) (with_parameters declarations rest)
  end.

(* Whether a value calls a procedure, so when it's worked out would show. *)
Fixpoint calls_something (e : Typed.expression) : bool :=
  match e with
  | Typed.Value_of _ | Typed.Fallback _ _ => true
  | Typed.Negate operand _ | Typed.Logic_not operand | Typed.Float_negate operand | Typed.Float_of operand
  | Typed.Whole_of_float _ operand _ | Typed.Text_places _ operand | Typed.Text_of _ operand _ | Typed.Length operand
  | Typed.All_literal _ operand => calls_something operand
  | Typed.Maths _ l r _ | Typed.Divide _ l r _ | Typed.Float_maths _ l r _ | Typed.Compare _ _ l r
  | Typed.Logic_and l r | Typed.Logic_or l r | Typed.Item _ l r _ => calls_something l || calls_something r
  | Typed.Join parts | Typed.List_literal _ parts => existsb calls_something parts
  | _ => false
  end.

(* trace: D94. A new variable's name: not in use, and not a procedure's. *)
Definition new_name (s : setting) (name : string) (at_ : place) : list diagnostic :=
  match find_variable name (setting_scope s) with
  | Some info => [Refused (Name_in_use name at_ (variable_name_at info))]
  | None => procedure_name_taken (setting_program s) name at_
  end.

(* trace: D14, D147, D171, D173. Whether a variable may be given a new value here. *)
Definition may_assign (s : setting) (name : string) (name_at : place) (info : variable_info) : list diagnostic :=
  match variable_kind info with
  | Let_variable => [Refused (Let_cannot_change name name_at (variable_keyword_at info))]
  | Parameter_variable => [Refused (Parameter_cannot_change name name_at (variable_name_at info))]
  | Loop_variable => [Refused (Loop_variable_cannot_change name name_at (variable_keyword_at info))]
  | Var_variable =>
      match find (fun entry => String.eqb (fst entry) name) (setting_going_through s) with
      | Some (_, loop_at) => [Refused (Going_through name name_at loop_at)]
      | None => []
      end
  end.

Fixpoint case_names (handlers : cases) : list (string * place) :=
  match handlers with
  | No_cases => []
  | Case failure failure_at _ _ rest => (failure, failure_at) :: case_names rest
  | Included _ _ _ _ _ rest => case_names rest
  | Expanded _ name_at _ _ _ _ _ inlined rest =>
      map (fun entry => (fst entry, name_at)) (case_names inlined) ++ case_names rest
  end.

(* Whether an `otherwise` uses a handler that couldn't be found, so what it covers isn't known (D55). *)
Fixpoint has_unknown_handler (handlers : cases) : bool :=
  match handlers with
  | No_cases => false
  | Included _ _ _ _ _ _ => true
  | Case _ _ _ _ rest | Expanded _ _ _ _ _ _ _ _ rest => has_unknown_handler rest
  end.

(* trace: D40. Every failure the call can give has its case, each once, and none for a failure it can't give. *)
Definition coverage (procedure : string) (failures : list string) (handlers : cases) (otherwise_at : place)
  : list diagnostic :=
  let named := case_names handlers in
  let missing :=
    map (fun f => Refused (Case_missing procedure f otherwise_at))
      (filter (fun f => negb (existsb (fun entry => String.eqb (fst entry) f) named)) failures) in
  let impossible :=
    map (fun entry => Refused (Case_not_possible procedure (fst entry) (snd entry)))
      (filter (fun entry => negb (existsb (String.eqb (fst entry)) failures)) named) in
  let fix twice (seen : list (string * place)) (rest : list (string * place)) :=
    match rest with
    | [] => []
    | (f, at_) :: more =>
        match find (fun entry => String.eqb (fst entry) f) seen with
        | Some (_, first) => [Refused (Case_twice f at_ first)]
        | None => []
        end ++ twice ((f, at_) :: seen) more
    end in
  missing ++ impossible ++ twice [] named.

(* A handled statement's call, as [check_run]'s, [Declare]'s or [Assign]'s value, before its `otherwise`. *)
Record attempt_check := {
  attempt_procedure : string;
  attempt_gives : gives;
  attempt_failures : list string;
  attempt_tree : option Typed.call;
  attempt_destination : Typed.destination;
  attempt_setting : setting;
  attempt_diagnostics : list diagnostic }.

Fixpoint check_statement (s : setting) (st : statement) {struct st} : setting * Typed.statement * list diagnostic :=
  match st with
  | Declare changeable name name_at keyword_at written value _ =>
      let '(t, tree, ds) := check_expression s (Some written) value in
      let mismatch :=
        expect t written (fun found => Refused (Wrong_value_type name written found (expression_at value))) (expression_at value) in
      let info := {| variable_name := name; variable_type := written;
                     variable_kind := if changeable then Var_variable else Let_variable;
                     variable_name_at := name_at; variable_keyword_at := keyword_at |} in
      (* trace: D121. `?? ignore` in a declaration names the variable it would leave with nothing. *)
      let ds := map (fun d => match d with
                              | Refused (Ignore_value procedure t None at_) => Refused (Ignore_value procedure t (Some name) at_)
                              | other => other
                              end) ds in
      (declare s info, Typed.Declare name written tree, new_name s name name_at ++ ds ++ mismatch)
  | Assign name name_at value _ _ =>
      let expected := match find_variable name (setting_scope s) with Some info => Some (variable_type info) | None => None end in
      let '(t, tree, ds) := check_expression s expected value in
      let problems :=
        match find_variable name (setting_scope s) with
        | None => [Refused (Unknown_variable name name_at (find_ended name (setting_ended s)))] ++ ds
        | Some info =>
            match may_assign s name name_at info with
            | [] =>
                ds ++ expect t (variable_type info)
                        (fun found => Refused (Wrong_value_type name (variable_type info) found (expression_at value)))
                        (expression_at value)
            | refused => refused ++ ds
            end
        end in
      (s, Typed.Assign name tree, problems)
  | Run action _ => let (tree, ds) := check_run s action in (s, tree, ds)
  | If condition then_part rest _ =>
      let (condition_tree, dc) := check_condition s condition in
      let '(ended_then, then_tree, dt) := check_block s then_part in
      let '(ended_else, else_tree, de) := check_else s rest in
      (with_ended s (ended_then ++ ended_else ++ setting_ended s), Typed.If condition_tree then_tree else_tree,
       dc ++ dt ++ de)
  | While condition body _ =>
      let (condition_tree, dc) := check_condition s condition in
      let dc := dc ++ float_equalities s condition in
      let '(ended_body, body_tree, db) := check_block (in_loop s) body in
      (with_ended s (ended_body ++ setting_ended s), Typed.While condition_tree body_tree, dc ++ db)
  | Break at_ => (s, Typed.Break, if setting_in_loop s then [] else [Refused (Break_outside_loop at_)])
  | Return None at_ =>
      (s, Typed.Return None,
       match setting_returns s with
       | Some t => [Refused (Bare_return_with_returns (setting_procedure s) t at_)]
       | None => []
       end)
  | Return (Some value) at_ =>
      let '(t, tree, ds) := check_expression s (setting_returns s) value in
      (s, Typed.Return (Some tree),
       match setting_returns s with
       | Some expected =>
           ds ++ expect t expected (fun _ => Not_designed_yet Return_type_wording (expression_at value)) (expression_at value)
       | None => ds ++ [Refused (Return_value_without_returns (setting_procedure s) at_)]
       end)
  | Labels _ at_ => (s, stand_in_statement, [Refused (Labels_not_first at_)])
  (* trace: D77, D80, D173 *)
  | Set_item name name_at label label_at index value _ at_ =>
      match find_variable name (setting_scope s) with
      | None => (s, stand_in_statement, [Refused (Unknown_variable name name_at (find_ended name (setting_ended s)))])
      | Some info =>
          let t := variable_type info in
          let change := list_may_change s name name_at in
          let '(i, index_tree, di) := check_expression s None index in
          let label_problems :=
            if String.eqb label "pos" || String.eqb label "offset" then plain_position label index t (expression_at index)
            else [Refused (Item_without_label label label_at)] in
          let index_problems :=
            match i with
            | Some Whole | None => []
            | Some other => [Refused (Position_type other (expression_at index))]
            end in
          match item_of t with
          | Some item =>
              let '(v, value_tree, dv) := check_expression s (Some item) value in
              (s,
               Typed.Assign name
                 (Typed.Value_of (Typed.Library_call (Replace_item t (String.eqb label "pos"))
                                    [Typed.Read name; index_tree; value_tree] at_)),
               change ++ di ++ label_problems ++ index_problems ++ dv
                 ++ expect v item (fun found => Refused (Item_type item found (expression_at value))) (expression_at value))
          | None => (s, stand_in_statement, di ++ [Refused (Not_a_list "[ ]" t name_at)])
          end
      end
  (* trace: D170, D171, D172, D173, D174 *)
  | For_each item item_at position from_one source body at_ =>
      let names :=
        new_name s item item_at
          ++ match position with
             | Some (i, i_at) => if String.eqb i item then [Refused (Name_in_use i i_at item_at)] else new_name s i i_at
             | None => []
             end in
      let loop_setting (item_type : type) :=
        let scope :=
          {| variable_name := item; variable_type := item_type; variable_kind := Loop_variable;
             variable_name_at := item_at; variable_keyword_at := at_ |}
          :: match position with
             | Some (i, i_at) =>
                 [{| variable_name := i; variable_type := Whole; variable_kind := Loop_variable;
                     variable_name_at := i_at; variable_keyword_at := at_ |}]
             | None => []
             end ++ setting_scope s in
        let going := match source with
                     | Variable_value name _ => (name, at_) :: setting_going_through s
                     | _ => setting_going_through s
                     end in
        change_setting s scope (setting_ended s) true going (setting_case s) in
      let position_name := option_map fst position in
      let loop_names := (item, item_at) :: match position with Some p => [p] | None => [] end in
      match source with
      | Range given range_at =>
          let checked := check_arguments s [Some Whole; Some Whole; Some Whole] given in
          let labels := argument_labels checked in
          let ds := values_diagnostics checked in
          let whole_value (a : checked_argument) :=
            expect (argument_type a) Whole (fun found => Refused (Argument_type "range" Whole found (argument_at a)))
              (argument_at a) in
          let '(ended_body, body_tree, db) := check_block (loop_setting Whole) body in
          let finish (first last : checked_argument) (included : bool) (step : option checked_argument) :=
            let step_tree := match step with Some a => argument_tree a | None => Typed.Whole_literal 1 end in
            let plain :=
              match plain_number (argument_value first), plain_number (argument_value last),
                    match step with Some a => plain_number (argument_value a) | None => Some 1%Z end with
              | Some a, Some b, Some c =>
                  if (c =? 0)%Z || ((0 <? c)%Z && (b <? a)%Z) || ((c <? 0)%Z && (a <? b)%Z)
                  then [Refused (Range_never_ends_plain range_at)] else []
              | _, _, _ => []
              end in
            (with_ended s (ended_body ++ loop_names ++ setting_ended s),
             Typed.For_range item position_name from_one (argument_tree first) (argument_tree last) included step_tree
               range_at body_tree,
             names ++ ds ++ whole_value first ++ whole_value last
               ++ match step with Some a => whole_value a | None => [] end ++ plain ++ db) in
          match checked, labels with
          | [a; b], ["from"; "to"] => finish a b true None
          | [a; b], ["from"; "before"] => finish a b false None
          | [a; b; c], ["from"; "to"; "step_by"] => finish a b true (Some c)
          | [a; b; c], ["from"; "before"; "step_by"] => finish a b false (Some c)
          | _, _ => (s, stand_in_statement, names ++ ds ++ [Refused (Range_labels range_at)] ++ db)
          end
      | _ =>
          let '(t, source_tree, ds) := check_expression s None source in
          match t with
          | Some t' =>
              match item_of t' with
              | Some item_type =>
                  let '(ended_body, body_tree, db) := check_block (loop_setting item_type) body in
                  (with_ended s (ended_body ++ loop_names ++ setting_ended s),
                   Typed.For_each item position_name from_one source_tree body_tree, names ++ ds ++ db)
              | None =>
                  match t' with
                  | Text => (s, stand_in_statement, names ++ ds ++ [Not_designed_yet Going_through_text (expression_at source)])
                  | _ => (s, stand_in_statement, names ++ ds ++ [Refused (For_each_source t' (expression_at source))])
                  end
              end
          | None => (s, stand_in_statement, names ++ ds)
          end
      end
  (* trace: D23, D40, D186 *)
  | Handled attempt handlers otherwise_at _ =>
      let checked :=
        match attempt with
        | Declare changeable name name_at keyword_at written (Call callee given call_at) _ =>
            let c := check_call s callee (check_arguments s (expected_arguments (setting_program s) callee) given) call_at in
            let info := {| variable_name := name; variable_type := written;
                           variable_kind := if changeable then Var_variable else Let_variable;
                           variable_name_at := name_at; variable_keyword_at := keyword_at |} in
            let mismatch :=
              match call_gives c with
              | Gives_value t => expect (Some t) written (fun found => Refused (Wrong_value_type name written found call_at)) call_at
              | Gives_nothing => [Refused (Gives_nothing_used call_at)]
              | Gives_unknown => []
              end in
            {| attempt_procedure := callee_name callee; attempt_gives := call_gives c; attempt_failures := call_failures c;
               attempt_tree := match call_tree c with Called tree => Some tree | _ => None end;
               attempt_destination := Typed.Into_new name written; attempt_setting := declare s info;
               attempt_diagnostics := new_name s name name_at ++ call_diagnostics c ++ mismatch |}
        | Assign name name_at (Call callee given call_at) _ _ =>
            let c := check_call s callee (check_arguments s (expected_arguments (setting_program s) callee) given) call_at in
            let problems :=
              match find_variable name (setting_scope s) with
              | None => [Refused (Unknown_variable name name_at (find_ended name (setting_ended s)))]
              | Some info =>
                  may_assign s name name_at info
                    ++ match call_gives c with
                       | Gives_value t =>
                           expect (Some t) (variable_type info)
                             (fun found => Refused (Wrong_value_type name (variable_type info) found call_at)) call_at
                       | Gives_nothing => [Refused (Gives_nothing_used call_at)]
                       | Gives_unknown => []
                       end
              end in
            {| attempt_procedure := callee_name callee; attempt_gives := call_gives c; attempt_failures := call_failures c;
               attempt_tree := match call_tree c with Called tree => Some tree | _ => None end;
               attempt_destination := Typed.Into name; attempt_setting := s;
               attempt_diagnostics := call_diagnostics c ++ problems |}
        | Run (Call callee given call_at) _ =>
            let c := check_call s callee (check_arguments s (expected_arguments (setting_program s) callee) given) call_at in
            {| attempt_procedure := callee_name callee; attempt_gives := call_gives c; attempt_failures := call_failures c;
               attempt_tree := match call_tree c with Called tree => Some tree | _ => None end;
               attempt_destination := Typed.Nowhere; attempt_setting := s;
               attempt_diagnostics :=
                 call_diagnostics c
                   ++ match call_gives c with
                      | Gives_value t => [Refused (Value_unused (callee_name callee) t call_at)]
                      | _ => []
                      end |}
        | Run (Method (Variable_value variable _ as target) name name_at given method_at) _ =>
            let m := check_method s target name name_at given method_at in
            {| attempt_procedure := variable ++ "." ++ name; attempt_gives := Gives_nothing;
               attempt_failures := method_failures m; attempt_tree := method_tree m;
               attempt_destination := Typed.Into (method_variable m); attempt_setting := s;
               attempt_diagnostics := method_diagnostics m |}
        | _ =>
            let '(_, _, ds) := check_statement s attempt in
            {| attempt_procedure := ""; attempt_gives := Gives_unknown; attempt_failures := [];
               attempt_tree := None; attempt_destination := Typed.Nowhere; attempt_setting := s;
               attempt_diagnostics := ds ++ [Refused (Without_failing_call "otherwise" otherwise_at)] |}
        end in
      let instead := match attempt_gives checked, attempt_destination checked with
                     | Gives_value t, _ => Some t
                     | _, _ => None
                     end in
      let '(ended_cases, cases_tree, dcases) :=
        check_cases (in_case s instead (attempt_procedure checked)) (match instead with Some _ => true | None => false end)
          handlers in
      let failing :=
        match attempt_gives checked, attempt_failures checked with
        | Gives_unknown, _ => []
        | _, [] => match attempt_diagnostics checked with
                   | [] => [Refused (Without_failing_call "otherwise" otherwise_at)]
                   | _ => []
                   end
        | _, failures =>
            if has_unknown_handler (expand_cases (setting_program s) handlers) then []
            else coverage (attempt_procedure checked) failures handlers otherwise_at
        end in
      (with_ended (attempt_setting checked) (ended_cases ++ setting_ended s),
       match attempt_tree checked with
       | Some tree => Typed.Handle (attempt_destination checked) tree cases_tree false
       | None => stand_in_statement
       end,
       attempt_diagnostics checked ++ failing ++ dcases)
  (* trace: D40, D186 *)
  | Instead value at_ =>
      match setting_case s with
      | None => let '(_, _, ds) := check_expression s None value in (s, stand_in_statement, ds ++ [Refused (Instead_outside_case at_)])
      | Some (None, procedure) =>
          let '(_, _, ds) := check_expression s None value in
          (s, stand_in_statement, ds ++ [Refused (Instead_without_value procedure at_)])
      | Some (Some t, _) =>
          let '(v, tree, ds) := check_expression s (Some t) value in
          (s, Typed.Instead tree,
           ds ++ expect v t (fun found => Refused (Fallback_type t found (expression_at value))) (expression_at value))
      end
  end

(* Checks an `otherwise` block's cases; with [must_end], none may fall off its end (D40, D186). *)
with check_cases (s : setting) (must_end : bool) (handlers : cases) {struct handlers}
  : list (string * place) * Typed.cases * list diagnostic :=
  match handlers with
  | No_cases => ([], Typed.No_cases, [])
  | Case failure _ body at_ rest =>
      let '(ended_body, body_tree, db) := check_block s body in
      let '(ended_rest, rest_tree, dr) := check_cases s must_end rest in
      let falls := if must_end && negb (always_ends_case_block body) then [Refused (Case_falls_off at_)] else [] in
      (ended_body ++ ended_rest, Typed.Case failure body_tree rest_tree, db ++ falls ++ dr)
  | Included name name_at _ _ at_ rest =>
      let '(ended_rest, rest_tree, dr) := check_cases s must_end rest in
      (ended_rest, rest_tree,
       (match find_handler (setting_program s) name with
        | Some _ => Not_designed_yet Handler_including_handler at_
        | None => Refused (Unknown_handler name name_at)
        end) :: dr)
  (* trace: D42, D43, D44 *)
  | Expanded name name_at jump given at_ parameters pairs inlined rest =>
      let '(ended_rest, rest_tree, dr) := check_cases s must_end rest in
      let checked := check_arguments s (map (fun x => Some (parameter_type x)) parameters) given in
      let wanted := map (fun x => (parameter_type x, label_of pairs (parameter_name x))) parameters in
      let argument_problems := check_against name wanted checked at_ None in
      let calling :=
        if existsb (fun a => calls_something (argument_tree a)) checked
        then [Not_designed_yet Handler_arguments_calling at_] else [] in
      let jumps := can_leave_cases false inlined in
      let marks :=
        if jumps && negb jump then [Refused (Handler_jump_unmarked name name_at)]
        else if negb jumps && jump then [Refused (Handler_jump_marked name name_at)]
        else [] in
      let inner := with_scope s (rev (map parameter_info parameters) ++ setting_scope s) in
      let '(ended_inlined, inlined_tree, di) := check_cases inner must_end inlined in
      let declarations :=
        map (fun '(x, a) => Typed.Declare (parameter_name x) (parameter_type x) (argument_tree a))
          (combine parameters checked) in
      (ended_inlined ++ ended_rest, append_cases (with_parameters declarations inlined_tree) rest_tree,
       marks ++ argument_problems ++ calling ++ di ++ dr)
  end

(* Checks a block's statements in turn; gives back the names it declared, which end with it (D93). *)
with check_block (s : setting) (b : block) {struct b} : list (string * place) * Typed.block * list diagnostic :=
  match b with
  | Empty => ([], Typed.Empty, [])
  | Then st rest =>
      let '(s', tree, ds) := check_statement s st in
      let after := match rest with Then next _ => follows st next | Empty => [] end in
      let '(names, rest_tree, dr) := check_block s' rest in
      (declared_in st ++ names, Typed.Then tree rest_tree, ds ++ after ++ dr)
  end

with check_else (s : setting) (e : else_part) {struct e} : list (string * place) * Typed.block * list diagnostic :=
  match e with
  | No_else => ([], Typed.Empty, [])
  | Else body _ => check_block s body
  | Else_if condition body rest _ =>
      let (condition_tree, dc) := check_condition s condition in
      let '(ended_body, body_tree, db) := check_block s body in
      let '(ended_rest, rest_tree, dr) := check_else s rest in
      (ended_body ++ ended_rest, Typed.Then (Typed.If condition_tree body_tree rest_tree) Typed.Empty, dc ++ db ++ dr)
  end.

Fixpoint last_statement (b : block) : option statement :=
  match b with
  | Empty => None
  | Then st Empty => Some st
  | Then _ rest => last_statement rest
  end.

(* trace: D102, D126. The second of two parameters with one name. *)
Fixpoint repeated_parameters (seen : list string) (parameters : list parameter) : list diagnostic :=
  match parameters with
  | [] => []
  | p :: rest =>
      (if existsb (String.eqb (parameter_name p)) seen
       then [Refused (Two_parameters_one_name (parameter_name p) (parameter_at p))] else [])
        ++ repeated_parameters (parameter_name p :: seen) rest
  end.

(* trace: D25, D89. Checks a `labels` line. *)
Fixpoint check_label_pairs (procedure : string) (parameters : list parameter) (seen_parameters seen_labels : list string)
    (pairs : list label_pair) : list diagnostic :=
  match pairs with
  | [] => []
  | one_pair :: rest =>
      let missing :=
        if existsb (fun p => String.eqb (parameter_name p) (pair_parameter one_pair)) parameters then []
        else [Refused (Label_for_missing_parameter procedure (pair_parameter one_pair) (pair_parameter_at one_pair))] in
      let twice :=
        if existsb (String.eqb (pair_parameter one_pair)) seen_parameters
        then [Refused (Two_labels_one_parameter (pair_parameter one_pair) (pair_parameter_at one_pair))] else [] in
      let shared :=
        if existsb (String.eqb (pair_label one_pair)) seen_labels
        then [Refused (One_label_two_parameters (pair_label one_pair) (pair_label_at one_pair))] else [] in
      missing ++ twice ++ shared
        ++ check_label_pairs procedure parameters (pair_parameter one_pair :: seen_parameters)
             (pair_label one_pair :: seen_labels) rest
  end.


(* A body's `labels` line, if it starts with one (D25), and the statements after it. *)
Definition labels_and_rest (b : block) : option (list label_pair) * block :=
  match b with
  | Then (Labels pairs _) rest => (Some pairs, rest)
  | _ => (None, b)
  end.

(* trace: D4, D25, D37, D39, D57, D88. A definition's refusals, and its body in the typed tree. *)
Definition check_definition (p : program) (d : definition) : Typed.block * list diagnostic :=
  let procedure := procedure_label d in
  let start := {| setting_program := p; setting_scope := rev (map parameter_info (definition_parameters d));
                  setting_ended := []; setting_in_loop := false; setting_procedure := procedure;
                  setting_returns := definition_returns d;
                  setting_failures :=
                    match definition_name d with
                    | Main => None
                    | Named _ => Some (failures_of d, definition_name_at d)
                    end;
                  setting_going_through := []; setting_case := None |} in
  let (labels_line, rest) := labels_and_rest (expand_block p (definition_body d)) in
  let labels_problems :=
    match labels_line with
    | Some pairs => check_label_pairs procedure (definition_parameters d) [] [] pairs
    | None => []
    end in
  let main_returns :=
    match definition_name d, definition_returns d with
    | Main, Some _ => [Not_designed_yet Main_returns (definition_name_at d)]
    | _, _ => []
    end in
  (* `proc.main` takes nothing (D4, D88): the parser has already refused any parameters. *)
  let main_parameters :=
    match definition_name d, definition_parameters d with
    | Main, _ :: _ => [Already_refused (definition_name_at d)]
    | _, _ => []
    end in
  let parameter_names :=
    flat_map (fun parameter => procedure_name_taken p (parameter_name parameter) (parameter_at parameter))
      (definition_parameters d) in
  let last_line :=
    match last_statement rest with
    | Some (Return None at_) => [Refused (Bare_return_last at_)]
    | _ => []
    end in
  let missing_return :=
    match definition_returns d with
    | Some t => if always_returns_block rest then [] else [Refused (Missing_return procedure t (definition_name_at d))]
    | None => []
    end in
  let '(_, body_tree, body_problems) := check_block start rest in
  (body_tree,
   repeated_parameters [] (definition_parameters d) ++ parameter_names ++ main_returns ++ main_parameters
     ++ labels_problems ++ body_problems ++ last_line ++ missing_return).

(* trace: D4, D64, D92. Exactly one `proc.main`, and one procedure to a name. *)
Fixpoint check_names (mains : list place) (names : list (string * place)) (p : list definition) : list diagnostic :=
  match p with
  | [] => match mains with [] => [Refused No_main] | _ => [] end
  | d :: rest =>
      match definition_name d with
      | Main =>
          match mains with
          | first :: _ => [Refused (Two_mains (definition_name_at d) first)]
          | [] => []
          end ++ check_names (mains ++ [definition_name_at d]) names rest
      | Named n =>
          (if is_library_word n then [Not_designed_yet Library_name_taken (definition_name_at d)] else [])
            ++ match find (fun entry => String.eqb (fst entry) n) names with
               | Some (_, first) => [Refused (Two_procedures_one_name n (definition_name_at d) first)]
               | None => []
               end
            ++ check_names mains (names ++ [(n, definition_name_at d)]) rest
      end
  end.

(* Every refusal in a program, and its typed tree. *)
Definition elaborate (p : program) : list diagnostic * Typed.program :=
  let checked := map (fun d => (d, check_definition p d)) (program_definitions p) in
  let procedures :=
    flat_map
      (fun '(d, (body, _)) =>
         match definition_name d with
         | Named n =>
             [{| Typed.procedure_name := n;
                 Typed.procedure_parameters := map (fun x => (parameter_name x, parameter_type x)) (definition_parameters d);
                 Typed.procedure_gives := definition_returns d;
                 Typed.procedure_failures := failures_of d;
                 Typed.procedure_body := body |}]
         | Main => []
         end)
      checked in
  let main :=
    match find (fun '(d, _) => is_main d) checked with
    | Some (_, (body, _)) => body
    | None => Typed.Empty
    end in
  (check_names [] [] (program_definitions p) ++ flat_map (fun '(_, (_, ds)) => ds) checked,
   {| Typed.program_procedures := procedures; Typed.program_main := main |}).

(* THE CHECKER: every refusal in a program, and every place Ralph must stop because something isn't decided or
   isn't built. A program is accepted when this is empty: when the checker finds nothing, and the second type checker
   (TypedTree.v) agrees that the typed tree has the types the evaluator needs. If ever it didn't, that would be a bug
   in Ralph, reported as one, never a program run without its types checked. *)
Definition check_program (p : program) : list diagnostic :=
  let (diagnostics, tree) := elaborate p in
  match diagnostics with
  | [] => if Typed.program_ok tree then [] else [Typed_tree_refused]
  | _ => diagnostics
  end.

(* The typed tree the evaluator runs. *)
Definition typed_program (p : program) : Typed.program := snd (elaborate p).
