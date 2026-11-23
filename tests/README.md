# Unio's tests

The contract `Beta++` and Ralph are built to pass (D12). Each test is written by hand from the standard,
and names the decisions it checks.

## A test

Each test is a folder named after its main decision, as in `d16_if/`:

| File | What it holds |
|---|---|
| `program.unio` | the program |
| `about.txt` | one line: what it checks, with its decisions and standard chapters |
| `expected.out` | exactly what the program writes to standard output |
| `expected.status` | the exit status (D56), as a number |
| `input.txt` | optional: what's typed, fed to standard input |
| `expected.err` | optional: exactly what's written to standard error, for messages |
| `expected-final.err` | optional: standard error in `--final`, only where it differs from `expected.err`, as D46's float check does |
| `check.py` | optional: the same calculation in Python, confirming `expected.out` (D12) |

A test passes when, run as

```
cd tests/NAME
unio run program.unio --working < input.txt
```

from inside the test's own folder, so a message names the file as `program.unio` (with no input when there's no
`input.txt`), its standard output, standard error and exit status match the expected
files exactly. `Beta++`'s own messages go to standard error. The same test run with `--final` matches the same files, except that
standard error matches `expected-final.err` where the test has one. Only D46's float check can need one: in `final` it
names the procedure or loop, where `working` names the exact line. Everything else is the same in both modes. Once Ralph exists, every test runs on
`unio oracle` too, with the same expected files (D50).

A `check.py` runs with `python3 -I check.py` from the test's folder, and exits with status 0 when `expected.out`
matches its own calculation.

## Rules

- **Expected files come from the standard,** never from what an implementation happens to print.
- **A building session never edits an expected file.** A test that looks wrong goes back to the design session, which
  checks it against the standard and asks Tankun where the standard is unclear (D12).
- **Refusals get tests once their wording is decided.** Each message's wording is a decision of its own (D54), so a
  building session drafts it and the design session brings it to Tankun.
- **Where something isn't decided,** the implementation stops with `NotDesignedYet` (D56), and a test for that comes
  only once it's decided.
