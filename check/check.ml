(* check/: runs random programs, and every test, on Ralph and Beta++ as black boxes, and reports where they differ
   (Building rule 12). Beta++ runs in both its modes, `--working` and `--final`. A difference is shrunk to the
   smallest program that still shows it. Neither implementation's source is read: only their programs are run.

   Beta++ is from before D190 to D203, so it's given each program in the spelling from before them (Printer), and
   messages are compared by their kind and line, since the source lines they quote are spelled differently. *)

let root = Filename.dirname (Sys.getcwd ())
let ralph = Filename.concat root "oracle/_build/default/shell/ralph.exe"
let beta = Filename.concat root "compiler/build/release/unio"

type run = { out : string; err : string; status : int }

let read_file path = try In_channel.with_open_bin path In_channel.input_all with Sys_error _ -> ""

(* Runs [command] in [dir] with [input] on standard input, for at most 20 seconds. *)
let execute dir command input =
  let out = Filename.concat dir "out.txt" and err = Filename.concat dir "err.txt" in
  let input_file = Filename.concat dir "input.txt" in
  Out_channel.with_open_bin input_file (fun oc -> output_string oc input);
  let shell =
    Printf.sprintf "cd %s && perl -e 'alarm 10; exec @ARGV' %s < input.txt > out.txt 2> err.txt" (Filename.quote dir)
      command
  in
  let status = match Unix.system shell with Unix.WEXITED n -> n | Unix.WSIGNALED _ | Unix.WSTOPPED _ -> 124 in
  { out = read_file out; err = read_file err; status }

(* The first line of each message: its kind and its line number, as in `refused 12`. *)
let message_heads err =
  List.filter_map
    (fun line ->
      let kinds = [ "refused: "; "check failed: "; "failed: "; "NotBuiltYet: "; "NotDesignedYet: "; "internal error:" ] in
      match List.find_opt (fun k -> String.starts_with ~prefix:k line) kinds with
      | Some kind ->
          let rest = String.sub line (String.length kind) (String.length line - String.length kind) in
          let line_number =
            match String.split_on_char ':' rest with _ :: n :: _ -> String.trim n | _ -> ""
          in
          Some (String.trim kind ^ " " ^ line_number)
      | None -> None)
    (String.split_on_char '\n' err)

(* How two runs differ, as words for the report, or [None] when they agree. *)
let differs (a : run) (b : run) =
  let parts =
    (if a.out <> b.out then [ "standard output" ] else [])
    @ (if a.status <> b.status then [ Printf.sprintf "status (%d against %d)" a.status b.status ] else [])
    @ if message_heads a.err <> message_heads b.err then [ "messages" ] else []
  in
  match parts with [] -> None | _ -> Some (String.concat ", " parts)

(* A run that can't be compared: something not built or not designed yet, on either side, or one too slow. *)
let not_comparable (r : run) =
  r.status = 3 || r.status = 124
  || List.exists
       (fun head -> String.starts_with ~prefix:"NotBuiltYet" head || String.starts_with ~prefix:"NotDesignedYet" head)
       (message_heads r.err)

type outcome = Same | Skipped of string | Different of string * run * run * run

let compare_program dir (p : Syntax.program) =
  let input = String.concat "" (List.map (fun l -> l ^ "\n") p.input) in
  Out_channel.with_open_bin (Filename.concat dir "program.unio") (fun oc ->
      output_string oc (Printer.program Printer.Current p));
  let r = execute dir (Filename.quote ralph ^ " program.unio") input in
  Out_channel.with_open_bin (Filename.concat dir "program.unio") (fun oc ->
      output_string oc (Printer.program Printer.Before_d190 p));
  let w = execute dir (Filename.quote beta ^ " run program.unio --working") input in
  let f = execute dir (Filename.quote beta ^ " run program.unio --final") input in
  if not_comparable r || not_comparable w || not_comparable f then Skipped "something not built, not designed or too slow"
  else
    match (differs r w, differs w f) with
    | None, None -> Same
    | Some how, _ -> Different ("Ralph and Beta++ --working differ in " ^ how, r, w, f)
    | None, Some how -> Different ("Beta++ --working and --final differ in " ^ how, r, w, f)

(* ---------------------------------------------------------------------------------------------------------------- *)
(* Shrinking: drop statements, one at a time, while the same difference stays. *)

let rec drop_each (items : 'a list) : 'a list list =
  match items with [] -> [] | x :: rest -> rest :: List.map (fun r -> x :: r) (drop_each rest)

let rec smaller_blocks (b : Syntax.statement list) : Syntax.statement list list =
  drop_each b
  @ List.concat
      (List.mapi
         (fun i s ->
           let replace with_ = List.mapi (fun j x -> if i = j then with_ else [ x ]) b |> List.concat in
           match (s : Syntax.statement) with
           | If (c, t, e) ->
               [ replace t ] @ (match e with Some e -> [ replace e ] | None -> [])
               @ List.map (fun t' -> replace [ Syntax.If (c, t', e) ]) (smaller_blocks t)
           | While (c, body) -> (
               (* A loop keeps its last line, the step that makes it end. *)
               match List.rev body with
               | step :: rest ->
                   List.map (fun body' -> replace [ Syntax.While (c, body' @ [ step ]) ]) (smaller_blocks (List.rev rest))
               | [] -> [])
           | _ -> [])
         b)

let smaller (p : Syntax.program) : Syntax.program list =
  List.map (fun main -> { p with main }) (smaller_blocks p.main)
  @ List.concat
      (List.mapi
         (fun i (proc : Syntax.procedure) ->
           List.map
             (fun body -> { p with procedures = List.mapi (fun j q -> if i = j then { proc with body } else q) p.procedures })
             (smaller_blocks proc.body))
         p.procedures)
  @ List.map (fun procedures -> { p with procedures }) (drop_each p.procedures)
  @ List.map (fun input -> { p with input }) (drop_each p.input)

let rec shrink dir (p : Syntax.program) (what : string) tries =
  if tries <= 0 then p
  else
    let rec first = function
      | [] -> None
      | candidate :: rest -> (
          match compare_program dir candidate with
          | Different (w, _, _, _) when w = what -> Some candidate
          | _ -> first rest)
    in
    match first (smaller p) with Some q -> shrink dir q what (tries - 1) | None -> p

(* ---------------------------------------------------------------------------------------------------------------- *)

let () =
  (* `check.exe show SEED` prints one program as Ralph reads it, and its input. *)
  if Array.length Sys.argv > 2 && Sys.argv.(1) = "show" then begin
    let p = Generator.program (int_of_string Sys.argv.(2)) in
    print_string (Printer.program Printer.Current p);
    exit 0
  end;
  (* `check.exe tests` runs every test in tests/ on Ralph and Beta++ in both modes, and says which match their
     expected files. Beta++ is from before D190, which the tests are written in, so its failures there aren't
     findings until it's brought up to date. *)
  if Array.length Sys.argv > 1 && Sys.argv.(1) = "tests" then begin
    let tests_dir = Filename.concat root "tests" in
    let names = List.sort compare (List.filter (fun n -> Sys.file_exists (Filename.concat (Filename.concat tests_dir n) "program.unio")) (Array.to_list (Sys.readdir tests_dir))) in
    let passes = Array.make 3 0 in
    List.iter
      (fun n ->
        let dir = Filename.concat tests_dir n in
        let input = read_file (Filename.concat dir "input.txt") in
        let expected =
          { out = read_file (Filename.concat dir "expected.out");
            err = read_file (Filename.concat dir "expected.err");
            status = (try int_of_string (String.trim (read_file (Filename.concat dir "expected.status"))) with Failure _ -> -1) }
        in
        let scratch = Filename.concat (Filename.get_temp_dir_name ()) ("unio-check-test-" ^ n) in
        (try Unix.mkdir scratch 0o755 with Unix.Unix_error _ -> ());
        Out_channel.with_open_bin (Filename.concat scratch "program.unio") (fun oc -> output_string oc (read_file (Filename.concat dir "program.unio")));
        let runs =
          [ execute scratch (Filename.quote ralph ^ " program.unio") input;
            execute scratch (Filename.quote beta ^ " run program.unio --working") input;
            execute scratch (Filename.quote beta ^ " run program.unio --final") input ]
        in
        let marks =
          List.mapi
            (fun i r ->
              let ok = r.out = expected.out && r.err = expected.err && r.status = expected.status in
              if ok then passes.(i) <- passes.(i) + 1;
              if ok then "pass" else "FAIL")
            runs
        in
        Printf.printf "%-40s Ralph %s   Beta++ --working %s   --final %s\n" n (List.nth marks 0) (List.nth marks 1) (List.nth marks 2))
      names;
    Printf.printf "\n%d tests: Ralph passes %d, Beta++ --working %d, Beta++ --final %d.\n" (List.length names) passes.(0) passes.(1) passes.(2);
    exit 0
  end;
  let count = if Array.length Sys.argv > 1 then int_of_string Sys.argv.(1) else 100 in
  let seed = if Array.length Sys.argv > 2 then int_of_string Sys.argv.(2) else 1 in
  let dir = Filename.concat (Filename.get_temp_dir_name ()) (Printf.sprintf "unio-check-%d" (Unix.getpid ())) in
  Unix.mkdir dir 0o755;
  let same = ref 0 and skipped = ref 0 and findings = ref [] in
  for i = 0 to count - 1 do
    let p = Generator.program (seed + i) in
    match compare_program dir p with
    | Same -> incr same
    | Skipped _ -> incr skipped
    | Different (what, _, _, _) ->
        let small = shrink dir p what 40 in
        let r, w =
          match compare_program dir small with
          | Different (_, r, w, _) -> (r, w)
          | _ -> ({ out = ""; err = ""; status = 0 }, { out = ""; err = ""; status = 0 })
        in
        findings := (seed + i, what, small, r, w) :: !findings
  done;
  let report = Buffer.create 4096 in
  Buffer.add_string report
    (Printf.sprintf "# check/ report\n\n%d random programs from seed %d: %d the same, %d skipped, %d different.\n\n"
       count seed !same !skipped (List.length !findings));
  List.iter
    (fun (s, what, p, r, w) ->
      Buffer.add_string report
        (Printf.sprintf "## Seed %d: %s\n\nThe program, as Ralph reads it:\n\n```\n%s```\n\nAs Beta++ reads it:\n\n```\n%s```\n\nInput: %S\n\nRalph: status %d, output %S, messages %S\n\nBeta++ --working: status %d, output %S, messages %S\n\n"
           s what (Printer.program Printer.Current p) (Printer.program Printer.Before_d190 p)
           (String.concat "\\n" p.input) r.status r.out (String.concat "; " (message_heads r.err)) w.status w.out
           (String.concat "; " (message_heads w.err))))
    (List.rev !findings);
  print_string (Buffer.contents report);
  Out_channel.with_open_bin "report.md" (fun oc -> output_string oc (Buffer.contents report))
