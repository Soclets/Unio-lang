# Ralph, the oracle: progress

Ralph is Unio's reference implementation (D129, D139, D140, D141). This file is where the oracle session keeps its
plan, where things stand, and its open questions, so a fresh context can carry on from it, `test-status.json` and
`git log`.

## The one command

```
cd oracle && opam exec --switch=ralph -- dune build @check -j 3
```

It builds the Rocq core (checking every proof), extracts it to OCaml, builds the shell and the test runner, checks
`Print Assumptions` for every main theorem against `assumptions/axioms.txt`, runs every test in `../tests`, writes
`test-status.json`, and tests reading and showing `Float`s against Python on 22,008 cases.

`check/`'s command: `cd check && opam exec --switch=ralph -- dune exec ./check.exe -- 300 1000` compares 300 random
programs from seed 1000 on Ralph and Beta++ in both modes and writes `check/report.md`; `./check.exe tests` runs every
test on all three; `./check.exe show SEED` prints one generated program.

To run a program by hand: `opam exec --switch=ralph -- dune exec --root oracle -- ralph PROGRAM.unio`, or the built
`oracle/_build/default/shell/ralph.exe PROGRAM.unio`.

**Placeholder:** Ralph's own program is called `ralph` and takes one file, `ralph program.unio`. It stands in for
`unio run program.unio --working` in the tests, and later for what `unio oracle` forwards to (D50).

## Pinned versions (Building rule 14)

- opam switch `ralph`
- OCaml 5.5.2
- The Rocq Prover 9.3.0, with rocq-stdlib 9.2.0
- dune 3.25.0, menhir 20260209, ocamlformat 0.29.0

## Layout

| Folder | What | Language |
|---|---|---|
| `core/` | Unio's meaning: syntax tree, values, `Whole` arithmetic, checker, evaluator, and the proofs | Rocq |
| `extraction/` | turns `core/` into OCaml (`Extract.v`), and the list of trusted extraction mappings | Rocq |
| `assumptions/` | `Print Assumptions` for every main theorem, captured to a file the test runner checks | Rocq |
| `shell/` | reading the file, lexer, parser, message wording and layout, exit statuses, printing, input, random | OCaml |
| `tests/` | the test runner | OCaml |

### Where each refusal lives

- **Shell (OCaml), how text is written:** `;` and `:`, closers, indentation, blank lines, spacing, quotes, a name's
  spelling (D99), `=` in a condition, chains of comparisons. These are found while reading the text, before there's
  a syntax tree.
- **Core (Rocq), what the program means:** names and scopes, types, `let` and `var`, labels, calls, `return`,
  `break`, slides, `.fmt` braces, failures, and the program's shape. The core gives back each refusal as data; the
  shell only words it (D54).

## Plan for all of Unio (from 2026-11-24)

The job: build every decision, D1 to D203, except `extern.cpp`'s C++ bodies, build modes and speed, colours and fonts,
and what the standard marks Not decided (which stops with `NotDesignedYet`). Done when every test passes, the proofs
below hold with nothing in `Print Assumptions` beyond the axioms file, and `check/` compares Ralph with `Beta++`.

Each checkpoint ends with something running, committed and pushed.

1. [x] **The new spellings (D187, D190 to D203)**, built together with checkpoint 2: names with no `$` (D192), keywords and
   built-ins (D196), opening lines with no `:` (D199), `-> Type` and `! [ … ]` (D190), `eq` and `not_eq`, `labels [ … ]`
   (D195), every text filling its braces, a `Bool` included, with `\{` (D200, D202), no `&` (D201), conditions must be
   `Bool`s (D187). Every test the first milestone passed passes again (37 of 53 on 2026-11-24).
2. [x] **A typed tree for the core.** The checker gives back, with its refusals, the program as a typed tree: names
   resolved, labels put in order, slides turned into calls, text's braces into joins. A small second type checker reads
   that tree, and the evaluator runs it. Type safety is re-proven on the typed tree, which keeps the proof the size of
   the language rather than the size of its messages. The same tests pass.
3. [x] **Lists, arrays and loops:** `List<T>`, `List<T>[len.max: n]`, `Array<T>[len: n]`, `[ … ]`, `[]`, `[all: v]`,
   `pos:` and `offset:`, `.len`, `.add`, `.remove`, setting an item, `range[…]` with `step_by:`, `for each` with
   `at pos` and `at offset`, and D173. `/`, `div.floor`, `div.trunc`, `rem.floor`, `rem.trunc` (D70, D71, D72), with
   their checks. Proved: type safety for all of it; dividing and remainders exact.
4. [x] **Failures in full:** done with checkpoint 3: `! [ … ]` in headers, `?`, `?? value`, `?? ignore`, `?? crash`
   (D152, status 5), `otherwise` with `case` and `instead`, D186. Left: handler families, `include`, handler parameters, `.*`; procedure
   families (`fam.proc`, D41); comments (`//`, `///`, `comment` blocks, D74).
5. [x] **Floats** (all but the proof of D178's roundings, still to do): `Float`, literals with `~` (D155, D180), `+ - * /` and `sqrt` with D177's check, comparisons and
   D184, `be.Float`, `be.Whole.floor`/`.trunc`/`.ceil`/`.nearest`/`.nearest.even` (D178), `be.Text` of a `Float`
   (D155, D181 to D183), `places:` (D175, D176). Proved with Flocq: each operation gives the nearest `Float`, ties to
   even, or stops; each rounding to `Whole` gives D178's number or stops.
6. [x] **Every other decided refusal,** with drafted wordings sent to the design session in batches.
7. [x] **`check/`:** a generator written from `standard/`, one printer, a list of what it doesn't generate yet, and a
   comparison of Ralph with `Beta++` in both modes on every generated program and test, shrinking any difference.

### Order of proofs

1. Type safety on the typed tree (checkpoint 2), growing with each checkpoint after it.
2. `Whole` arithmetic exact (kept), and `/`, `div`, `rem` exact or stopping (checkpoint 3).
3. `Float` operations correctly rounded (checkpoint 5), with Flocq; then D178's roundings to `Whole`.
4. Showing a `Float` as text: proved where it can be, otherwise in the shell, tested against Python's `repr`.

### Readings the new decisions overtake

- Reading 10 (names in messages keep their `$`): gone with D192.
- `Condition_not_bool` (`NotDesignedYet`): refused now (D187).
- `Format_bool` (`NotDesignedYet`): a `Bool` fills in as `true` or `false` (D202).
- Everything about `.fmt` (D29, D133): every text fills its braces (D200), and D133's refusal goes (D192).
- `&` and D72's refusal of `&` beside maths: gone (D201).
- D8's missing `:` refusal: gone; an opening line ending in `:` is refused instead (D199).

## Status

**2026-11-24, 11:25: the finish line's four parts hold**, apart from the questions below, which wait on Tankun:
1. Every decision is built, D1 to D207, except `extern.cpp`'s C++ bodies, build modes, colours and fonts, what isn't
   decided (`NotDesignedYet`), and the memory cap (D115, D122, D134), asked about.
2. All 53 tests pass.
3. Proven with nothing beyond `assumptions/axioms.txt`: `type_safety` (all of Unio as built), `whole_arithmetic_exact`,
   `whole_negate_exact`, `whole_division_exact`, `float_arithmetic_correct`, `float_sqrt_correct`,
   `float_to_whole_exact`.
4. `check/` runs: 300 programs, 121 the same, 177 skipped (mostly Beta++'s `NotBuiltYet` for dividing), 2 different
   (Beta++ `--final` crashing, sent). It found two Ralph bugs, fixed.

Questions waiting (all sent to the design session): the memory cap; `~0.5` refused or not; where `~` goes on a
negative number; `be.Float` above 2^53; a too-big `Float` literal; a `len.max` list where a plain one goes; `[]` with no
type; `?` in `proc.main`; a line after `instead`; checking unused handlers; when a handler's arguments are worked out.

2026-11-24, 10:50: comment blocks and `///` (D74), procedure and handler families, `include` and handler parameters
(D41 to D44), D126's shared type in front, D81's operator after a step, `extern.cpp` declarations (stopping with
`NotDesignedYet`, since where the C++ lives isn't decided), and D207 are built. 53 of 53 tests pass. What's left of
the language: the memory cap (D115, D122, D134), asked about below. Next: `check/`.

Readings taken meanwhile, sent to the design session:
- A handler's cases are checked where it's used, as if written there (D42); a handler never used isn't checked.
- A handler's arguments that call a procedure stop with `NotDesignedYet`, since whether they're worked out before the
  call or when a case runs isn't clear from D44.

2026-11-24, 10:35: floats are built, and all 53 tests pass. Proven: `float_arithmetic_correct` and `float_sqrt_correct`
(Flocq), with type safety now covering floats too. The theorems about floats rest on Flocq's four axioms, listed with
their reasons in `assumptions/axioms.txt`, which the test runner checks `Print Assumptions` against. `type_safety`
shows them too, only because Flocq's float values carry proofs that use them; extraction erases those.
Reading and showing decimals (`float_of_decimal`, `text_of_float`, `text_with_places` in core/Float.v) are in Rocq but
not proven yet: they're tested against Python (see the float tests' `check.py` and `tests/` in oracle).

2026-11-24, later: checkpoint 3 and most of 4 are done: lists, arrays, `range`, `for each`, dividing, and failures
(`! [ … ]`, `?`, `??`, `otherwise`, `instead`). Proven: `whole_division_exact`, and type safety for all of it, a failure
passed up with `?` always being one its procedure lists. 43 of 53 tests pass; the 10 left are floats, and
`d171_for_each_break`, whose guard clause D9 refuses (sent to the design session).

2026-11-24: checkpoints 1 and 2 are done. The core is now `Syntax.v` (what the parser gives), `Checker.v` (refusals
and the typed tree), `TypedTree.v` (the typed tree and its second type checker), `Evaluator.v` (runs the typed tree)
and `Safety.v` (type safety, proven about the second type checker, with nothing in `Print Assumptions`). 37 of 53
tests pass; the 16 left need lists, `for each`, floats and `otherwise`.

## Wording drafts (sent to the design session in batches)

Built with these meanwhile. Batch 1, sent 2026-11-24:
1. **A name written with `$` (D192):** `fix:` the line without the `$`s; `why:` "a name is a plain word, with no `$`."
2. **`==` or `!=` (D190):** `fix:` the line with `eq` or `not_eq`; `why:` "`eq` and `not_eq` compare two values;
   Unio has no `==` or `!=`."
3. **`&` (D201):** `what:` "`&` isn't how Unio joins text"; `why:` "text is joined by filling it in with braces, as in
   `"{first} {last}"`."
4. **An opening line ending in `:` (D199):** `fix:` the line without it; `why:` "a block's opening line ends with
   nothing; `end` shows where the block ends."
5. **A `labels` line without `[ ]` (D195):** `fix:` the line with them; `why:` "a `labels` line puts its pairs in
   `[ ]`."
6. **A condition that isn't a `Bool` (D187):** for a `Whole`, `fix:` the line with ` not_eq 0` after the condition;
   otherwise `what:` "this condition is a `Text`, but a condition is a `Bool`"; `why:` "a condition is a `Bool`; a
   number or text doesn't stand for true or false."
7. **`places:` on anything but a `Float` (D175):** `what:` "`places:` rounds a `Float`, but `won` is a `Bool`"; `why:`
   "`places:` says how many digits after the point a `Float` shows."
8. **`+` on two texts that aren't both quotes or names (D201):** no `fix:` can be shown, so D89's `what:` "`+` works on
   two `Whole`s, but this is a `Text` and a `Text`", with D201's `why:`.
9. **A variable with a built-in's name, as `let show_msg: Whole = 1;` (D102, D192):** D102's wording with no
   `because:`, since a built-in has no line to show.

Batch 2, sent 2026-11-24 (lists, loops, dividing, failures; each in `Wording.ml` or `ralph.ml`):
- `?`, `?? crash`, `?? ignore` or `otherwise` after no failing call: D102's `??` wording with the word changed, and
  `why:` "`?` passes up the failure of the call right before it." / "`otherwise` deals with the failures of the call
  right before it."
- `?` passing up a failure its procedure doesn't list: "`load` can fail with `missing`, which this procedure doesn't
  list", `because:` "its failures are listed here", `why:` "`?` passes a failure up to the caller, so the procedure
  lists it after `!`." `?` in `proc.main` stops with `NotDesignedYet`.
- `otherwise`: "`load` can fail with `broken`, and no case here deals with it" / "`load` can't fail with `gone`" /
  "there's already a case for `x`" / "this case can reach its end without `instead`, `return` or `break`" / "this
  `instead` isn't in a case of an `otherwise`" / "`bag.add` gives back nothing, so there's nothing for `instead` to
  stand for".
- Dividing: a bare `div` or `rem`: "`div` needs to say how it rounds: `div.floor` or `div.trunc`"; runtime "a `Whole`
  can't be divided by zero" (`when:` `7 div.floor 0`), "7 doesn't divide exactly by 2" (`when:` `7 / 2`, `why:` "`/` is
  for numbers that divide exactly; `div.floor` and `div.trunc` round.").
- Lists: an item of the wrong type, too many items for `len.max`, an array written with the wrong count, `[]` where a
  non-list goes, `[all: …]` on a list, an item reached with no label, a position that isn't a `Whole`, a plain position
  no list has, `.add` on a `let`, `.add` or `.remove` on an array, an `Array` written without `[len: n]`, and at
  runtime "this list has no item at `pos: 4`" with `when:` "the list holds 3 items".
- `for each`: D173's "`players` can't change here, since this `for each` is going through it", a loop's name given a
  new value, going through a non-list, a `range` with the wrong labels, and "this `range` never reaches its end" at
  compile time and at runtime (`when:` "from: 10, to: 1, step_by: 1").
- `NotDesignedYet`: `[]` with nothing saying its type; a list with one `len.max` where another goes; facts besides
  `.len`; methods besides `.add` and `.remove`; a method on something that isn't a variable; `range` outside `for
  each`; a line after `instead`; going through text; comparing lists.

Decided wordings brought up to date with later decisions, as `Wording.ml` says: D88's `returns` now reads `->`
(D190); D87's `otherwise:` reads `otherwise` and D102's `else:` reads `else` (D199); D92's "braces in `.fmt` text" reads
"braces in text" (D200).

## Theorem statements sent to the design session

- `whole_division_exact` (core/Whole.v), sent 2026-11-24: for any two whole numbers, `/`, `div.floor`, `div.trunc`,
  `rem.floor` and `rem.trunc` each give a whole number that fits, exactly the one D70 and D71 describe (spelled out in
  `divides_as`), or stop: dividing by zero stops, `/` stops when the division isn't exact, and -9223372036854775808
  divided by -1 stops with the overflow check.
- `type_safety` widened 2026-11-24 to lists, loops, dividing and failures, statement unchanged; it now also promises a
  failure passed up with `?` is always one its procedure lists, so none escapes `proc.main`.

- `whole_arithmetic_exact` (core/Whole.v): for any two whole numbers, `+`, `-` and `*` give the mathematically exact
  answer whenever it fits in a `Whole`; when the exact answer is bigger than the largest `Whole` they stop with D46's
  overflow check saying "too big", and when smaller than the smallest, "too small". Sent 2026-11-21.
- `type_safety` (core/Safety.v), re-proven 2026-11-24 on the typed tree, statement unchanged: "the checker accepts"
  now includes the second type checker agreeing. Sent again 2026-11-24.
- `type_safety` as first sent: if the checker accepts a program, running it never gets stuck. However the input
  goes and whatever random numbers come back, every way through it ends by reaching the end of `proc.main`, by a
  failed runtime check (D46's overflow), by a stop for something not decided yet (`random` with `from:` above `to:`),
  by `ask` finding no more input, or is still running when the fuel runs out. Sent 2026-11-21.
- `whole_negate_exact` (core/Whole.v): `-` in front of a whole number gives exactly its negative when that fits; the
  one that doesn't, `-` of -9223372036854775808, stops with the overflow check, "too big". Sent 2026-11-21.

## Questions for the design session

Each stops with `NotDesignedYet` in Ralph until it's answered. Sent 2026-11-21 unless marked otherwise. Questions 1 to
3 are answered by D142, 4 by D143, 5 and 6 by D144, 7 by D145, 8 by D146, 9 by D147, 10 from D128, all built.

1. *(Answered, D142.)* **Negation overflowing:** D92's `when:` shows the values, as in `9223372036854775807 + 1`. What does it show for
   `-$x` when `$x` is -9223372036854775808? (Draft: `-(-9223372036854775808)`.)
2. *(Answered, D142.)* **D99's other bad names:** D102 gives "`` `Score` has a capital letter, but names have none ``" and says "likewise"
   for a name starting with a digit or `_`, ending with `_`, or with two `_` in a row. The exact wordings? (Drafts:
   "`` `$2x` starts with a digit, but names start with a letter ``", "`` `$_x` starts with `_`, but names start with a
   letter ``", "`` `$x_` ends with `_`, but `_` only goes between words ``", "`` `$a__b` has two `_` in a row, but `_`
   only goes between words ``".)
3. *(Answered, D142.)* **D128's three refusals** (a slide of one or two calls, three calls nested, a chain mixing both): their wording
   "comes with a later batch".
4. *(Answered, D143: tabs too.)* **`be.Whole` and spaces (D95):** only the space character, or tabs too?
5. *(Answered, D144: `\r\n` is one line break.)* **`ask` and Windows:** is a `\r` before the line break part of the answer? (Ralph keeps it for now; only `\n` ends
   a line.)
6. *(Answered, D144.)* **A file with `\r\n` line endings:** Ralph stops with `NotDesignedYet`.
7. *(Answered, D145.)* **A comment on a line of its own:** how is it indented? Ralph accepts the indentation of the line after it (or one
   level in, when that line is a closer or `else`), and stops with `NotDesignedYet` otherwise.
8. *(Answered, D146: refused.)* **Two statements on one line**, as in `a(); b();`: Ralph stops with `NotDesignedYet`.
9. *(Answered, D147: refused, like a `let`.)* **Giving a parameter a new value:** D130 leaves a parameter's words undecided, so Ralph stops with
   `NotDesignedYet`.

10. *(Answered by the design session from D128: the innermost call starts the slide whole when it takes more than
    one value.)* **Which argument starts a slide** in D142's fix for nested calls, when the innermost call takes more than one
    argument: `show_msg(be.Text(larger(3, 9)))` could become `larger(3, 9) |> be.Text |> show_msg` or
    `3 |> larger(9) |> be.Text |> show_msg`. Ralph stops with `NotDesignedYet` there. Sent 2026-11-21.

## Readings taken where the standard is quiet

Each is what Ralph does now. The design session confirmed all but 2 and 8 on 2026-11-21; 2 became D148, and 8 is
with Tankun.

1. **Where refusals live:** the prompt puts "every refusal" in Rocq. Ralph's parser (OCaml) refuses what's about how
   text is written (`;`, `:`, closers, indentation, blank lines, quotes, names' spelling, `=` in a condition, chained
   comparisons), since those are found before there's a syntax tree; the Rocq checker refuses everything about
   meaning. The type-safety theorem covers what the checker accepts.
2. *(Decided, D148: status 1.)* **Status with both kinds:** a program with refusals and a `NotBuiltYet` or
   `NotDesignedYet` exits with 1; 3 is only for limits alone.
3. **The parser's messages,** generalised from D92's three: "`` `)` should be here, not `x` ``", "a value should be
   here, not `` `x` ``", "the line ends where `` `"` `` should be", with no `why:`.
4. **Carets** where the decisions don't say: a type mismatch in `==` or `+` points at the operator; a missing `return`
   (D88) at the procedure's name; no `proc.main` at line 1 column 1; the file ending inside a block just after the
   last line's text; a line after `return` or `break` at that whole line.
5. **One extra blank line** reads "1 extra blank line, after the one on line 3", singular.
6. **Bad names** (D99) are refused where they're declared; using an undeclared one gives D92's unknown variable.
7. **After `return` or `break`,** only the first line that follows is refused.
8. **`while`** always counts as a way through that can reach the end, for D57's "every way through ends in
   `return`", even `while true:`.
9. **`random`** is seeded differently on every run (seeding isn't decided).
10. **Names in messages** keep their `$`: "there's no variable named `$nme` here", also for `{nme}` with no `$`.
11. **The line-number column** in a message is as wide as its widest line number, and at least 2.
