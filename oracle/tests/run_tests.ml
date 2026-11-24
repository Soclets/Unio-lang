(* Ralph's test runner.

   Runs every test in the repository's tests/ folder as tests/README.md describes: from inside the test's own folder,
   as `ralph program.unio`, with input.txt (or nothing) on standard input, and compares standard output, standard
   error and the exit status with the expected files byte for byte. Runs each check.py with `python3 -I check.py`.
   Checks that every main theorem's `Print Assumptions` shows nothing outside the trusted list. Writes the result to
   oracle/test-status.json, so a fresh context sees at once where things stand. *)

let seconds_allowed = 10.0

type outcome = { standard_output : string; standard_error : string; status : int }

let read_file path =
  match In_channel.with_open_bin path In_channel.input_all with
  | contents -> Ok contents
  | exception Sys_error message -> Error message

let write_file path contents =
  match
    Out_channel.with_open_bin path (fun channel -> Out_channel.output_string channel contents)
  with
  | () -> Ok ()
  | exception Sys_error message -> Error message

let temporary_file suffix =
  match Filename.temp_file "ralph-test-" suffix with
  | path -> Ok path
  | exception Sys_error message -> Error message

let unix_result f =
  match f () with
  | value -> Ok value
  | exception Unix.Unix_error (error, call, _) -> Error (call ^ ": " ^ Unix.error_message error)

(* Waits for the child, killing it once it has run longer than [seconds_allowed]. *)
let rec wait_for child started =
  match Unix.waitpid [ Unix.WNOHANG ] child with
  | 0, _ ->
      if Unix.gettimeofday () -. started > seconds_allowed then begin
        Unix.kill child Sys.sigkill;
        let _ = Unix.waitpid [] child in
        Error "timed out"
      end
      else begin
        Unix.sleepf 0.01;
        wait_for child started
      end
  | _, Unix.WEXITED code -> Ok code
  | _, Unix.WSIGNALED signal -> Error (Printf.sprintf "killed by signal %d" signal)
  | _, Unix.WSTOPPED signal -> Error (Printf.sprintf "stopped by signal %d" signal)

(* Runs [program] with [arguments] inside [folder], with [input] as standard input. *)
let run_in folder program arguments input =
  let ( let* ) = Result.bind in
  let* output_path = temporary_file ".out" in
  let* error_path = temporary_file ".err" in
  let* code =
    unix_result (fun () ->
        let input_descriptor = Unix.openfile input [ Unix.O_RDONLY ] 0 in
        let output_descriptor = Unix.openfile output_path [ Unix.O_WRONLY; Unix.O_TRUNC ] 0 in
        let error_descriptor = Unix.openfile error_path [ Unix.O_WRONLY; Unix.O_TRUNC ] 0 in
        match Unix.fork () with
        | 0 -> (
            match
              Unix.chdir folder;
              Unix.dup2 input_descriptor Unix.stdin;
              Unix.dup2 output_descriptor Unix.stdout;
              Unix.dup2 error_descriptor Unix.stderr;
              Unix.execv program (Array.of_list (program :: arguments))
            with
            | _ -> Unix._exit 127
            | exception Unix.Unix_error _ -> Unix._exit 127)
        | child ->
            Unix.close input_descriptor;
            Unix.close output_descriptor;
            Unix.close error_descriptor;
            wait_for child (Unix.gettimeofday ()))
  in
  let* code = code in
  let* standard_output = read_file output_path in
  let* standard_error = read_file error_path in
  let _ = unix_result (fun () -> Unix.unlink output_path) in
  let _ = unix_result (fun () -> Unix.unlink error_path) in
  Ok { standard_output; standard_error; status = code }

let first_difference expected actual =
  let length = min (String.length expected) (String.length actual) in
  let rec find index =
    if index >= length then length
    else if expected.[index] = actual.[index] then find (index + 1)
    else index
  in
  find 0

(* Shows where two texts first differ, with a little of each around that place. *)
let describe_difference what expected actual =
  let at = first_difference expected actual in
  let around text =
    let start = max 0 (at - 40) in
    let stop = min (String.length text) (at + 40) in
    String.escaped (String.sub text start (stop - start))
  in
  Printf.sprintf "%s differs at byte %d:\n      expected: %s\n      got:      %s" what at
    (around expected) (around actual)

let optional_file path = if Sys.file_exists path then read_file path else Ok ""

type verdict = Pass | Fail of string list

let check_test ralph folder =
  let ( let* ) = Result.bind in
  let file name = Filename.concat folder name in
  let input = if Sys.file_exists (file "input.txt") then file "input.txt" else "/dev/null" in
  let* expected_output = read_file (file "expected.out") in
  let* expected_error = optional_file (file "expected.err") in
  let* expected_status_text = read_file (file "expected.status") in
  let* expected_status =
    match int_of_string_opt (String.trim expected_status_text) with
    | Some status -> Ok status
    | None -> Error "expected.status isn't a number"
  in
  let* outcome = run_in folder ralph [ "program.unio" ] input in
  let problems =
    List.concat
      [
        (if outcome.standard_output = expected_output then []
         else [ describe_difference "standard output" expected_output outcome.standard_output ]);
        (if outcome.standard_error = expected_error then []
         else [ describe_difference "standard error" expected_error outcome.standard_error ]);
        (if outcome.status = expected_status then []
         else [ Printf.sprintf "exit status: expected %d, got %d" expected_status outcome.status ]);
      ]
  in
  let* python_problems =
    if Sys.file_exists (file "check.py") then
      let* python = run_in folder "/usr/bin/env" [ "python3"; "-I"; "check.py" ] "/dev/null" in
      Ok
        (if python.status = 0 then []
         else [ "check.py failed: " ^ String.trim python.standard_error ])
    else Ok []
  in
  Ok (match problems @ python_problems with [] -> Pass | problems -> Fail problems)

(* trace: D189. Every theorem in the captured `Print Assumptions` output rests on nothing, or only on the axioms listed
   in assumptions/axioms.txt, each with its reason there (Building rule 14). *)
let check_assumptions path believed_path =
  match (read_file path, read_file believed_path) with
  | Error message, _ | _, Error message -> Fail [ message ]
  | Ok text, Ok believed_text ->
      let believed =
        List.filter
          (fun line -> line <> "" && line.[0] <> '#')
          (List.map String.trim (String.split_on_char '\n' believed_text))
      in
      let lines = List.filter (fun line -> String.trim line <> "") (String.split_on_char '\n' text) in
      let unexpected =
        List.filter
          (fun line ->
            if line = "Closed under the global context" || line = "Axioms:" then false
            else if line.[0] = ' ' then false
            else
              match String.index_opt line ' ' with
              | Some i -> not (List.mem (String.sub line 0 i) believed)
              | None -> true)
          lines
      in
      if lines = [] then Fail [ "no theorems were checked" ]
      else if unexpected = [] then Pass
      else Fail (List.map (fun line -> "not on the list of believed axioms: " ^ line) unexpected)

let json_string text =
  let buffer = Buffer.create (String.length text + 2) in
  Buffer.add_char buffer '"';
  String.iter
    (fun character ->
      match character with
      | '"' -> Buffer.add_string buffer "\\\""
      | '\\' -> Buffer.add_string buffer "\\\\"
      | '\n' -> Buffer.add_string buffer "\\n"
      | character when Char.code character < 0x20 ->
          Buffer.add_string buffer (Printf.sprintf "\\u%04x" (Char.code character))
      | character -> Buffer.add_char buffer character)
    text;
  Buffer.add_char buffer '"';
  Buffer.contents buffer

let json_of_verdict = function
  | Pass -> "{ \"status\": \"pass\" }"
  | Fail problems ->
      Printf.sprintf "{ \"status\": \"fail\", \"problems\": [%s] }"
        (String.concat ", " (List.map json_string problems))

let () =
  match Sys.argv with
  | [| _; ralph; assumptions; believed |] -> (
      let source_root =
        match Sys.getenv_opt "DUNE_SOURCEROOT" with Some root -> root | None -> Sys.getcwd ()
      in
      let tests_folder = Filename.concat (Filename.dirname source_root) "tests" in
      let ralph =
        if Filename.is_relative ralph then Filename.concat (Sys.getcwd ()) ralph else ralph
      in
      match Sys.readdir tests_folder with
      | exception Sys_error message ->
          prerr_endline ("can't read the tests: " ^ message);
          exit 1
      | names ->
          let names =
            List.sort compare
              (List.filter
                 (fun name -> Sys.is_directory (Filename.concat tests_folder name))
                 (Array.to_list names))
          in
          let results =
            List.map
              (fun name ->
                let verdict =
                  match check_test ralph (Filename.concat tests_folder name) with
                  | Ok verdict -> verdict
                  | Error message -> Fail [ "couldn't run: " ^ message ]
                in
                (name, verdict))
              names
          in
          let assumptions_verdict = check_assumptions assumptions believed in
          let passed = List.length (List.filter (fun (_, verdict) -> verdict = Pass) results) in
          let failed = List.length results - passed in
          List.iter
            (fun (name, verdict) ->
              match verdict with
              | Pass -> Printf.printf "pass  %s\n" name
              | Fail problems ->
                  Printf.printf "FAIL  %s\n" name;
                  List.iter (fun problem -> Printf.printf "    %s\n" problem) problems)
            results;
          (match assumptions_verdict with
          | Pass -> print_endline "pass  Print Assumptions: every main theorem rests on nothing beyond assumptions/axioms.txt"
          | Fail problems ->
              print_endline "FAIL  Print Assumptions";
              List.iter (fun problem -> Printf.printf "    %s\n" problem) problems);
          Printf.printf "%d of %d tests pass\n" passed (List.length results);
          let json =
            Printf.sprintf
              "{\n\
              \  \"passed\": %d,\n\
              \  \"failed\": %d,\n\
              \  \"assumptions\": %s,\n\
              \  \"tests\": {\n\
               %s\n\
              \  }\n\
               }\n"
              passed failed
              (json_of_verdict assumptions_verdict)
              (String.concat ",\n"
                 (List.map
                    (fun (name, verdict) ->
                      Printf.sprintf "    %s: %s" (json_string name) (json_of_verdict verdict))
                    results))
          in
          (match write_file (Filename.concat source_root "test-status.json") json with
          | Ok () -> ()
          | Error message -> prerr_endline ("can't write test-status.json: " ^ message));
          exit (if failed = 0 && assumptions_verdict = Pass then 0 else 1))
  | _ ->
      prerr_endline "usage: run_tests RALPH ASSUMPTIONS";
      exit 2
