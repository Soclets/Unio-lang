(* `Float`: IEEE 754 binary64 (D157), proven with Flocq (D189).

   A `Float` is Flocq's [binary_float 53 1024], which is exactly IEEE 754's binary64: 53 bits of precision, exponents
   up to 1024, and subnormal numbers down to 2^-1074. Ralph's running code is Flocq's own arithmetic on the bits, all
   in integers; the axioms Flocq's proofs rest on (listed in assumptions/Axioms.v) appear only in the theorems here,
   never in what runs.

   A `Float` in Unio is always a real number (D177): a result IEEE 754 would make infinite stops the program with a
   failed check, as dividing by zero does (D46), and so does `sqrt` of a negative number (D185). So every `Float` a
   program holds is finite, and the theorems say what each operation gives for finite `Float`s. *)

From Stdlib Require Import ZArith Reals Lia Lra String Ascii List Bool.
From Flocq Require Import Core IEEE754.BinarySingleNaN.
From Ralph Require Import Whole.
Import ListNotations.
Open Scope Z_scope.

Definition float := binary_float 53 1024.

#[global] Instance float_precision : Prec_gt_0 53. Proof. unfold Prec_gt_0. lia. Qed.
#[global] Instance float_range : Prec_lt_emax 53 1024. Proof. unfold Prec_lt_emax. lia. Qed.

(* The real number nearest [r] that a `Float` can hold, a tie going to the one whose last bit is even, as IEEE 754
   rounds by default and Unio's `+`, `-`, `*`, `/` and `sqrt` do (D163, D179, D185). [SpecFloat.fexp 53 1024] is
   binary64's: 53 bits, and nothing smaller than 2^-1074. *)
Definition nearest (r : R) : R := round radix2 (SpecFloat.fexp 53 1024) ZnearestE r.

(* 2^1024: a `Float` this big or bigger would be infinite (D177). *)
Definition float_limit : R := bpow radix2 1024.

Definition is_zero (x : float) : bool := match x with B754_zero _ => true | _ => false end.

(* What a `Float` operation gives: the `Float`, or why it stops (D46, D177, D185). *)
Inductive float_checked :=
| Float_fits (f : float)
| Float_too_big
| Float_by_zero
| Float_negative_root.

Inductive float_operation := Float_plus | Float_minus | Float_times | Float_divide.

Definition keep_finite (z : float) : float_checked := if is_finite z then Float_fits z else Float_too_big.

(* trace: D46, D163, D177, D179 *)
Definition float_arithmetic (operator : float_operation) (x y : float) : float_checked :=
  match operator with
  | Float_plus => keep_finite (Bplus mode_NE x y)
  | Float_minus => keep_finite (Bminus mode_NE x y)
  | Float_times => keep_finite (Bmult mode_NE x y)
  | Float_divide => if is_zero y then Float_by_zero else keep_finite (Bdiv mode_NE x y)
  end.

(* trace: D177, D185. A negative number's square root isn't a real number; negative zero's is negative zero. *)
Definition float_sqrt (x : float) : float_checked :=
  match x with
  | B754_finite true _ _ _ => Float_negative_root
  | _ => keep_finite (Bsqrt mode_NE x)
  end.

(* trace: D27. `-` in front of a `Float`: always exact. *)
Definition float_negate (x : float) : float := Bopp x.

(* The exact result an operation stands for, on the real numbers. *)
Definition exact_result (operator : float_operation) (a b : R) : R :=
  match operator with
  | Float_plus => a + b
  | Float_minus => a - b
  | Float_times => a * b
  | Float_divide => a / b
  end%R.

Lemma keep_finite_spec : forall (z : float) r,
  (if Rlt_bool (Rabs (nearest r)) float_limit then B2R z = nearest r /\ is_finite z = true else is_finite z = false) ->
  match keep_finite z with
  | Float_fits w => is_finite w = true /\ B2R w = nearest r
  | Float_too_big => (float_limit <= Rabs (nearest r))%R
  | _ => False
  end.
Proof.
  intros z r. unfold keep_finite. destruct (Rlt_bool_spec (Rabs (nearest r)) float_limit) as [L | L]; intros H.
  - destruct H as [E F]. rewrite F. split; assumption.
  - rewrite H. exact L.
Qed.

Lemma overflow_not_finite : forall (z : float) s, B2SF z = binary_overflow 53 1024 mode_NE s -> is_finite z = false.
Proof. intros z s E. destruct z; simpl in *; try reflexivity; destruct s; simpl in E; discriminate. Qed.

Lemma is_zero_B2R : forall x : float, is_finite x = true -> (is_zero x = true <-> B2R x = 0%R).
Proof.
  intros [s | s | | s m e B] F; simpl in *; try discriminate; split; intros H; try reflexivity; try discriminate.
  exfalso. revert H. apply F2R_neq_0. destruct s; discriminate.
Qed.

Ltac from_flocq C :=
  unfold nearest, float_limit; simpl round_mode in C; revert C;
  destruct (Rlt_bool _ _); intros C;
  [ destruct C as [C1 [C2 _]]; split; [exact C1 | try rewrite C2; auto with bool]
  | first [ eapply overflow_not_finite; exact C | destruct C as [C1 _]; eapply overflow_not_finite; exact C1 ] ].

(* THEOREM: `Float` arithmetic is correctly rounded.
   In plain words: for any two `Float`s, `+`, `-`, `*` and `/` give the `Float` nearest the exact real answer, a tie
   going to the one whose last bit is even, as IEEE 754 does, whenever that nearest number is one a `Float` can hold;
   when it's too big for any `Float`, they stop with D177's check instead of giving infinity; and `/` by zero stops
   with D46's check. Every `Float` they give is a real number. *)
Theorem float_arithmetic_correct : forall operator (x y : float),
  is_finite x = true -> is_finite y = true ->
  match float_arithmetic operator x y with
  | Float_fits z =>
      is_finite z = true /\ B2R z = nearest (exact_result operator (B2R x) (B2R y))
      /\ (operator = Float_divide -> B2R y <> 0%R)
  | Float_too_big =>
      (operator = Float_divide -> B2R y <> 0%R)
      /\ (float_limit <= Rabs (nearest (exact_result operator (B2R x) (B2R y))))%R
  | Float_by_zero => operator = Float_divide /\ B2R y = 0%R
  | Float_negative_root => False
  end.
Proof.
  intros operator x y Fx Fy.
  assert (Done : forall z r, (operator = Float_divide -> B2R y <> 0%R) ->
            (if Rlt_bool (Rabs (nearest r)) float_limit then B2R z = nearest r /\ is_finite z = true
             else is_finite z = false) ->
            match keep_finite z with
            | Float_fits w => is_finite w = true /\ B2R w = nearest r /\ (operator = Float_divide -> B2R y <> 0%R)
            | Float_too_big => (operator = Float_divide -> B2R y <> 0%R) /\ (float_limit <= Rabs (nearest r))%R
            | Float_by_zero => operator = Float_divide /\ B2R y = 0%R
            | Float_negative_root => False
            end).
  { intros z r D H. pose proof (keep_finite_spec z r H) as K. destruct (keep_finite z); try contradiction.
    - destruct K as [K1 K2]. split; [exact K1 | split; [exact K2 | exact D]].
    - split; [exact D | exact K]. }
  destruct operator; simpl.
  - apply Done; [discriminate |]. pose proof (Bplus_correct 53 1024 _ _ mode_NE x y Fx Fy) as C. from_flocq C.
  - apply Done; [discriminate |]. pose proof (Bminus_correct 53 1024 _ _ mode_NE x y Fx Fy) as C. from_flocq C.
  - apply Done; [discriminate |]. pose proof (Bmult_correct 53 1024 _ _ mode_NE x y) as C.
    rewrite Fx, Fy in C. from_flocq C.
  - destruct (is_zero y) eqn:Z.
    + split; [reflexivity | apply is_zero_B2R; assumption].
    + assert (N : B2R y <> 0%R).
      { intros E. apply is_zero_B2R in E; [| exact Fy]. rewrite E in Z. discriminate. }
      apply Done; [intros _; exact N |]. pose proof (Bdiv_correct 53 1024 _ _ mode_NE x y N) as C.
      rewrite Fx in C. from_flocq C.
Qed.

(* THEOREM: `sqrt` is correctly rounded.
   In plain words: for any `Float` that isn't negative, `sqrt` gives the `Float` nearest its exact square root, a tie
   going to the even last bit; for a negative one it stops with D185's check, since its square root isn't a real
   number. *)
Theorem float_sqrt_correct : forall x : float, is_finite x = true ->
  match float_sqrt x with
  | Float_fits z => is_finite z = true /\ B2R z = nearest (sqrt (B2R x)) /\ (0 <= B2R x)%R
  | Float_negative_root => (B2R x < 0)%R
  | _ => False
  end.
Proof.
  intros x F. pose proof (Bsqrt_correct 53 1024 _ _ mode_NE x) as [C1 [C2 _]].
  destruct x as [s | s | | s m e B]; simpl in F; try discriminate.
  - change (float_sqrt (B754_zero s)) with (keep_finite (Bsqrt mode_NE (B754_zero s))). unfold keep_finite.
    rewrite C2. split; [exact C2 | split; [exact C1 |]]. simpl. lra.
  - destruct s.
    + simpl. apply F2R_lt_0. simpl. lia.
    + change (float_sqrt (B754_finite false m e B)) with (keep_finite (Bsqrt mode_NE (B754_finite false m e B))).
      unfold keep_finite. rewrite C2. split; [exact C2 | split; [exact C1 |]].
      apply F2R_ge_0. simpl. lia.
Qed.

(* ---------------------------------------------------------------------------------------------------------------- *)
(* `be.Whole` on a `Float` (D178) and `be.Float` on a `Whole` (D162) *)

Inductive to_whole := Whole_floor | Whole_trunc | Whole_ceil | Whole_nearest | Whole_nearest_even.

(* A finite `Float`'s exact value as a fraction [numerator / denominator], the denominator a power of 2 and positive. *)
Definition fraction (x : float) : Z * Z :=
  match x with
  | B754_finite s m e _ =>
      if 0 <=? e then (cond_Zopp s (Zpos m) * 2 ^ e, 1) else (cond_Zopp s (Zpos m), 2 ^ (- e))
  | _ => (0, 1)
  end.

(* trace: D178. Rounds [n / d], [d] positive, to a whole number the way [way] says. *)
Definition round_fraction (way : to_whole) (n d : Z) : Z :=
  let down := Z.div n d in
  let left := n - down * d in
  match way with
  | Whole_floor => down
  | Whole_ceil => if left =? 0 then down else down + 1
  | Whole_trunc => Z.quot n d
  | Whole_nearest | Whole_nearest_even =>
      match Z.compare (2 * left) d with
      | Lt => down
      | Gt => down + 1
      | Eq =>
          match way with
          | Whole_nearest => if 0 <=? down then down + 1 else down
          | _ => if Z.even down then down else down + 1
          end
      end
  end.

(* trace: D46, D178. [None] when the whole number is too big or too small for a `Whole`. *)
Definition float_to_whole (way : to_whole) (x : float) : option Z :=
  let (n, d) := fraction x in
  let w := round_fraction way n d in
  if (whole_minimum <=? w) && (w <=? whole_maximum) then Some w else None.

(* The whole number each way gives for a real number, as Flocq names them. *)
Definition rounding (way : to_whole) (r : R) : Z :=
  match way with
  | Whole_floor => Zfloor r
  | Whole_trunc => Ztrunc r
  | Whole_ceil => Zceil r
  | Whole_nearest => ZnearestA r
  | Whole_nearest_even => ZnearestE r
  end.

(* trace: D162. A whole number as the nearest `Float`; every `Whole` fits, so it never stops. *)
Definition float_of_whole (n : Z) : float := binary_normalize 53 1024 _ _ mode_NE n 0 false.

(* ---------------------------------------------------------------------------------------------------------------- *)
(* Reading a number written with a point (D155, D180) *)

(* The nearest `Float` to [n / d], [n] at least 0 and [d] positive, or [None] if it's too big for one. It works out
   enough bits of the quotient that what's left over can only push the rounding one way, keeps one more bit saying
   whether anything is left over, and lets Flocq's [binary_normalize] round that exactly. *)
Definition float_of_fraction (n d : Z) : option float :=
  let shift := Z.max 0 (Z.log2 d - Z.log2 n + 64) in
  let scaled := n * 2 ^ shift in
  let q := Z.div scaled d in
  let r := Z.modulo scaled d in
  let sticky := 2 * q + (if r =? 0 then 0 else 1) in
  let f := binary_normalize 53 1024 _ _ mode_NE sticky (- shift - 1) false in
  if is_finite f then Some f else None.

(* A decimal number's digits as a whole number, with how many came after the point. *)
Definition decimal_value (before after : string) : option (Z * Z) :=
  match whole_of_literal (before ++ after)%string with
  | Some n => Some (n, Z.of_nat (String.length after))
  | None => None
  end.

(* trace: D155, D180. A number written with a point: the nearest `Float`, and whether it's exactly that. *)
Definition float_of_decimal (before after : string) : option (float * bool) :=
  match decimal_value before after with
  | Some (n, places) =>
      match float_of_fraction n (10 ^ places) with
      | Some f =>
          let (fn, fd) := fraction f in
          Some (f, Z.eqb (fn * 10 ^ places) (n * fd))
      | None => None
      end
  | None => None
  end.

(* ---------------------------------------------------------------------------------------------------------------- *)
(* Showing a `Float` (D155, D175, D176, D181, D182, D183) *)

Open Scope string_scope.

Fixpoint digits_of (steps : nat) (n : Z) (rest : string) : string :=
  match steps with
  | O => rest
  | S steps' =>
      let rest' := String (ascii_of_nat (48 + Z.to_nat (n mod 10))) rest in
      if (n <? 10)%Z then rest' else digits_of steps' (n / 10) rest'
  end.

(* A whole number's digits, with no sign. *)
Definition digits (n : Z) : string := digits_of (S (Z.to_nat (Z.log2 (Z.abs n)))) (Z.abs n) "".

Definition zeros (count : Z) : string := String.concat "" (List.repeat "0" (Z.to_nat count)).

(* [n / 10^k] written out in full, with no `e` notation and no sign: at least one digit before the point, and none
   after it when [k] is 0 or less. *)
Definition decimal_text (n k : Z) : string :=
  let ds := digits n in
  let len := Z.of_nat (String.length ds) in
  if (k <=? 0)%Z then ds ++ zeros (- k)
  else if (len <=? k)%Z then "0." ++ zeros (k - len) ++ ds
  else substring 0 (Z.to_nat (len - k)) ds ++ "." ++ substring (Z.to_nat (len - k)) (Z.to_nat k) ds.

(* [n / d] rounded to the nearest whole number, a tie going to the even one, [n] and [d] positive. *)
Definition round_even (n d : Z) : Z := round_fraction Whole_nearest_even n d.

(* The power of ten just at or below [n / d], [n] and [d] positive: [10^t <= n / d < 10^(t+1)]. *)
Fixpoint ten_power_steps (steps : nat) (t n d : Z) : Z :=
  match steps with
  | O => t
  | S steps' =>
      let low := if (0 <=? t)%Z then (10 ^ t * d <=? n)%Z else (d <=? n * 10 ^ (- t))%Z in
      let high := if (0 <=? t + 1)%Z then (n <? 10 ^ (t + 1) * d)%Z else (n * 10 ^ (- t - 1) <? d)%Z in
      if low && high then t else if low then ten_power_steps steps' (t + 1) n d else ten_power_steps steps' (t - 1) n d
  end.

(* A first guess from the bits, then a few steps to be exact. *)
Definition ten_power (n d : Z) : Z :=
  let guess := ((Z.log2 n - Z.log2 d) * 3 / 10)%Z in
  ten_power_steps 1000 guess n d.

(* The shortest decimal that reads back as the same `Float`, as [(digits, k)] meaning [digits / 10^k], for a positive
   [n / d]: for each count of significant digits from 1, the nearest decimal with that many, until one reads back
   (D155). The nearest one with the fewest digits is the one Python's `repr` gives. *)
Fixpoint shortest_steps (steps : nat) (count : Z) (x : float) (n d t : Z) : Z * Z :=
  match steps with
  | O => (0, 0)
  | S steps' =>
      (* The decimal's last digit is at 10^(t - count + 1); [k] is how many places after the point that is. *)
      let k := (count - 1 - t)%Z in
      let candidate := if (0 <=? k)%Z then round_even (n * 10 ^ k) d else round_even n (d * 10 ^ (- k)) in
      let back := if (0 <=? k)%Z then float_of_fraction candidate (10 ^ k)
                  else float_of_fraction (candidate * 10 ^ (- k)) 1 in
      match back with
      | Some y => if Beqb (Babs x) y then (candidate, k) else shortest_steps steps' (count + 1) x n d t
      | None => shortest_steps steps' (count + 1) x n d t
      end
  end.

(* trace: D155, D181, D182, D183. A `Float` as text: the shortest decimal that reads back as it, written out in full,
   with `.0` when it has no fraction, and `~` in front when it isn't exactly the stored value. Negative zero shows as
   `0.0`. [None] for a negative value shown with `~`: where the `~` goes on a negative number isn't decided. *)
Definition text_of_float (x : float) : option string :=
  let (n, d) := fraction x in
  if (n =? 0)%Z then Some "0.0"
  else
    let a := Z.abs n in
    let '(shown, k) := shortest_steps 30 1 x a d (ten_power a d) in
    let body := decimal_text shown k in
    let body := if (k <=? 0)%Z then body ++ ".0" else body in
    let exact := if (0 <=? k)%Z then Z.eqb (shown * d) (a * 10 ^ k) else Z.eqb (shown * 10 ^ (- k) * d) a in
    if exact then Some (if (n <? 0)%Z then "-" ++ body else body)
    else if (n <? 0)%Z then None
    else Some ("~" ++ body).

(* trace: D175, D176, D178. A `Float` rounded to [places] digits after the point, a tie going away from zero, always
   showing that many, and with no minus when it rounds to zero. *)
Definition text_with_places (x : float) (places : Z) : string :=
  let (n, d) := fraction x in
  let a := Z.abs n in
  let rounded := round_fraction Whole_nearest (a * 10 ^ places) d in
  let body := decimal_text rounded places in
  if (n <? 0)%Z && negb (rounded =? 0)%Z then "-" ++ body else body.
