(* `Whole`: whole numbers from -9223372036854775808 to 9223372036854775807 (D15).

   Ralph keeps a `Whole` as one of Rocq's exact integers (`Z`), which have no size limit, and checks every result
   against `Whole`'s range: a result outside it stops the program with D46's overflow check, "too big" or "too small"
   (D92). Since nothing is ever cut down to 64 bits, there's nothing to get wrong about wrapping, and the theorems
   below say so. *)

From Stdlib Require Import ZArith String Ascii List Bool Lia.
Import ListNotations.
Open Scope Z_scope.

Definition whole_minimum : Z := -9223372036854775808.
Definition whole_maximum : Z := 9223372036854775807.

(* Whether a number fits in a `Whole`. *)
Definition fits (n : Z) : Prop := whole_minimum <= n <= whole_maximum.

(* What D46's overflow check finds about a result. *)
Inductive checked :=
| Fits (n : Z)
| Too_big
| Too_small.

(* trace: D46, D92 *)
Definition check_range (n : Z) : checked :=
  if n >? whole_maximum then Too_big
  else if n <? whole_minimum then Too_small
  else Fits n.

(* The arithmetic the subset has (D27, D59). *)
Inductive arithmetic := Plus | Minus | Times.

Definition exact (operator : arithmetic) (a b : Z) : Z :=
  match operator with
  | Plus => a + b
  | Minus => a - b
  | Times => a * b
  end.

(* trace: D27, D59, D46 *)
Definition whole_arithmetic (operator : arithmetic) (a b : Z) : checked :=
  check_range (exact operator a b).

(* trace: D27, D46 *)
Definition whole_negate (a : Z) : checked := check_range (- a).

(* `check_range` keeps a number exactly when it fits, and says which way it's out otherwise. *)
Lemma check_range_spec : forall n,
  (fits n -> check_range n = Fits n) /\
  (n > whole_maximum -> check_range n = Too_big) /\
  (n < whole_minimum -> check_range n = Too_small).
Proof.
  intro n; unfold check_range, fits, whole_minimum, whole_maximum.
  repeat split; intros;
    repeat match goal with
    | |- context [if ?c then _ else _] => destruct c eqn:?
    end;
    rewrite ?Z.gtb_lt, ?Z.gtb_ltb, ?Z.ltb_lt, ?Z.ltb_ge in *;
    try reflexivity; try lia.
Qed.

(* THEOREM: `Whole` arithmetic is exact.
   In plain words: for any two whole numbers, `+`, `-` and `*` give the mathematically exact answer whenever it fits
   in a `Whole`; when the exact answer is bigger than the largest `Whole`, they stop with D46's overflow check saying
   "too big", and when it's smaller than the smallest, "too small". Nothing ever wraps around. *)
Theorem whole_arithmetic_exact : forall operator a b,
  (fits (exact operator a b) -> whole_arithmetic operator a b = Fits (exact operator a b)) /\
  (exact operator a b > whole_maximum -> whole_arithmetic operator a b = Too_big) /\
  (exact operator a b < whole_minimum -> whole_arithmetic operator a b = Too_small).
Proof. intros; apply check_range_spec. Qed.

(* THEOREM: negation is exact.
   In plain words: making a whole number negative with `-` gives exactly its negative whenever that fits in a
   `Whole`; the one that doesn't, `-` of -9223372036854775808, stops with D46's overflow check saying "too big". *)
Theorem whole_negate_exact : forall a,
  (fits (- a) -> whole_negate a = Fits (- a)) /\
  (- a > whole_maximum -> whole_negate a = Too_big) /\
  (- a < whole_minimum -> whole_negate a = Too_small).
Proof. intros; apply check_range_spec. Qed.

Lemma floor_low : forall a b q r, -9223372036854775808 <= a <= 9223372036854775807 ->
  -9223372036854775808 <= b <= 9223372036854775807 -> b <> 0 -> a = b * q + r ->
  (0 <= r < b) \/ (b < r <= 0) -> -9223372036854775808 <= q.
Proof.
  intros a b q r A B N E R.
  destruct (Z.le_gt_cases (-9223372036854775808) q) as [Q | Q]; [exact Q |]. exfalso.
  destruct (Z.lt_trichotomy b 0) as [Bn | [Bz | Bp]]; [| lia |]; nia.
Qed.

Lemma trunc_low : forall a b q r, -9223372036854775808 <= a <= 9223372036854775807 ->
  -9223372036854775808 <= b <= 9223372036854775807 -> b <> 0 -> a = b * q + r ->
  Z.abs r < Z.abs b -> (0 <= a -> 0 <= r) -> (a <= 0 -> r <= 0) -> -9223372036854775808 <= q.
Proof.
  intros a b q r A B N E R S1 S2.
  destruct (Z.le_gt_cases (-9223372036854775808) q) as [Q | Q]; [exact Q |]. exfalso.
  destruct (Z.lt_trichotomy b 0) as [Bn | [Bz | Bp]]; [| lia |];
  destruct (Z.le_gt_cases 0 a) as [Ap | An].
  - specialize (S1 Ap). rewrite (Z.abs_neq b) in R by lia. rewrite (Z.abs_eq r) in R by lia. nia.
  - specialize (S2 ltac:(lia)). rewrite (Z.abs_neq b) in R by lia. rewrite (Z.abs_neq r) in R by lia. nia.
  - specialize (S1 Ap). rewrite (Z.abs_eq b) in R by lia. rewrite (Z.abs_eq r) in R by lia. nia.
  - specialize (S2 ltac:(lia)). rewrite (Z.abs_eq b) in R by lia. rewrite (Z.abs_neq r) in R by lia.
    assert (b * q <= b * (-9223372036854775809)) by (apply Z.mul_le_mono_pos_l; lia). nia.
Qed.

(* The ways of dividing two `Whole`s (D70, D71). *)
Inductive division := Divide_exactly | Divide_floor | Divide_trunc | Remainder_floor | Remainder_trunc.

(* What dividing gives: the number, or why it stops (D46, D70, D72). *)
Inductive divided :=
| Divided (n : Z)
| By_zero
| Not_exact
| Quotient_too_big.

(* trace: D46, D70, D71, D72 *)
Definition whole_divide (way : division) (a b : Z) : divided :=
  if b =? 0 then By_zero
  else
    let result :=
      match way with
      | Divide_exactly | Divide_floor => Z.div a b
      | Divide_trunc => Z.quot a b
      | Remainder_floor => Z.modulo a b
      | Remainder_trunc => Z.rem a b
      end in
    match way with
    | Divide_exactly => if Z.rem a b =? 0 then (if result >? whole_maximum then Quotient_too_big else Divided result)
                        else Not_exact
    | _ => if result >? whole_maximum then Quotient_too_big else Divided result
    end.

(* What each way of dividing [a] by [b] gives, in school terms, as D70 and D71 describe it. [r] is what's left over
   when [n] whole groups of [b] are taken out of [a]. *)
Definition divides_as (way : division) (a b n : Z) : Prop :=
  match way with
  (* `/`: [b] goes into [a] exactly [n] times *)
  | Divide_exactly => b * n = a
  (* `div.floor`: what's left over is between 0 and [b], on [b]'s side of 0: the fraction rounds down *)
  | Divide_floor => let r := a - b * n in (0 <= r < b) \/ (b < r <= 0)
  (* `div.trunc`: what's left over is smaller than [b] and on [a]'s side of 0: the fraction is cut off *)
  | Divide_trunc => let r := a - b * n in Z.abs r < Z.abs b /\ (0 <= a -> 0 <= r) /\ (a <= 0 -> r <= 0)
  (* `rem.floor`: what's left over after `div.floor`, with [b]'s sign *)
  | Remainder_floor => exists q, n = a - b * q /\ ((0 <= n < b) \/ (b < n <= 0))
  (* `rem.trunc`: what's left over after `div.trunc`, with [a]'s sign *)
  | Remainder_trunc => exists q, n = a - b * q /\ Z.abs n < Z.abs b /\ (0 <= a -> 0 <= n) /\ (a <= 0 -> n <= 0)
  end.

(* THEOREM: dividing `Whole`s is exact.
   In plain words: for any two whole numbers [a] and [b], each way of dividing either gives a whole number that fits,
   which is exactly the one D70 and D71 describe ([divides_as] above), or stops: dividing by zero stops (D72); `/`
   stops when [b] doesn't go into [a] exactly (D70); and the one answer too big for a `Whole`,
   -9223372036854775808 divided by -1, stops with the overflow check (D46). Nothing ever wraps around. *)
Theorem whole_division_exact : forall way a b, fits a -> fits b ->
  match whole_divide way a b with
  | Divided n => b <> 0 /\ divides_as way a b n /\ fits n
  | By_zero => b = 0
  | Not_exact => way = Divide_exactly /\ b <> 0 /\ ~ (exists n, b * n = a)
  | Quotient_too_big => b <> 0 /\ exists n, divides_as way a b n /\ n > whole_maximum
  end.
Proof.
  intros way a b Fa Fb. unfold fits, whole_minimum, whole_maximum in *. unfold whole_divide.
  destruct (Z.eqb_spec b 0) as [B | B]; [exact B |].
  pose proof (Z.div_mod a b B) as Dm. pose proof (Z.quot_rem' a b) as Qr.
  assert (Mb : (0 <= a mod b < b) \/ (b < a mod b <= 0)).
  { destruct (Z.lt_trichotomy b 0) as [N | [Z0 | P]]; [right | lia | left].
    - apply Z.mod_neg_bound. exact N.
    - apply Z.mod_pos_bound. exact P. }
  assert (Rb : Z.abs (Z.rem a b) < Z.abs b) by (apply Z.rem_bound_abs; exact B).
  assert (Rs1 : 0 <= a -> 0 <= Z.rem a b) by (intros H; apply Z.rem_nonneg; assumption).
  assert (Rs2 : a <= 0 -> Z.rem a b <= 0).
  { intros H. destruct (Z.eq_dec a 0) as [Z0 | Z0]; [subst; rewrite Z.rem_0_l; lia |].
    apply Z.rem_nonpos; lia. }
  pose proof (floor_low a b (a / b) (a mod b) Fa Fb B Dm Mb) as Fl.
  pose proof (trunc_low a b (Z.quot a b) (Z.rem a b) Fa Fb B Qr Rb Rs1 Rs2) as Tl.
  assert (Rr : -9223372036854775808 <= Z.rem a b <= 9223372036854775807).
  { destruct (Z.abs_spec b) as [[_ E1] | [_ E1]]; destruct (Z.abs_spec (Z.rem a b)) as [[_ E2] | [_ E2]];
      rewrite E1, E2 in Rb; lia. }
  destruct way; simpl; unfold whole_maximum.
  - destruct (Z.eqb_spec (Z.rem a b) 0) as [R0 | R0].
    + assert (M0 : a mod b = 0) by (apply Z.mod_divide; [exact B | apply Z.rem_divide; assumption]).
      destruct (a / b >? 9223372036854775807) eqn:G; [apply Z.gtb_lt in G | rewrite Z.gtb_ltb, Z.ltb_ge in G].
      * split; [exact B |]. exists (a / b). split; [lia | lia].
      * split; [exact B |]. split; lia.
    + split; [reflexivity |]. split; [exact B |]. intros [n En]. apply R0.
      apply Z.rem_divide; [exact B |]. exists n. lia.
  - destruct (a / b >? 9223372036854775807) eqn:G; [apply Z.gtb_lt in G | rewrite Z.gtb_ltb, Z.ltb_ge in G].
    + split; [exact B |]. exists (a / b). split; [| lia]. simpl. replace (a - b * (a / b)) with (a mod b) by lia.
      exact Mb.
    + split; [exact B |]. split; [| lia]. simpl. replace (a - b * (a / b)) with (a mod b) by lia. exact Mb.
  - destruct (Z.quot a b >? 9223372036854775807) eqn:G; [apply Z.gtb_lt in G | rewrite Z.gtb_ltb, Z.ltb_ge in G].
    + split; [exact B |]. exists (Z.quot a b). split; [| lia]. simpl.
      replace (a - b * Z.quot a b) with (Z.rem a b) by lia. auto.
    + split; [exact B |]. split; [| lia]. simpl. replace (a - b * Z.quot a b) with (Z.rem a b) by lia. auto.
  - destruct (a mod b >? 9223372036854775807) eqn:G; [apply Z.gtb_lt in G; lia | rewrite Z.gtb_ltb, Z.ltb_ge in G].
    split; [exact B |]. split; [| lia]. exists (a / b). split; [lia | exact Mb].
  - destruct (Z.rem a b >? 9223372036854775807) eqn:G; [apply Z.gtb_lt in G; lia | rewrite Z.gtb_ltb, Z.ltb_ge in G].
    split; [exact B |]. split; [| lia]. exists (Z.quot a b). split; [lia | auto].
Qed.


(* ---------------------------------------------------------------------------------------------------------------- *)
(* Writing a whole number as text, for `be.Text` (D22) and `.fmt` (D29). *)

Definition digit_character (d : Z) : ascii := ascii_of_nat (48 + Z.to_nat d).

(* The decimal digits of [n], in front of [rest]. [steps] bounds the work so Rocq sees it finish: a number with
   [steps] binary digits has at most [steps] decimal ones. *)
Fixpoint decimal_digits (steps : nat) (n : Z) (rest : list ascii) : list ascii :=
  match steps with
  | O => rest
  | S steps' =>
      let digits := digit_character (n mod 10) :: rest in
      if n / 10 =? 0 then digits else decimal_digits steps' (n / 10) digits
  end.

(* trace: D22 *)
Definition text_of_whole (n : Z) : string :=
  match n with
  | Z0 => "0"%string
  | Zpos p => string_of_list_ascii (decimal_digits (Pos.size_nat p) (Zpos p) [])
  | Zneg p => string_of_list_ascii ("-"%char :: decimal_digits (Pos.size_nat p) (Zpos p) [])
  end.

(* ---------------------------------------------------------------------------------------------------------------- *)
(* Reading a whole number from text. *)

Definition digit_value (c : ascii) : option Z :=
  let code := nat_of_ascii c in
  if (48 <=? code)%nat && (code <=? 57)%nat then Some (Z.of_nat (code - 48)) else None.

(* The number some digits spell, if they're all digits and there's at least one. *)
Fixpoint digits_value (so_far : Z) (characters : list ascii) : option Z :=
  match characters with
  | [] => Some so_far
  | c :: rest =>
      match digit_value c with
      | Some d => digits_value (so_far * 10 + d) rest
      | None => None
      end
  end.

Definition number_of_digits (characters : list ascii) : option Z :=
  match characters with
  | [] => None
  | _ => digits_value 0 characters
  end.

(* A whole number literal in a program, as its digits (D15). Whether it fits is the checker's question. *)
Definition whole_of_literal (digits : string) : option Z := number_of_digits (list_ascii_of_string digits).

(* trace: D95, D143. Spaces and tabs around the number are ignored. *)
Fixpoint drop_spaces (characters : list ascii) : list ascii :=
  match characters with
  | " "%char :: rest | "009"%char :: rest => drop_spaces rest
  | _ => characters
  end.

(* trace: D95, D143
   `be.Whole`: spaces and tabs around the number are ignored, a `+` or `-` in front and leading zeros are fine, and
   anything else fails, as does a number that doesn't fit in a `Whole`. *)
Definition whole_of_text (text : string) : option Z :=
  let trimmed := rev (drop_spaces (rev (drop_spaces (list_ascii_of_string text)))) in
  let signed :=
    match trimmed with
    | "-"%char :: digits => option_map Z.opp (number_of_digits digits)
    | "+"%char :: digits => number_of_digits digits
    | digits => number_of_digits digits
    end in
  match signed with
  | Some n => if (whole_minimum <=? n) && (n <=? whole_maximum) then Some n else None
  | None => None
  end.
