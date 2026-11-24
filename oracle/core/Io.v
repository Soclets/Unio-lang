(* How the pure core asks for input and output.

   The evaluator never prints or reads by itself. It gives back a tree of requests: "show this text", "I need a line
   of input", "I need a random number from low to high", each holding what to do next with the answer. The shell
   (shell/ralph.ml) walks the tree and does the real printing, reading and random numbers, so everything in Rocq stays
   pure and provable. *)

From Stdlib Require Import String ZArith.
From Ralph Require Import Syntax Whole Float.

(* Why a program stopped before reaching its end. *)
Inductive arithmetic_operation :=
| Operation_binary (a : Z) (operator : arithmetic) (b : Z)
| Operation_negate (a : Z).

Inductive stop :=
(* D46's overflow check failed, at a place, with the values that broke it (D92). *)
| Overflow (at_ : place) (too_big : bool) (operation : arithmetic_operation)
(* trace: D154. Calls nested too deep: how deep, and the procedure the call that went too deep is in. *)
| Calls_too_deep (at_ : place) (depth : nat) (inside : string)
(* `ask` found no more input: the program ends quietly with status 0 (D96). *)
| Input_ended
(* trace: D70, D71, D72. Dividing stopped: by zero, not exactly with `/`, or a quotient too big, with the values. *)
| Division_stopped (at_ : place) (why : divided) (way : division) (a b : Z)
(* trace: D46, D75. An item reached at a position the list doesn't have: the position as written, counted from 1 or
   0, and how many items the list holds. *)
| Bad_position (at_ : place) (index : Z) (from_one : bool) (length : Z)
(* trace: D172. A `range` that can never reach its end: its first number, its end, whether that's included, and its
   step. *)
| Range_never_ends (at_ : place) (first last : Z) (included : bool) (step : Z)
(* trace: D46, D177, D185. A `Float` operation stopped: too big for a `Float`, dividing by zero, or `sqrt` of a negative
   number; the operation ([None] for `sqrt`) and its values. *)
| Float_stopped (at_ : place) (why : float_checked) (operation : option float_operation) (x y : float)
(* trace: D178. `be.Whole.floor` and the rest given a `Float` too big for a `Whole`. *)
| Float_to_whole_too_big (at_ : place) (way : to_whole) (x : float)
(* Something not decided, found only while running: what it is, worded as D103 does. *)
| Undecided (at_ : place) (what : string)
(* trace: D152. `?? crash` met a failure: the procedure that failed and the failure. *)
| Crashed (at_ : place) (procedure failure : string)
(* trace: D23. `?` passing a failure up: it leaves the procedure, which gives it to its caller. Never the end of a
   run, since `proc.main` can't pass a failure up. *)
| Passing_up (failure : string)
(* trace: D160. `random` with `from:` above `to:`: a failed check, with both values. *)
| Random_backwards (at_ : place) (low high : Z)
(* The evaluator ran out of fuel, its step counter (see Evaluator.v). *)
| Out_of_fuel
(* The evaluator met something it has no rule for. The type-safety theorem says a program the checker accepts
   never reaches this. *)
| Stuck.

Inductive io (A : Type) : Type :=
| Done (result : A)
| Stop (reason : stop)
| Show (text : string) (ends_line : bool) (next : unit -> io A)
| Ask (question : string) (next : option string -> io A)
| Random (low high : Z) (next : Z -> io A).

Arguments Done {A}.
Arguments Stop {A}.
Arguments Show {A}.
Arguments Ask {A}.
Arguments Random {A}.

(* Does [m], then [k] with its result. *)
Fixpoint bind {A B : Type} (m : io A) (k : A -> io B) : io B :=
  match m with
  | Done a => k a
  | Stop reason => Stop reason
  | Show text ends_line next => Show text ends_line (fun u => bind (next u) k)
  | Ask question next => Ask question (fun answer => bind (next answer) k)
  | Random low high next => Random low high (fun n => bind (next n) k)
  end.

(* Turns a failure passing up into what [handler] makes of it, as a procedure's call does with its body (D23). *)
Fixpoint catch_failure {A : Type} (m : io A) (handler : string -> io A) : io A :=
  match m with
  | Done a => Done a
  | Stop (Passing_up failure) => handler failure
  | Stop reason => Stop reason
  | Show text ends_line next => Show text ends_line (fun u => catch_failure (next u) handler)
  | Ask question next => Ask question (fun answer => catch_failure (next answer) handler)
  | Random low high next => Random low high (fun n => catch_failure (next n) handler)
  end.

(* [safe_stopping fine P m]: however the input goes, and whatever random numbers come back, every way through [m]
   ends in a result satisfying [P], or a stop that's [fine]. Each way through the tree is finite, so this is an
   ordinary inductive definition. *)
Inductive safe_stopping {A : Type} (fine : stop -> Prop) (P : A -> Prop) : io A -> Prop :=
| safe_done : forall a, P a -> safe_stopping fine P (Done a)
| safe_stop : forall reason, fine reason -> safe_stopping fine P (Stop reason)
| safe_show : forall text ends_line next, safe_stopping fine P (next tt) -> safe_stopping fine P (Show text ends_line next)
| safe_ask : forall question next, (forall answer, safe_stopping fine P (next answer)) ->
    safe_stopping fine P (Ask question next)
| safe_random : forall low high next, (forall n, safe_stopping fine P (next n)) ->
    safe_stopping fine P (Random low high next).

(* [safe P m]: every way through [m] ends in a result satisfying [P], or a stop that isn't [Stuck]. *)
Definition safe {A : Type} (P : A -> Prop) (m : io A) : Prop := safe_stopping (fun reason => reason <> Stuck) P m.

Lemma safe_bind : forall (A B : Type) (fine : stop -> Prop) (P : A -> Prop) (Q : B -> Prop) (m : io A)
    (k : A -> io B),
  safe_stopping fine P m -> (forall a, P a -> safe_stopping fine Q (k a)) -> safe_stopping fine Q (bind m k).
Proof.
  intros A B fine P Q m k Hm Hk; induction Hm; simpl; try (apply Hk; assumption); constructor; auto.
Qed.

Lemma safe_weaken : forall (A : Type) (fine fine' : stop -> Prop) (P Q : A -> Prop) (m : io A),
  safe_stopping fine P m -> (forall a, P a -> Q a) -> (forall r, fine r -> fine' r) -> safe_stopping fine' Q m.
Proof.
  intros A fine fine' P Q m Hm HPQ Hf; induction Hm; constructor; auto.
Qed.

Lemma safe_catch : forall (A : Type) (fine fine' : stop -> Prop) (P : A -> Prop) (m : io A) handler,
  safe_stopping fine P m ->
  (forall r, fine r -> (forall f, r <> Passing_up f) -> fine' r) ->
  (forall f, fine (Passing_up f) -> safe_stopping fine' P (handler f)) ->
  safe_stopping fine' P (catch_failure m handler).
Proof.
  intros A fine fine' P m handler Hm Hf Hh; induction Hm; simpl.
  - constructor; assumption.
  - destruct reason; try (constructor; apply Hf; [assumption | discriminate]). apply Hh; assumption.
  - constructor; auto.
  - constructor; auto.
  - constructor; auto.
Qed.
