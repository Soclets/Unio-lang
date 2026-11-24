(* Prints Ralph's own answers for reading and showing many `Float`s, for floats_check.py to compare with Python's
   `repr` and `decimal` (D155, D175, D176, D178, D181, D182, D183). These parts of Ralph's core aren't proven yet, so
   they're tested hard instead. Each line is one case, its fields separated by `|`. *)

module Core = Ralph_core.Core

let places = List.filter_map (fun p -> Core.whole_of_literal (string_of_int p)) [ 0; 1; 2; 3; 5 ]

let random_digits count = String.init count (fun i -> Char.chr (48 + if i = 0 then 1 + Random.int 9 else Random.int 10))

let shown f = match Core.text_of_float f with Some t -> t | None -> "UNDECIDED"

let case before after =
  match Core.float_of_decimal before after with
  | None -> Printf.printf "read|%s.%s|TOO_BIG\n" before after
  | Some (f, exact) ->
      Printf.printf "read|%s.%s|%s|%b|%s\n" before after (shown f) exact
        (String.concat "|" (List.map (fun p -> Core.text_with_places f p) places))

let operation_name = function
  | Core.Float_plus -> "+"
  | Core.Float_minus -> "-"
  | Core.Float_times -> "*"
  | Core.Float_divide -> "/"

let () =
  Random.init 2026;
  let read () =
    let before = if Random.int 4 = 0 then "0" else random_digits (1 + Random.int 18) in
    let after = if Random.int 5 = 0 then "0" else String.init (1 + Random.int 22) (fun _ -> Char.chr (48 + Random.int 10)) in
    (before, after)
  in
  for _ = 1 to 6000 do
    let before, after = read () in
    case before after
  done;
  (* Small and large ones, past what most programs write. *)
  List.iter
    (fun (b, a) -> case b a)
    [ ("0", "00000000000000000000000000000000000000000000000000000000000000000000000000000001"); ("0", "1"); ("0", "2");
      ("0", "3"); ("1", "0"); ("9007199254740993", "0"); ("123456789012345678901234567890", "5");
      ("0", "000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004940656458412465441765687928682213723651") ];
  for _ = 1 to 4000 do
    let b1, a1 = read () and b2, a2 = read () in
    match (Core.float_of_decimal b1 a1, Core.float_of_decimal b2 a2) with
    | Some (x, _), Some (y, _) ->
        List.iter
          (fun op ->
            match Core.float_arithmetic op x y with
            | Core.Float_fits z ->
                Printf.printf "maths|%s.%s|%s|%s.%s|%s|%s\n" b1 a1 (operation_name op) b2 a2 (shown z)
                  (String.concat "|" (List.map (fun p -> Core.text_with_places z p) places))
            | Core.Float_too_big -> Printf.printf "maths|%s.%s|%s|%s.%s|TOO_BIG\n" b1 a1 (operation_name op) b2 a2
            | Core.Float_by_zero -> Printf.printf "maths|%s.%s|%s|%s.%s|BY_ZERO\n" b1 a1 (operation_name op) b2 a2
            | Core.Float_negative_root -> ())
          [ Core.Float_plus; Core.Float_minus; Core.Float_times; Core.Float_divide ]
    | _ -> ()
  done
