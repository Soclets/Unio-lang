(* Type safety: a program the checker accepts never gets stuck.

   The evaluator (Evaluator.v) stops with [Stuck] whenever it meets something it has no rule for: a variable that
   isn't there, `+` on a `Bool`, a procedure that doesn't exist, `break` outside a loop, a procedure with `->`
   finishing without `return`, a failure no case handles, and so on. This file proves that none of that ever happens to
   a program the checker (Checker.v) accepts, however its input goes and whatever random numbers come back.

   The checker accepts a program only when the second type checker (TypedTree.v) accepts its typed tree too, so the
   proof is about that second, small checker. It goes by induction on the evaluator's fuel, the "definitional
   interpreter" method: at each amount of fuel, every part of an accepted tree, run where the type checker said its
   variables would be, gives a value of the type the type checker worked out, or stops for a reason that isn't
   [Stuck]; and a failure passed up with `?` is always one its procedure lists. *)

From Stdlib Require Import String List Bool ZArith Lia.
From Ralph Require Import Whole Syntax Io TypedTree Checker Evaluator.
Import ListNotations.
Import Typed.
Open Scope list_scope.
Open Scope nat_scope.

(* ---------------------------------------------------------------------------------------------------------------- *)
(* Values, variables and their types *)

Fixpoint has_type (t : type) (v : value) {struct v} : Prop :=
  match v with
  | Whole_value _ => t = Whole
  | Bool_value _ => t = Bool
  | Text_value _ => t = Text
  | List_value items =>
      match item_of t with
      | Some item =>
          (fix all (vs : list value) : Prop :=
             match vs with
             | [] => True
             | x :: rest => has_type item x /\ all rest
             end) items
      | None => False
      end
  end.

Lemma list_typed : forall t item items, item_of t = Some item ->
  (has_type t (List_value items) <-> Forall (has_type item) items).
Proof.
  intros t item items It. simpl. rewrite It.
  induction items as [| x rest IH]; split; intros H.
  - constructor.
  - exact Logic.I.
  - destruct H as [Hx Hr]. constructor; [exact Hx | apply IH; exact Hr].
  - inversion H; subst. split; [assumption | apply IH; assumption].
Qed.

(* The values in [env] are where, and of the types, the type checker's [ctx] said. *)
Definition matches (ctx : context) (env : environment) : Prop :=
  Forall2 (fun entry binding => fst entry = fst binding /\ has_type (snd entry) (snd binding)) ctx env.

(* [env] holds [ctx]'s variables, and maybe more declared since, innermost first. *)
Definition extends (ctx : context) (env : environment) : Prop := exists extra, matches (extra ++ ctx) env.

Lemma option_Z_eqb_true : forall a b, option_Z_eqb a b = true -> a = b.
Proof. intros [x |] [y |]; simpl; intros H; try discriminate; try reflexivity. apply Z.eqb_eq in H; subst; reflexivity. Qed.

Lemma type_eqb_true : forall a b, type_eqb a b = true -> a = b.
Proof.
  induction a as [| | | x IH m | x IH m]; intros [| | | y n | y n]; simpl; intros H; try discriminate; try reflexivity;
    apply andb_true_iff in H; destruct H as [H1 H2]; apply IH in H1; subst.
  - apply option_Z_eqb_true in H2; subst; reflexivity.
  - apply Z.eqb_eq in H2; subst; reflexivity.
Qed.

Lemma is_type_some : forall found t, is_type found t = true -> found = Some t.
Proof.
  intros [f |] t H; simpl in H; [apply type_eqb_true in H; subst; reflexivity | discriminate].
Qed.

Lemma lookup_matches : forall ctx env name t,
  matches ctx env -> find_type name ctx = Some t -> exists v, lookup name env = Some v /\ has_type t v.
Proof.
  intros ctx env name t M; unfold find_type, lookup.
  induction M as [| [n u] [n' v] ctx' env' [E Hv] M IH]; simpl in *; [discriminate |].
  subst n'. destruct (String.eqb n name) eqn:N.
  - intros H; inversion H; subst. exists v; auto.
  - exact IH.
Qed.

Lemma assign_matches : forall ctx env name t v,
  matches ctx env -> find_type name ctx = Some t -> has_type t v ->
  exists env', assign name v env = Some env' /\ matches ctx env'.
Proof.
  intros ctx env name t v M; unfold find_type.
  induction M as [| [n u] [n' w] ctx' env' [E Hw] M IH]; simpl in *; [discriminate |].
  subst n'. intros F Hv. destruct (String.eqb n name) eqn:N.
  - inversion F; subst. exists ((n, v) :: env'). split; [reflexivity |]. constructor; auto.
  - destruct (IH F Hv) as [env'' [A M']]. rewrite A. exists ((n, w) :: env''). split; [reflexivity |].
    constructor; auto.
Qed.

Lemma matches_length : forall ctx env, matches ctx env -> length ctx = length env.
Proof. intros ctx env M; induction M; simpl; auto. Qed.

Lemma matches_extends : forall ctx env, matches ctx env -> extends ctx env.
Proof. intros ctx env M; exists []; exact M. Qed.

Lemma matches_app : forall a b env, matches (a ++ b) env -> matches b (skipn (length a) env).
Proof.
  induction a as [| x a IH]; intros b env M; simpl in *; [exact M |].
  inversion M; subst. simpl. apply IH. assumption.
Qed.

(* The variables a block declared end with it, leaving those in use before it (D93). *)
Lemma restore_matches : forall ctx env env', matches ctx env -> extends ctx env' -> matches ctx (restore env env').
Proof.
  intros ctx env env' M [extra M']. unfold restore.
  pose proof (matches_length _ _ M) as L. pose proof (matches_length _ _ M') as L'.
  rewrite length_app in L'.
  replace (length env' - length env) with (length extra) by lia.
  apply matches_app; assumption.
Qed.

Lemma extends_trans : forall ctx ctx' env, (exists extra, ctx' = extra ++ ctx) -> extends ctx' env -> extends ctx env.
Proof.
  intros ctx ctx' env [extra E] [more M]; subst. exists (more ++ extra). rewrite <- app_assoc. exact M.
Qed.

Lemma values_matches : forall (parameters : list (string * type)) values,
  Forall2 has_type (map snd parameters) values ->
  exists env, bind_parameters parameters values = Some env /\ matches (rev parameters) env.
Proof.
  induction parameters as [| [n t] ps IH]; intros values H; simpl in H.
  - inversion H; subst. exists []. split; [reflexivity | constructor].
  - inversion H as [| t' v ts vs Hv Hrest]; subst.
    destruct (IH vs Hrest) as [env [B M]]. simpl. rewrite B.
    exists (env ++ [(n, v)]). split; [reflexivity |].
    apply Forall2_app; [exact M | constructor; [split; auto | constructor]].
Qed.

Lemma loop_matches : forall ctx env item item_type v position from_one pass,
  matches ctx env -> has_type item_type v ->
  matches (loop_context item item_type position ctx) (loop_locals item v position from_one pass env).
Proof.
  intros ctx env item item_type v position from_one pass M H. unfold loop_context, loop_locals.
  constructor; [split; auto |]. destruct position as [i |]; simpl; [| exact M].
  constructor; [split; reflexivity | exact M].
Qed.

Lemma loop_extends : forall ctx env item item_type position,
  extends (loop_context item item_type position ctx) env -> extends ctx env.
Proof.
  intros ctx env item item_type position X. eapply extends_trans; [| exact X].
  unfold loop_context. exists ((item, item_type) :: match position with Some i => [(i, Whole)] | None => [] end).
  reflexivity.
Qed.

(* ---------------------------------------------------------------------------------------------------------------- *)
(* What each part of a run gives back, when it's well typed *)

(* A stop that's fine: never [Stuck], and a failure passing up only when its procedure lists it (D23). *)
Definition stops_ok (up : list string) (reason : stop) : Prop :=
  reason <> Stuck /\ forall f, reason = Passing_up f -> In f up.

Definition outcome_ok (gives : option type) (failures : list string) (o : outcome) : Prop :=
  match o with
  | Gave v => exists t, gives = Some t /\ has_type t v
  | Gave_nothing => gives = None
  | Failed f => In f failures
  end.

Definition result_ok (gives : option type) (r : option value) : Prop :=
  match gives, r with
  | Some t, Some v => has_type t v
  | None, None => True
  | _, _ => False
  end.

(* How a statement or block may finish: carrying on where [carry_on] says, leaving a loop only inside one, leaving the
   procedure with the value it gives back, leaving a case with the value `instead` gives, and never carrying on when it
   [always] leaves. *)
Definition flow_ok (carry_on leave : environment -> Prop) (a : around) (always : bool) (f : flow) : Prop :=
  match f with
  | Continue env => always = false /\ carry_on env
  | Leave_loop env => inside_loop a = true /\ leave env
  | Leave_procedure r => result_ok (gives_back a) r
  | Leave_case env v => (exists t, instead_type a = Some t /\ has_type t v) /\ leave env
  end.

Ltac fine := constructor; split; [discriminate | let Hs := fresh "Hs" in intros ? Hs; discriminate Hs].

Lemma safe_checked_whole : forall up at_ r op, safe_stopping (stops_ok up) (has_type Whole) (checked_whole at_ r op Whole_value).
Proof. intros up at_ [n | |] op; simpl; [constructor; reflexivity | fine | fine]. Qed.

Lemma safe_need_bool : forall (A : Type) fine (P : A -> Prop) v (a b : unit -> io A),
  has_type Bool v -> safe_stopping fine P (a tt) -> safe_stopping fine P (b tt) -> safe_stopping fine P (need_bool v a b).
Proof. intros A fine P [n | [|] | t | l] a b H Ha Hb; simpl in *; try discriminate; try contradiction; assumption. Qed.

Ltac wrong H := simpl in H; try discriminate; try contradiction.

Lemma safe_compare : forall up operator t a b,
  comparable operator t = true -> has_type t a -> has_type t b ->
  safe_stopping (stops_ok up) (has_type Bool) (compare_values operator a b).
Proof.
  intros up operator t a b C Ha Hb.
  destruct t; simpl in C; try (destruct operator; discriminate);
    destruct a; simpl in Ha; try discriminate; try contradiction;
    destruct b; simpl in Hb; try discriminate; try contradiction;
    destruct operator; simpl in *; try discriminate; constructor; reflexivity.
Qed.

Lemma safe_text_of : forall up t v, shown t = true -> has_type t v -> safe_stopping (stops_ok up) (has_type Text) (text_of v).
Proof.
  intros up t [n | b | s | l] Sg H; simpl in H; subst; simpl in Sg; try discriminate;
    try (constructor; reflexivity).
  destruct t; simpl in *; try discriminate; contradiction.
Qed.

Lemma safe_join : forall up values, Forall (has_type Text) values -> safe_stopping (stops_ok up) (has_type Text) (join_texts values).
Proof.
  intros up values H; induction H as [| v vs Hv Hvs IH]; simpl; [constructor; reflexivity |].
  destruct v as [n | b | t | l]; wrong Hv.
  eapply safe_bind; [exact IH |]. intros [m | c | u | k] Hu; wrong Hu. constructor; reflexivity.
Qed.

Lemma safe_divide : forall up way a b at_, has_type Whole a -> has_type Whole b ->
  safe_stopping (stops_ok up) (has_type Whole) (divide_values way a b at_).
Proof.
  intros up way [x | | | ] [y | | | ] at_ Ha Hb; wrong Ha; wrong Hb. simpl.
  destruct (whole_divide way x y); [constructor; reflexivity | fine | fine | fine].
Qed.

Lemma typed_texts : forall ts values, Forall2 has_type ts values -> Forall (fun t => t = Text) ts ->
  Forall (has_type Text) values.
Proof.
  intros ts values H; induction H as [| t v ts vs Hv Hvs IH]; intros A; constructor;
    inversion A; subst; auto.
Qed.

Lemma typed_items : forall item ts values, Forall2 has_type ts values -> Forall (fun t => t = item) ts ->
  Forall (has_type item) values.
Proof.
  intros item ts values H; induction H as [| t v ts vs Hv Hvs IH]; intros A; constructor;
    inversion A; subst; auto.
Qed.

Lemma pairwise_repeat : forall (f : expression -> type -> bool) parts t,
  forallb (fun part => f part t) parts = true -> pairwise f parts (repeat t (length parts)) = true.
Proof.
  intros f parts t; induction parts as [| e rest IH]; simpl; [reflexivity |].
  intros H; apply andb_true_iff in H; destruct H as [H1 H2]. rewrite H1, (IH H2). reflexivity.
Qed.

Lemma repeat_same : forall (t : type) n, Forall (fun u => u = t) (repeat t n).
Proof. induction n; simpl; constructor; auto. Qed.

Lemma Forall_repeat : forall (A : Type) (P : A -> Prop) x n, P x -> Forall P (repeat x n).
Proof. induction n; simpl; constructor; auto. Qed.

Lemma Forall_replace : forall P n v items, Forall P items -> P v -> Forall P (replace_nth n v items).
Proof.
  intros P n v items; revert n; induction items as [| x rest IH]; intros [| n] H Hv; simpl; auto;
    inversion H; subst; constructor; auto.
Qed.

Lemma Forall_remove : forall P n items, Forall P items -> Forall P (remove_nth n items).
Proof.
  intros P n items; revert n; induction items as [| x rest IH]; intros [| n] H; simpl; auto;
    inversion H; subst; auto.
Qed.

Lemma Forall_first : forall (A : Type) (P : A -> Prop) n l, Forall P l -> Forall P (firstn n l).
Proof. intros A P n l; revert n; induction l as [| x l IH]; intros [| n] H; simpl; auto; inversion H; subst; auto. Qed.

Lemma Forall_skip : forall (A : Type) (P : A -> Prop) n l, Forall P l -> Forall P (skipn n l).
Proof. intros A P n l; revert n; induction l as [| x l IH]; intros [| n] H; simpl; auto; inversion H; subst; auto. Qed.

Lemma offset_in : forall from_one index length n, offset_of from_one index length = Some n -> (Z.of_nat n < length)%Z.
Proof.
  intros from_one index length n H. unfold offset_of in H.
  destruct ((0 <=? _)%Z && (_ <? length)%Z) eqn:B; [| discriminate]. inversion H; subst.
  apply andb_true_iff in B. destruct B as [B1 B2]. apply Z.leb_le in B1. apply Z.ltb_lt in B2.
  rewrite Z2Nat.id; assumption.
Qed.

Lemma safe_item_at : forall (A : Type) up (P : A -> Prop) from_one items index at_ k,
  (forall n, n < length items -> safe_stopping (stops_ok up) P (k n)) ->
  safe_stopping (stops_ok up) P (item_at from_one items index at_ k).
Proof.
  intros A up P from_one items index at_ k H. unfold item_at.
  destruct (offset_of _ _ _) as [n |] eqn:O; [| fine].
  apply H. apply offset_in in O. lia.
Qed.

Lemma apply_library_safe : forall up which values at_ takes gives failures,
  library_signature which = Some (takes, gives, failures) -> Forall2 has_type takes values ->
  safe_stopping (stops_ok up) (outcome_ok gives failures) (apply_library which values at_).
Proof.
  intros up which values at_ takes gives failures Sg H.
  destruct which as [same_line | | | | container | container from_one | container from_one | container from_one];
    simpl in Sg.
  - inversion Sg; subst. inversion H as [| ? v ? ? Hv H']; subst; inversion H'; subst.
    destruct v; wrong Hv. simpl. constructor. constructor. reflexivity.
  - inversion Sg; subst. inversion H as [| ? v ? ? Hv H']; subst; inversion H'; subst.
    destruct v; wrong Hv. simpl. constructor. intros [line |]; [constructor; exists Text; split; reflexivity | fine].
  - inversion Sg; subst. inversion H as [| ? v ? ? Hv H']; subst; inversion H' as [| ? w ? ? Hw H'']; subst;
      inversion H''; subst.
    destruct v; wrong Hv. destruct w; wrong Hw. simpl.
    destruct (_ <=? _)%Z; [constructor; intros m; constructor; exists Whole; split; reflexivity | fine].
  - inversion Sg; subst. inversion H as [| ? v ? ? Hv H']; subst; inversion H'; subst.
    destruct v; wrong Hv. simpl.
    destruct (whole_of_text t); [constructor; exists Whole; split; reflexivity | constructor; simpl; auto].
  - destruct container as [| | | item most | item length]; inversion Sg; subst.
    inversion H as [| ? v ? ? Hv H']; subst; inversion H' as [| ? w ? ? Hw H'']; subst; inversion H''; subst.
    destruct v as [| | | items]; try (simpl in Hv; discriminate). cbn [apply_library].
    destruct (has_room (List_of item most) items) eqn:R.
    + constructor. exists (List_of item most). split; [reflexivity |].
      apply (list_typed (List_of item most) item); [reflexivity |].
      apply Forall_app. split; [apply (list_typed (List_of item most) item); [reflexivity | exact Hv] | constructor; auto].
    + constructor. simpl. destruct most; [left; reflexivity |]. simpl in R. discriminate.
  - destruct container as [| | | item most | item length]; inversion Sg; subst.
    inversion H as [| ? v ? ? Hv H']; subst; inversion H' as [| ? w ? ? Hw H'']; subst;
      inversion H'' as [| ? z ? ? Hz H''']; subst; inversion H'''; subst.
    destruct v as [| | | items]; try (simpl in Hv; discriminate). destruct z as [k | | | ]; wrong Hz. cbn [apply_library].
    destruct (insert_offset _ _ _) as [n |]; [| fine].
    destruct (has_room (List_of item most) items) eqn:R.
    + constructor. exists (List_of item most). split; [reflexivity |].
      apply (list_typed (List_of item most) item); [reflexivity |].
      apply (list_typed (List_of item most) item) in Hv; [| reflexivity].
      apply Forall_app. split; [apply Forall_first; exact Hv | constructor; [exact Hw | apply Forall_skip; exact Hv]].
    + constructor. simpl. destruct most; [left; reflexivity |]. simpl in R. discriminate.
  - destruct container as [| | | item most | item length]; inversion Sg; subst.
    inversion H as [| ? v ? ? Hv H']; subst; inversion H' as [| ? w ? ? Hw H'']; subst; inversion H''; subst.
    destruct v as [| | | items]; try (simpl in Hv; discriminate). destruct w as [k | | | ]; wrong Hw. simpl.
    apply safe_item_at. intros n _. constructor. exists (List_of item most). split; [reflexivity |].
    apply (list_typed (List_of item most) item); [reflexivity |]. apply Forall_remove.
    apply (list_typed (List_of item most) item); [reflexivity | exact Hv].
  - destruct (item_of container) as [item |] eqn:I; inversion Sg; subst.
    inversion H as [| ? v ? ? Hv H']; subst; inversion H' as [| ? w ? ? Hw H'']; subst;
      inversion H'' as [| ? z ? ? Hz H''']; subst; inversion H'''; subst.
    destruct v as [n | b | t | items]; [destruct container; wrong Hv | destruct container; wrong Hv
                                      | destruct container; wrong Hv |].
    destruct w as [k | | | ]; wrong Hw. simpl.
    apply safe_item_at. intros n _. constructor. exists container. split; [reflexivity |].
    apply (list_typed container item); [exact I |]. apply Forall_replace; [| exact Hz].
    apply (list_typed container item); [exact I | exact Hv].
Qed.

Lemma find_procedure_in : forall procedures name d, find_procedure procedures name = Some d -> In d procedures.
Proof. intros procedures name d H; unfold find_procedure in H; apply find_some in H; tauto. Qed.

Lemma covered_find : forall failures handlers f, covered failures handlers = true -> In f failures ->
  exists body, find_case f handlers = Some body.
Proof.
  induction failures as [| g rest IH]; intros handlers f C I; [destruct I |].
  simpl in C. apply andb_true_iff in C. destruct C as [C1 C2].
  destruct I as [E | I]; [subst | apply IH; assumption].
  destruct (find_case f handlers) as [body |]; [exists body; reflexivity | discriminate].
Qed.

Lemma cases_find : forall procedures a ctx must_leave handlers f body,
  cases_ok procedures a ctx must_leave handlers = true -> find_case f handlers = Some body ->
  block_ok procedures a ctx body = true /\ (must_leave = true -> always_leaves_block body = true).
Proof.
  intros procedures a ctx must_leave handlers f body; induction handlers as [| g b rest IH]; simpl;
    intros C F; [discriminate |].
  apply andb_true_iff in C. destruct C as [C C3]. apply andb_true_iff in C. destruct C as [C1 C2].
  destruct (String.eqb g f).
  - inversion F; subst. split; [exact C1 | intros M; subst; exact C2].
  - apply IH; assumption.
Qed.

Lemma within_in : forall failures up f, within failures up = true -> In f failures -> In f up.
Proof.
  intros failures up f W I. unfold within in W. rewrite forallb_forall in W. apply W in I.
  apply existsb_exists in I. destruct I as [g [G E]]. apply String.eqb_eq in E. subst. exact G.
Qed.

(* A statement's checked context grows only by what it declares. *)
Lemma statement_ok_grows : forall procedures a ctx s ctx',
  statement_ok procedures a ctx s = Some ctx' -> exists extra, ctx' = extra ++ ctx.
Proof.
  intros procedures a ctx s ctx' H.
  destruct s; simpl in H;
    repeat match goal with
           | H : context [match ?x with _ => _ end] |- _ => destruct x
           | H : context [if ?x then _ else _] |- _ => destruct x
           end;
    try discriminate; inversion H; subst;
    first [exists []; reflexivity | eexists [(_, _)]; reflexivity].
Qed.

(* ---------------------------------------------------------------------------------------------------------------- *)
(* The proof, by induction on fuel *)

Section Safety_proof.

Variable procedures : list procedure.
Hypothesis procedures_checked : forallb (procedure_ok procedures) procedures = true.

Definition expression_safe (fuel : nat) := forall up ctx e t env where_,
  type_of procedures up ctx e = Some t -> matches ctx env ->
  safe_stopping (stops_ok up) (has_type t) (evaluate fuel where_ procedures env e).

Definition all_values_safe (fuel : nat) := forall up ctx es ts env where_,
  pairwise (fun e t => is_type (type_of procedures up ctx e) t) es ts = true -> matches ctx env ->
  safe_stopping (stops_ok up) (Forall2 has_type ts) (evaluate_all fuel where_ procedures env es).

Definition call_safe (fuel : nat) := forall up ctx c gives failures env where_,
  call_type procedures up ctx c = Some (gives, failures) -> matches ctx env ->
  safe_stopping (stops_ok up) (outcome_ok gives failures) (perform fuel where_ procedures env c).

Definition apply_safe (fuel : nat) := forall up d values at_ where_,
  In d procedures -> Forall2 has_type (map snd (procedure_parameters d)) values ->
  safe_stopping (stops_ok up) (outcome_ok (procedure_gives d) (procedure_failures d))
    (apply fuel where_ procedures d values at_).

Definition statement_safe (fuel : nat) := forall a ctx s ctx' env where_,
  statement_ok procedures a ctx s = Some ctx' -> matches ctx env ->
  safe_stopping (stops_ok (passes_up a)) (flow_ok (matches ctx') (extends ctx) a (always_leaves s))
    (execute fuel where_ procedures env s).

Definition statements_safe (fuel : nat) := forall a ctx b env where_,
  block_ok procedures a ctx b = true -> matches ctx env ->
  safe_stopping (stops_ok (passes_up a)) (flow_ok (extends ctx) (extends ctx) a (always_leaves_block b))
    (execute_statements fuel where_ procedures env b).

Definition block_safe (fuel : nat) := forall a ctx b env where_,
  block_ok procedures a ctx b = true -> matches ctx env ->
  safe_stopping (stops_ok (passes_up a)) (flow_ok (matches ctx) (matches ctx) a (always_leaves_block b))
    (execute_block fuel where_ procedures env b).

Definition go_through_safe (fuel : nat) := forall a ctx item item_type position from_one body items pass env where_,
  block_ok procedures (in_a_loop a) (loop_context item item_type position ctx) body = true ->
  Forall (has_type item_type) items -> matches ctx env ->
  safe_stopping (stops_ok (passes_up a)) (flow_ok (matches ctx) (extends ctx) a false)
    (go_through fuel where_ procedures env item position from_one body items pass).

Definition count_through_safe (fuel : nat) :=
  forall a ctx item position from_one body current last included step pass env where_,
  block_ok procedures (in_a_loop a) (loop_context item Whole position ctx) body = true -> matches ctx env ->
  safe_stopping (stops_ok (passes_up a)) (flow_ok (matches ctx) (extends ctx) a false)
    (count_through fuel where_ procedures env item position from_one body current last included step pass).

Definition all_safe (fuel : nat) :=
  expression_safe fuel /\ all_values_safe fuel /\ call_safe fuel /\ apply_safe fuel /\ statement_safe fuel
  /\ statements_safe fuel /\ block_safe fuel /\ go_through_safe fuel /\ count_through_safe fuel.

Lemma no_fuel_safe : all_safe 0.
Proof.
  unfold all_safe, expression_safe, all_values_safe, call_safe, apply_safe, statement_safe, statements_safe, block_safe,
    go_through_safe, count_through_safe.
  repeat split; intros; fine.
Qed.

Ltac use_type H := apply is_type_some in H.

Lemma expression_step : forall f, all_safe f -> expression_safe (S f).
Proof.
  intros f (E & A & C & _). intros up ctx e t env where_ T M.
  destruct e as [n | b | s | name | operand at_ | operand | operator l r at_ | way l r at_ | operator compared l r
                 | l r | l r | parts | from operand | container items | container value | from_one container index at_
                 | container | c | c fallback]; simpl in T |- *.
  - inversion T; subst; constructor; reflexivity.
  - inversion T; subst; constructor; reflexivity.
  - inversion T; subst; constructor; reflexivity.
  - destruct (lookup_matches _ _ _ _ M T) as [v [L H]]. rewrite L. constructor; exact H.
  - destruct (is_type _ Whole) eqn:O; inversion T; subst. use_type O.
    eapply safe_bind; [eapply E; eauto |]. intros [n | b | s | k] H; wrong H. apply safe_checked_whole.
  - destruct (is_type _ Bool) eqn:O; inversion T; subst. use_type O.
    eapply safe_bind; [eapply E; eauto |]. intros v H.
    apply safe_need_bool; [exact H | constructor; reflexivity | constructor; reflexivity].
  - destruct (is_type _ Whole && is_type _ Whole) eqn:O; inversion T; subst.
    apply andb_true_iff in O; destruct O as [Ol Or]. use_type Ol. use_type Or.
    eapply safe_bind; [eapply E; eauto |]. intros a Ha.
    eapply safe_bind; [eapply E; eauto |]. intros b Hb.
    destruct a as [x | | | ]; wrong Ha. destruct b as [y | | | ]; wrong Hb. apply safe_checked_whole.
  - destruct (is_type _ Whole && is_type _ Whole) eqn:O; inversion T; subst.
    apply andb_true_iff in O; destruct O as [Ol Or]. use_type Ol. use_type Or.
    eapply safe_bind; [eapply E; eauto |]. intros a Ha.
    eapply safe_bind; [eapply E; eauto |]. intros b Hb. apply safe_divide; assumption.
  - destruct (comparable operator compared && is_type _ compared && is_type _ compared) eqn:O; inversion T; subst.
    apply andb_true_iff in O; destruct O as [O Or]. apply andb_true_iff in O; destruct O as [Oc Ol].
    use_type Ol. use_type Or.
    eapply safe_bind; [eapply E; eauto |]. intros a Ha.
    eapply safe_bind; [eapply E; eauto |]. intros b Hb.
    eapply safe_compare; eauto.
  - destruct (is_type _ Bool && is_type _ Bool) eqn:O; inversion T; subst.
    apply andb_true_iff in O; destruct O as [Ol Or]. use_type Ol. use_type Or.
    eapply safe_bind; [eapply E; eauto |]. intros a Ha.
    apply safe_need_bool; [exact Ha | | constructor; reflexivity].
    eapply safe_bind; [eapply E; eauto |]. intros b Hb.
    apply safe_need_bool; [exact Hb | constructor; reflexivity | constructor; reflexivity].
  - destruct (is_type _ Bool && is_type _ Bool) eqn:O; inversion T; subst.
    apply andb_true_iff in O; destruct O as [Ol Or]. use_type Ol. use_type Or.
    eapply safe_bind; [eapply E; eauto |]. intros a Ha.
    apply safe_need_bool; [exact Ha | constructor; reflexivity |].
    eapply safe_bind; [eapply E; eauto |]. intros b Hb.
    apply safe_need_bool; [exact Hb | constructor; reflexivity | constructor; reflexivity].
  - destruct (forallb _ parts) eqn:O; inversion T; subst.
    eapply safe_bind.
    + eapply A; [apply (pairwise_repeat (fun e t => is_type (type_of procedures up ctx e) t)); exact O | exact M].
    + intros values H. apply safe_join. eapply typed_texts; [exact H | apply repeat_same].
  - destruct (shown from && is_type _ from) eqn:O; inversion T; subst.
    apply andb_true_iff in O; destruct O as [Os Oo]. use_type Oo.
    eapply safe_bind; [eapply E; eauto |]. intros v H. eapply safe_text_of; eauto.
  - destruct (item_of container) as [item |] eqn:I; [| discriminate].
    destruct (forallb _ items) eqn:O; inversion T; subst.
    eapply safe_bind.
    + eapply A; [apply (pairwise_repeat (fun e t => is_type (type_of procedures up ctx e) t)); exact O | exact M].
    + intros values H. constructor. apply (list_typed _ item); [exact I |].
      eapply typed_items; [exact H | apply repeat_same].
  - destruct container as [| | | item most | item length]; try discriminate.
    destruct (is_type _ item) eqn:O; inversion T; subst. use_type O.
    eapply safe_bind; [eapply E; eauto |]. intros v H. constructor.
    apply (list_typed _ item); [reflexivity |]. apply Forall_repeat; exact H.
  - destruct (type_of procedures up ctx container) as [ct |] eqn:Tc; [| discriminate].
    destruct (is_type _ Whole) eqn:O; [| discriminate]. use_type O.
    eapply safe_bind; [eapply E; eauto |]. intros cv Hc.
    eapply safe_bind; [eapply E; eauto |]. intros iv Hi.
    destruct iv as [k | | | ]; wrong Hi.
    destruct cv as [n | b | s | items];
      [destruct ct; wrong Hc; discriminate | destruct ct; wrong Hc; discriminate
      | destruct ct; wrong Hc; discriminate |].
    apply (list_typed ct t items) in Hc; [| exact T].
    apply safe_item_at. intros n L.
    destruct (nth_error items n) as [v |] eqn:N.
    + constructor. eapply Forall_forall; [exact Hc | eapply nth_error_In; exact N].
    + apply nth_error_None in N. lia.
  - destruct (type_of procedures up ctx container) as [ct |] eqn:Tc; [| discriminate].
    destruct (item_of ct) as [item |] eqn:I; inversion T; subst.
    eapply safe_bind; [eapply E; eauto |]. intros cv Hc.
    destruct cv as [n | b | s | items];
      [destruct ct; wrong Hc; discriminate | destruct ct; wrong Hc; discriminate
      | destruct ct; wrong Hc; discriminate |].
    constructor; reflexivity.
  - destruct (call_type procedures up ctx c) as [[[u |] [| g gs]] |] eqn:O; inversion T; subst.
    eapply safe_bind; [eapply C; eauto |].
    intros [v | | g] H; simpl in H; try discriminate; try contradiction.
    destruct H as [u [U Hv]]. inversion U; subst. constructor; exact Hv.
  - destruct (call_type procedures up ctx c) as [[[u |] failures] |] eqn:O; try discriminate.
    destruct (is_type _ u) eqn:F; inversion T; subst. use_type F.
    eapply safe_bind; [eapply C; eauto |].
    intros [v | | g] H; simpl in H.
    + destruct H as [u [U Hv]]. inversion U; subst. constructor; exact Hv.
    + discriminate.
    + eapply E; eauto.
Qed.

Lemma all_values_step : forall f, all_safe f -> all_values_safe (S f).
Proof.
  intros f (E & A & _). intros up ctx es ts env where_ P M.
  destruct es as [| e rest]; destruct ts as [| t ts]; simpl in P |- *; try discriminate.
  - constructor. constructor.
  - apply andb_true_iff in P; destruct P as [Pe Prest]. use_type Pe.
    eapply safe_bind; [eapply E; eauto |]. intros v Hv.
    eapply safe_bind; [eapply A; eauto |]. intros vs Hvs.
    constructor. constructor; assumption.
Qed.

Lemma call_step : forall f, all_safe f -> call_safe (S f).
Proof.
  intros f (E & A & C & Ap & _). intros up ctx c gives failures env where_ T M.
  destruct c as [which given at_ | name given at_ | inner name at_ | inner]; simpl in T |- *.
  - destruct (library_signature which) as [[[takes g] fs] |] eqn:Sg; [| discriminate].
    destruct (pairwise _ given takes) eqn:P; inversion T; subst.
    eapply safe_bind; [eapply A; eauto |]. intros values H.
    eapply apply_library_safe; eauto.
  - destruct (find_procedure procedures name) as [d |] eqn:F; [| discriminate].
    destruct (pairwise _ given _) eqn:P; inversion T; subst.
    eapply safe_bind; [eapply A; eauto |]. intros values H.
    eapply Ap; [eapply find_procedure_in; eauto | exact H].
  - destruct (call_type procedures up ctx inner) as [[g fs] |] eqn:I; inversion T; subst.
    eapply safe_bind; [eapply C; eauto |]. intros [v | | g'] H; simpl.
    + constructor. exact H.
    + constructor. exact H.
    + fine.
  - destruct (call_type procedures up ctx inner) as [[g fs] |] eqn:I; [| discriminate].
    destruct (within fs up) eqn:W; inversion T; subst.
    eapply safe_bind; [eapply C; eauto |]. intros [v | | g'] H; simpl.
    + constructor. exact H.
    + constructor. exact H.
    + constructor. split; [discriminate |]. intros f' Ef. inversion Ef; subst. eapply within_in; eauto.
Qed.

Lemma apply_step : forall f, all_safe f -> apply_safe (S f).
Proof.
  intros f (_ & _ & _ & _ & _ & _ & B & _). intros up d values at_ where_ I H. simpl.
  destruct (values_matches _ _ H) as [locals [L M]]. rewrite L.
  destruct (Nat.leb _ _); [fine |].
  pose proof (proj1 (forallb_forall _ _) procedures_checked d I) as P.
  unfold procedure_ok in P. apply andb_true_iff in P; destruct P as [Pb Pr].
  eapply safe_catch.
  - eapply safe_bind; [eapply B; eauto |].
    intros [env' | env' | [v |] | env' v] Hf; simpl in Hf |- *; unfold procedure_result.
    + destruct Hf as [Always _]. destruct (procedure_gives d); [rewrite Always in Pr; discriminate |].
      constructor; reflexivity.
    + destruct Hf; discriminate.
    + destruct (procedure_gives d) as [t |]; [| contradiction]. constructor. exists t; auto.
    + destruct (procedure_gives d) as [t |]; [contradiction |]. constructor; reflexivity.
    + destruct Hf as [[t [It _]] _]. discriminate.
  - intros r [N _] P. split; [exact N | intros g E; exfalso; exact (P g E)].
  - intros g [_ In_g]. constructor. simpl. apply In_g. reflexivity.
Qed.

Lemma deliver_safe : forall up a ctx ctx' destination v env t,
  matches ctx env -> has_type t v ->
  match destination with
  | Into_new name written => t = written /\ ctx' = (name, written) :: ctx
  | Into name => find_type name ctx = Some t /\ ctx' = ctx
  | Nowhere => False
  end ->
  safe_stopping (stops_ok up) (flow_ok (matches ctx') (extends ctx) a false) (deliver destination v env).
Proof.
  intros up a ctx ctx' destination v env t M H D. destruct destination as [name written | name |]; simpl.
  - destruct D as [E1 E2]; subst. constructor. simpl. split; [reflexivity |]. constructor; [split; auto | exact M].
  - destruct D as [F E]; subst. destruct (assign_matches _ _ _ _ _ M F H) as [env' [As M']]. rewrite As.
    constructor. simpl. split; [reflexivity | exact M'].
  - contradiction.
Qed.

Lemma statement_step : forall f, all_safe f -> statement_safe (S f).
Proof.
  intros f (E & A & C & Ap & St & Ss & B & G & K). intros a ctx s ctx' env where_ T M.
  destruct s as [name written value | name value | c | condition tp ep | condition body
                 | item position from_one source body | item position from_one first last included step at_ body
                 | | [value |] | destination c handlers ignore | value];
    simpl in T |- *.
  - destruct (is_type _ written) eqn:O; inversion T; subst. use_type O.
    eapply safe_bind; [eapply E; eauto |]. intros v Hv. constructor. simpl. split; [reflexivity |].
    constructor; [split; auto | exact M].
  - destruct (find_type name ctx) as [t |] eqn:F; [| discriminate].
    destruct (is_type _ t) eqn:O; inversion T; subst. use_type O.
    eapply safe_bind; [eapply E; eauto |]. intros v Hv.
    destruct (assign_matches _ _ _ _ _ M F Hv) as [env' [As M']]. rewrite As.
    constructor. simpl. split; [reflexivity | exact M'].
  - destruct (call_type procedures (passes_up a) ctx c) as [[[u |] [| g gs]] |] eqn:O; inversion T; subst.
    eapply safe_bind; [eapply C; eauto |]. intros [v | | g] H; simpl in H.
    + destruct H as [u [U _]]; discriminate.
    + constructor. simpl. split; [reflexivity | exact M].
    + contradiction.
  - destruct (is_type _ Bool && block_ok _ _ _ tp && block_ok _ _ _ ep) eqn:O; inversion T; subst.
    apply andb_true_iff in O; destruct O as [O Ob]. apply andb_true_iff in O; destruct O as [Oc Oa]. use_type Oc.
    eapply safe_bind; [eapply E; eauto |]. intros v Hv.
    apply safe_need_bool; [exact Hv | |].
    + eapply safe_weaken; [eapply B; eauto | | auto].
      intros [env' | env' | r | env' w] Hf; simpl in Hf |- *; try exact Hf.
      * destruct Hf as [Al Mt]. rewrite Al. split; [reflexivity | exact Mt].
      * destruct Hf as [L Mt]. split; [exact L | apply matches_extends; exact Mt].
      * destruct Hf as [I Mt]. split; [exact I | apply matches_extends; exact Mt].
    + eapply safe_weaken; [eapply B; eauto | | auto].
      intros [env' | env' | r | env' w] Hf; simpl in Hf |- *; try exact Hf.
      * destruct Hf as [Al Mt]. rewrite Al, andb_false_r. split; [reflexivity | exact Mt].
      * destruct Hf as [L Mt]. split; [exact L | apply matches_extends; exact Mt].
      * destruct Hf as [I Mt]. split; [exact I | apply matches_extends; exact Mt].
  - destruct (is_type _ Bool && block_ok _ _ _ body) eqn:O; inversion T; subst.
    apply andb_true_iff in O; destruct O as [Oc Ob]. use_type Oc.
    eapply safe_bind; [eapply E; eauto |]. intros v Hv.
    apply safe_need_bool; [exact Hv | | constructor; simpl; split; [reflexivity | exact M]].
    eapply safe_bind; [apply (B (in_a_loop a)); eauto |].
    intros [env' | env' | r | env' w] Hf; simpl in Hf.
    + destruct Hf as [_ M']. apply (St a ctx' (While condition body) ctx'); [| exact M'].
      simpl. rewrite Oc, Ob. reflexivity.
    + destruct Hf as [_ M']. constructor. simpl. split; [reflexivity | exact M'].
    + constructor. exact Hf.
    + destruct Hf as [I Mt]. constructor. simpl. split; [exact I | apply matches_extends; exact Mt].
  - destruct (type_of procedures (passes_up a) ctx source) as [st |] eqn:Ts; [| discriminate].
    destruct (item_of st) as [item_type |] eqn:I; [| discriminate].
    destruct (block_ok _ _ _ body) eqn:Ob; inversion T; subst.
    eapply safe_bind; [eapply E; eauto |]. intros v Hv.
    destruct v as [n | b | s | items];
      [destruct st; wrong Hv; discriminate | destruct st; wrong Hv; discriminate
      | destruct st; wrong Hv; discriminate |].
    apply (list_typed st item_type items) in Hv; [| exact I].
    eapply G; eauto.
  - destruct (is_type _ Whole && is_type _ Whole && is_type _ Whole && block_ok _ _ _ body) eqn:O;
      inversion T; subst.
    apply andb_true_iff in O; destruct O as [O Ob]. apply andb_true_iff in O; destruct O as [O Os].
    apply andb_true_iff in O; destruct O as [Of Ol]. use_type Of. use_type Ol. use_type Os.
    eapply safe_bind; [eapply E; eauto |]. intros x Hx.
    eapply safe_bind; [eapply E; eauto |]. intros y Hy.
    eapply safe_bind; [eapply E; eauto |]. intros z Hz.
    destruct x as [p | | | ]; wrong Hx. destruct y as [q | | | ]; wrong Hy. destruct z as [r | | | ]; wrong Hz.
    destruct (never_ends p q r); [fine |]. eapply K; eauto.
  - destruct (inside_loop a) eqn:L; inversion T; subst.
    constructor. simpl. split; [exact L | apply matches_extends; exact M].
  - destruct (gives_back a) as [t |] eqn:Gb; [| discriminate]. destruct (is_type _ t) eqn:O; inversion T; subst. use_type O.
    eapply safe_bind; [eapply E; eauto |]. intros v Hv. constructor. simpl. rewrite Gb. exact Hv.
  - destruct (gives_back a) eqn:Gb; inversion T; subst. constructor. simpl. rewrite Gb. exact I.
  - destruct (call_type procedures (passes_up a) ctx c) as [[gives failures] |] eqn:Oc; [| discriminate].
    destruct (ignore || covered failures handlers) eqn:Cv; [| discriminate].
    assert (Fin : forall g, In g failures -> ignore = false ->
              exists body, find_case g handlers = Some body).
    { intros g Ig N. subst. simpl in Cv. eapply covered_find; eauto. }
    destruct destination as [name written | name |]; destruct gives as [t |]; try discriminate.
    + destruct (type_eqb t written && negb ignore && cases_ok _ _ _ _ handlers) eqn:O; inversion T; subst.
      apply andb_true_iff in O; destruct O as [O Oh]. apply andb_true_iff in O; destruct O as [Ot Oi].
      apply type_eqb_true in Ot. subst. apply negb_true_iff in Oi.
      eapply safe_bind; [eapply C; eauto |]. intros [v | | g] H; simpl in H.
      * destruct H as [u [U Hv]]. inversion U; subst. eapply deliver_safe; eauto; simpl; auto.
      * discriminate.
      * destruct (Fin g H Oi) as [body Fc]. rewrite Fc.
        destruct (cases_find _ _ _ _ _ _ _ Oh Fc) as [Ob Ol].
        eapply safe_bind; [apply (B (in_a_case a (Some written))); eauto |].
        intros [env' | env' | r | env' w] Hf; simpl in Hf.
        -- destruct Hf as [Al _]. rewrite (Ol eq_refl) in Al. discriminate.
        -- destruct Hf as [L Mt]. constructor. simpl. split; [exact L | apply matches_extends; exact Mt].
        -- constructor. exact Hf.
        -- destruct Hf as [[u [U Hw]] Mt]. simpl in U. inversion U; subst. eapply deliver_safe; eauto; simpl; auto.
    + destruct (is_type (find_type name ctx) t && cases_ok _ _ _ _ handlers) eqn:O; inversion T; subst.
      apply andb_true_iff in O; destruct O as [Ot Oh]. use_type Ot.
      eapply safe_bind; [eapply C; eauto |]. intros [v | | g] H; simpl in H.
      * destruct H as [u [U Hv]]. inversion U; subst. eapply deliver_safe; eauto; simpl; auto.
      * discriminate.
      * destruct (find_case g handlers) as [body |] eqn:Fc.
        -- destruct (cases_find _ _ _ _ _ _ _ Oh Fc) as [Ob _].
           eapply safe_bind; [apply (B (in_a_case a (Some t))); eauto |].
           intros [env' | env' | r | env' w] Hf; simpl in Hf.
           ++ destruct Hf as [_ Mt]. constructor. simpl. split; [reflexivity | exact Mt].
           ++ destruct Hf as [L Mt]. constructor. simpl. split; [exact L | apply matches_extends; exact Mt].
           ++ constructor. exact Hf.
           ++ destruct Hf as [[u [U Hw]] Mt]. simpl in U. inversion U; subst. eapply deliver_safe; eauto; simpl; auto.
        -- destruct ignore; [constructor; simpl; split; [reflexivity | exact M] |].
           destruct (Fin g H eq_refl) as [body Fb]. rewrite Fb in Fc. discriminate.
    + destruct (cases_ok _ _ _ _ handlers) eqn:Oh; inversion T; subst.
      eapply safe_bind; [eapply C; eauto |]. intros [v | | g] H; simpl in H.
      * destruct H as [u [U _]]. discriminate.
      * constructor. simpl. split; [reflexivity | exact M].
      * destruct (find_case g handlers) as [body |] eqn:Fc.
        -- destruct (cases_find _ _ _ _ _ _ _ Oh Fc) as [Ob _].
           eapply safe_bind; [apply (B (in_a_case a None)); eauto |].
           intros [env' | env' | r | env' w] Hf; simpl in Hf.
           ++ destruct Hf as [_ Mt]. constructor. simpl. split; [reflexivity | exact Mt].
           ++ destruct Hf as [L Mt]. constructor. simpl. split; [exact L | apply matches_extends; exact Mt].
           ++ constructor. exact Hf.
           ++ destruct Hf as [[u [U _]] _]. discriminate.
        -- destruct ignore; [constructor; simpl; split; [reflexivity | exact M] |].
           destruct (Fin g H eq_refl) as [body Fb]. rewrite Fb in Fc. discriminate.
  - destruct (instead_type a) as [t |] eqn:It; [| discriminate].
    destruct (is_type _ t) eqn:O; inversion T; subst. use_type O.
    eapply safe_bind; [eapply E; eauto |]. intros v Hv. constructor. simpl.
    split; [exists t; split; assumption | apply matches_extends; exact M].
Qed.

Lemma statements_step : forall f, all_safe f -> statements_safe (S f).
Proof.
  intros f (E & A & C & Ap & St & Ss & B & _). intros a ctx b env where_ T M.
  destruct b as [| s rest]; simpl in T |- *.
  - constructor. simpl. split; [reflexivity | apply matches_extends; exact M].
  - destruct (statement_ok procedures a ctx s) as [ctx' |] eqn:O; [| discriminate].
    pose proof (statement_ok_grows _ _ _ _ _ O) as Gr.
    eapply safe_bind; [eapply St; eauto |].
    intros [env' | env' | r | env' w] Hf; simpl in Hf.
    + destruct Hf as [Al M']. eapply safe_weaken; [eapply Ss; eauto | | auto].
      intros [env'' | env'' | r | env'' w] Hg; simpl in Hg |- *; try exact Hg.
      * destruct Hg as [Al' X]. rewrite Al, Al'. split; [reflexivity | eapply extends_trans; eauto].
      * destruct Hg as [L X]. split; [exact L | eapply extends_trans; eauto].
      * destruct Hg as [I X]. split; [exact I | eapply extends_trans; eauto].
    + constructor. simpl. exact Hf.
    + constructor. simpl. exact Hf.
    + constructor. simpl. exact Hf.
Qed.

Lemma block_step : forall f, all_safe f -> block_safe (S f).
Proof.
  intros f (E & A & C & Ap & St & Ss & B & _). intros a ctx b env where_ T M. simpl.
  eapply safe_bind; [eapply Ss; eauto |].
  intros [env' | env' | r | env' w] Hf; simpl in Hf; constructor; simpl.
  - destruct Hf as [Al X]. split; [exact Al | eapply restore_matches; eauto].
  - destruct Hf as [L X]. split; [exact L | eapply restore_matches; eauto].
  - exact Hf.
  - destruct Hf as [I X]. split; [exact I | eapply restore_matches; eauto].
Qed.

Lemma go_through_step : forall f, all_safe f -> go_through_safe (S f).
Proof.
  intros f (E & A & C & Ap & St & Ss & B & G & K).
  intros a ctx item item_type position from_one body items pass env where_ Ob H M. simpl.
  destruct items as [| v rest]; [constructor; simpl; split; [reflexivity | exact M] |].
  inversion H as [| ? ? Hv Hrest]; subst.
  eapply safe_bind; [apply (B (in_a_loop a)); [exact Ob | apply loop_matches; [exact M | exact Hv]] |].
  intros [env' | env' | r | env' w] Hf; simpl in Hf.
  - destruct Hf as [_ Mt]. eapply G; eauto. eapply restore_matches; [exact M |].
    eapply loop_extends. apply matches_extends. exact Mt.
  - destruct Hf as [_ Mt]. constructor. simpl. split; [reflexivity |].
    eapply restore_matches; [exact M |]. eapply loop_extends. apply matches_extends. exact Mt.
  - constructor. simpl. exact Hf.
  - destruct Hf as [I Mt]. constructor. simpl. split; [exact I |].
    eapply loop_extends. apply matches_extends. exact Mt.
Qed.

Lemma count_through_step : forall f, all_safe f -> count_through_safe (S f).
Proof.
  intros f (E & A & C & Ap & St & Ss & B & G & K).
  intros a ctx item position from_one body current last included step pass env where_ Ob M. simpl.
  destruct (past_end _ _ _ _); [constructor; simpl; split; [reflexivity | exact M] |].
  eapply safe_bind; [apply (B (in_a_loop a)); [exact Ob | apply loop_matches; [exact M | reflexivity]] |].
  intros [env' | env' | r | env' w] Hf; simpl in Hf.
  - destruct Hf as [_ Mt]. eapply K; eauto. eapply restore_matches; [exact M |].
    eapply loop_extends. apply matches_extends. exact Mt.
  - destruct Hf as [_ Mt]. constructor. simpl. split; [reflexivity |].
    eapply restore_matches; [exact M |]. eapply loop_extends. apply matches_extends. exact Mt.
  - constructor. simpl. exact Hf.
  - destruct Hf as [I Mt]. constructor. simpl. split; [exact I |].
    eapply loop_extends. apply matches_extends. exact Mt.
Qed.

Lemma every_fuel_safe : forall f, all_safe f.
Proof.
  induction f as [| f IH]; [exact no_fuel_safe |].
  split; [apply expression_step; exact IH |].
  split; [apply all_values_step; exact IH |].
  split; [apply call_step; exact IH |].
  split; [apply apply_step; exact IH |].
  split; [apply statement_step; exact IH |].
  split; [apply statements_step; exact IH |].
  split; [apply block_step; exact IH |].
  split; [apply go_through_step; exact IH |].
  apply count_through_step; exact IH.
Qed.

End Safety_proof.

Lemma run_typed_safe : forall p fuel limit, program_ok p = true -> safe (fun _ => True) (run_typed fuel limit p).
Proof.
  intros p fuel limit O. unfold program_ok in O. apply andb_true_iff in O; destruct O as [Op Om].
  unfold run_typed, safe.
  match goal with |- safe_stopping _ _ ?m => assert (H : safe_stopping (stops_ok []) (fun _ => True) m) end.
  { eapply safe_bind.
    - apply (proj1 (proj2 (proj2 (proj2 (proj2 (proj2 (proj2 (every_fuel_safe (program_procedures p) Op fuel))))))) main_around);
        [exact Om | constructor].
    - intros [env | env | [v |] | env v] Hf; simpl in Hf.
      + constructor; exact I.
      + destruct Hf; discriminate.
      + contradiction.
      + constructor; exact I.
      + destruct Hf as [[t [It _]] _]. discriminate. }
  eapply safe_weaken; [exact H | auto | intros r [N _]; exact N].
Qed.

(* THE TYPE-SAFETY THEOREM. In plain words: if the checker accepts a program, running it never gets stuck. However
   the input goes, and whatever random numbers come back, every way through it ends by reaching the end of
   `proc.main`, or stops with a failed runtime check (overflow (D46), dividing by zero or not exactly (D70, D72), a
   position a list doesn't have (D75), a `range` that can't reach its end (D172), calls nested too deep (D154),
   `random` with `from:` above `to:` (D160)), or on purpose with `?? crash` (D152), or with `ask` finding no more input
   (D96), or is still running when the fuel runs out. A failure passed up with `?` never escapes `proc.main`.

   It doesn't say the checker's rules are the ones the standard decides: that's what the tests check. *)
Theorem type_safety : forall p fuel limit, check_program p = [] -> safe (fun _ => True) (run fuel limit p).
Proof.
  intros p fuel limit H. unfold check_program in H. unfold run, typed_program.
  destruct (elaborate p) as [diagnostics tree]. simpl.
  destruct diagnostics; [| discriminate].
  destruct (program_ok tree) eqn:O; [| discriminate].
  apply run_typed_safe; exact O.
Qed.
