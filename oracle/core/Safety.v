(* Type safety: a program the checker accepts never gets stuck.

   The evaluator (Evaluator.v) stops with [Stuck] whenever it meets something it has no rule for: a variable that
   isn't there, `+` on a `Bool`, a procedure that doesn't exist, `break` outside a loop, a procedure with `->`
   finishing without `return`, and so on. This file proves that none of that ever happens to a program the checker
   (Checker.v) accepts, however its input goes and whatever random numbers come back.

   The checker accepts a program only when the second type checker (TypedTree.v) accepts its typed tree too, so the
   proof is about that second, small checker. It goes by induction on the evaluator's fuel, the "definitional
   interpreter" method: at each amount of fuel, every part of an accepted tree, run where the type checker said its
   variables would be, gives a value of the type the type checker worked out, or stops for a reason that isn't
   [Stuck]. *)

From Stdlib Require Import String List Bool ZArith Lia.
From Ralph Require Import Syntax Whole Io TypedTree Checker Evaluator.
Import ListNotations.
Import Typed.
Open Scope list_scope.
Open Scope nat_scope.

(* ---------------------------------------------------------------------------------------------------------------- *)
(* Values, variables and their types *)

Definition type_of_value (v : value) : type :=
  match v with
  | Whole_value _ => Whole
  | Bool_value _ => Bool
  | Text_value _ => Text
  end.

Definition has_type (t : type) (v : value) : Prop := type_of_value v = t.

(* The values in [env] are where, and of the types, the type checker's [ctx] said. *)
Definition matches (ctx : context) (env : environment) : Prop :=
  Forall2 (fun entry binding => fst entry = fst binding /\ has_type (snd entry) (snd binding)) ctx env.

(* [env] holds [ctx]'s variables, and maybe more declared since, innermost first. *)
Definition extends (ctx : context) (env : environment) : Prop := exists extra, matches (extra ++ ctx) env.

Lemma type_eqb_true : forall a b, type_eqb a b = true -> a = b.
Proof. intros [] []; simpl; congruence. Qed.

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

(* ---------------------------------------------------------------------------------------------------------------- *)
(* What each part of a run gives back, when it's well typed *)

Definition outcome_ok (gives : option type) (can_fail : bool) (o : outcome) : Prop :=
  match o with
  | Gave v => exists t, gives = Some t /\ has_type t v
  | Gave_nothing => gives = None
  | Failed => can_fail = true
  end.

Definition result_ok (gives : option type) (r : option value) : Prop :=
  match gives, r with
  | Some t, Some v => has_type t v
  | None, None => True
  | _, _ => False
  end.

(* How a statement or block may finish: carrying on where [carry_on] says, leaving a loop only inside one, leaving the
   procedure with the value it gives back, and never carrying on when it [always] returns. *)
Definition flow_ok (carry_on leave : environment -> Prop) (in_loop : bool) (gives : option type) (always : bool)
    (f : flow) : Prop :=
  match f with
  | Continue env => always = false /\ carry_on env
  | Leave_loop env => in_loop = true /\ leave env
  | Leave_procedure r => result_ok gives r
  end.

Lemma not_stuck_overflow : forall a b c, Overflow a b c <> Stuck. Proof. discriminate. Qed.
Lemma not_stuck_fuel : Out_of_fuel <> Stuck. Proof. discriminate. Qed.

Lemma safe_checked_whole : forall at_ r op, safe (has_type Whole) (checked_whole at_ r op Whole_value).
Proof. intros at_ [n | |] op; simpl; constructor; [reflexivity | discriminate | discriminate]. Qed.

Lemma safe_need_bool : forall (A : Type) (P : A -> Prop) v (a b : unit -> io A),
  has_type Bool v -> safe P (a tt) -> safe P (b tt) -> safe P (need_bool v a b).
Proof. intros A P [n | [|] | t] a b H Ha Hb; simpl in *; try discriminate; assumption. Qed.

Lemma safe_compare : forall operator t a b,
  comparable operator t = true -> has_type t a -> has_type t b -> safe (has_type Bool) (compare_values operator a b).
Proof.
  intros operator t [x | x | x] [y | y | y] C Ha Hb; unfold has_type in *; simpl in *; subst; try discriminate;
    destruct operator; simpl in *; try discriminate; constructor; reflexivity.
Qed.

Lemma safe_text_of : forall t v, shown t = true -> has_type t v -> safe (has_type Text) (text_of v).
Proof.
  intros t [n | b | s] S H; unfold has_type in H; simpl in *; subst; try discriminate; constructor; reflexivity.
Qed.

Lemma safe_join : forall values, Forall (has_type Text) values -> safe (has_type Text) (join_texts values).
Proof.
  intros values H; induction H as [| v vs Hv Hvs IH]; simpl; [constructor; reflexivity |].
  destruct v as [n | b | t]; unfold has_type in Hv; simpl in Hv; try discriminate.
  eapply safe_bind; [exact IH |]. intros [m | c | u] Hu; unfold has_type in Hu; simpl in Hu; try discriminate.
  constructor; reflexivity.
Qed.

Lemma typed_texts : forall ts values, Forall2 has_type ts values -> Forall (fun t => t = Text) ts ->
  Forall (has_type Text) values.
Proof.
  intros ts values H; induction H as [| t v ts vs Hv Hvs IH]; intros A; constructor;
    inversion A; subst; auto.
Qed.

Lemma pairwise_repeat : forall procedures ctx parts,
  forallb (fun part => is_type (type_of procedures ctx part) Text) parts = true ->
  pairwise (fun e t => is_type (type_of procedures ctx e) t) parts (repeat Text (length parts)) = true.
Proof.
  intros procedures ctx parts; induction parts as [| e rest IH]; simpl; [reflexivity |].
  intros H; apply andb_true_iff in H; destruct H as [H1 H2]. rewrite H1, (IH H2). reflexivity.
Qed.

Lemma repeat_text : forall n, Forall (fun t => t = Text) (repeat Text n).
Proof. induction n; simpl; constructor; auto. Qed.

Lemma not_stuck_input : Input_ended <> Stuck. Proof. discriminate. Qed.
Lemma not_stuck_random : forall a b c, Random_backwards a b c <> Stuck. Proof. discriminate. Qed.

Lemma apply_library_safe : forall which values at_ takes gives can_fail,
  library_signature which = (takes, gives, can_fail) -> Forall2 has_type takes values ->
  safe (outcome_ok gives can_fail) (apply_library which values at_).
Proof.
  intros which values at_ takes gives can_fail S H.
  destruct which; simpl in S; inversion S; subst; clear S;
    repeat (match goal with
            | H : Forall2 _ (_ :: _) _ |- _ => inversion H; subst; clear H
            | H : Forall2 _ [] _ |- _ => inversion H; subst; clear H
            end);
    repeat match goal with
           | v : value |- _ => destruct v; unfold has_type in *; simpl in *; try discriminate
           end;
    simpl.
  - constructor. constructor. reflexivity.
  - constructor. intros [line |]; constructor; [exists Text; split; reflexivity | discriminate].
  - destruct (_ <=? _)%Z;
      [constructor; intros m; constructor; exists Whole; split; reflexivity | constructor; discriminate].
  - destruct (whole_of_text t); [constructor; exists Whole; split; reflexivity | constructor; reflexivity].
Qed.

Lemma find_procedure_in : forall procedures name d, find_procedure procedures name = Some d -> In d procedures.
Proof. intros procedures name d H; unfold find_procedure in H; apply find_some in H; tauto. Qed.

(* A statement's checked context grows only by what it declares. *)
Lemma statement_ok_grows : forall procedures ctx in_loop gives s ctx',
  statement_ok procedures ctx in_loop gives s = Some ctx' -> exists extra, ctx' = extra ++ ctx.
Proof.
  intros procedures ctx in_loop gives s ctx' H.
  destruct s as [name written value | name value | c | condition a b | condition body | | [value |]]; simpl in H.
  - destruct (is_type _ _); inversion H; subst. exists [(name, written)]. reflexivity.
  - destruct (find_type _ _); [destruct (is_type _ _) |]; inversion H; subst; exists []; reflexivity.
  - destruct (call_type _ _ _) as [[[t |] [|]] |]; inversion H; subst; exists []; reflexivity.
  - destruct (_ && _ && _); inversion H; subst; exists []; reflexivity.
  - destruct (_ && _); inversion H; subst; exists []; reflexivity.
  - destruct in_loop; inversion H; subst; exists []; reflexivity.
  - destruct gives; [destruct (is_type _ _) |]; inversion H; subst; exists []; reflexivity.
  - destruct gives; inversion H; subst; exists []; reflexivity.
Qed.

(* ---------------------------------------------------------------------------------------------------------------- *)
(* The proof, by induction on fuel *)

Section Safety_proof.

Variable procedures : list procedure.
Hypothesis procedures_checked : forallb (procedure_ok procedures) procedures = true.

Definition expression_safe (fuel : nat) := forall ctx e t env where_,
  type_of procedures ctx e = Some t -> matches ctx env ->
  safe (has_type t) (evaluate fuel where_ procedures env e).

Definition all_values_safe (fuel : nat) := forall ctx es ts env where_,
  pairwise (fun e t => is_type (type_of procedures ctx e) t) es ts = true -> matches ctx env ->
  safe (Forall2 has_type ts) (evaluate_all fuel where_ procedures env es).

Definition call_safe (fuel : nat) := forall ctx c gives can_fail env where_,
  call_type procedures ctx c = Some (gives, can_fail) -> matches ctx env ->
  safe (outcome_ok gives can_fail) (perform fuel where_ procedures env c).

Definition apply_safe (fuel : nat) := forall d values at_ where_,
  In d procedures -> Forall2 has_type (map snd (procedure_parameters d)) values ->
  safe (outcome_ok (procedure_gives d) false) (apply fuel where_ procedures d values at_).

Definition statement_safe (fuel : nat) := forall ctx in_loop gives s ctx' env where_,
  statement_ok procedures ctx in_loop gives s = Some ctx' -> matches ctx env ->
  safe (flow_ok (matches ctx') (extends ctx) in_loop gives (always_returns s))
    (execute fuel where_ procedures env s).

Definition statements_safe (fuel : nat) := forall ctx in_loop gives b env where_,
  block_ok procedures ctx in_loop gives b = true -> matches ctx env ->
  safe (flow_ok (extends ctx) (extends ctx) in_loop gives (always_returns_block b))
    (execute_statements fuel where_ procedures env b).

Definition block_safe (fuel : nat) := forall ctx in_loop gives b env where_,
  block_ok procedures ctx in_loop gives b = true -> matches ctx env ->
  safe (flow_ok (matches ctx) (matches ctx) in_loop gives (always_returns_block b))
    (execute_block fuel where_ procedures env b).

Definition all_safe (fuel : nat) :=
  expression_safe fuel /\ all_values_safe fuel /\ call_safe fuel /\ apply_safe fuel /\ statement_safe fuel
  /\ statements_safe fuel /\ block_safe fuel.

Lemma out_of_fuel_safe : forall (A : Type) (P : A -> Prop), safe P (Stop Out_of_fuel).
Proof. intros; constructor; discriminate. Qed.

Lemma no_fuel_safe : all_safe 0.
Proof.
  unfold all_safe, expression_safe, all_values_safe, call_safe, apply_safe, statement_safe, statements_safe, block_safe.
  repeat split; intros; apply out_of_fuel_safe.
Qed.

Ltac use_type H := apply is_type_some in H.

Lemma expression_step : forall f, all_safe f -> expression_safe (S f).
Proof.
  intros f (E & A & C & _). intros ctx e t env where_ T M.
  destruct e as [n | b | s | name | operand at_ | operand | operator l r at_ | operator compared l r | l r | l r
                 | parts | from operand | c | c fallback]; simpl in T |- *.
  - inversion T; subst; constructor; reflexivity.
  - inversion T; subst; constructor; reflexivity.
  - inversion T; subst; constructor; reflexivity.
  - destruct (lookup_matches _ _ _ _ M T) as [v [L H]]. rewrite L. constructor; exact H.
  - destruct (is_type _ Whole) eqn:O; inversion T; subst. use_type O.
    eapply safe_bind; [eapply E; eauto |]. intros [n | b | s] H; unfold has_type in H; simpl in H; try discriminate.
    apply safe_checked_whole.
  - destruct (is_type _ Bool) eqn:O; inversion T; subst. use_type O.
    eapply safe_bind; [eapply E; eauto |]. intros v H.
    apply safe_need_bool; [exact H | constructor; reflexivity | constructor; reflexivity].
  - destruct (is_type _ Whole && is_type _ Whole) eqn:O; inversion T; subst.
    apply andb_true_iff in O; destruct O as [Ol Or]. use_type Ol. use_type Or.
    eapply safe_bind; [eapply E; eauto |]. intros a Ha.
    eapply safe_bind; [eapply E; eauto |]. intros b Hb.
    destruct a as [x | | ]; unfold has_type in Ha; simpl in Ha; try discriminate.
    destruct b as [y | | ]; unfold has_type in Hb; simpl in Hb; try discriminate.
    apply safe_checked_whole.
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
    eapply safe_bind; [eapply A; [apply pairwise_repeat; exact O | exact M] |].
    intros values H. apply safe_join. eapply typed_texts; [exact H | apply repeat_text].
  - destruct (shown from && is_type _ from) eqn:O; inversion T; subst.
    apply andb_true_iff in O; destruct O as [Os Oo]. use_type Oo.
    eapply safe_bind; [eapply E; eauto |]. intros v H. eapply safe_text_of; eauto.
  - destruct (call_type procedures ctx c) as [[[u |] [|]] |] eqn:O; inversion T; subst.
    eapply safe_bind; [eapply C; eauto |].
    intros [v | |] H; simpl in H; try discriminate.
    destruct H as [u [U Hv]]. inversion U; subst. constructor; exact Hv.
  - destruct (call_type procedures ctx c) as [[[u |] [|]] |] eqn:O; try discriminate.
    destruct (is_type _ u) eqn:F; inversion T; subst. use_type F.
    eapply safe_bind; [eapply C; eauto |].
    intros [v | |] H; simpl in H.
    + destruct H as [u [U Hv]]. inversion U; subst. constructor; exact Hv.
    + discriminate.
    + eapply E; eauto.
Qed.

Lemma all_values_step : forall f, all_safe f -> all_values_safe (S f).
Proof.
  intros f (E & A & _). intros ctx es ts env where_ P M.
  destruct es as [| e rest]; destruct ts as [| t ts]; simpl in P |- *; try discriminate.
  - constructor. constructor.
  - apply andb_true_iff in P; destruct P as [Pe Prest]. use_type Pe.
    eapply safe_bind; [eapply E; eauto |]. intros v Hv.
    eapply safe_bind; [eapply A; eauto |]. intros vs Hvs.
    constructor. constructor; assumption.
Qed.

Lemma call_step : forall f, all_safe f -> call_safe (S f).
Proof.
  intros f (E & A & C & Ap & _). intros ctx c gives can_fail env where_ T M.
  destruct c as [which given at_ | name given at_]; simpl in T |- *.
  - destruct (library_signature which) as [[takes g] fails] eqn:Sg.
    destruct (pairwise _ given takes) eqn:P; inversion T; subst.
    eapply safe_bind; [eapply A; eauto |]. intros values H.
    eapply apply_library_safe; eauto.
  - destruct (find_procedure procedures name) as [d |] eqn:F; simpl in T; [| discriminate].
    destruct (pairwise _ given _) eqn:P; inversion T; subst.
    eapply safe_bind; [eapply A; eauto |]. intros values H.
    eapply Ap; [eapply find_procedure_in; eauto | exact H].
Qed.

Lemma apply_step : forall f, all_safe f -> apply_safe (S f).
Proof.
  intros f (_ & _ & _ & _ & _ & _ & B). intros d values at_ where_ I H. simpl.
  destruct (values_matches _ _ H) as [locals [L M]]. rewrite L.
  destruct (Nat.leb _ _); [constructor; discriminate |].
  pose proof (proj1 (forallb_forall _ _) procedures_checked d I) as P.
  unfold procedure_ok in P. apply andb_true_iff in P; destruct P as [Pb Pr].
  eapply safe_bind; [eapply B; eauto |].
  intros [env' | env' | [v |]] Hf; simpl in Hf |- *; unfold procedure_result.
  - destruct Hf as [Always _]. destruct (procedure_gives d); [rewrite Always in Pr; discriminate |].
    constructor; reflexivity.
  - destruct Hf; discriminate.
  - destruct (procedure_gives d) as [t |]; [| contradiction]. constructor. exists t; auto.
  - destruct (procedure_gives d) as [t |]; [contradiction |]. constructor; reflexivity.
Qed.

Lemma statement_step : forall f, all_safe f -> statement_safe (S f).
Proof.
  intros f (E & A & C & Ap & St & Ss & B). intros ctx in_loop gives s ctx' env where_ T M.
  destruct s as [name written value | name value | c | condition a b | condition body | | [value |]];
    simpl in T |- *.
  - destruct (is_type _ written) eqn:O; inversion T; subst. use_type O.
    eapply safe_bind; [eapply E; eauto |]. intros v Hv. constructor. simpl. split; [reflexivity |].
    constructor; [split; auto | exact M].
  - destruct (find_type name ctx) as [t |] eqn:F; [| discriminate].
    destruct (is_type _ t) eqn:O; inversion T; subst. use_type O.
    eapply safe_bind; [eapply E; eauto |]. intros v Hv.
    destruct (assign_matches _ _ _ _ _ M F Hv) as [env' [As M']]. rewrite As.
    constructor. simpl. split; [reflexivity | exact M'].
  - destruct (call_type procedures ctx c) as [[[u |] [|]] |] eqn:O; inversion T; subst.
    eapply safe_bind; [eapply C; eauto |]. intros [v | |] H; simpl in H.
    + destruct H as [u [U _]]; discriminate.
    + constructor. simpl. split; [reflexivity | exact M].
    + discriminate.
  - destruct (is_type _ Bool && block_ok _ _ _ _ a && block_ok _ _ _ _ b) eqn:O; inversion T; subst.
    apply andb_true_iff in O; destruct O as [O Ob]. apply andb_true_iff in O; destruct O as [Oc Oa]. use_type Oc.
    eapply safe_bind; [eapply E; eauto |]. intros v Hv.
    apply safe_need_bool; [exact Hv | |].
    + eapply safe_weaken; [eapply B; eauto |].
      intros [env' | env' | r] Hf; simpl in Hf |- *; try exact Hf.
      * destruct Hf as [Al Mt]. rewrite Al. split; [reflexivity | exact Mt].
      * destruct Hf as [L Mt]. split; [exact L | apply matches_extends; exact Mt].
    + eapply safe_weaken; [eapply B; eauto |].
      intros [env' | env' | r] Hf; simpl in Hf |- *; try exact Hf.
      * destruct Hf as [Al Mt]. rewrite Al, andb_false_r. split; [reflexivity | exact Mt].
      * destruct Hf as [L Mt]. split; [exact L | apply matches_extends; exact Mt].
  - destruct (is_type _ Bool && block_ok _ _ _ _ body) eqn:O; inversion T; subst.
    apply andb_true_iff in O; destruct O as [Oc Ob]. use_type Oc.
    eapply safe_bind; [eapply E; eauto |]. intros v Hv.
    apply safe_need_bool; [exact Hv | | constructor; simpl; split; [reflexivity | exact M]].
    eapply safe_bind; [eapply B; eauto |].
    intros [env' | env' | r] Hf; simpl in Hf.
    + destruct Hf as [_ M']. apply (St ctx' in_loop gives (While condition body) ctx'); [| exact M'].
      simpl. rewrite Oc, Ob. reflexivity.
    + destruct Hf as [_ M']. constructor. simpl. split; [reflexivity | exact M'].
    + constructor. exact Hf.
  - destruct in_loop; inversion T; subst. constructor. simpl. split; [reflexivity | apply matches_extends; exact M].
  - destruct gives as [t |]; [| discriminate]. destruct (is_type _ t) eqn:O; inversion T; subst. use_type O.
    eapply safe_bind; [eapply E; eauto |]. intros v Hv. constructor. simpl. exact Hv.
  - destruct gives; inversion T; subst. constructor. simpl. exact I.
Qed.

Lemma statements_step : forall f, all_safe f -> statements_safe (S f).
Proof.
  intros f (E & A & C & Ap & St & Ss & B). intros ctx in_loop gives b env where_ T M.
  destruct b as [| s rest]; simpl in T |- *.
  - constructor. simpl. split; [reflexivity | apply matches_extends; exact M].
  - destruct (statement_ok procedures ctx in_loop gives s) as [ctx' |] eqn:O; [| discriminate].
    pose proof (statement_ok_grows _ _ _ _ _ _ O) as G.
    eapply safe_bind; [eapply St; eauto |].
    intros [env' | env' | r] Hf; simpl in Hf.
    + destruct Hf as [Al M']. eapply safe_weaken; [eapply Ss; eauto |].
      intros [env'' | env'' | r] Hg; simpl in Hg |- *; try exact Hg.
      * destruct Hg as [Al' X]. rewrite Al, Al'. split; [reflexivity | eapply extends_trans; eauto].
      * destruct Hg as [L X]. split; [exact L | eapply extends_trans; eauto].
    + constructor. simpl. exact Hf.
    + constructor. simpl. exact Hf.
Qed.

Lemma block_step : forall f, all_safe f -> block_safe (S f).
Proof.
  intros f (E & A & C & Ap & St & Ss & B). intros ctx in_loop gives b env where_ T M. simpl.
  eapply safe_bind; [eapply Ss; eauto |].
  intros [env' | env' | r] Hf; simpl in Hf; constructor; simpl.
  - destruct Hf as [Al X]. split; [exact Al | eapply restore_matches; eauto].
  - destruct Hf as [L X]. split; [exact L | eapply restore_matches; eauto].
  - exact Hf.
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
  apply block_step; exact IH.
Qed.

End Safety_proof.

Lemma run_typed_safe : forall p fuel limit, program_ok p = true -> safe (fun _ => True) (run_typed fuel limit p).
Proof.
  intros p fuel limit O. unfold program_ok in O. apply andb_true_iff in O; destruct O as [Op Om].
  unfold run_typed.
  eapply safe_bind; [eapply (every_fuel_safe (program_procedures p) Op fuel); [exact Om | constructor] |].
  intros [env | env | [v |]] Hf; simpl in Hf.
  - constructor; exact I.
  - destruct Hf; discriminate.
  - contradiction.
  - constructor; exact I.
Qed.

(* THE TYPE-SAFETY THEOREM. In plain words: if the checker accepts a program, running it never gets stuck. However
   the input goes, and whatever random numbers come back, every way through it ends by reaching the end of
   `proc.main`, or stops with a failed runtime check (D46's overflow, calls nested too deep (D154), `random` with
   `from:` above `to:` (D160)), or with `ask` finding no more input (D96), or is still running when the fuel runs out.

   It doesn't say the checker's rules are the ones the standard decides: that's what the tests check. *)
Theorem type_safety : forall p fuel limit, check_program p = [] -> safe (fun _ => True) (run fuel limit p).
Proof.
  intros p fuel limit H. unfold check_program in H. unfold run, typed_program.
  destruct (elaborate p) as [diagnostics tree]. simpl.
  destruct diagnostics; [| discriminate].
  destruct (program_ok tree) eqn:O; [| discriminate].
  apply run_typed_safe; exact O.
Qed.
