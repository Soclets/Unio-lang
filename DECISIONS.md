# Plainly decisions

Every choice Tankun makes about Plainly, in the order it was made. Numbers
are never reused or renumbered; a changed decision is a new entry that says
which one it replaces.

Each entry: what was chosen, the alternatives weighed, why this one won, and
Tankun's own words.

## D1. Licences: Apache-2.0 WITH LLVM-exception for code, CC BY 4.0 for writing

2026-11-20.

**Chosen.** Plainly's code is under Apache-2.0 WITH LLVM-exception
(`LICENSE`). Its writing, meaning the Markdown files (README, this log, and
any design docs to come), is under CC BY 4.0 (`LICENSE-CC-BY-4.0`), credited
as `Plainly GitHub repo text: https://github.com/Soclets/Plainly`. This copies
Cyborg's D262, which copied CyborgPL; Lyftar uses the same pair.

**Weighed.**
- Plain Apache-2.0, the licence on all of Tankun's other language repos at
  first glance, and v1's. It has a patent promise (contributors can't sue
  users over patents on their code), but it clashes with GPLv2-only software,
  and arguably puts a notice requirement on every compiled program that has
  Plainly's runtime or standard library inside it.
- MIT. Short and plain, but no patent promise, and it too asks for its notice
  wherever its code goes, compiled programs included.
- MIT OR Apache-2.0, the user's choice, as Rust does. It fixes the GPLv2
  clash, but not the notice requirement in compiled programs. The design
  claude first argued against it as "two licences to explain, against one
  word for a thing"; Tankun rejected that argument ("That's like saying only
  C should exist"), rightly: one word for a thing is a rule about Plainly's
  code, not its licensing, and the argument was withdrawn.
- GPL. Forces work built with the tools to stay open source; wrong for a
  language Tankun wants people to adopt.

**Why this won.** Plainly is compiled, so pieces of Plainly's own code (the
code behind `show_msg`, say) end up inside every program people build. The
LLVM exception says that embedded code owes nothing, no notice and no credit,
and removes Apache-2.0's clash with GPLv2, while keeping the patent promise.
None of the other options does all three. Writing gets its own licence
because software licences fit prose badly; CC BY 4.0 lets anyone reuse the
docs and design reasoning with credit. Tankun asked the Cyborg design claude
("Mf, just ask Cyborg design claude"), which explained D262 and advised taking
the LLVM exception for any language whose runtime ends up in users' programs,
and adding the licence files before a repo is public (Cyborg sat public and
unlicensed for five days; Plainly for a few minutes).

**Tankun's words.** Asked "Go with that?", the owner chose: "yes".

(Changed by D138: examples and demos, code samples in the docs included, are MIT-0.)

## D2. Every keyword has one spelling, the short one, and the docs teach the full word

2026-11-20.

**Chosen.** Code has one spelling for each keyword, the short form: `proc`, `var`, `msg`, never `procedure`,
`variable` or `message`. The docs teach the full word once, where a keyword first appears ("`proc` is short for
procedure"), and so do error messages, so a beginner learns the concept and then types it short.

```
proc.main:
    show_msg("Hello, World!");
end proc.main
```

(Hello world's other parts, `.main`, `show_msg`, `;` and `end`, aren't decided yet.)

**Weighed.**
- Both forms, long and short, as in Plainly v1 (its D28: `procedure` or `proc`, `mutable` or `mut`). It let
  beginners start with full words, but anyone reading other people's code met the short ones anyway, so beginners
  learnt both, and teams argue over which to write.
- Only the long forms. Plainest to read, but long to type everywhere.

**Why this won.** One spelling per thing means every program looks the same, a search for `proc` finds every
procedure, and nobody learns two words for one thing. The short forms are clipped words, not symbols, so they stay
plain once taught. The cost is that a beginner sees `proc` before knowing what it stands for, which the docs and
messages make up for by teaching the full word at first sight.

**Tankun's words.** From multifinity's chat (Nov 19): "So, learn concepts, then type short" and "teach the full
words, and remember the shorten". Asked "Only the short form in code, with the docs teaching the full word once?",
the owner chose: "yea".

## D3. `( )` holds a procedure's parameters and a call's arguments, `[ ]` is for lists, `< >` for types

2026-11-20.

**Chosen.** Each kind of bracket has one job:
- `( )` for procedures, in their definition and in calls, and for grouping maths;
- `[ ]` for lists, as in `[1, 2, 3]` and reaching an item;
- `< >` for filling in a type, as in `List<Whole>`.

```
proc add($a: Whole, $b: Whole) returns Whole:
    return $a + $b;
end proc add

add(1, 2);
```

(`$`, `returns`, `return` and the types here aren't decided yet.)

**Weighed.**
- `[ ]` for a definition's parameters and `( )` for calls, as in Plainly v1 (its D51: `[ ]` holds values and runs
  nothing, `( )` runs something), so a definition can't be mistaken for a call.

**Why this won.** In v2, `proc` in front already marks a definition, so the brackets don't need to as well. Python,
and nearly every language a beginner meets next, writes `( )` in both places, which fits "static Python". It also
leaves `[ ]` to lists alone, so each bracket means one thing. What's lost is v1's signal that `[ ]` never runs
anything: `range(from: 1, to: 5)`, say, now looks like the call it is.

**Tankun's words.** From multifinity's chat (Nov 19): "If kids ask why, then I'll probably say there's maybe not a
real reason. So, maybe switch to `()`? `proc add()` and `add()` don't look the same". Asked "`( )` for parameters and
calls?", the owner chose: "yea".

(Changed by D165: a procedure's parameters go in `[ ]`, and `[ ]` also holds a type's settings and building a record.)

## D4. A definition that takes nothing has no brackets, and every call writes `()`

2026-11-20.

**Chosen.** A procedure's definition writes brackets only when it has parameters. A call always writes `( )`, empty
or not. `proc.main` is never called, since only the runtime starts it, so it has no call form.

```
proc.main:
    show_msg("Hello, World!");
end proc.main

proc roll_dice returns Whole:
    ...
end proc roll_dice

$roll: Whole = roll_dice();
```

(`.main`'s meaning, `returns` and `$` aren't decided yet.)

**Weighed.**
- `()` everywhere, `proc.main():` and `proc roll_dice() returns Whole:`, as in Python. `proc.main()` reads like
  calling a method `main` on something called `proc`, as `$list.add()` would.
- `proc.main:` alone without brackets, and `()` on every other definition. It singles out `main` for no reason a
  learner could see.
- An empty pair in definitions, as Tankun first wrote `proc.main[]`. An empty bracket looks unfinished.

**Why this won.** In a definition, brackets hold parameters, so with none there's nothing to hold (multifinity's
rule). In a call, `( )` means "run it", so it's always there, which is what Python readers expect. Both readings
avoid the method-call look of `proc.main()`.

**Tankun's words.** Asked "No brackets on a definition that takes nothing, `()` on every call?", the owner chose:
"yea, what about calls inside slides?"

## D5. Slides: `|>` passes a value along as each step's first argument

2026-11-20.

**Chosen.** v2 has slides (a pipe): `|>` passes the value on its left into the next step as its first argument, so a
chain reads left to right in the order it runs. A step with nothing else to pass is written bare. A step with more
arguments takes `( )` for those only, and the slid value goes in first.

```
$points |> be.Text |> show_msg;
$score |> clamp(min: 0, max: 100) |> be.Text |> show_msg;
```

A step isn't a whole call, so D4's "every call writes `()`" doesn't apply to it: the step names the procedure, and the
slide does the calling. `|> show_msg()` would look like calling `show_msg` with nothing, when it actually gets the
slid value.

(`be.Text`, `clamp` and its labels, and where `|>` sits among other operators aren't decided yet.)

**Weighed.**
- `()` on every step, as D4 asks of calls. Empty `()` on each step of a long chain read "as a stroke" (multifinity's
  chat), and it hides that a value goes in.
- No slides, nesting calls inside out instead: `show_msg(be.Text(clamp($score, min: 0, max: 100)))`.

**Why this won.** A chain reads in the order it runs, where nesting reads from the inside out. Writing only what's
added in a step's `( )` matches Elixir and Plainly v1's pipe (its D29, D30), and keeps D4's rule true where it means
something: a full call writes all its arguments in `( )`.

**Tankun's words.** Asked "Slides like that?", the owner chose: "yea".

## D6. `show_msg` ends the line, and `show_msg.same_line` doesn't

2026-11-20.

**Chosen.** `show_msg` shows text and ends the line, like Python's `print`. `show_msg.same_line` shows text and leaves
the line open, for prompts and drawing.

```
show_msg("Hello, World!");
show_msg.same_line("Your guess: ");
```

The docs teach "`msg` is short for message" (D2).

**Weighed.**
- `append_msg` for the second one (multifinity's chat: "You're appending the message to output"). "Append" is
  programmer jargon for "add to the end", and a beginner may read it as adding to a message rather than to the
  screen; it also gives two unrelated-looking names to nearly one job.
- `show_msg.no_new_line`. It names what's missing rather than what you get.
- No newline by itself, writing it out every time. Most prints want one, and a beginner who forgets it gets
  everything on one line.

**Why this won.** Showing a message is one thing, so it's one procedure, and the narrowing names its one difference,
the way `.main` narrows `proc`. `.same_line` says exactly what appears on screen. This is Plainly v1's D12 with v2's
name.

**Tankun's words.** Asked "`show_msg` ends the line, and `show_msg.same_line` doesn't?", the owner chose: "yea".

## D7. `;` ends every statement

2026-11-20.

**Chosen.** Every statement ends with `;`, slides included, so a statement can run over several lines and ends only
at its `;`:

```
$score
|> clamp(min: 0, max: 100)
|> be.Text
|> show_msg;
```

A missing `;` is refused, with the place it goes as the fix.

(How a block's opening line and closer are written isn't decided yet.)

**Weighed.**
- Ending a statement at the end of its line, as Python does. One less symbol per line, and a forgotten `;` is the
  most common beginner mistake in C-like languages. But a statement running over several lines then needs a rule:
  Python's brackets or `\`, or JavaScript's guessing where statements end, which goes wrong in well-known ways.

**Why this won.** Every statement visibly stops, which was Plainly v1's reason (its D31), and long slides need no
special rule. With the exact fix in every message, a missing `;` costs a keystroke, not confusion.

**Tankun's words.** Asked "`;` ends every statement?", the owner chose: "yea".

## D8. A block opens with `:` and closes with `end` and what it closes

2026-11-20.

**Chosen.** A block's opening line ends with `:`. Its closer is `end` followed by what it closes, standing alone with
no `;`: `end proc add`, `end proc.main`, `end if`.

```
proc larger($a: Whole, $b: Whole) returns Whole:
    if $a > $b:
        return $a;
    else:
        return $b;
    end if
end proc larger
```

(Indentation, `if`, `return` and comparisons aren't decided yet. This example first had `return $b;` after `end if`,
the shape Plainly v1's D50 and Cyborg's D430 refuse, and called itself `add` though it doesn't add.)

**Weighed.**
- Python's way: `:` to open, and the block ends where the indentation does, with no closing line. Shorter, and
  closest to "static Python", but a wrongly indented line silently moves outside its block, pasted code can change
  meaning, and deep in nested code nothing says which block just ended.

**Why this won.** "Built for reading": `end if` and `end proc add` say which block ends, so a reader never counts
indentation. A missing closer gets a clear refusal instead of a silent change of meaning. Indentation can still be
required for looks, as a decision of its own. This is Plainly v1's shape (its D31, D35).

**Tankun's words.** Asked "Blocks open with `:` and close with `end` plus what they close?", the owner chose: "yea".

(Changed by D199: an opening line ends with nothing, no `:`.)

## D9. After an `if` where any way leaves, nothing follows `end if`

2026-11-20.

**Chosen.** When any way through an `if` leaves, by `return`, `break` or a failure, nothing may follow its `end if`
in the same block. Code that should run afterwards goes in the ways that don't leave. That covers:
- every way leaving with no `else`, the classic guard clause;
- only some ways leaving, where the code after `end if` would run only after the others;
- every way leaving, `else` included, where the code after `end if` could never run.

Each is refused while building.

```
proc greet($name: Text):
    if $name == "":
        return;
    else:
        show_msg("Hi, " & $name & "!");
    end if
end proc greet
```

(`==` on text, a bare `return;`, `&`, and the messages' wording aren't decided yet.)

**Weighed.**
- Guard clauses, as in Python and most languages: `if $name == "": return; end if` with the rest after. The habit
  most learners meet elsewhere.
- Plainly v1's D50 alone, refusing only the first case and leaving the other two open, as v1 did.

**Why this won.** A guard clause looks like a procedure doing two things in a row, when it does one or the other;
with `else`, the paths read as alternatives. Both shapes compile to the same test and jump, so it costs nothing at run
time. Covering all three cases at once leaves no shape where code after an `if` runs only sometimes, or never. This is
Plainly v1's D50 and Cyborg's D430, completed. Long guard chains become flat `else if` chains.

**Tankun's words.** Tankun spotted D8's first example breaking this: has code. Asked "After an `if` where any way leaves, nothing follows `end if`?",
the owner chose: "yea".

## D10. Bodies are indented 4 spaces per level, and anything else is refused

2026-11-20.

**Chosen.** A block's body is indented one level inside its opening line and its closer, and a block inside a body one
level further. One level is 4 spaces. Any other indentation, a tab included, is refused while building, with the whole
corrected line as the fix.

```
proc.main:
    show_msg("Hello, World!");
end proc.main
```

**Weighed.**
- A formatter, `plainly format`, rewriting files as Go's `gofmt` does, with the checker not caring. A beginner has
  to know to run it.
- Free indentation. A body's lines drift, so code can read wrong while running right.
- Tabs, or a width of the writer's choosing. Programs would look different from one another.

**Why this won.** Since D8 ends every block with `end`, indentation never decides where a block ends, so it's only
about looks, and "built for reading" wants every program to look the same. Python gets that by making indentation
meaningful; Plainly gets it by checking it. A refusal with the corrected line teaches it the first time. This is
Plainly v1's D70 and D74.

**Tankun's words.** Asked "4 spaces per level, required, tabs refused?", the owner chose: "yea".

## D11. Variable names start with `$`

2026-11-20.

**Chosen.** A variable's name starts with `$`: `$name`, `$secret`, `$roll`.

**Weighed.**
- `#`, as in Plainly v1. In Python and most other languages `#` starts a comment, so `#score` looks like one to
  anyone coming from them.
- No mark, as in Python. Variables could then clash with keywords and procedure names, and a new keyword could break
  existing programs.

**Why this won.** A mark means a variable is never mistaken for a keyword or a call (`$roll` is a value, `roll()` a
call), keywords can be added later without breaking anyone's names, and variables stand out when filled into text.
`$` already means "a variable" in shells and PHP. The cost is one character per name, and looking less like Python.

**Tankun's words.** Asked "Variable names start with `$`?", the owner chose: "yea. Compiler before oracle, right? But
with tests. And also a standard before compiler"

## D12. The order of work: standard, tests, compiler, then the oracle

2026-11-20.

**Chosen.**
1. **A standard grows with the decisions,** in `standard/`. Each decision that changes a rule updates the standard in
   the same commit, so the standard says what Plainly is now and DECISIONS.md how it got there.
   - It starts with a **Terms** chapter defining every word it relies on (statement, block, procedure, refused, and so
     on), each defined before any chapter uses it.
   - **Every general form says what its placeholders stand for,** right before or after it, as in: `proc name(parameters)
     returns Type:`, where `name` is the procedure's name, `parameters` its parameters separated by commas, and `Type`
     the type it gives back. A real example with no placeholders needs no such line.
2. **Tests are written by hand from the standard,** each a small program with its exact expected output or refusal,
   naming the decision and section it comes from. Where an expected value is computed (arithmetic, rounding, overflow,
   text, a whole program's output), it's cross-checked by the same calculation in Python, or in Rust where fixed-size
   numbers matter, with the check kept beside the test.
3. **The compiler is built to pass those tests.** Its side never edits an expected output: a test that looks wrong
   goes back to the design session, which checks it against the standard, and asks Tankun where the standard is
   unclear.
4. **The oracle comes later,** as a second implementation written from the standard, running the same tests, and as
   the web playground. Where the compiler, the oracle and an expected output disagree, the standard decides.

Nothing gets built until Tankun says so (CLAUDE.md); this sets the order.

**Weighed.**
- The oracle first, as in Plainly v1, where building it was what found the gaps in the design. Compiler first gets a
  usable language sooner; until the oracle exists, only the tests' named rules and their cross-checks stand against a
  wrong expected output, so the tests have to cover the awkward cases, not just programs that work.
- C as a cross-check: its signed overflow is undefined behaviour, so it's least trustworthy on exactly the cases that
  matter.
- SPARK at Platinum level, Ada with mathematical proof of correctness: the strongest opinion, but proving even a short
  function can take days, and the tests need an independent answer, not a proof. Lower SPARK levels prove only that
  code doesn't crash, not that its answer is right.

**Why this won.** A standard written alongside the decisions is always the current truth, and its Terms chapter and
placeholder lines make it readable by someone who isn't a programmer. Tests written from it are the compiler's
contract, and a compiler that may never edit them can't lock a wrong expectation in. An independent calculation in
another language catches a wrong expected value before any compiler exists, and the oracle later checks everything
twice.

**Tankun's words.** Tankun set the order in their answer to D11, quoted whole there, then added "Before that, I think there should be a definition inside the standard about
the terms it uses, and also if you write `let $placeholder: Placeholder = placeholder;`, you should say before or after
what `placeholder` in that context means", asked has code, suggested "What about a separate language's opinion on
result too? When possible, maybe C, Python, Rust, or SPARK Platinum", then "Holy shit, bro. Do you know how diabolical
Plat is?". Asked "Go with that?", the owner chose: "yea".

(Changed by D140: the oracle is built first, to a set finish line, then the compiler.)

## D13. `let` makes a variable that can't change, `var` one that can, and the type is always written

2026-11-20.

**Chosen.** A new variable is declared with `let` or `var`, its name, its type and its first value:

```
let $secret: Whole = 42;
var $tries: Whole = 0;
```

- `let`: its value never changes after this line.
- `var`: its value can change. The docs teach "`var` is short for variable", a value that can vary (D2).
- The type is always written, never worked out from the value.

(`Whole`, numbers, and how a variable is changed aren't decided yet.)

**Weighed.**
- No word for a declaration, `$secret: Whole = 42;`, with a word only for one that can change, as in Plainly v1
  (`mutable`). Creating and changing then look more alike.
- `const` as well, for a value known while building that can sit outside any procedure, as in multifinity's notes
  (`const $MAXTRIES: Whole = 5;`). It means nearly what `let` does, and only matters once anything outside a procedure
  is decided, so it waits.
- Working the type out from the value, as Python and most modern languages do. multifinity's reason against it: if
  `let $name = "Tankun"` looked dynamic, a parameter refusing the wrong type later would surprise beginners.

**Why this won.** A word in front says "a new variable starts here", so a declaration is never mistaken for a change.
`let` and `var` are Nim's and Swift's words and close to JavaScript's, and both teach in one sentence. A written type
shows from the first line that Plainly is static, and says which kind of number a variable holds.

**Tankun's words.** Asked "`let` and `var`, with the type always written?", the owner chose: "yea".

## D14. A bare `=` changes a `var`, with no `change` in front

2026-11-20.

**Chosen.** A `var` gets a new value with its name, `=` and the value, as a statement of its own:

```
var $tries: Whole = 0;
$tries = $tries + 1;
```

- `=` on a `let` is refused, since a `let` never changes (D13).
- `=` only ever stands alone as a statement. It never appears inside a condition, so `if $tries = 3:` is refused, the
  classic typo for comparing. The fix offered was `==`, but how comparison is written isn't decided yet.

(`+`, `if` and shorthand like `+=` aren't decided yet.)

**Weighed.**
- `change` in front, `change $tries = $tries + 1;`, as in Plainly v1 (its D27), so a change can never be mistaken for
  a creation. In v2, `let` and `var` already mark every creation (D13), so the word adds nothing.

**Why this won.** A line starting with `let` or `var` makes a variable, and one starting with `$tries =` changes it,
so the two can't be confused. It's how Python and most languages write a change, and searching for `$tries =` still
finds every one. Keeping `=` out of conditions catches the `=`-for-`==` typo.

(Changed by D190: the fix and the `why:` name `eq`, not `==`.)

**Tankun's words.** Asked "A bare `=` changes a `var`, and `change` goes?", the owner chose: "yea".

## D15. `Whole` is a 64-bit signed whole number, with no other name

2026-11-20.

**Chosen.** `Whole` holds a whole number from -9223372036854775808 to 9223372036854775807, negatives included: a
64-bit signed integer, Rust's `i64`. It has no second name: there's no `i64` meaning the same thing.

```
let $secret: Whole = 42;
```

Other sizes, if they come, are different types with names of their own, not second names for `Whole`.

(Going past the range, and how whole numbers are written, aren't decided yet.)

**Weighed.**
- `Whole` and `i64` both, as in Plainly v1 (its D65). Two spellings for one type, against D2.
- 32 bits, as C's and Java's `int`. It runs out at about 2.1 billion, which a score or a timer in milliseconds can
  reach.
- Unlimited size, as Python's `int`. Every calculation gets slower and needs memory, for a range a game never uses.

**Why this won.** "Whole number" is the school-maths term, so the name teaches itself. 64 bits is far more than a game
needs, and matches Rust, so anything crossing over to Rust keeps its value. One name per type follows D2.

**Tankun's words.** Asked "`Whole`, a 64-bit signed whole number, with no other name?", the owner chose: "yea".

## D16. `if`, `else if`, `else` and `end if`

2026-11-20.

**Chosen.**

```
if $guess < $secret:
    show_msg("Too low");
else if $guess > $secret:
    show_msg("Too high");
else:
    show_msg("Correct!");
end if
```

- `if`, its condition and `:`, with no brackets and no `then`.
- Any number of `else if`, then at most one `else:`, each with its own body.
- One `end if` closes the whole chain (D8).

(Comparisons like `<`, and what a condition may be, aren't decided yet.)

**Weighed.**
- `elif`, as in Python. It's a made-up contraction, not short for any one word, so it breaks D2's "learn the concept,
  then type it short".
- Brackets around the condition, as in C, or `then`, as in Lua. Both are noise once `:` ends the line.

**Why this won.** It's Python's shape with plain words, ending each opening line with `:` like every block (D8). This
is Plainly v1's D35.

**Tankun's words.** Asked "`if`, `else if`, `else` and `end if` like that?", the owner chose: "yea".

## D17. Comparisons: `==`, `!=`, `<`, `>`, `at_least` and `at_most`

2026-11-20.

**Chosen.**

```
$lives == 0
$guess != $secret
$guess < $secret
$score > $best
$hp at_least 1
$hp at_most 100
```

- `==` and `!=` for equal and not equal; `<` and `>` for less and greater.
- `at_least` and `at_most` instead of `>=` and `<=`.
- `<` and `>` have a space on each side, since `< >` also fills in a type with no spaces, as in `List<Whole>` (D3).

(Comparing two pieces of text, and combining conditions, aren't decided yet.)

**Weighed.**
- `>=` and `<=`, as in nearly every language. They're where beginners trip: which way round, whether the number
  itself counts, `<=` or `=<`.
- `=` for equality, as in maths. `=` already gives a value (D13, D14), and `=` inside a condition is refused (D14).

**Why this won.** Symbols where they're read at a glance, words where they aren't: `==`, `!=`, `<` and `>` are
understood without reading them in your head, and `at_least` and `at_most` say exactly whether the number counts. The
spacing rule keeps comparisons and types apart. This is Plainly v1's D33 and D34.

(Changed by D190: `==` and `!=` are `eq` and `not_eq`.)

**Tankun's words.** Asked "Those six comparisons?", the owner chose: "yea, `proc . main` also shouldn't be legal"
(the second half is D18).

## D18. A narrowing's `.` has no spaces around it

2026-11-20.

**Chosen.** The `.` of a narrowing touches the words on both sides: `proc.main`, `show_msg.same_line`. Writing
`proc . main`, or a space on either side, is refused, with the joined form as the fix.

**Weighed.**
- Allowing spaces, as many languages do around `.`. The same thing could then be written several ways, against one
  spelling per thing (D2), and `proc . main` reads like three separate words.

**Why this won.** A narrowing and its word are one name, `proc.main`, and should look like one, every time. Tankun
raised it.

**Tankun's words.** In answer to D17's question: "yea, `proc . main` also shouldn't be legal". Taken as the rule for
every narrowing, not `proc.main` alone.

## D19. `while` repeats while its condition holds

2026-11-20.

**Chosen.** `while`, its condition and `:` open a loop that runs its body again and again as long as the condition
holds, checked before each pass. `end while` closes it (D8).

```
var $tries: Whole = 0;
while $tries < 5:
    show_msg("Guess!");
    $tries = $tries + 1;
end while
```

(`+`, leaving a loop early, and other kinds of loop aren't decided yet.)

**Weighed.**
- `repeat while`, or `loop while`. Longer, with nothing gained over the word every language uses.

**Why this won.** It's Python's word, and the shape of every other block (D8). Plainly v1 had the same (its D53).

**Tankun's words.** Asked "`while` like that?", the owner chose: "yea".

## D20. `ask` shows a question and gives back what the player types

2026-11-20.

**Chosen.** `ask(question)` shows the question, leaves the cursor on its line, waits until the player presses Enter,
and gives back what they typed, without the Enter:

```
let $typed: Text = ask("Your guess: ");
```

What's typed always comes back as text, even digits: typing `42` gives the text `"42"`, since a keyboard only sends
characters. Making it a number is a separate step, which can fail.

(`Text`, turning text into a number, asking with no question, running out of input, and reading single key presses
aren't decided yet.)

**Weighed.**
- `read_msg()`, pairing with `show_msg`. What a player types isn't a message to anyone.
- `read_input()`. "Input" is vague: key presses, the mouse and files are input too.
- `read_line()`, with the question shown first by `show_msg.same_line` (D6). It names what the computer does rather
  than what the program means, and takes two lines for the common case.
- A `msg` family, `msg.show(...)` and `msg.ask(...)` (Tankun's idea). A narrowing makes a word more specific (D18's
  `proc.main`), and `msg.show` isn't a kind of message but an action, so the `.` would change meaning; it also reads
  noun-first and looks like calling a method on an object named `msg`, the look D4 removed. Grouping by topic belongs
  to packages, not narrowings.

**Why this won.** From the player's side the game is asking: it shows a question and waits for the answer, one act,
so one procedure. It reads like English, `let $typed: Text = ask("Your guess: ");`, and the common case needs no
`.same_line`. Tankun found the word.

**Tankun's words.** "What if they input a number? What about something like `read_input`? Idk. What does this do",
"Read? It seems more like `ask`?", "What if we made `msg` a family? `msg.ask`, `msg.show`? Lol", then, asked
"`ask(question)`?", the owner chose: "yea".

## D21. `Text` is the type for text, written in double quotes

2026-11-20.

**Chosen.** Text has the type `Text`, and a piece of text is written in double quotes:

```
let $name: Text = "Mia";
show_msg("Don't give up!");
```

Single quotes aren't used for text.

(A quote inside text, other escapes, empty text, joining and comparing text aren't decided yet.)

**Weighed.**
- `String` or `str`, as most languages say. Jargon that needs explaining ("a string of characters").
- Single and double quotes both, as in Python. Two ways to write the same text, against D2's one spelling per thing.

**Why this won.** `Text` is the plain word and needs no explaining. With only double quotes there's one way to write
text, and an apostrophe inside, as in `"Don't"`, needs nothing special. Plainly v1 and multifinity's notes both use
`Text`.

**Tankun's words.** Asked "`Text`, written in double quotes?", the owner chose: "yea".

## D22. `be.Type(value)` converts a value to a type

2026-11-20.

**Chosen.** Converting is `be` narrowed by the type the value becomes:

```
let $typed: Text = ask("Your guess: ");
let $guess: Whole = be.Whole($typed);
show_msg(be.Text($guess));
```

Converting a value to the type it already is, like `be.Text` of a `Text`, is refused, since it does nothing.

`be.Whole("abc")` can't give a number, so converting can fail. (How a failure is handled, and what may be converted
to what, aren't decided yet.)

**Weighed.**
- The type called like a procedure, as Python's `int("42")`. It hides that converting is an action that can fail, and
  makes a type look like a procedure.
- A procedure per conversion, like `text_to_whole`. A new name for every pair of types.

**Why this won.** `be` ("become") narrowed by the type's own name is a real narrowing (D18), so nothing new is learnt
for each type. Refusing a conversion that does nothing catches a misunderstanding instead of hiding it. This is
Plainly v1's D6 and D90.

**Tankun's words.** Asked "`be.Type(value)` for converting?", the owner chose: "yea".

## D23. Failures must be handled: `?`, `??` and `otherwise:`

2026-11-20.

**Chosen.** A procedure that can fail says so, and every call to it must deal with the failure, or the program is
refused while building. There are three ways, taken from Cyborg:

```
let $level: Text = load_text("level1.txt")?;
let $guess: Whole = be.Whole($typed) ?? 0;
save_text($line, "save.txt") ?? ignore;
load_level($name) ?? crash;
```

- **`?` passes the failure up** to whoever called this procedure, which must list that failure itself.
- **`??` handles it on one line:** `?? value` carries on with that value, `?? ignore` ignores the failure on purpose,
  and `?? crash` stops the program on purpose.
- **`otherwise:` handles each failure in its own `case`,** each ending in a fallback value, `return`, `break`, or
  failing on purpose.

(How a procedure lists its failures, failures' names, the exact form of the `otherwise:` block and its cases, and how
a procedure fails on purpose aren't decided yet.)

**Weighed.**
- No checking, as with Python's exceptions, where any call can fail unnoticed until it happens; or special values like
  `-1`, which get ignored.
- `otherwise use 0`, `otherwise ignore` and `otherwise crash` in place of `??`, as in Plainly v1 (its D56), arguing
  that `??` and `otherwise` would be two spellings of "if this fails". Tankun: "That's longer for a common one, though":
  15 characters against 4 for a fallback value, which games need often. And since there's no `otherwise use`, `??` is
  the only one-line form and `otherwise:` the only block form, two shapes for two sizes of job, not two spellings.
- `?? void`, Cyborg's word for ignoring. "Ignore" says what's happening.

**Why this won.** An unhandled failure is a crash waiting for the one input nobody tested, like a player typing `abc`;
refusing it while building means it's dealt with before anyone plays, and a library procedure gaining a failure gives
its callers a build error, not a surprise. `?` and `??` read as a family, "on failure, pass it up" and "on failure, do
this instead", short where they're common, as D2's "learn the concept, then type it short" asks. Searching `?? ignore`
or `?? crash` finds every deliberate one. This is Cyborg's design, and Plainly v1's D42, D43 and D55.

**Tankun's words.** "Use Cyborg's? With `?`, `??`, and `otherwise:`?", "That's longer for a common one, though", then,
asked "Handling required, with `?`, `??` (a value, `ignore` or `crash`) and `otherwise:`?", the owner chose: "yea".

## D24. Labels: names for arguments, chosen by the procedure and written at every call

2026-11-20.

**Chosen.** A procedure can give its arguments labels, and every call writes them:

```
let $secret: Whole = random(from: 1, to: 100);
```

- The procedure's writer chooses each label. A call can't leave one off, or write one the procedure doesn't have.
- By convention, the first argument, the thing being worked on, has no label, as in `show_msg("Hi")` or a slide's
  value (D5), so simple calls stay simple.

(How a procedure declares its labels, defaults, label order, and `random` itself aren't decided yet. The first sketch
of a declaration, labels inside the parameter list, was the form Plainly v1's D9 turned down, and was dropped.)

**Weighed.**
- Arguments by position only, `random(1, 100)`. The reader has to remember which is which, and two can be swapped by
  mistake.
- Optional names, as Python's keyword arguments. Most code then skips them, so the reader still guesses.

**Why this won.** A call says what each value means, so it reads without opening the procedure, and arguments can't be
swapped by mistake. This is Cyborg's labels, and Plainly v1's D8.

**Tankun's words.** "What the fuck is that label decl syntax", "What does `random` do?", then, asked "Labels at the
call?", the owner chose: "yea".

## D25. Labels are declared on a `labels` line at the top of the body

2026-11-20.

**Chosen.** A procedure declares its labels on a `labels` line, the first line of its body, pairing each labelled
parameter with its label, with commas between and `;` at the end, and no brackets:

```
proc random($low: Whole, $high: Whole) returns Whole:
    labels $low as from, $high as to;
    ...
end proc random

let $secret: Whole = random(from: 1, to: 100);
```

where `...` stands for the rest of the body. Inside, the procedure uses `$low` and `$high`; callers write `from:` and
`to:` (D24).

(Defaults, label order, and `random` itself aren't decided yet.)

**Weighed.**
- The label as the parameter's own name, with a mark: `proc random(labeled $from: Whole, labeled $to: Whole)`. Each
  parameter packs a mark, a name and a type into one item, the crowding Plainly v1's D9 turned down ("That's bad"),
  and renaming a parameter breaks every call.
- `labels [$low as from, $high as to];`, as in Plainly v1. Since D3, `[ ]` means a list, and these pairings aren't a
  list the program works with. `( )` would look like a call.
- Labels inside the parameter list, `proc random(from $low: Whole, to $high: Whole)`, the first sketch for D24, which
  Tankun refused ("What the fuck is that label decl syntax").

**Why this won.** The header keeps one name and one type per parameter, and the inside name stays apart from the
outside label, so a procedure can rename its insides without breaking a call. The line runs nothing and gives back
nothing, so it's neither a call nor a list, and takes no brackets. `range(from: 1, to: 5)`, by contrast, gives back a
value, so it's a call (D3, D4).

**Tankun's words.** "Why no `[]`?", "Wait, then `range()` is legal or not", then, asked "A `labels` line, with no
brackets?", the owner chose: "yea".

(Changed by D195: the `labels` line puts its pairs in `[ ]`.)

## D26. `random(from: low, to: high)` gives a whole number with both ends included

2026-11-20.

**Chosen.** `random(from: low, to: high)` gives a whole number from `low` to `high`, both included, each equally
likely:

```
let $secret: Whole = random(from: 1, to: 100);
```

It's game randomness: fast, and fine for dice, loot and secret numbers in a game, not for anything that must be
unguessable.

(Seeding, a separate kind of randomness for real secrets, `from:` above `to:`, and random numbers of other types
aren't decided yet.)

**Weighed.**
- Leaving out the top, as Python's `randrange(1, 100)`: a classic off-by-one, where 100 never comes up.
- `randomize`, as in multifinity's first sketch. In Nim it means seeding, not picking a number.

**Why this won.** `from:` and `to:` read exactly as the range you get, both ends included, as people mean when they
say "a number from 1 to 100". Keeping the plain name for game randomness leaves room for a clearly different name for
secrets later, the split Plainly v1's D25 made.

**Tankun's words.** Asked "`random(from:, to:)`, both ends included?", the owner chose: "yea".

## D27. `+` adds and `-` subtracts, and a `-` with no space after it negates

2026-11-20.

**Chosen.**

```
$tries = $tries + 1;
let $left: Whole = 5 - $tries;
let $back: Whole = -$speed;
```

- `+` adds and `-` subtracts numbers, with a space on each side.
- A `-` right before a number or a name, with no space after it, makes it negative: `-7`, `-$speed`.
- `+` is only for numbers; text is joined some other way.

(Going past `Whole`'s range, multiplying, dividing, maths order, and joining text aren't decided yet.)

**Weighed.**
- `+` for joining text as well, as in Python. `"5" + 3` could then be misread as joining or as adding.

**Why this won.** Spacing tells subtracting (`$a - $b`) from negating (`-$b`), as D17's spacing tells comparisons from
types. Keeping `+` for numbers means a `+` always adds. This is Plainly v1's D1, D84 and D86.

**Tankun's words.** Asked "`+` and `-` like that?", the owner chose: "yea".

## D28. `&` joins text, and doesn't convert numbers by itself

2026-11-20.

**Chosen.** `&` joins two pieces of text. A number joined with `&` is refused, with `be.Text(...)` as the fix (D22),
so it's always visible where a number becomes text:

```
show_msg("Hello, " & $name & "!");
show_msg("You got it in " & be.Text($tries) & " tries.");
```

(Filling values into text, and `&` next to `+` or `-` without brackets, aren't decided yet.)

**Weighed.**
- `+`, as in Python. D27 keeps `+` for numbers, so `"5" + 3` can't be misread.
- Converting numbers by itself, as JavaScript does. `"5" & 3` would quietly mean something, and where a number becomes
  text would be hidden.

**Why this won.** `&` reads as "and", is what Ada, Visual Basic and Excel use, and has no other job in Plainly. This
is Plainly v1's D1 and D6, and multifinity's notes.

**Tankun's words.** Asked "`&` joins text, with no automatic converting?", the owner chose: "yea".

(Changed by D201: `&` goes, and text is joined only with braces.)

## D29. `.fmt` fills values into text, with braces holding only names

2026-11-20.

**Chosen.** `.fmt` fills in what's in braces. It narrows `show_msg` to show the result, and `be.Text` to give it back
as `Text`:

```
show_msg.fmt("You got it in {$tries} tries.");
let $line: Text = be.Text.fmt("{$name}: {$score}");
```

- Braces hold only a variable's name. `{$tries + 1}` and `{roll()}` are refused, so text never hides a calculation or a
  call that could fail.
- A number in braces becomes text by itself.
- The text is checked while building: a name in braces that isn't a variable is refused before the program runs.
- Without `.fmt`, text is plain: `show_msg("{$tries}")` shows exactly `{$tries}`.
- The docs teach "`fmt` is short for format" (D2).

(A literal `{` inside `.fmt` text, settings in braces like `places: 2`, and the order of `.fmt` and `.same_line`
together aren't decided yet.)

(Settings in braces: `places:`, by D175.)

**Weighed.**
- `.format`, as in Plainly v1. D2's short form is `fmt`, known from Go and Rust.
- Python's f-strings, `f"You got it in {tries} tries."`. Shorter, but one letter before the quote changes what the
  text means, easy to miss when reading.
- Cyborg's `@fmt("...")`, a compiler builtin giving a "format value" that becomes text wherever it's used. The `@`
  marks Cyborg's builtins, and the format value exists because Cyborg makes every memory allocation visible; Cyborg's
  design claude advised that `.fmt` returning text is simpler for a language without that. Taken from it: names-only
  braces and checking while building.

**Why this won.** One narrowing covers both showing and building text, with no new keyword, and a fill-in can only
read a value, never do work. It replaces long `&` chains with `be.Text` in each (D28).

**Tankun's words.** "What about Cyborg's `@fmt`?", "How about `.fmt`?", then, asked "`.fmt` on `show_msg` and
`be.Text`, with braces holding only names, checked while building?", the owner chose: "yea".

(Changed by D200: every text fills its braces, and `.fmt` goes.)

## D30. `\` makes the next character literal, with no C-style codes

2026-11-20.

**Chosen.** Inside text, `\` makes the next character literal, and does nothing else:

```
show_msg.fmt("Type \{help} to see the commands, {$name}.");
show_msg("She said \"hi\".");
```

- `\{` is a brace in `.fmt` text, `\"` a quote, and `\\` a backslash.
- Only `{` needs escaping in `.fmt` text: a `}` with no open `{` is just a character.
- `\` doesn't start C-style codes: `\n` isn't a new line and `\t` isn't a tab.

(How a new line or a tab is written inside text, and whether `\` before a letter is refused, aren't decided yet.)

**Weighed.**
- C's codes, `\n`, `\t` and the rest, as Python has. Codes to memorise, which a plain word can replace.
- Python's doubled braces, `{{` and `}}`. Two rules where one does.

**Why this won.** One rule covers every case: the character after `\` is taken as it is. This is Plainly v1's D3 and
D5 ("`\` escapes, but it doesn't format like C", Tankun in v1).

**Tankun's words.** Asked "`\` makes the next character literal, with no C codes?", the owner chose: "yea".

## D31. Narrowings go strongest first, and any other order is refused

2026-11-20.

**Chosen.** When a word has two or more narrowings, the one that changes the action most comes first, and any other
order is refused, with the right spelling as the fix. `.fmt` changes what's shown, and `.same_line` only where it ends,
so:

```
show_msg.fmt.same_line("Lives: {$lives}, your move: ");
```

and `show_msg.same_line.fmt(...)` is refused, with `fix: show_msg.fmt.same_line`.

(A table of narrowing kinds, to place each new narrowing without judging it afresh, isn't decided yet.)

**Weighed.**
- Any order. Two spellings for one thing, against D2, and a reader may wonder whether the orders differ.

**Why this won.** One spelling means a search finds every use, and the reader learns the most important fact first.
This is Plainly v1's D14 and Cyborg's rule.

**Tankun's words.** Asked "Narrowings go strongest first, with any other order refused?", the owner chose: "yea".

## D32. `break` leaves the innermost loop, and there's no `continue`

2026-11-20.

**Chosen.** `break;` leaves the innermost loop it's in. An `if` that breaks has the rest of the pass in its other
ways (D9). There's no `continue`: ending one pass early is an `if` around the rest.

```
while $tries < 7:
    let $guess: Whole = be.Whole(ask("Your guess: ")) ?? 0;
    $tries = $tries + 1;
    if $guess < $secret:
        show_msg("Too low");
    else if $guess > $secret:
        show_msg("Too high");
    else:
        show_msg.fmt("Correct! You got it in {$tries} tries.");
        break;
    end if
end while
```

(Leaving a loop further out, by naming it, isn't decided yet.)

**Weighed.**
- `continue`, as in Python and C. In Radium's cold tests every word for it was misread: `continue` as "carry on",
  `skip` as skipping the whole loop, and `next` and others too (Radium's D77, Plainly v1's D53).

**Why this won.** `break` is the word every language uses, and with D9 the way out of a loop always sits in its own
branch. Without `continue`, the shape of the code shows which lines a pass runs.

**Tankun's words.** Asked "`break` leaves the innermost loop, and no `continue`?", the owner chose: "yea".

## D33. `Bool` is the type for true or false, with the values `true` and `false`

2026-11-20.

**Chosen.** A value that's either true or false has the type `Bool`, and its two values are written `true` and
`false`. A comparison gives a `Bool`, and that's what `if` and `while` check.

```
var $won: Bool = false;
$won = $guess == $secret;
```

The docs teach "`Bool` is short for Boolean, a value that's either true or false, named after George Boole" (D2).

(Combining conditions with words like `and`, `or` and `not`, and whether a condition must be a `Bool`, aren't decided
yet.)

**Weighed.**
- `Truth`. Reads oddly: `var $won: Truth`.
- `YesNo`. Made up, and found in no other language.
- `Flag`. Jargon of its own.
- `True` and `False`, capitalised as in Python. Plainly's other keyword values are lowercase.

**Why this won.** `Bool` follows D2: a short form taught once, and the word every language and tutorial uses, so a
learner keeps meeting it.

**Tankun's words.** Asked "`Bool`, with `true` and `false`?", the owner chose: "yea".

## D34. `and`, `or` and `not` combine conditions, in that order, and stop early

2026-11-20.

**Chosen.**

```
if not $won:
    show_msg.fmt("Out of tries! It was {$secret}.");
end if

if $hp at_least 1 and $lives > 0 or $cheat == true:
```

- `and`, `or` and `not` are words.
- `not` is worked out first, then `and`, then `or`, so the second example means
  `($hp at_least 1 and $lives > 0) or $cheat == true`, with no brackets needed. Comparisons come before all three.
- `and` and `or` stop early: the right side runs only if it can still change the answer, so a guard like
  `$i at_most $count and $items[pos: $i] == 0` never reaches past the end of a list.

(A form that always works out both sides, and lists and positions, aren't decided yet.)

**Weighed.**
- C's `&&`, `||` and `!`. Symbols to memorise where Python and plain English use words.
- Requiring brackets wherever `and` meets `or`. More to write, for an order nearly every language shares.
- Always working out both sides, as Ada's plain `and` does. Its users end up writing `and then` everywhere to stay
  safe.

**Why this won.** Plain words, Python's own, in the order most languages use, with the safe behaviour as the default.
This is Plainly v1's D36, D37 and D92.

**Tankun's words.** Asked "`and`, `or` and `not` like that?", the owner chose: "yea".

## D35. Plainly files end in `.plainly`

2026-11-20.

**Chosen.** A Plainly file's name ends in `.plainly`, as in `game.plainly`.

**Weighed.**
- A short extension like `.pl`, taken by Perl, or `.pn`, which says nothing.

**Why this won.** It names the language, so people and editors know what a file is; nothing else uses it, so GitHub
and editors can map it to Plainly without a clash; and it's easy to search for. It's long, but typed rarely. This is
Plainly v1's D78.

**Tankun's words.** Asked "`game.plainly`?", the owner chose: "yea. Where's families? And making a extern proc"

(Changed by D135: files end in `.cplus`.)

## D36. `extern.rust proc` declares a procedure whose body is written in Rust

2026-11-20.

**Chosen.** `extern.rust` in front of `proc` says the procedure's body is written in Rust, outside the Plainly file.
Its body is empty, or holds only a `labels` line (D25), never code, and its closer doesn't repeat `extern.rust`:

```
extern.rust proc beep returns Bool:
end proc beep
```

- `extern` is short for external (D2); `.rust` narrows it to where the body is, leaving room for `extern.c` later.
- Callers can't tell it apart from any other procedure.

(How Plainly's values cross into Rust, and what an extern procedure does when it fails, are left for when building
starts.)

**Weighed.**
- `proc.rust`, narrowing `proc` itself. `extern` is a modifier in front, like `let` against `var`, and says the body
  is elsewhere before saying where.

**Why this won.** A game's library needs procedures that talk to the terminal and the operating system, which are
written in Rust, and this lets them look like any other procedure to the people calling them. This is Plainly v1's
D40, with v2's short forms.

**Tankun's words.** Asked "`extern.rust proc` like that?", the owner chose: "yea. `returns` locked" (the second half
is D37).

(Replaced by D131: PlainCompiler is C++ on LLVM, and `extern.rust` becomes `extern.cpp`, whose details are open again.)

## D37. A procedure's header says what it gives back with `returns`

2026-11-20.

**Chosen.** A procedure that gives back a value says so at the end of its header, with `returns` and the type:

```
proc larger($a: Whole, $b: Whole) returns Whole:
proc roll_dice returns Whole:
extern.rust proc beep returns Bool:
```

(How a procedure gives back its value in the body, a procedure that gives back nothing, and how failures are listed
in the header aren't decided yet.)

**Weighed.** Nothing else was put forward: the word had been in every example since D3, and Tankun locked it.

**Why this won.** It reads as what it says, "returns a whole number", in the header where a reader looks for what a
procedure takes and gives. It's Plainly v1's word.

(Changed by D190: the result is written `-> Type`.)

**Tankun's words.** In answer to D36's question: "yea. `returns` locked".

## D38. A procedure that gives nothing back writes no `returns`

2026-11-20.

**Chosen.** A header writes `returns` only when the procedure gives back a value. One that gives nothing back writes
nothing there, and if it can fail, its failures follow on their own, with no `returns` and no `or`:

```
proc.main:
proc greet($name: Text):
proc save_game($state: Text) fails disk_full:
proc load_level($name: Text) returns Level or fails not_found:
```

(The word `fails` and how failures are listed were placeholders here, and aren't decided yet; nor is how a procedure
leaves early when it gives nothing back.)

**Weighed.**
- `returns nothing`, always, as Plainly v1's D100 chose, so every header reads "returns *this* or fails *that*" and a
  learner meets the difference between doing something and giving something back. Every header in every game pays
  for it, and v2's D4 writes only what's there.

**Why this won.** It follows D4: a definition writes only what's there, so `proc.main:` and the many procedures that
only do something stay short. The difference between doing and giving back can still be taught where someone trips on
it: using what such a procedure gives as a value is refused, with a message saying it gives nothing back. This is
Plainly v1's D46 before its D100.

**Tankun's words.** "`returns nothing or fail`? When there's void & fail?", then, asked "A procedure that gives
nothing back writes no `returns`, and `fails` alone when it can fail?", the owner chose: "yes".

## D39. A header lists its failures after `fails`, separated by commas, with no brackets

2026-11-20.

**Chosen.** A procedure that can fail lists its failures' names at the end of its header, after `fails`, separated by
commas. After `returns`, it's joined with `or`; with no `returns`, `fails` stands alone (D38):

```
proc load_level($name: Text) returns Level or fails not_found, broken:
proc save_game($state: Text) fails disk_full:
```

A failure's name is a plain word, like `not_found` or `disk_full`.

(How a procedure fails on purpose, the form of `otherwise:` and its cases, and handler families aren't decided yet.)

**Weighed.**
- `or fails [not_found, broken]`, as in Plainly v1. Since D3, `[ ]` means a list value, and a failure list is part of
  the definition. `( )` would look like a call.

**Why this won.** The header reads as English, "returns a Level, or fails: not found, broken", and the failures sit
next to what the procedure gives back, since a failure is what it can give back instead. The brackets follow the same
reasoning as D25's `labels` line.

(Changed by D190: failures are written `! [ … ]`.)

**Tankun's words.** Asked "`fails`, then names separated by commas, no brackets?", the owner chose: "yea".

## D40. The `otherwise:` block: one `case` per failure, each ending in `instead`, `return`, `break` or failing

2026-11-20.

**Chosen.**

```
let $best: Whole = load_best_score() otherwise:
    case not_found:
        show_msg("No high score yet.");
        instead 0;
    case unreadable:
        instead 0;
end otherwise
```

- `otherwise:` after a call that can fail opens the block, and `end otherwise` closes it (D8).
- One `case` per failure, naming it (D39). The cases must cover every failure still possible at that call, so a
  procedure gaining a failure makes every incomplete block a build error.
- Each case ends in one of four ways: `instead` a value, carrying on with it; `return`; `break`; or failing on purpose.
  A case that could fall off its end is refused.
  (Changed by D186: when the call gives back no value, a case may also just end.)
- `case` is indented one level in, and its body one level further (D10).

(How a procedure fails on purpose, and `return` itself, aren't decided yet.)

**Weighed.**
- `?? value` for every failure alike (D23). It can't treat failures differently, as when a missing file means "no score
  yet" but a broken one should warn.
- `match`, `catch` or `except` blocks, from other languages. `otherwise` reads as English after a call: "load the best
  score, otherwise...".

**Why this won.** Each failure gets its own handling where it's needed, the build checks none is forgotten, and every
case says how the line carries on. This is Cyborg's `otherwise:` and Plainly v1's D55, with v2's indentation.

**Tankun's words.** Asked "The `otherwise:` block like that?", the owner chose: "yea".

## D41. A family is a word and its kinds, declared together in a `fam.kind` block

2026-11-20.

**Chosen.** A family declares a word and its kinds together. `fam` narrowed by what it holds opens it, and it holds
only that kind of thing: `fam.proc` for a procedure and its narrowings, `fam.handler` for a failure's handlers.

```
fam.proc show_msg:
    proc show_msg($text: Text):
        ...
    end proc show_msg

    proc show_msg.same_line($text: Text):
        ...
    end proc show_msg.same_line
end fam.proc show_msg
```

where each `...` stands for that procedure's body.

- **Every member reads as "a Y kind of X"** for its name `X.Y`, or is the word `X` itself. Anything else is refused:
  `show_msg.same_line` is a same-line kind of showing, but `geometry.area` isn't a kind of geometry.
- **A narrowed procedure is declared inside its word's family,** so every variant is in one place.
- **Each member keeps its full name,** so one search finds its declaration and every use.
- **The test is what a narrowing is in general:** a kind. Everything v2 has passes it: `show_msg.same_line`,
  `show_msg.fmt`, `be.Whole`, `proc.main`, and handlers like `word_failed.use_placeholder`.
- `fam` is short for family (D2).

(How a handler family's handlers are written, handlers that take arguments, and handlers covering only some failures
aren't decided yet.)

**Weighed.**
- Cyborg's families before its D480: any named group, `fam.fn geometry` with `geometry.area()`, which grew into
  modules. Tankun's words: too big, when the purpose was `print` and `print.stored`.
- A family block with no kind, `fam show_msg:`, which Tankun questioned ("Woah, why no `.`?"): the opening line wouldn't
  say what's inside, and a family could mix procedures and handlers.
- No family block, with `proc show_msg.same_line` declarable anywhere. Shorter, but variants could scatter, and families
  stop being a visible thing.
- A `msg` family, `msg.show` and `msg.ask` (D20's alternative, which seemed worth reopening once families came in). It
  fails the test, "a show kind of message", so D20 stands.

**Why this won.** It's the original idea of families, a word and its variants, with Cyborg's test (its D480, refined
by Tankun on 2026-11-20) keeping them from growing into folders. The kind in `fam.kind` puts what's inside in the first
word, and lets the checker refuse anything else.

**Tankun's words.** "Wait what? That's not families", "Now, here's the thing. I think Cyborg's families are too big
grouping. You know what I mean? The purpose was originally `print`, and `print.stored` being different in a family.
Familiy now can create shit like different modules. And I think that is too big", "Woah, why no `.`?", "Actually,
wait. I think we should pause here, and let me go refine families in Cyborg. So, it would be better or more in my
vision. Since families are one of my biggest innovations.", then, after Cyborg's D480, asked "Families as a word and
its kinds, in a `fam.kind` block, with every member passing "a Y kind of X"?", the owner chose: "yea".

## D42. Handlers are declared with `handler` in a `fam.handler`, used with `otherwise`, and `*` marks one that can jump

2026-11-20.

**Chosen.**

```
fam.handler word_failed:
    handler word_failed.use_placeholder:
        case too_long:
            instead "...";
        case no_words:
            instead "(none)";
    end handler word_failed.use_placeholder

    handler word_failed.give_up:
        case too_long:
            return;
        case no_words:
            return;
    end handler word_failed.give_up
end fam.handler word_failed

let $title: Text = first_word($heading) otherwise word_failed.use_placeholder;
let $name: Text = first_word($typed) otherwise word_failed.*give_up;
```

- Each member of a `fam.handler` starts with `handler` and its full name, and is closed with `end handler` and that
  name, as `fam.proc`'s members are with `proc` (D41).
- A handler's body is `case`s, exactly as in an `otherwise:` block (D40). `otherwise family.handler` uses it at a call
  as if its cases were written there, so they must cover every failure still possible at that call.
- The family's word names what fails, so each handler reads as a kind of handling it (D41).
- A handler that can `return` or `break` is marked `*` where it's used, as in `word_failed.*give_up`: required on one
  that can jump, refused on one that can't.

(`return` itself, handlers that take arguments, handlers covering only some failures, and whether failing on purpose
inside a case counts as a jump aren't decided yet.)

**Weighed.**
- No mark, as an ordinary handler call. A `return` inside a handler leaves the caller's procedure, and nothing at the
  call would show that the lines after it might never run.
- The mark where the handler's declared. Then reading a call wouldn't show it.
- A handler header with no `handler` word, as Cyborg writes `word_failed.use_placeholder:`. `fam.proc`'s members start
  with `proc`, so v2's handlers start with `handler`.

**Why this won.** Handling that repeats across many calls is written once and named, and reads at the call as what it
does. The `*` at the use is the part of Cyborg's design that has most clearly earned its keep, Cyborg's design claude
reports: a hidden return out of the caller is the real surprise. This is Cyborg's handler families (its D46, D480) and
Plainly v1's D41.

**Tankun's words.** Asked "Handlers declared with `handler` inside a `fam.handler`, used as `otherwise
family.handler`, with `*` at the use for one that can jump?", the owner chose: "yea".

## D43. `include` brings a handler's cases into an `otherwise:` block, beside cases of its own

2026-11-20.

**Chosen.** Inside an `otherwise:` block, `include family.handler;` brings in that handler's cases as if written
there, and the block's own `case`s cover the failures it doesn't:

```
let $title: Text = load_word($file) otherwise:
    include word_failed.use_placeholder;
    case disk_full:
        instead "?";
end otherwise
```

- Together, the included and written cases must cover every failure still possible at the call, with no failure
  covered twice (D40).
- A handler that can jump is marked as at any use: `include word_failed.*give_up;` (D42).

(Handlers that take arguments aren't decided yet.)

**Weighed.**
- `use`, the word first proposed. Vaguer, since plain `otherwise family.handler` also uses a handler, and it's the
  word other languages use for importing names, which v2 may want later.
- No combining, so a call with one failure the handler doesn't cover needs a whole new handler. Cyborg's design claude
  warned to settle this early, since Cyborg never did.

**Why this won.** A handler covering some failures stays reusable on calls that can fail in more ways. `include` says
exactly what happens, its cases included as if written there, and leaves `use` free. Tankun found the word.

**Tankun's words.** "`include` instead?", then, asked "`include` inside `otherwise:` to combine a handler with extra
cases?", the owner chose: "yea".

## D44. Handlers take parameters as procedures do

2026-11-20.

**Chosen.** A handler can take parameters, written as a procedure's are: `( )` only when it has some (D4), a `labels`
line at the top of its body (D25), and arguments in `( )` with their labels where it's used (D24). An argument is
worked out at the call, before the cases run, and the cases read it like any parameter.

```
fam.handler word_failed:
    handler word_failed.use_default($fallback: Text):
        labels $fallback as with;
        case too_long:
            instead $fallback;
        case no_words:
            instead $fallback;
    end handler word_failed.use_default
end fam.handler word_failed

let $title: Text = first_word($heading) otherwise word_failed.use_default(with: "Untitled");
```

`include` takes arguments the same way: `include word_failed.use_default(with: "?");` (D43).

**Weighed.**
- No parameters, so every fallback value needs its own handler. Cyborg's design claude reports this as the gap its
  users hit first ("use_placeholder" wants to be "use_default(with: …)"), and Cyborg never settled it.

**Why this won.** A handler is reusable across calls that want different fallbacks, and it's written with the rules
procedures already use, so nothing new is learnt.

**Tankun's words.** Asked "Handlers take parameters like procedures do?", the owner chose: "yea. Let's decide arch,
like backend, memory, etc"

## D45. The compiler is written in Rust and compiles ahead of time to native code through Cranelift

2026-11-20.

**Chosen.** Plainly's compiler is written in Rust. It compiles a whole program ahead of time to one native executable,
through Cranelift, with no bytecode and no JIT. Running a program compiles it to a temporary file and starts it, as
`go run` does. The web playground runs the oracle compiled to WebAssembly, so the compiler needs no second backend for
the web.

(The command's name and its parts, build modes, and the oracle's language aren't decided yet.)

**Weighed.**
- LLVM. It optimizes more, but compiles far slower, so running a program wouldn't feel instant; a terminal game won't
  notice the difference in speed.
- Bytecode with an interpreter or a JIT, as Python and Java do. A runtime to install alongside every game, and a
  bytecode format to design and keep stable.
- Compiling to C, or to WebAssembly first. An extra toolchain on every player's machine, or a web-first design, which
  multifinity's notes warn killed Fale.

**Why this won.** A player gets one file that starts instantly, matching the "Download" installer in multifinity's
notes. Cranelift compiles fast enough that running feels immediate, covers x86-64 and ARM64, and is a Rust library, so
the compiler and `extern.rust` procedures (D36) share one world. This is Plainly v1's D16.

**Tankun's words.** Asked "A Rust compiler, ahead of time to native through Cranelift?", the owner chose: "yea, what
about build modes? `--Working` (no optimization, every runtime check kept) and `--Final` (max optimization from backend
and frontend, cheap checks kept)?"

(Replaced by D131: PlainCompiler is C++ on LLVM, and `extern.rust` becomes `extern.cpp`, whose details are open again.)

## D46. Two build modes, working and final, with no default; final never drops a check

2026-11-20.

**Chosen.** Every build names one of two modes, with the flags `--working` and `--final`. There's no default.

- **Working:** no optimizations, so the fastest compile, and every check kept, each stopping at the exact line:
  whole-number overflow, a bad list position, division by zero, NaN in floats.
- **Final:** full optimization, from Plainly's own front end and from Cranelift. It never drops a check; it only makes
  expensive ones cheaper. Overflow, position and division-by-zero checks cost almost nothing and stay. Checks the
  optimizer proves can never fail are removed. The NaN check after every float operation becomes the CPU's own flags,
  read where a value leaves a procedure; its message names the procedure, and says to build in working mode to find
  the line.

(How the modes are written in docs and messages, the command's name, and what each check's message says aren't
decided yet. Overflow, positions, division and floats themselves aren't decided either; the list says what's checked
once they are.)

**Weighed.**
- Plainly v1's three modes, `Working`, `FinalSafe` and `FinalPerf` (its D19), where the third dropped safety checks for
  speed. A terminal game never needs that speed, and a dropped check turns a clear stop into a silent wrong answer.
- `--Working` and `--Final`, capitalised, as Tankun first wrote them. Command-line flags are lowercase almost
  everywhere.
- A default mode. Someone ships a slow working build by accident, or debugs in final without knowing it.

**Why this won.** Two modes cover the two jobs, writing a game and shipping it, and the rule that final never drops a
check means a shipped game is exactly as safe as the one that was tested. Tankun proposed the pair.

**Tankun's words.** In D45's answer (quoted there), Tankun proposed `--Working` and `--Final`. Asked "Two modes,
`Working` and `Final`, where `Final` never drops a check, with no default and lowercase flags?", the owner chose: "yea,
lowercase in docs too?"

## D47. Build modes are written lowercase everywhere

2026-11-20.

**Chosen.** The modes are `working` and `final` everywhere: on the command line, in the docs and in messages, as in
"build in `working` mode" and "build with `--working` to find the line".

**Weighed.**
- `Working` and `Final`, capitalised in docs and messages, as Plainly v1 wrote them. Each mode would have two spellings,
  the flag's and the name's.

**Why this won.** One spelling per thing (D2), and a reader sees exactly what they type. Tankun raised it.

**Tankun's words.** "yea, lowercase in docs too?" (in D46's answer), then, asked "Modes written lowercase everywhere,
docs and messages included?", the owner chose: "yea".

## D48. Memory is managed by a Go-style garbage collector that never moves objects

2026-11-20.

**Chosen.** Plainly frees memory with a tracing garbage collector in the style of Go's:
- it marks what's still in use while the program keeps running, so pauses stay well under a millisecond whatever the
  memory size;
- it never moves objects, so an `extern.rust` procedure (D36) can hold a plain pointer during a call;
- it needs only a write barrier, a check when a reference is stored;
- it groups objects by size, which keeps memory tidy without moving anything;
- it's precise, finding every reference through the stack maps Cranelift records (D45).

It may be built first as a simple mark-and-sweep with the same never-moving promise, growing into the full design
without changing any program.

**Weighed.**
- A simple mark-and-sweep only. Simplest to build, but its pauses grow with memory, which limits Plainly if it grows
  past terminal games.
- A moving, generational collector, as Java's and .NET's. Fast, but `extern.rust` code would need to pin objects.
- Reference counting, Swift-style, with copy-on-write. It frees memory the moment it's unused and appealed as fun to
  build ("But Swift-style seems fun, though"), but its count updates thread through the whole compiler, and with
  `share` (D49) it leaks cycles unless the programmer marks links `weak` or a backup cycle collector is added, as
  Python has. Tankun pointed out that for terminal games its main gains, no pauses and flat memory, are worth little
  ("Wait, look at our target, CLI games").
- Hylo's mutable value semantics: nothing is ever shared, so memory needs no runtime bookkeeping. The purest, but a
  research design, and it rules out `share` entirely.
- Ownership, as Rust's and Cyborg's. Borrowing rules are wrong for "static Python".

**Why this won.** Tankun asked for "the more flexible kind": Go's design scales from a small terminal game to anything
bigger, like a GUI package, with the same promises, handles every cycle `share` can make, and keeps Rust code simple
because nothing moves. This is Plainly v1's D38 (PlainGC). Its cost is size, roughly 5,000 to 12,000 lines of Rust by
v1's estimate, which the simple first version spreads out.

**Tankun's words.** "How about Swift-style?", "Wait, look at our target, CLI games", "But Swift-style seems fun,
though. What's share?", "What's Hylo's", "What is share for, though?", "What about RC with `share` and `copy` when
needed?", "So, what about `share` & `copy` with GC? What kind of GC, though. I would take the more flexible kind",
then, asked "Go-style GC (non-moving, collecting while the program runs), with `copy` and `share` required when
assigning a list or record?", the owner chose: "yea".

## D49. Assigning a list or record says `copy` or `share`

2026-11-20.

**Chosen.** When a list or a record is given to a new name, the line says whether that name gets its own copy or
shares the original, and there's no default:

```
var $b: List<Whole> = copy $a;
var $c: List<Whole> = share $a;
```

Changing `$b` leaves `$a` alone. Changing `$c` changes `$a`, since they're two names for one list, and the word
`share` on that line says so. A plain value like a `Whole` needs neither word, since copying and sharing it look the
same. `copy` really copies: the garbage collector (D48) keeps no counts to make it lazy.

(Lists, records, `List<…>`, whether arguments and changes with `=` need a word, and copying cost aren't decided yet.)

**Weighed.**
- Values only, with no `share`, as in Hylo. Nothing can be aliased, but things that really are one thing, like the
  player every monster targets, must be referred to by something like a number and looked up.
- Sharing by default, as in Python, where `b = a` makes two names for one list. Changing one variable then changes
  another with nothing on the page to say so, a classic beginner surprise.
- Copying by default. Hides when a large copy happens.

**Why this won.** Sharing is there when it's really meant, and both cases are visible on the line that makes them,
so "I changed `$b` and `$a` changed too" can only happen where `share` is written. This is Plainly v1's D32, which
Tankun brought back here ("What about RC with `share` and `copy` when needed?").

**Tankun's words.** Decided with D48, in the same answer (quoted there).

(Replaced by D130: Hylo-style values.)

## D50. The command is `plainly`, with `run`, `build`, `check` and `oracle`

2026-11-20.

**Chosen.**

```
plainly run game.plainly --working
plainly build game.plainly --final
plainly check game.plainly
plainly oracle game.plainly
```

- `run` builds to a temporary file and runs it (D45); `build` makes the file to ship; both need a mode (D46).
- `check` only reports what's refused, without building, so it needs no mode.
- `oracle` runs the file on the oracle, the separate reference implementation, printing exactly what the compiled
  program would, with the same exit status. It needs no mode: it never builds, and keeps every check. `plainly`
  forwards to the oracle's own program, as `git something` runs a separate `git-something`, so the oracle stays
  separate code (D12); if it isn't installed, `plainly oracle` says how to get it. `plainly help` lists it as the
  reference implementation, for testing.

(A formatter isn't needed, since D10 refuses wrong indentation. Commands for tests or new projects, and the messages,
aren't decided yet.)

**Weighed.**
- `apy`, after the compiler, as Plainly v1 had. A second name to learn, and "APY" is a finance term crowding search
  results.
- The oracle as its own command, `plainoracle game.plainly`, as in Plainly v1, to keep it away from beginners. Tankun
  asked "Why not `plainly oracle`?": one name for all of Plainly's tools, with forwarding keeping the oracle separate
  and optional, and the help text saying what it's for.

**Why this won.** Everything is under the language's own name. The oracle's users are the test suite, compiler
developers, the web playground and bug reports, and `plainly oracle` serves all of them without making it part of the
compiler.

**Tankun's words.** "With `plainly oracle`?", "Why would they use it, then?", "So, how is the oracle gonna be tested?",
"Yeah, no shit, sherlock. But what the fuck do you say to run it", "Why not `plainly oracle`?", then, asked "`plainly`
with `run`, `build`, `check` and `oracle`, where `oracle` forwards to the separate oracle program?", the owner chose:
"yea. Names:
PlainCompiler
_Oracle
_GC" (the names are D51).

## D51. The parts are PlainCompiler, PlainOracle and PlainGC

2026-11-20.

**Chosen.** Plainly's compiler is PlainCompiler (D45), its reference implementation PlainOracle (D12, D50), and its
garbage collector PlainGC (D48). The command stays `plainly` (D50).

**Weighed.**
- Plainly v1's AroundPy (AroundPython, APy) for the compiler, a joke about its speed. A name that has to be explained.

**Why this won.** Each name says what the part is, with the language's name in front, so they read as one family of
tools. Tankun named them, writing `_` for "Plain".

**Tankun's words.** In their answer to D50, quoted whole there.

(Changed by D139: the oracle is named `oracle`, not PlainOracle.)

## D52. PlainOracle is written in C

2026-11-20.

**Chosen.** PlainOracle, the reference implementation (D12, D50, D51), is written in C.

(The C standard and compiler, how its memory, tagged values, overflow checks and Unicode are handled, and the guard
rails that keep it obviously correct aren't decided yet.)

**Weighed.** The design claude recommended OCaml throughout, and Tankun chose C.
- OCaml, as Plainly v1's oracle was (its D17): pattern matching that reads like the standard's rules, a garbage
  collector for free, and `wasm_of_ocaml` for the browser playground; a second toolchain, and `Int64` needed for every
  `Whole`.
- C++: `std::variant` and `std::visit` for checked tagged values, and `unique_ptr` and standard containers so memory
  frees itself; a large language needing a strict subset to stay readable.
- SPARK at Silver: checked arithmetic, checked variant records, and a proof that it never crashes, but not that its
  answers are right; pointers only under ownership rules with no garbage collector, and an experimental path to
  WebAssembly.
- The case against C: a bare `union` lets the wrong field be read, memory is freed by hand, text is bytes with no
  Unicode, and signed overflow is undefined behaviour unless every addition uses a checked form such as C23's
  `ckd_add`.

**Why this won.** It's an experiment: Tankun wants to see how many problems C causes. So every problem C causes
in PlainOracle is recorded, as it happens, in [`design/c-problems.md`](design/c-problems.md): what went wrong, which
part of C caused it, how it was caught, and what it cost. C also needs nothing beyond a C compiler, runs everywhere,
compiles to WebAssembly through Emscripten, and is a different language from PlainCompiler's Rust, so the two can't
share code or bugs (D12).

**Tankun's words.** "You know what's fucking funny? Clang C", "Can I see C syntax?", "What about SPARK? Not hardcore
SPARK, though", "C or C++ for PlainOracle, if there's two options only", "C for PlainOracle, and I'm not kidding.",
then, asked for the reason, "My reason for C is that I wanted to see how much problems C would cause, so make sure to
record them."

(Replaced by D129: PlainOracle is an OCaml shell around a core proven in Rocq.)

## D53. PlainOracle is careful modern C: C23, Clang, every warning, and sanitizers on every test run

2026-11-20.

**Chosen.** PlainOracle is written the way a serious C project is today:
- C23, so overflow is checked with the standard `ckd_add`, `ckd_sub` and `ckd_mul`;
- compiled with Clang, with every warning on and warnings treated as errors;
- every test run under AddressSanitizer (memory errors) and UndefinedBehaviorSanitizer (undefined behaviour).

Everything these guard rails catch is still logged in `design/c-problems.md` (D52).

**Weighed.**
- Plain C, with no guard rails. It would mostly measure how many bugs slip through unwatched, which says more about the
  setup than about C.

**Why this won.** D52's experiment measures what C costs as it's really written, and the log then shows both what C
gets wrong and what it takes to catch it.

**Tankun's words.** Asked "Careful modern C (C23, Clang, all warnings, sanitizers on every test run), with everything
the guard rails catch still logged?", the owner chose: "yea. We have naming rules already, right?"

(Replaced by D129: PlainOracle is an OCaml shell around a core proven in Rocq.)

## D54. The layout of a message

2026-11-20.

**Chosen.**

```
refused: game.plainly:5:5, line 5 column 5
 5 |     $lives = $lives - 1;
   |     ^^^^^^
 what:    `$lives` can't be given a new value
 because: line 2 declares it with `let`
 2 |     let $lives: Whole = 3;
   |     ^^^
 why:     only a `var` can be given a new value.
```

- **The first word is the kind:** `refused:` while building, `check failed:` while running.
- **The place is written twice:** `file:line:column` for editors and tools, then `line N column M` for people.
- **The source line is shown,** with `^` under exactly the part in question.
- **Then labelled lines, each only when known, in this order:**
  1. `fix:`, in place of `what:`, when there's exactly one fix; otherwise `what:`, what's wrong;
  2. `when:`, the values that broke a check while running;
  3. `because:`, the earlier place the error comes from, such as a declaration or an earlier error, as a sentence,
     followed by that line with `^` under the part that causes it; in another file, the sentence names the file;
  4. `why:`, the rule, as a plain sentence a beginner can read.
- **No error codes, and no "did you mean" guesses:** only what's certain.
- **Every error is shown,** and a broken line doesn't set off false errors after it: a refused declaration still
  creates its variable with its written type.

(Each message's wording, how columns are counted in text that isn't plain English letters, and the exit statuses
aren't decided yet.)

**Weighed.**
- `because:` as a sentence alone, as first proposed. Tankun asked for the code too: a beginner shouldn't have to
  scroll to find the line that causes the error.
- Showing every line between the two places. A long gap would make a long message.
- Error codes, as C compilers and Rust have. They're for looking up, where Plainly's messages say it all.
- "Did you mean" guesses. A wrong guess is worse than none.

**Why this won.** Each message says where, what, why, and where it came from, in words and in code, with nothing
uncertain. This is Plainly v1's D58 to D60 and Cyborg's format, with `because:` showing its line, as Rust's "declared
here" notes do.

**Tankun's words.** "Where's because? That msg seems like it should have because", "Should we have because show code
too?", then, asked "That message layout, with `because:` showing its line?", the owner chose: "yea".

## D55. Anti-cascade: one mistake gives one message

2026-11-20.

**Chosen.**
1. **After an error, only that statement is skipped,** and checking carries on, so one build shows every real error.
2. **A refused declaration still creates its variable** with its written type (D13), so later lines don't fail
   because it "doesn't exist".
3. **A refused expression's type becomes "unknown",** and nothing is refused for using an unknown value, so one
   mistake can't set off a chain of messages about everything using its result.
4. **Knock-on errors are sorted out:** the first error's fix, when it has exactly one, is applied in memory and the
   program checked again. Anything that disappears was caused by it, and is shown under a `because:` pointing back at
   it (D54), not as an error of its own.
5. **A broken block opener:** if it's clear what was meant, as with a header missing only its `:`, checking carries
   on into the body. If it isn't clear, checking stops there.

**Weighed.**
- Stopping at the first error, as some compilers do. One fix per build, which is slow to work through.
- Skipping a broken block to its `end` and carrying on. With a header too broken to read, the matching `end` can be
  misjudged, making every message after it wrong (Plainly v1's D62).
- Reporting every error as found, with no sorting. A beginner sees ten messages for one typo and starts at the wrong
  one.

**Why this won.** A wrong message is worse than a missing one (D54), and a cascade of false ones buries the real
mistake. This is Plainly v1's D58 and D62, Cyborg's rules, and what v1's PlainOracle did.

**Tankun's words.** "Where's Anti Cascade?", then, asked "Those five anti-cascade rules?", the owner chose: "yea".

## D56. Exit statuses

2026-11-20.

**Chosen.**

| Status | When |
|---|---|
| 0 | the program ran to its end |
| 1 | it was refused while building |
| 2 | the file couldn't be read |
| 3 | `NotBuiltYet` or `NotDesignedYet`: PlainCompiler or PlainOracle can't handle something yet |
| 4 | a check failed while running, like overflow (D46) |
| 5 | a failure left `proc.main`, or `?? crash` stopped the program on purpose (D23) |

`NotBuiltYet` is for something decided but not built yet, and `NotDesignedYet` for something no decision covers yet.
They're the implementations' own limits, not Plainly errors, and use D54's layout with their name as the kind.

(What a failure leaving `proc.main` shows, and how `NotBuiltYet` and `NotDesignedYet` are worded, aren't decided yet.)

**Weighed.**
- One status for every kind of failure, as many programs do. A test couldn't tell "refused" from "crashed" without
  reading the message.
- Status 4 for a deliberate crash too. A failed check is a bug; giving up on purpose isn't.

**Why this won.** Each kind of ending has its own number, so tests and scripts can tell them apart. 1 to 4 are Plainly
v1's D71 and D82; 5 is new, since v1 never decided it.

**Tankun's words.** Asked "Those six exit statuses?", the owner chose: "yea".

## D57. `return value;` gives back a value, and a bare `return;` leaves a procedure that gives nothing back

2026-11-20.

**Chosen.**

```
proc larger($a: Whole, $b: Whole) returns Whole:
    if $a > $b:
        return $a;
    else:
        return $b;
    end if
end proc larger

proc greet($name: Text):
    if $name == "":
        return;
    else:
        show_msg.fmt("Hi, {$name}!");
    end if
end proc greet
```

- **`return value;`** gives back a value, in a procedure with `returns` (D37). It must be the header's type, and every
  way through the procedure must end in one, or the procedure is refused.
- **A bare `return;`** leaves early, in a procedure with no `returns` (D38).
- **Nothing may follow `return` in the same block,** since it could never run, as with D9.
- **A bare `return;` as a procedure's last line is refused,** since the procedure ends there anyway.

(`$name == ""`, comparing text, isn't decided yet.)

**Weighed.**
- `return nothing;`, as in Plainly v1 (its D100), which matched v1's `returns nothing` headers. v2's headers write
  nothing when nothing comes back (D38), so neither does `return`.

**Why this won.** `return` is followed by exactly what the header says comes back: a value, or nothing. Code that can
never run is refused rather than left as a trap.

**Tankun's words.** Asked "`return` like that?", the owner chose: "yea.
What about adding `proc larger(Whole $a, $b) returns Whole:`?
Infront like that means every" (the second part is still being weighed).

## D58. Names have no `$`

2026-11-20.

**Chosen.** A variable's name is a plain word with no mark, written the same where it's made and where it's used:

```
let secret: Whole = random(from: 1, to: 100);
var tries: Whole = 0;
tries = tries + 1;
show_msg.fmt("You got it in {tries} tries.");
proc add(a: Whole, b: Whole) returns Whole:
```

A name can't be a keyword: a program using a keyword as a name is refused. If a later version of Plainly adds a
keyword, a program already using that word as a name stops building and has to rename it.

This replaces D11. Entries before this one write names with `$`. (Replaced by D125, which brings `$` back.)

**Weighed.**
- `$` on every name (D11). It keeps names apart from keywords in text with no colour, which matters most in a language
  that reads in words (`if hp at_least max and not won:`), means a new keyword never breaks a program, and tells
  autocomplete a variable comes next. Tankun: editors are more practical than that, the command line can colour code
  too, and Plainly is a language for learning, not one with Cyborg's guarantees: "If your shit breaks, sorry, but it
  broke".
- `$` only where a name is used, as shell scripts do (`name=Tankun`, `echo $name`). Two spellings for every variable,
  and shell's famous beginner trap.
- Highlighting in place of `$`, as asked. It helps where there's colour, but chats, plain terminals and editors without
  Plainly support show code bare.

**Why this won.** Code is mostly written and read in editors, the command line and the docs, all of which can colour
it, so the mark mostly costs a character per name. Without it, Plainly looks more like Python, as "static Python"
suggests. The costs are accepted: names and keywords look alike where there's no colour, a new keyword can break a
program, and words can't become operators over common names, so multiplying is `*`, not `x` (D59).

**Tankun's words.** Their answer to D57 (quoted whole there), "You can't do that, lol", "yea", has code, "Removing `$` would make it faster, but idk if
that's worth it", "What if we required it at use only?", "Wait, I think we forgot IDEs exist", "Wait, can't highlight
replace `$`?", "But IDEs are alot more practical, and CLI could do highlighting. Plus it's a learn language, rather
than Cyborg-style garuntees. If your shit breaks, sorry, but it broke", "We could replace `x` with `*`, and `*` with
`^`?", "Wouldn't that make it two meanings?", "Wait, then `=` is double meaning. So, maybe we should loosen the
rule?", "No, look at `!=`", "So, then we get `!` marking for free? Or just `*` again?", then, asked "Drop `$`, and
multiply with `*`?", the owner chose: "yea".

## D59. `*` multiplies

2026-11-20.

**Chosen.** `*` multiplies, with a space on each side, as in nearly every language:

```
let total: Whole = price * count;
```

`.*`, the mark on a handler that can jump (D42), is a different symbol: it's written stuck to a dot, so it's read as
one symbol of its own, and never comes where multiplying could. D42 doesn't change.

The rule behind that: **each symbol, read as a whole, has one job.** A longer symbol counts as its own, so pieces
inside it may echo other symbols: `!=` echoes `=`, `|>` echoes `>`, and `.*` echoes `*`. What the rule still refuses
is one whole symbol doing two jobs.

(Dividing, maths order, and going past `Whole`'s range aren't decided yet.)

**Weighed.**
- `x`, the sign taught at school, as in Plainly v1 (its D84). Without `$` (D58), `x` couldn't also be a name, and `x`
  is the most common name in a game, a position.
- Moving the jump mark to `^` (Tankun's idea), or to `!`. Both were allowed once the rule was stated as above, and
  neither adds anything over keeping `.*`, which is Cyborg's and Plainly v1's mark.
- A strict rule that no symbol appears in two meanings, even inside another. `=` already means "gets this value" alone
  and "equal" inside `!=`, as in nearly every language since C, and avoiding that would need `/=` or `:=`.

**Why this won.** `*` is what every other language and calculator app uses, and frees `x` to be a name. Stating the
symbol rule by whole symbols keeps it honest about `=` and `!=`.

**Tankun's words.** Decided with D58, in the same answer (quoted there).

## D60. A symbol has one job in any one place

2026-11-20.

**Chosen.** A symbol may do different jobs in different places, but only one job in any one place:
- `-` between two values subtracts, and right before one negates (D27);
- `<` and `>` between two values compare (D17), and right after a type's name fill it in (D3);
- `*` between two values multiplies (D59), and right after a dot marks a handler that can jump (D42).

Two jobs for one symbol in the same place would be refused as a design. A longer symbol, like `==`, `!=`, `|>` or
`??`, is a symbol of its own, so the pieces inside it don't count.

This replaces D59's wording of the rule ("each symbol, read as a whole, has one job"), which `-` and `< >` already
broke. D59's choice of `*` stands.

**Weighed.**
- "One job unless spacing or position tells the jobs apart at a glance", as the design claude first put it. It says
  the same thing more loosely; Tankun's version names the real line: the place.
- One job per symbol everywhere, as first assumed. `-` and `< >` already break it, and so would `.*`.

**Why this won.** What a symbol does is decided by where it's written, never guessed from the meaning around it, just
as a reader learns `-5` and `a - b` apart without thinking. Tankun put it this way.

**Tankun's words.** "So, what should the loosen rule be?", "No, I meant the symbol", "They aren't in the same place",
then, asked "Record it: a symbol has one job in any one place?", the owner chose: "yea".

## D61. Parameters sharing one type write it once, in front

2026-11-20.

**Chosen.** When a procedure has two or more parameters, all of one type, the type is written once, in front, and
covers them all. With mixed types, or a single parameter, each parameter writes its own type after its name:

```
proc add(Whole a, b) returns Whole:
proc draw(x: Whole, name: Text):
proc double(n: Whole) returns Whole:
```

The other form is refused, with the right one as the fix, so each header has exactly one spelling: the form follows
the situation, and the writer never chooses (D2's aim, as D60 does for symbols).

**Weighed.**
- Each parameter always writing its own type, `add(a: Whole, b: Whole)`, as the design claude recommended. One order
  everywhere, matching `let a: Whole` (D13), and nothing to rewrite when a parameter of another type is added. Tankun
  compared the two side by side and found the short one faster (has code).
- A type in front covering every name after it until the next type, as in C's `int a, b`. The design claude first
  misread Tankun's idea this way; to find a parameter's type you scan back past others, and C's `int* a, b` shows the
  trap.
- Go's order, `add(a, b: Whole)`, type after the names it covers. To find the first name's type you scan forward.
- Allowing both forms. Two spellings for one header.

**Why this won.** With every parameter one type, the short form reads faster: "all Whole" at a glance. Requiring it
exactly then, and the long form otherwise, keeps one spelling per header. The costs are accepted: the type comes first
only in short headers, and adding a parameter of another type means rewriting the header, which the refusal's fix
does.

**Tankun's words.** In their answer to D57 (quoted whole there), then the messages listed in D58; asked "The short form required when two or more parameters share
one type?", the owner chose: "yea".

(Replaced by D126: every parameter writes its own type after its name.)

## D62. PlainCompiler's stages, with one IR of Plainly's own

2026-11-20.

**Chosen.**

```
source → syntax tree → typed tree → Plainly IR → Cranelift IR → native code
```

- **Syntax tree:** the program as written.
- **Typed tree:** names resolved and types attached. Refusals happen here, so `plainly check` (D50) stops after it.
- **Plainly IR:** the one intermediate form of Plainly's own, a graph of simple steps where everything hidden is
  written out: each check (D46), each allocation for PlainGC (D48), labels and defaults filled in, and each handler's
  cases (D42). `final` mode's own optimizations run on it (D46).
- **Cranelift IR,** then native code (D45).

Both build modes take the same path and differ only in optimizations, so a translation bug shows in `working` mode too,
where tests and PlainOracle catch it.

(Which optimizations `final` mode makes isn't decided yet.) (Decided by D124.)

**Weighed.**
- No IR of Plainly's own, going from the typed tree straight to Cranelift. Plainly's own optimizations, like removing
  checks it can prove, need a form that knows Plainly's types and checks, which Cranelift's doesn't.
- Two IRs of its own, as Go has. Go needs them because it writes its own backend; with Cranelift doing the low-level
  work, one is enough.

**Why this won.** It's Swift's shape (its SIL sits between the syntax tree and LLVM), and Plainly v1's D22: one layer of
Plainly's own for its checks and optimizations, with the backend library doing the rest.

**Tankun's words.** Asked "These stages for PlainCompiler?", the owner chose: "yea".

(Changed by D131: the stage after Plainly IR is LLVM IR, not Cranelift IR.)

## D63. The standard library targets the terminal, on `crossterm`; a GUI only as a later package, if ever

2026-11-20.

**Chosen.** Plainly's standard library targets the terminal: showing text (D6), asking (D20), reading single key
presses, colours, drawing at a position and clearing the screen, on Windows, macOS and Linux alike. It's built on
`crossterm`, a Rust crate that handles every terminal's differences, through `extern.rust` procedures (D36). Examples
and the README show terminal games. A GUI, if it ever comes, is a separate package wrapping a library like raylib
behind `extern.rust`, and the language doesn't change for it.

(The library's procedures and names, beyond those decided, aren't decided yet.)

**Weighed.**
- Writing terminal escape codes directly. Every terminal's differences, Windows' especially, would land on Plainly.
- A GUI in the standard library. A far larger library, for games Plainly isn't aimed at first.
- The browser as the main target. multifinity's notes warn that Fale died drifting into a contained sandbox; the web
  playground stays a trailer (D45).

**Why this won.** Offline terminal games are Plainly's first target, and `crossterm` is the proven way to reach every
terminal from Rust. This is Plainly v1's D49.

**Tankun's words.** Asked "The standard library built on `crossterm`, terminal first, with a GUI only as a later
package?", the owner chose: "yea, if ever".

## D64. A program is every `.plainly` file in its folder; packages go in a manifest; `package::` settles a clash

2026-11-20.

**Chosen.**
- **A program is every `.plainly` file (D35) in its folder.** There are no imports between a program's own files: a
  procedure in one file calls one in another directly, in any order. There's exactly one `proc.main` across them all.
- **Packages are listed once, in a manifest file in the folder,** and their procedures are then usable in every file,
  with no imports.
- **Names are used bare,** as in `draw(...)`. When two packages both have a name, the bare name is refused, with the
  fix naming each package's version: `crossterm::draw(...)`. `::` names a package, one level deep, never a path inside
  one.

Every name in a program shares one space, so two of its files can't both declare the same procedure.

(The manifest's name and format, versions, and where packages come from aren't decided yet.)

**Weighed.**
- Import lines at the top of each file, as Python has. More to write in every file, and "which file is this from?"
  puzzles.
- Paths, like Rust's `std::io::stdin`. Tankun refused paths in Plainly v1 (its D39).
- A space of names per file. Two files could both have `helper`, at the cost of imports between them.

**Why this won.** It's Go's shape: a folder is a program, so a beginner never writes an import, and the rare clash is
settled on the spot with the package's name. This is Plainly v1's D39 with v2's files.

**Tankun's words.** Asked "One program per folder, a manifest for packages, bare names with `package::` only for a
clash?", the owner chose: "yea".

## D65. Compiling: one background thread while you edit, every core when you run or build, and a shared cache

2026-11-20.

**Chosen.**
- **Background:** while you edit, PlainCompiler compiles after every save on one thread of its own, inside the editor
  support (the language server), in `working` mode or the mode last run, filling the cache. It never blocks typing,
  and a newer save cancels an unfinished build.
- **Parallel:** `plainly run` and `plainly build` compile whatever the cache doesn't have on every CPU core, procedure
  by procedure, since Cranelift compiles each on its own.
- **Cached:** each compiled piece is saved under a fingerprint of everything that affects it (its code, the compiler's
  version, the mode) in the system's cache folder, shared by every project. Only what changed is recompiled, and a
  build can never differ because of the cache.

Without an editor, `plainly run` compiles on demand, in parallel, with the cache.

(The language server itself, the cache folder's place on each system, and clearing the cache aren't decided yet.)

**Weighed.**
- Background compiling in parallel too. It would take every core while you work, making the editor and a game being
  tested stutter.
- Background checking only, compiling at `run`. `run` would wait for the whole compile.
- A cache per project. The same package compiled again for every game.

**Why this won.** `plainly run` feels close to instant (D45) because most of the work was done while you were typing,
without slowing you down; when you're waiting, everything goes to the build. Keying the cache by fingerprint is how
Cyborg's `okay` keeps cached builds exactly equal to fresh ones.

**Tankun's words.** "no. What about compiling? Para, concur, cached, background?" (what the "no" answered, about threads in
the language, is still to be checked), "Let me answer compiling first. By background I meant that it compiles on
another thread while you work", "Background compiling is on another thread, but not para", then, asked "Background
compiling on one thread while you edit, parallel when you run or build, and a shared cache?", the owner chose: "yea".

## D66. Plainly programs can run several things at once

2026-11-20.

**Chosen.** v2 has threads in the language: a Plainly program can run several parts of itself at once, like a game's
music and its enemies beside the player's turn. This is apart from PlainCompiler's own threads (D65), which only make
building faster.

(How it's written, how parts talk to each other, what may be shared between them, and how PlainGC handles them aren't
decided yet.)

**Weighed.**
- One step at a time, with threads left for later, as the design claude recommended: terminal games rarely need them,
  they bring the hardest bugs (two parts changing one thing at once, results that differ between runs), and they're
  easy to add later but hard to take back.

**Why this won.** Tankun's choice; their reason isn't recorded yet. Real-time terminal games can want music, timers
and enemies moving on their own, and designing it in from the start avoids bolting it on later.

**Tankun's words.** "no. What about compiling? Para, concur, cached, background?" (quoted in D65 too), "What is the
diff?", then, asked "Should Plainly programs themselves run one step at a time in v2, with threads in the language
left for later?", the owner chose: "We should have".

## D67. Tasks taking turns on one thread are the everyday way to run things at once; real threads are opt-in

2026-11-20.

**Chosen.** Running several things at once (D66) comes in two kinds:
1. **Tasks on one thread, the everyday way:** several tasks take turns, and each hands over only at points it chooses,
   like waiting for a key or a timer. Only one runs at any moment, so nothing changes behind a task's back, and the
   turns go in the same order every run.
2. **Real threads on several cores, opt-in,** for when a game needs more speed, like a chess-style search. Only those
   who choose them meet their risks.

```
proc play_music:
    while true:
        play_note("C");
        wait(seconds: 1);
    end while
end proc play_music
```

(The words for starting a task and handing over, and how real threads share or send values, aren't decided yet.)

**Weighed.**
- Real threads only, as the first framing assumed. Every program wanting music beside a game would meet data races.
- Tasks only. A game needing several cores, like a search, couldn't have them.

**Why this won.** Tankun's idea: people who don't want to learn threads use tasks, which can't race and give the same
result every run, as Unity's coroutines, Lua's coroutines and JavaScript's `async` already do for games. Threads stay
there for speed, with their risks landing only on those who reach for them.

**Tankun's words.** "Does ZGC-style GC help?", "What does A give?", "What big data could Terminal games have?",
"ZGC-style GC + A seems very fun", "Lol, Plainly v1 was just abandoned because I didn't get to the fun stuff being
real, ZGC and comoiler", "Can't people who don't wanna learn threads just do "concurrent" single thread?", then, asked
"Tasks on one thread as the everyday way, with real threads opt-in for speed?", the owner chose: "yea".

## D68. Real threads are workers that send each other messages; values that never change can be read by all

2026-11-20.

**Chosen.** The opt-in real threads (D67) are workers:
- **Each worker runs on its own thread, with its own variables.** Nothing changeable is ever shared between two
  workers.
- **Workers talk by sending values,** which arrive as copies.
- **`share` (D49) can't cross from one worker to another;** trying is refused while building. This is what makes data
  races impossible.
- **Values that can never change, like a `let`, may be read by every worker without copying,** since reading alone
  can't race.

```
let search: Worker = start(find_best_move);
send(search, board);
let best: Move = receive(search);
```

(The words, including `Worker`, `start`, `send` and `receive`, are placeholders, and aren't decided yet.)

What it doesn't cover: many threads writing one big thing (a chess engine's shared table), sending big changeable data
often, parallel loops writing into one list, a shared counter, and lock-free techniques; each needs one owning worker,
or splitting the data. And it rules out data races only: messages from several workers can still arrive in different
orders between runs, and two workers each waiting on the other freeze, as in every threading design.

**Weighed.**
- Shared memory with locks (A), as Java, C#, Python and C++ have. It covers every gap above, and pairs well with a
  ZGC-style collector, but a forgotten lock gives data races, bugs that differ between runs and vanish when looked for.
  Played through a 60-minute class, as Tankun asked: half the hour would go on a score that's sometimes wrong, and a
  program passing for the student could fail for the teacher.
- Ownership, as Cyborg and Rust prevent races with. It makes every program, threaded or not, follow borrowing rules:
  "Ah, Ownership is too much to learn" (Tankun). A garbage collector can replace ownership's memory job, but not its
  race job: Go and Java have collectors and data races.
- Locks attached to the data, `Locked<Table>`, as Rust's `Mutex`. Without ownership, a reference can still be kept
  after the lock is let go, so races narrow without going away.

**Why this won.** No data races anywhere, with no ownership to learn, and the cost falls only on code that sends
values between workers. Its gaps are advanced work a beginner class doesn't reach. This is Erlang's processes and
Dart's isolates, with read-only sharing added for the big read-mostly data games have: maps and word lists.

**Tankun's words.** "I heard Cyborg can't do data race, why can't it?", "Ah, Ownership is too much to learn", "But
wait, isn't Ownership just GC with no perf tradeoff? So, can't GC do good too?", "What's your idea, again?", "What does
that not cover", "What about A?", "Okay, let's say we're in a classroom. 60 mins of class: Cranelift ✅, grade more.
Let's go.", then, asked "Real threads as workers that send messages, with values that never change readable by all of
them?", the owner chose: "yea".

## D69. PlainGC is ZGC-style: it moves objects while the program runs

2026-11-20.

**Chosen.** PlainGC is in the style of Java's ZGC:
- one physical heap for every worker's thread (D68), collected while they all keep running, with pauses that stay
  tiny at any heap size;
- it moves objects as it collects, compacting memory so it never fragments, however long a game runs;
- every read of a reference gets a small check, a load barrier, emitted by PlainCompiler, so a moved object is found;
- it's precise, finding references through the stack maps Cranelift records (D45);
- `extern.rust` code (D36) holds handles to Plainly values rather than plain pointers, since objects can move.

This replaces D48's Go-style collector. D49's `copy` and `share` are unchanged.

(How handles work on the Rust side, how a moved object is found, and the order of building it aren't decided yet.)

**Weighed.**
- Go-style (D48): never moves objects, so Rust code keeps plain pointers, with only a write barrier, and roughly
  5,000 to 12,000 lines of Rust by Plainly v1's estimate, against 10,000 to 25,000.
- A simple mark-and-sweep. Easiest to build, with pauses that grow with memory.

**Why this won.** Users never see the difference, so it's the builder's choice, and building a ZGC-style collector is
one of the parts Tankun wants to make real: v1 was abandoned before its compiler and ZGC were built (D67's words). With
workers on many threads sharing one heap (D68), it has real work to do: compacting, and short pauses under many
threads. The cost lands on PlainCompiler's load barriers and on Rust code holding handles.

**Tankun's words.** "Does ZGC-style GC help?" and "ZGC-style GC + A seems very fun" (D67), then, asked "ZGC-style
PlainGC, replacing D48's Go-style?", the owner chose: "yea".

(Replaced by D130: Hylo-style values.)

## D70. `/` divides exactly; `div.floor` and `div.trunc` round

2026-11-20.

**Chosen.**

```
let half: Whole = 8 / 2;
let each: Whole = 7 div.floor 2;
let each: Whole = 7 div.trunc 2;
```

These give 4, 3 and 3. With -7 in place of 7, `div.floor` gives -4 and `div.trunc` gives -3.

- **`/` divides exactly,** with a space on each side, pairing with `*` (D59). A remainder, as in `7 / 2`, is a failed
  check, like overflow: it stops the program in both build modes (D46), with a message pointing to `div.floor` and
  `div.trunc`. `/` is for when the numbers divide evenly, so a remainder is a bug.
- **`div.floor` rounds down to the nearest whole number below,** so -3.5 becomes -4. Python's `//`.
- **`div.trunc` cuts the fraction off,** toward zero, so -3.5 becomes -3. What C, Java and Rust's `/` do. `trunc` is
  short for truncate, and `div` for divide (D2).
- **A bare `div` is refused:** it always says how it rounds.

(Remainders, dividing by zero, dividing floats, and the messages' wording aren't decided yet.)

**Weighed.**
- `div.exact`, a failure the program must handle, as in Plainly v1 (its D85). As `/`, every exact division would need
  `?` or `??`, even `8 / 2`.
- `/` with one default rounding, as Python's `//` or C's `/`. The rounding of negatives is then a surprise to whoever
  expected the other.
- `div.down` and `div.toward_zero`, Plainly v1's words. `.trunc` names the operation in the real word (Tankun asked for it); and "down" gives only a direction, where "floor" says it stops at the nearest whole number
  (Tankun pointed this out).

**Why this won.** `/` reads like maths, where `8 / 2` is exactly 4, and keeps the most common operator free of
failure handling. Rounding division names how it rounds, in the words learners meet everywhere else; floor matters in
games, where positions divided into tiles go wrong with truncation as soon as they're negative.

**Tankun's words.** "Let's design div", "What about `/` is exact only", "What is `div.down` and `div.toward_zero`. Is
that `.trunc`? If so, just say it like that", "What does floor do?", "Ah, so we could use `.down` for floor", "Why is
it called floor?", "`.down` doesn't sound like it says there's a limit, though", then, asked "`/` exact with a
remainder as a failed check, and `div.floor` and `div.trunc` for rounding?", the owner chose: "yea".

## D71. `rem.floor` and `rem.trunc` give the remainder, matching `div`

2026-11-20.

**Chosen.** The remainder, what's left after taking out as many whole groups as fit, is `rem` with the same two
narrowings as `div` (D70), with a space on each side:

```
let left: Whole = 7 rem.floor 2;
let left: Whole = 7 rem.trunc 2;
```

Both give 1. With -7 in place of 7, `rem.floor` gives 1 and `rem.trunc` gives -1.

- **Each remainder matches its division,** so `a div.floor b` and `a rem.floor b` always fit back together into `a`,
  and the same for `.trunc`.
- **`rem.floor`'s remainder has the sign of the number divided by,** as Python's `%`, so wrapping around works:
  `-1 rem.floor 8` is 7, the last square of a board of 8.
- **`rem.trunc`'s has the sign of the number divided,** as C's, Java's and Rust's `%`.
- **A bare `rem` is refused,** as `div` is.
- `rem` is short for remainder (D2).

(Dividing by zero, and remainders of floats, aren't decided yet.)

**Weighed.**
- `%`, as most languages write it. It means floor's remainder in Python and trunc's in C, which is the trap, and Plainly
  may want `%` for percentages.
- `mod`, short for modulo, as Plainly v1 had. "Remainder" is the word school uses.
- One remainder only. The negative-number split would then surprise whoever expected the other.

**Why this won.** Games use the remainder for even and odd, every third turn, and wrapping around a board, and
`.floor` gets wrapping right with negatives, where C's and Java's `%` give the classic bug. Matching `div` means
nothing new to learn.

**Tankun's words.** "What does it do?", then, asked "`rem.floor` and `rem.trunc`, matching `div`?", the owner chose:
"yea".

## D72. Maths order, with brackets required where maths doesn't say

2026-11-20.

**Chosen.** Without brackets, operators go in school maths' order, from first to last:
1. a `-` negating, as in `-7` or `-speed` (D27);
2. `*`, `/`, `div` and `rem`, left to right;
3. `+` and `-`, left to right;
4. comparisons, then `not`, `and` and `or` (D34).

So `2 + 3 * 4` is 14, and `10 - 4 - 3` is 3. Where maths doesn't say which goes first, brackets are required: `&` next
to an unbracketed `+`, `-`, `*`, `/`, `div` or `rem` is refused, so `"Total: " & a + b` needs `( )` to show what's
meant (D3).

Dividing by zero, with `/`, `div` or `rem`, is a failed check that stops the program in both modes, as D46 already
lists.

(Where `|>` sits in this order, and the messages' wording, aren't decided yet.)

**Weighed.**
- An order for `&` against `+`, as most languages pick. A reader would have to remember it, and `"5" & 3 + 4` could be
  read either way.
- Brackets wherever two different operators meet. More brackets than school maths ever needed.

**Why this won.** Where maths has an order, everyone already knows it; where it has none, `( )` shows it rather than a
rule nobody remembers. This is Plainly v1's D83.

**Tankun's words.** Asked "Maths order like that, with brackets required wherever maths doesn't say?", the owner
chose: "yea".

(Changed by D201: `&` goes, and with it the rule for `&` next to maths.)

## D73. `|>` comes last, so a slide takes everything on its left

2026-11-20.

**Chosen.** In D72's order, `|>` comes after everything else: maths, `&`, comparisons and logic. A slide takes the
whole expression on its left:

```
a + 1 |> be.Text |> show_msg;
"HP: " & be.Text(hp) |> show_msg;
```

The first slides `a + 1`, the second the joined text. `( )` around the left side is allowed, and never needed.

**Weighed.**
- `|>` tighter than maths, so `a + 1 |> be.Text` would mean `a + (1 |> be.Text)`, sliding one piece out of a sum,
  which is never what's meant.
- `|>` between maths and comparisons, as Plainly v1's D97 placed it (after maths and `&`). Putting it after
  comparisons and logic too means a slide never cuts into the middle of anything.

**Why this won.** A slide reads left to right as "take all this, then do that". Elixir and F# put their pipes last in
the same way.

**Tankun's words.** Asked "`|>` comes last, after maths, `&`, comparisons and logic?", the owner chose: "yea".

## D74. Comments: `//`, `///` before a declaration, and named `comment name:` blocks

2026-11-20.

**Chosen.**

```
/// Gives the larger of two whole numbers.
proc larger(Whole a, b) returns Whole:
    // the tie goes to b
    if a > b:
        return a;
    else:
        return b;
    end if
end proc larger

comment old_scoring:
    let bonus: Whole = tries * 10;
    show_msg.fmt("Bonus: {bonus}");
end comment old_scoring
```

- **`//` comments to the end of the line,** on a line of its own or after a statement.
- **`///` is a doc comment,** on the lines right before a declaration, which editors show and a docs tool can collect.
  A `///` with no declaration after it is refused.
- **`comment name:` to `end comment name` is a block comment,** shaped like every other block (D8). Everything between
  is ignored, broken code included, and the comment ends only at its own `end comment` with its name, so comment
  blocks can sit inside each other and a stray line can't end one early. Its opening and closing lines follow D10's
  indentation; what's between can be anything.
- Inside text, `//` is just characters: `show_msg("a // b")` shows `a // b`.

(What a docs tool makes of `///`, and which declarations take one, aren't decided yet.)

**Weighed.**
- `#`, as Python has, which the design claude proposed since `#` was free after D58. Tankun's set does more for the
  same learning.
- C's `/* */` block comments. They can't nest, and a stray `*/` inside ends one early.
- No block comments, several `//` lines instead. Switching off a stretch of code means editing every line.

**Why this won.** Each kind has one job: a note, a doc for a declaration, or a stretch switched off. The named block
fits Plainly's `:` and `end` shape and fixes `/* */`'s known bug. Tankun designed the set.

**Tankun's words.** Proposed instead of `#` (has code); then, asked "`//`, `///` before a declaration, and named
`comment name:` blocks?", the owner chose: "yea".

## D75. Lists: `List<Type>`, written in `[ ]`, with items reached by `pos:` or `offset:`

2026-11-20.

**Chosen.**

```
var students: List<Text> = ["Fern", "Plern", "Churn"];
let first: Text = students[pos: 1];
let also_first: Text = students[offset: 0];
```

- **`List<Type>` is a list of one type,** written in `[ ]` with commas (D3).
- **An item is reached with a label saying how it counts,** with no default:
  - `pos:`, short for position (D2), counts as people do, from 1;
  - `offset:` counts steps from the start, from 0.

  A bare `students[1]` is refused.
- **A bad position is a failed check** that stops the program, like overflow (D46): `pos: 0`, or `pos: 4` in a list
  of 3. Where the checker can see it while building, it's refused instead.

(Empty lists, adding and removing items, length, changing an item, and going through a list aren't decided yet.)

**Weighed.**
- Counting from 0 with a bare number, as Python and C do. It's the off-by-one trap, and Plainly is for beginners.
- Counting from 1 with a bare number, as Lua does. Anyone moving to another language then trips the other way.
- One label only. `pos:` alone suits people, but offsets are what arithmetic on positions needs, like the middle of a
  list or wrapping with `rem.floor`.

**Why this won.** The label says how the number counts, so it can't be misread either way, and both ways stay
available. This is multifinity's sketch, as Plainly v1 (its D15) and Cyborg do it.

**Tankun's words.** Asked "Lists like that, with `pos:` and `offset:` and no default?", the owner chose: "yea".

## D76. An empty list is `[]`, and empty text is `""`

2026-11-20.

**Chosen.** The empty brackets and quotes themselves:

```
var hand: List<Text> = [];
var typed: Text = "";
```

`[]` takes its list type from where it goes, which every variable writes (D13).

(Comparing lists and comparing text, as in `hand == []`, aren't decided yet.)

**Weighed.**
- `.empty`, with `[]` and `""` refused, as in Plainly v1 (its D68): an empty pair looks like unfinished work, and
  `.empty` says it's empty on purpose. A word to learn where every other language writes `[]` and `""`.

**Why this won.** Nothing new to learn, as in Python, and since every variable writes its type, `[]` is never
ambiguous. Tankun's choice.

**Tankun's words.** Asked "`.empty` for empty lists and text, with `[]` and `""` refused?", the owner chose: "no";
then, asked "`[]` and `""` for empty lists and text?", the owner chose: "yea".

## D77. Methods are called on a value with a plain `.`, and ones that change it need a `var`

2026-11-20.

**Chosen.** A value's methods are called with a plain `.` after it:

```
var students: List<Text> = ["Fern", "Plern"];
students.add("Mult");
students.remove(pos: 1);
```

- **`.` after a value calls a method; `.` after a word names a kind** (D41), as in `show_msg.same_line`. These are two
  places, so D60 allows it, and highlighting shows which is which: the value is coloured as a variable, the word as a
  procedure or keyword.
- **A method that changes its value can only be called on a `var`;** on a `let` it's refused.

(Which methods lists and text have, how a type's methods are declared, and whether programs can declare their own
aren't decided yet.)

**Weighed.**
- A procedure with `var` at the call, `add(var students, "Mult")`, as Swift's and Hylo's `inout`. It shows the change
  at the call and keeps `.` to one job, but looks least like Python.
- Giving back a new list to store, `students = add(students, "Mult")`. Forgetting the `students =` silently does
  nothing, and each call copies the list.
- Cyborg's `.%` and `.%%`. The design claude first took their `%` for a way around D41's rule for `.`; Tankun corrected
  it: the `%` says how the value is borrowed, because Cyborg makes ownership explicit, and v2 has no ownership (D68).

**Why this won.** It's the most familiar shape there is, Python's and nearly every language's, and reads as English.
`var` still marks every list that can change, where it's declared (D13). Without `$` (D58), `students.add` and
`show_msg.same_line` look alike in plain text, and highlighting tells them apart, as D58 already counts on.

**Tankun's words.** "Isn't it a method?", "Actually, no. It's because Cyborg doesn't do implicit ownership", "There's
highlightung, though", then, asked "Methods on values with a plain `.`, with changing ones only allowed on a `var`?",
the owner chose: "yea. Btw, `let` is deep".

## D78. `let` is deep, and `share` never crosses between a `let` and a `var`

2026-11-20.

**Chosen.** Nothing reachable through a `let` can ever change: not its items, nor the items inside its items. So
`share` (D49) is refused between a `let` and a `var`, either way, with `copy` as the fix:

```
var scores: List<Whole> = [1, 2];
let frozen: List<Whole> = copy scores;
```

- `share` from a `var` into a `let` is refused: the `let` would change whenever the `var` did.
- `share` from a `let` into a `var` is refused: the `var` could change the `let`'s value.
- `share` between two `let`s, or between two `var`s, is allowed.

**Weighed.**
- A shallow `let`, as JavaScript's `const`, where the name can't be given a new value but its list can still change.
  A `let` list could then change under a reader who trusted it, and D68's workers couldn't read it without copying.

**Why this won.** A `let` means what it says all the way down, so a reader never has to check whether something
reachable through it might change. It's what lets every worker read a `let` without copying (D68). Tankun stated it.

**Tankun's words.** "yea. Btw, `let` is deep" (in D77's answer); then, asked "`let` is deep, with `share` refused
between a `let` and a `var`?", the owner chose: "yea".

(Replaced by D130: Hylo-style values.)

## D79. A fact about a value is read with no `()`: a list's length is `.len`

2026-11-20.

**Chosen.** After a value's `.`, a name with `( )` is a method, which does something (D77), and a name with no `( )` is
a fact the value already knows, read without running anything. A list's number of items is the fact `.len`:

```
let count: Whole = students.len;
```

`len` is short for length (D2).

(Which other facts lists and text have, and records' fields, which will be read the same way, aren't decided yet.)

**Weighed.**
- `students.len()`, every name after a value's `.` a method call. One rule fewer for now, but records' fields will
  bring the split back.
- `students.length`, the full word, as first proposed with no `()`. D2's short form is `len`, which Python readers
  know from `len(x)`.

**Why this won.** The `()` tells at a glance whether a line does something or reads something, as D4 has it: `( )`
means "run this", and reading a length runs nothing.

**Tankun's words.** "students.length?", "Why no `()`, btw just `len`", then, asked "`students.len`, read with no
`()`?", the owner chose: "yea".

## D80. Lists change with `.add`, `.remove`, and `=` on an item

2026-11-20.

**Chosen.**

```
students.add("Churn");
students.add("Tankun", pos: 1);
students.remove(pos: 2);
students[pos: 1] = "Mia";
```

- **`.add(item)` puts the item at the end;** `.add(item, pos: n)` or `.add(item, offset: n)` puts it at that place,
  moving the later items along.
- **`.remove(pos: n)`** or **`.remove(offset: n)`** takes an item out, closing the gap.
- **`list[pos: n] = value`** (or `offset: n`) changes one item, with `=` as for a variable (D14).

Each needs a `var` list (D77), and a bad position is a failed check (D75).

(Other list methods, like finding an item, joining lists, or taking a part of one, aren't decided yet.)

**Weighed.**
- `append` and `insert`, Python's names. `add` is the plain word, and one name with an optional place covers both, as
  multifinity's notes had it.

**Why this won.** Plain words, reading as English, with the same `pos:` and `offset:` as reaching an item (D75) and the
same `=` as changing a variable (D14).

**Tankun's words.** Asked "`.add`, `.remove`, and changing an item with `=`?", the owner chose: "yea".

## D81. `??` sticks to the call before it; chains of comparisons and an operator after a step are refused

2026-11-20.

**Chosen.**
1. **`??` belongs to the call right before it,** as `?` does, and takes a single value, `ignore` or `crash` after it
   (D23). So `score + be.Whole(t) ?? 0` means `score + (be.Whole(t) ?? 0)`, and anything bigger after `??` needs `( )`.
2. **Two comparisons in a row, as in `1 < x < 10`, are refused,** with `1 < x and x < 10` as the fix.
3. **An operator after a slide's step, as in `x |> f + 1`, is refused,** since a step must be a procedure (D5), with
   `(x |> f) + 1` as the fix (D73).

**Weighed.**
- `1 < x < 10` meaning "both hold", as in maths and Python. In most other languages it means `(1 < x) < 10`, comparing
  a `Bool`, so a learner moving on would be betrayed by it.
- `??` taking a whole expression after it. It handles one call's failure, so it belongs to that call, and a long
  fallback reads better in `( )`.

**Why this won.** Each closes a gap left by D72 and D73, which the compiler session found, by refusing what could be
misread and giving the one-word or one-bracket fix.

**Tankun's words.** Asked "`??` sticks to its call, chains of comparisons refused, and an operator after a step
refused?", the owner chose: "yea".

## D82. Exit statuses 6 for a wrongly written command, and 7 for a bug in Plainly's own tools

2026-11-20.

**Chosen.** Two more rows for D56's table:

| Status | When |
|---|---|
| 6 | the command itself was written wrong, like `plainly run game.plainly` with no mode, or an unknown command |
| 7 | PlainCompiler or PlainOracle itself went wrong: a bug in the tool, never in the program, with a message saying how to report it |

(The messages for both aren't decided yet.)

**Weighed.**
- 64 and 70, from Unix's `sysexits.h` (64 for a usage mistake, 70 for an internal software error), which the compiler
  session used as placeholders. A few Unix tools follow it, but almost nothing reads those numbers, and one small
  scheme is easier to learn.
- One status for both, or 1. A bug in Plainly must never look like a mistake in the program.

**Why this won.** All of Plainly's statuses stay in one short table, and a test suite can tell a bug in Plainly's tools
from a bug in the program it ran. The compiler session found both gaps.

**Tankun's words.** Asked "Exit statuses 6 for a wrong command, and 7 for a bug in Plainly's own tools?", the owner
chose: "yea".

## D83. Knock-on errors are shown as their own messages, each with `because:` pointing back

2026-11-20.

**Chosen.** D55's rule 4 works this way: when the first error's single fix, applied in memory, makes later errors
disappear, each of those is still shown as a message of its own, with a `because:` line pointing back to the first
error:

```
refused: game.plainly:7:9, line 7 column 9
 ...
 because: it follows from the error at line 3 column 5
```

(The exact wording of that `because:` line isn't decided yet.)

**Weighed.**
- Folding them into the first error's message, as "2 more errors follow from this one". Shorter, but it hides where
  the later trouble is.

**Why this won.** A beginner still sees every line affected, and the `because:` tells them to fix the first error
before the rest, rather than starting at the last and getting confused. It's the compiler session's reading of D55,
and what Cyborg does.

**Tankun's words.** Asked "Knock-on errors shown as their own messages, each with `because:` pointing back to the
first?", the owner chose: "yea"; then, asked to check which of two options that meant, the first, the owner chose:
"yea".

## D84. `fix:` always shows the whole corrected line

2026-11-20.

**Chosen.** A message's `fix:` line (D54) shows the whole line as it should be, not just the piece that changes:

```
refused: game.plainly:4:29, line 4 column 29
 4 |     let tries: Whole = 0
   |                         ^
 fix:  `    let tries: Whole = 0;`
```

**Weighed.**
- Only the piece that changes, as in `fix: ;`, with the `^` showing where it goes. Shorter, but for longer fixes, like
  reordering narrowings or changing `+` to `&`, the reader has to work out how the line ends up, and a piece of
  indentation can't be read at all.

**Why this won.** A beginner can copy the fix straight in, and there's never a doubt about where a piece goes. D10's
indentation fix needs the whole line anyway. It's what the compiler session drafted (its Q18).

**Tankun's words.** Asked "`fix:` always shows the whole corrected line?", the owner chose: "yea".

## D85. The wording of the first batch of refusals: lines, blocks and variables

2026-11-20.

**Chosen.** These messages, drafted by the compiler session in D54's layout, each with its `fix:` showing the whole
corrected line (D84) where there's one:

| Refused | `what:` | `why:` |
|---|---|---|
| a missing `;` (D7) | (a `fix:`) | every statement ends with `;`. |
| a wrong closer (D8) | (a `fix:`) | a closer is `end` and what it closes. |
| `;` after a closer (D8) | (a `fix:`) | a closer stands alone, with no `;`. |
| a missing closer (D8) | `` `end if` is missing before this line `` | every block ends with `end` and what it closes. |
| a missing `:` on an opening line (D8) | (a `fix:`) | a block's opening line ends with `:`. |
| wrong indentation, or a tab (D10) | (a `fix:`) | each level of indentation is 4 spaces, and tabs aren't used. |
| a declaration with no type (D13) | `` `x` needs its type, written after a `:` `` | a declaration always writes the variable's type. |
| `=` on a `let` (D14) | `` `lives` can't be given a new value `` | only a `var` can be given a new value. |
| `=` in a condition (D14) | (a `fix:` with `==`) | `=` gives a variable a value, and is never part of a condition; `==` compares. |
| a missing space around `<`, `>`, `+`, `-` or `*` (D17, D27, D59) | (a `fix:`) | `<`, `>`, `+`, `-` and `*` between two values have a space on each side. |
| spaces around a narrowing's `.` (D18) | (a `fix:`) | a narrowing's `.` touches the words on both sides. |
| text in single quotes (D21) | (a `fix:`) | text is written in double quotes, never single ones like `'hi'`. |

Three drafts shown the first time but not in the table answered here go in the next batch: the `because:` line for `=`
on a `let`, the missing closer at the end of a file, and a missing `:` or `=` in a declaration.

**Tankun's words.** Asked "Do any of those read wrong?", the owner chose: "no.".

(Changed by D132: the spacing `why:` follows one pattern for every operator.)

## D86. The text after every label starts at the same column, the width of `because:`

2026-11-20.

**Chosen.** In every message, the text after `fix:`, `what:`, `when:`, `because:` and `why:` starts at the same column,
one space after the longest label, `because:`, whether or not that message has a `because:`:

```
 what:    `lives` can't be given a new value
 because: line 2 declares it with `let`
 why:     only a `var` can be given a new value.
```

and, in a message with no `because:`:

```
 fix:     `    let tries: Whole = 0;`
 why:     every statement ends with `;`.
```

**Weighed.**
- The widest label in each message, so a message without `because:` sits closer. The column then shifts from message
  to message.

**Why this won.** One rule, with nothing to work out, and every message lines up the same way at a glance. It's how
the compiler session already prints them.

**Tankun's words.** Asked "Text after every label starts at the same column, the width of `because:`?", the owner
chose: "yea".

## D87. The wording of the second batch of refusals

2026-11-20.

**Chosen.** These messages, drafted by the compiler session in D54's layout, with `fix:` showing the whole corrected
line (D84) and the label column of D86. Names and types in them are filled in from the program:

| Refused | `what:` | `because:` | `why:` |
|---|---|---|---|
| `=` on a `let` (D14) | D85's | `` line 2 declares it with `let` ``, with that line shown | D85's |
| the file ending inside a block (D8) | `` the file ends before `end proc.main` `` | | every block ends with `end` and what it closes. |
| a missing `:` in a declaration (D13) | (a `fix:`) | | a declaration writes `:` between the variable's name and its type. |
| a missing `=` in a declaration (D13) | (a `fix:`) | | a declaration gives its variable a first value after `=`. |
| comparing two types (D17) | `` `==` compares two values of one type, and this is a `Whole` and a `Text` `` | | a comparison is between two values of the same type. |
| converting to the type it already is (D22) | `` this value is already a `Text`, so `be.Text` does nothing `` | | converting a value to the type it already is does nothing, so it's refused. |
| `be` with no type (D22) | `` `be` needs the type the value becomes, as in `be.Text` `` | | a value is converted with `be` narrowed by the type it becomes. |
| a call that can fail, unhandled (D23) | this call can fail, and nothing here deals with the failure | | every call that can fail deals with its failure, with `?`, `??` or `otherwise:`. |
| `+` on two texts (D27, D28) | (a `fix:` with `&`) | | `+` is only for numbers, and `&` joins text. |
| a number joined with `&` (D28) | (a `fix:` with `be.Text(...)`) | | `&` joins two pieces of text, and a number becomes text only where `be.Text` says so. |
| a keyword used as a name (D58) | `` `if` is a keyword, so it can't be a name `` | | a name can't be one of Plainly's own words. |

Changed by D89: "but this is a `Whole` and a `Text`".

**Tankun's words.** Asked "Do any of those read wrong?", the owner chose: "no".

(Changed by D132: the keyword message is for procedures' names.)

## D88. The wording of the third batch of refusals: procedures, calls and `return`

2026-11-20.

**Chosen.** These messages, drafted by the compiler session in D54's layout, with D84's `fix:` and D86's label column.
Names, types and numbers in them are filled in from the program:

| Refused | `what:` | `because:` | `why:` |
|---|---|---|---|
| `( )` on a definition with no parameters (D4) | (a `fix:`) | | a definition writes `( )` only when it has parameters. |
| parameters on `proc.main` (D4) | `` `proc.main` takes nothing `` | | only the program's start runs `proc.main`, so it's never given anything. |
| `()` on a slide step with nothing else to pass (D5) | (a `fix:`) | | a step with nothing else to pass is written bare, since the slide gives it its value. |
| a missing label (D24) | (a `fix:`) | | every call writes the labels its procedure chose. |
| a label where there's none (D24) | (a `fix:`) | | a call writes only the labels its procedure chose. |
| a wrong label (D24) | `` this argument's label is `to`, not `upto` `` | | every call writes the labels its procedure chose. |
| too few or too many arguments (D24) | `` `pick` takes 2 values, and this call gives 1 value `` | `` `pick` is declared here `` | a call gives every parameter a value, with its label if it has one. |
| using what a procedure with no `returns` gives (D38) | this call gives nothing back, so it can't be used as a value | | a procedure with no `returns` gives nothing back. |
| `return value;` with no `returns` (D38, D57) | `` `greet` has no `returns`, so it gives nothing back `` | | only a procedure with `returns` gives back a value. |
| a bare `return;` with `returns` (D57) | `` `pick` gives back a `Whole`, so `return` needs one `` | | in a procedure with `returns`, `return` gives back a value of that type. |
| a way through with no `return` (D57) | `` some way through `pick` reaches its end without `return` giving back a `Whole` `` | | every way through a procedure with `returns` ends in `return` and a value. |
| a line after `return` (D57) | this line comes after a `return` in the same block, so it can never run | `` the `return` is here `` | nothing may follow `return` in the same block. |
| a bare `return;` as the last line (D57) | a bare `return;` as a procedure's last line does nothing | | a procedure ends there anyway; `return;` is for leaving early. |
| a line after an `if` that can leave (D9) | this line follows an `if` that can leave | `` the `if` on line 4 can leave `` | when any way through an `if` leaves, nothing may follow its `end if`; code that should run afterwards goes in the ways that don't leave. |
| `break` outside a loop (D32) | this `break` isn't inside a loop | | `break` leaves the innermost loop it's in. |

Changed by D89: "but this call gives 1 value".

**Tankun's words.** Asked "Do any of those read wrong?", the owner chose: "no".

(Changed by D165: the message for brackets on a definition with no parameters is about `[ ]`, not `( )`.)

## D89. The fourth batch of refusals, and "but" where a sentence sets what's expected against what was found

2026-11-20.

**Chosen.** Where a `what:` sets what's expected against what was found, it says "but", not "and". That changes two
wordings already approved, and shapes this batch:
- D87's comparing two types becomes `` `==` compares two values of one type, but this is a `Whole` and a `Text` ``.
- D88's argument count becomes `` `pick` takes 2 values, but this call gives 1 value ``.

The fourth batch, with names and types filled in from the program:

| Refused | `what:` | `because:` | `why:` |
|---|---|---|---|
| a slid value of the wrong type (D5) | `` `f` takes a `Whole` first, but the slid value is a `Text` `` | | a slide passes the value on its left in as the step's first argument. |
| the value after `??` of the wrong type (D23) | `` the call gives a `Whole`, so the value after `??` must be one too, not a `Text` `` | | a value's type has to match where it's used. |
| `labels` not on the first line (D25) | a `labels` line can only be the first line of a procedure's body | | a procedure declares its labels on the first line of its body. |
| a label for a parameter that isn't there (D25) | `` `pick` has no parameter named `lo` `` | | a `labels` line gives labels to the procedure's own parameters. |
| two labels on one parameter (D25) | `` `low` already has a label `` | | each parameter has at most one label. |
| one label on two parameters (D25) | `` two parameters have the label `from` `` | | each label names one parameter, so a call can say which value is which. |
| `-` on something that isn't a number (D27) | `` `-` makes a number negative, but this is a `Text` `` | | a `-` with no space after it makes a number negative. |
| a space after a negating `-` (D27) | (a `fix:`) | | a `-` that makes a value negative has no space after it. |
| `+`, `-` or `*` on anything but two `Whole`s (D27, D59) | `` `+` works on two `Whole`s, but this is a `Bool` and a `Whole` `` | | `+`, `-` and `*` are only for numbers. |
| a `Bool` joined with `&` (D28) | `` `&` joins text, but this is a `Bool` `` | | `&` joins two pieces of text, and anything else becomes text only where `be.Text` says so. |
| `show_msg.same_line.fmt` (D31) | (a `fix:` with `show_msg.fmt.same_line`) | | narrowings go strongest first: `.fmt` changes what's shown, `.same_line` only where it ends. |
| the wrong parameter form (D61) | (a `fix:` with the other form) | | parameters sharing one type write it once, in front, when there are two or more; otherwise each writes its own. |
| both parameter forms in one header (D61) | a header writes one type in front for every parameter, or a type after each, never both | | parameters sharing one type write it once, in front; otherwise each writes its own. |
| `&` next to maths without brackets (D72) | `` `&` is next to maths without brackets, so it isn't clear which goes first `` | the maths is here | where maths doesn't say which goes first, `( )` shows it. |

**Weighed.**
- "and", as drafted. It reads as adding a second fact rather than as the mismatch that's the error. Where "and" adds,
  as in "`+` is only for numbers, and `&` joins text", it stays.

**Why this won.** The message is about a mismatch, and "but" says so. Tankun spotted it.

**Tankun's words.** "I think some may be using "and" wrongly, instead it should be "but"?", then, asked "With those
changes, does the fourth batch read right, and should the two approved ones change too?", the owner chose: "yea\".

(Changed by D132: D61's parameter form gets D126's fix and `why:`, and the both-forms message goes.)

## D90. "Compile time" and "runtime" are the words for when a program is checked and when it runs

2026-11-20.

**Chosen.** The standard, the docs and messages say **compile time** for when PlainCompiler checks a program and turns
it into something that can run, and **runtime** for when the compiled program runs, as in "checked at compile time"
and "a check that fails at runtime". They replace "while building" and "while running".

**Weighed.**
- "While building" and "while running", the plain phrases used until now. Every other language, tutorial and error
  message says "compile time" and "runtime", so a learner meets them almost at once.

**Why this won.** They're the real words, learnt once and used everywhere, as with `.floor` and `.trunc` (D70).
Tankun raised it.

**Tankun's words.** "I think we should use "compile time" and "runtime"? Like, those are very important words. What's
`(or)`? What's "this program has two proc.mains, plus because: the first is here"
What's the "space" in "every name in a program shares one space, so two procedures can’t have one name."", then,
asked "Compile time and runtime everywhere, in place of while building and while
running?", the owner chose: "yea, what about `plainly compile`?"

## D91. The command that makes the file to ship is `plainly compile`

2026-11-20.

**Chosen.** `plainly build` (D50) becomes `plainly compile`:

```
plainly compile game.plainly --final
plainly run game.plainly --working
plainly check game.plainly
```

It still needs a mode (D46), and `run`, `check` and `oracle` stay as they are.

**Weighed.**
- `build`, as D50 had it. A second word for the act D90 calls compiling, and in other tools (Cargo, Go, npm) "build"
  also means fetching packages, running scripts and bundling, which this command doesn't do.

**Why this won.** "Compile time is when `plainly compile` runs": one word for one thing (D2), matching D90. Tankun
raised it.

**Tankun's words.** "yea, what about `plainly compile`?" (in D90's answer); then, asked "`plainly compile` in place of
`plainly build`?", the owner chose: "yea".

## D92. The wording of the fifth batch: `.fmt`, a program's shape, names, unreadable code, overflow and the tools' own messages

2026-11-20.

**Chosen.** These messages, in D54's layout, with D84's `fix:`, D86's label column and D89's "but". Names, types and
values are filled in from the program:

| When | `what:` | `why:` |
|---|---|---|
| a brace that isn't a variable (D29) | `` there's no variable named `nme` here `` | braces in `.fmt` text hold a variable's name, checked at compile time. |
| a calculation or call in braces (D29) | braces in `.fmt` text hold only a variable's name | text never hides a calculation or a call; work it out into a variable first. |
| `.fmt` with no text (D29) | `` `.fmt` takes one piece of text `` | `.fmt` fills in the braces of the text it's given. |
| `.fmt`'s text with a label (D29) | `` `.fmt`'s text has no label `` | `.fmt` fills in the braces of the text it's given. |
| two `proc.main`s (D64) | `` this program has two `proc.main`s ``, with `because:` the first is here | a program has exactly one `proc.main`, where it starts. |
| two procedures with one name (D64) | `` there's already a procedure named `pick` ``, with `because:` the first is here | every procedure in a program needs its own name, since a call has to know which one it means. |
| no `proc.main` (D64) | `` this program has no `proc.main` `` | a program starts with `proc.main`. |
| an unknown variable | `` there's no variable named `x` here `` | a variable is declared with `let` or `var` before it's used. |
| an unknown procedure | `` there's no procedure named `x` `` | a call names a procedure the program or the library has. |
| a procedure used without `( )` (D4) | `` `x` is a procedure, so using it writes `( )` with its arguments `` | a call writes the procedure's name and `( )`. |
| a variable called | `` `x` is a variable, not a procedure `` | only a procedure can be called. |
| a value of the wrong type | `` `x` is a `Whole`, but this value is a `Text` `` | a value's type has to match where it's used. |
| an argument of the wrong type | `` `f` takes a `Whole` here, but this is a `Text` `` | a value's type has to match where it's used. |
| `;` expected | `` `;` should be here, not `x` `` | (none) |
| a line ending early | `` the line ends where `)` should be `` | (none) |
| the file ending early | the file ends where a value should be | (none) |
| overflow, at runtime (D46), as `check failed:` | `` the result is too big for a `Whole` ``, with `when:` the values, as in `9223372036854775807 + 1` | a `Whole` holds whole numbers from -9223372036854775808 to 9223372036854775807. |
| underflow, at runtime (D46), as `check failed:` | `` the result is too small for a `Whole` ``, with `when:` the values | the same. |

The tools' own messages:
- **`internal error:`** (status 7, D82): `what:` the problem; `why:` "this is a bug in PlainCompiler. Please report it at
  https://github.com/Soclets/Plainly/issues, with the program that caused it."
- **`can't read:`** (status 2, D56): `can't read: game.plainly`, then `what:` the system's reason.
- **A wrongly written command** (status 6, D82): `plainly: run and compile need a mode: --working or --final`, then
  how to use the command.

The parser's three messages have no `why:`, since there's no rule to name beyond what's written.

**Weighed.**
- "every name in a program shares one space, so two procedures can't have one name", as drafted. "Space" is
  programmer jargon for a namespace.

**Tankun's words.** Their questions about the first showing are quoted in D90; then, asked "Do any of those read
wrong?", the owner chose: "no".

(Changed by D132: the missing-mode line has backticks.)

(Changed by D135: the command is `cplus`, so its mistakes start `cplus:`, and the internal error names `Clang\n`.)

(Changed by the repository's rename on 2026-11-21: the report address is https://github.com/Soclets/Unio-lang/issues.)

## D93. A variable declared inside a block ends with the block

2026-11-20.

**Chosen.** Whatever is declared inside a block (an `if`'s way, an `else`, a loop's body, an `otherwise` case, a
handler's case) ends where that block ends:

```
if lives > 0:
    let message: Text = "Still alive";
    show_msg(message);
end if
show_msg(message);
```

The last line is refused with D92's "there's no variable named `message` here". After the block, the same name can be
declared again, since that's a new variable. A `var` declared outside and changed inside keeps its new value.

**Weighed.**
- Variables lasting after their block, as in Python. If the block didn't run, the variable never got a value, so the
  compiler would have to prove every way through set it, and a beginner would have to learn why it sometimes exists
  afterwards.

**Why this won.** It's what C, Rust, Java and Cyborg do, and Plainly v1's D102, where a variable leaking out of an `if`
crashed v1's oracle. The compiler session asked (its Q11).

**Tankun's words.** Asked "Variables declared in a block end with the block?", the owner chose: "yea".

## D94. A name in use can't be declared again, and a variable can't take a procedure's name

2026-11-20.

**Chosen.**
- **While a variable is in use,** in its own block or any block inside it, its name can't be declared again. Two
  things get two names:

  ```
  let typed: Text = ask("Your guess: ");
  let guess: Whole = be.Whole(typed) ?? 0;
  ```

  After a block ends, a name declared inside it can be declared again (D93).
- **A variable can't take a procedure's name,** since without `$` (D58), `roll` the variable and `roll()` the
  procedure would look alike.

Both are refused.

(The messages' wording isn't decided yet.)

**Weighed.**
- `shadow` in front, as Plainly v1 chose (its D91): `shadow let guess: Whole = be.Whole(guess) ?? 0;` declares a name
  again, visibly, and may change its type. A keyword for a habit, reusing a name, that mostly saves thinking of a second
  one.
- Allowing it freely, as Python does. A reader has to work out which `guess` each line means.

**Why this won.** Two names for two things is what reading needs: a reader never has to ask which `guess` a line
means. The compiler session asked (its Q12).

**Tankun's words.** Asked "Names in use can't be declared again, and a variable can't take a procedure's name?" with
`shadow` as the alternative, the owner chose: "yea"; then, asked to confirm it was the first, the owner chose: "yea".

(The second half, a variable can't take a procedure's name, is replaced by D127, then restored by D192.)

## D95. Which text `be.Whole` reads

2026-11-20.

**Chosen.** `be.Whole` is forgiving about what players really type, and strict about everything else:

| Text | Result |
|---|---|
| `42`, ` 42`, `42 ` | 42: spaces around the number are ignored |
| `-7` | -7 |
| `+5` | 5 |
| `007` | 7: leading zeros are fine |
| `-0` | 0 |
| `abc`, empty, `4 2`, `4.5`, `1,000`, `1_000` | fails |
| a number too big or too small for a `Whole` | fails |

A failure is handled with `?`, `??` or `otherwise:` (D23), like any other. A number that doesn't fit is bad input, not a
bug in the program, so it fails rather than stopping as a failed check.

(The failure's name isn't decided yet.)

**Weighed.**
- Only digits with an optional `-`, as the compiler did until now. A player typing ` 42` stopped the guessing game.
- Commas between groups of three digits, `1,000` as a thousand, as English and Thai write it. In much of Europe and
  South America `1,000` means one, so it was left out.
- No `+`. Harmless and unambiguous to accept, and Python's `int("+5")` does too; refusing it would only annoy someone
  who's right.
- A too-big number as a failed check at runtime (D46). It comes from input, not a mistake in the program.

**Why this won.** `be.Whole` is mostly used on what a player typed (D20), so a stray space or a leading zero shouldn't
count as "not a number". The compiler session found the gap (its Q13).

**Tankun's words.** "Isn't `1,000` 1000?", "nvm then", "Why is `+` and `-` allowed?", then, asked "`be.Whole` accepting
spaces around the number, a `+` or `-`, and leading zeros, with everything else failing?", the owner chose: "yea".

(Changed by D143: tabs around the number are ignored too.)

## D96. When input runs out, `ask` ends the program quietly, with status 0

2026-11-20.

**Chosen.**
- When there's no more input, because the player pressed the end-of-input key (Ctrl+D on macOS and Linux, Ctrl+Z then
  Enter on Windows) or a file of answers ran out, `ask` ends the program right there, quietly, with exit status 0, as
  if the player chose to quit.
- A last line with no Enter after it still counts as an answer.

**Weighed.**
- `ask` able to fail, so a program could save before stopping (D23). Every `ask` in every program would then need
  handling, even a three-line hello-name program. Writing it as `?? save_game()` (Tankun's question) doesn't work:
  `??` carries on with a value, and `save_game()` gives none and doesn't stop the program.
- Ending with a message and a status of its own. More to learn for something that isn't an error; a message would be
  noise for the player who pressed the key on purpose.

The dangers, accepted: the program stops without a chance to save; status 0 doesn't tell a script that input ran out
(a test still catches it, since its output won't match); and it's silent when a file of answers runs out early. A
narrowed `ask` that reports running out as a failure, for games that want to save on quit, can be added when one
needs it.

**Why this won.** Ending input is something a person does on purpose, and the shell and most terminal programs take
it as "I'm done". It keeps `ask` simple for every program. The compiler session asked (its Q14).

**Tankun's words.** "Doesn't  Control + Z mean undo?", "Does it mean end program?", "Isn't Control + C copy?", "any
danger?", "handle?", "Why not just `?? save_game()`?", then, asked "When input runs out, `ask` ends the program
quietly with status 0, and a last line without Enter still counts?", the owner chose: "yea".

## D97. Blank lines are allowed anywhere, at most one in a row

2026-11-20.

**Chosen.** A blank line may separate the parts of a procedure, or procedures from each other, anywhere in a file. Two
or more blank lines in a row are refused, with the fix closing them up to one.

```
proc.main:
    let secret: Whole = random(from: 1, to: 100);
    var tries: Whole = 0;

    while tries < 7:
        ...
    end while
end proc.main
```

where `...` stands for the loop's body.

(Whether a blank line may have spaces on it, and the message's wording, aren't decided yet.)

**Weighed.**
- Blank lines only between procedures, as the compiler accepted until now. A long procedure can't be split into
  readable parts.
- Any number in a row. A run of blank lines says nothing a single one doesn't, and programs would stop looking alike
  (D10).

**Why this won.** One blank line splits a procedure into parts the way paragraphs split a page, and capping it at one
keeps every program looking the same. The compiler session asked (its Q7).

**Tankun's words.** Asked "Blank lines allowed anywhere, at most one in a row?", the owner chose: "yea".

## D98. All spacing is fixed, and anything else is refused

2026-11-20.

**Chosen.** Beyond D10's indentation and the spacing D17, D18, D27 and D59 already fix, spacing follows one rule,
the spacing every example uses, and anything else is refused with the corrected line as the fix (D84):

| Where | Rule | Right | Refused |
|---|---|---|---|
| around `=`, `==`, `!=`, `&`, `\|>`, `??` | one space each side | `a == b` | `a==b` |
| after `,` and `:` | one space | `add(1, 2)`, `x: Whole` | `add(1,2)` |
| inside `( )` and `[ ]` | none | `(a + b)`, `[1, 2]` | `( a + b )` |
| before a call's `(` | none | `roll()` | `roll ()` |
| anywhere but indentation | never two spaces in a row | | `let  x` |
| at the end of a line, and on a blank line | no spaces | | a space after `;` |

(Spacing inside text is the program's own. The messages' wording isn't decided yet.)

**Weighed.**
- Free spacing, with a formatter to tidy it. A beginner has to know to run it, and diffs fill with spacing changes.

**Why this won.** Every program looks the same (D10), so reading anyone's code feels like reading your own. It's what
Go gets from `gofmt`, built into the checker, with the fix in every refusal. The compiler session asked (its Q8).

**Tankun's words.** Asked "All spacing fixed as above, with anything else refused?", the owner chose: "yea".

## D99. A name is lowercase letters, digits and `_` between words, starting with a letter

2026-11-20.

**Chosen.** A name, of a variable, a procedure, a label or a failure, is made of:
- lowercase English letters `a` to `z`, digits, and `_` joining words, as in `player2`, `x1` and `hp_max_2`;
- starting with a letter, so `2player` is refused;
- with no capitals, so a name is never mistaken for a type, which is capitalised (`Whole`, `List`);
- with `_` only between words: never at the start or end, nor two in a row (`_x`, `x_`, `hp__max` are refused).

(Letters beyond English, and the messages' wording, aren't decided yet.)

**Weighed.**
- Only lowercase words joined by `_`, as the compiler accepted until now. Digits are what games need most:
  `player2`, `x1`.
- Capitals in names, as in `playerName`. Without `$` (D58), a capitalised name could look like a type.
- Any letter, as Python allows. Which letters count, and how two spellings of one letter compare, are questions better
  left until someone needs them; v2 has no Thai (multifinity's notes).

**Why this won.** Names stay easy to read and impossible to confuse with types or numbers. The compiler session asked
(its Q9).

**Tankun's words.** Asked "Names as lowercase letters, digits and `_` between words, starting with a letter?", the
owner chose: "yea".

## D100. Every spacing mistake on a line is one message, with every gap fixed at once

2026-11-20.

**Chosen.** A line with several spacing mistakes (D98), like `    show_msg( "three" ); ` with three, gives one message,
with a `^` under each gap and a `fix:` showing the line fully corrected (D84):

```
 fix:     `    show_msg("three");`
```

(Its wording isn't decided yet; the `why:` drafted for it names the spacing rule once.)

**Weighed.**
- One message per mistake. Each `fix:` corrects only its own gap, so copying one still leaves the rest, and the reader
  goes round once per gap.

**Why this won.** D84's point is that the fix can be copied straight in, and only one message per line keeps that true.
The compiler session leaned the same way.

**Tankun's words.** Asked "Spacing mistakes on one line give one message, with every gap fixed at once?", the owner
chose: "yea".

## D101. `fix:` only when the one fix can be shown as a line; otherwise `what:` says what's wrong

2026-11-20.

**Chosen.** A message has a `fix:` when there's exactly one fix and it can be shown as a corrected line to copy (D54,
D84). Otherwise it has a `what:`, which says what's wrong, as `what:` always does. So extra blank lines (D97), whose fix
is deleting lines, get:

```
refused: game.plainly:4:1, line 4 column 1
 4 | 
   | ^
 what:    2 extra blank lines, after the one on line 3
 why:     one blank line is enough to separate the parts of a program.
```

(That message's wording is drafted, not yet decided.)

**Weighed.**
- A `fix:` in words, "remove blank lines 4 and 5, leaving one", as the compiler session drafted: an exception to D84,
  whose `fix:` is always a line to copy.
- A `what:` as an exception to D54, which gives a `fix:` whenever there's exactly one fix, as the design claude first
  put it. Tankun pointed out that was an exception too.

**Why this won.** Stating what D54 and D84 mean together leaves neither with an exception: a `fix:` is always a line to
copy, and anything that can't be shown that way, like deleting or moving lines, says what's wrong instead.

**Tankun's words.** "Isn't yours also an exception?", "Does that `what:` say fix or the problem", then, asked "`fix:`
only when there's one fix that can be shown as a line, and a `what:` saying what's wrong otherwise?", the owner chose:
"yea".

## D102. The wording of the sixth batch, part one: parameters, narrowings, `else:`, D81, names in use, knock-on errors, names, blank lines and spacing

2026-11-20.

**Chosen.** These messages, in D54's layout, with D84's `fix:`, D86's label column, D89's "but" and D101's `fix:` or
`what:`. Names, types, values and places are filled in from the program:

| When refused | `what:` or `fix:` | `because:` | `why:` |
|---|---|---|---|
| two parameters with one name | `` two parameters are named `x` `` | | each parameter needs its own name. |
| a narrowing written twice | `` `.fmt` is written twice `` | | each narrowing is written once. |
| an unknown narrowing | `` `show_msg` has no narrowing `.x` `` | | `` `show_msg`'s narrowings are `.fmt` and `.same_line`. `` |
| anything after `else:` but `end if` | `` nothing can follow an `if`'s `else:` part but `end if` `` | | `` an `if` has at most one `else:`, and it comes last. `` |
| `1 < x < 10` (D81) | fix: `1 < x and x < 10` | | `` a comparison sets two values against each other; `and` joins two comparisons, naming the middle value twice. `` |
| `x \|> f + 1` (D81) | fix: `(x \|> f) + 1` | | a slide's step is a procedure, so an operator after it goes outside brackets around the slide. |
| `??` not after a call (D81) | `` `??` here doesn't follow a call that can fail `` | | `` `??` deals with the failure of the call right before it. `` |
| a name declared again (D94) | `` `guess` is already in use here `` | `` `guess` is declared here `` | a name in use can't be declared again; two things get two names. |
| a variable or parameter with a procedure's name (D94) | `` `roll` is already a procedure's name `` | `` the procedure `roll` is declared here `` | `` a variable can't take a procedure's name, since `roll` and `roll()` would look alike. `` |
| a variable used after its block (D93) | D92's unknown variable | `` `note` is declared inside a block that has ended `` | D92's unknown variable |
| a knock-on error (D83) | the error's own | it follows from the error at line 3 column 5 | the error's own |
| a bad name (D99) | `` `Score` has a capital letter, but names have none ``, and likewise for a name that starts with a digit, starts with `_`, ends with `_`, or has two `_` in a row | | `` a name is lowercase letters and digits, starting with a letter, with `_` only between words. `` |
| extra blank lines (D97, D101) | 2 extra blank lines, after the one on line 3 | | one blank line is enough to separate the parts of a program. |
| several spacing mistakes on a line (D100) | fix: the corrected line | | `` spacing follows one rule: one space around operators and after `,` and `:`, none inside brackets or before a call's `(`, never two in a row, and none at the end of a line. `` |
| one spacing mistake (D98) | fix: the corrected line | | by its kind: `` `==` has one space on each side. `` / `` `,` and `2` have one space between them. `` / `` no space goes between `(` and `"three"`. `` / spaces never come two in a row, outside indentation. / a line never ends with spaces. / a blank line has no spaces on it. |

An unknown narrowing's `why:` lists the word's narrowings in the same pattern for any number: "`` `x`'s narrowings are
`.a`, `.b` and `.c` ``", or "`` `x`'s only narrowing is `.a` ``" when it has one.

Parameters count as variables for D94: a parameter named `roll` in a program with `proc roll` is refused too.

**Weighed.**
- "`` `show_msg` is narrowed by `.fmt` and `.same_line` ``", as drafted. It can be read as "always narrowed by both
  together", though each works alone and both together are written `show_msg.fmt.same_line`.
- "and/or" there. It fixes the meaning, but it isn't plain English for a beginner, and the slash reads like a symbol.
- "`` `.fmt`, `.same_line`, or both ``". Exact, but clumsy for a word with three narrowings, and "both" says nothing of
  their order, which has its own rule (D89).
- "two comparisons in a row are refused", as the `1 < x < 10` `why:` was drafted. It repeats the refusal and explains
  nothing.
- "`` `Score` has a capital letter, and names have none ``", as drafted. D89's rule wants "but" for what's found against
  what's expected.
- Letting a parameter take a procedure's name. `roll` and `roll()` would look alike all the same.

**Why this won.** Each `why:` names the rule rather than repeating the refusal, and a list of a word's narrowings says
what exists without suggesting how they combine.

**Tankun's words.** Shown the batch and asked "Do all of these read right?", Tankun asked:

> `show_msg is narrowed by .fmt and .same_line.`
> should it be `and/or` or clearer?

Asked "Change that `why:` to "`show_msg`'s narrowings are `.fmt` and `.same_line`"?", the owner chose: "yea". Then,
asked "Do the other rows read right as they are, including parameters counting as variables in the D94 row?", the
owner chose: "yea".

(Changed by D128: the `x |> f + 1` row's fix, `(x |> f) + 1`, is itself a slide of one step, which D128 refuses; for a
slide that short the fix is a call, `f($x) + 1`, and brackets go around slides of three or more.)

## D103. The wording of the sixth batch, part two: the command's own messages, words with no more narrowings, and `NotBuiltYet` and `NotDesignedYet`

2026-11-20.

**Chosen.** These messages, with D86's label column and D89's "but".

**Command mistakes** (status 6, D82). Each first line is followed by how to use the command, as D92's is:

| When | First line |
|---|---|
| no command | `plainly: no command given` |
| an unknown command | ``plainly: `go` isn't a command`` |
| no file | ``plainly: `run` needs a file`` |
| two files | ``plainly: `run` takes one file, but this gives 2`` |
| no mode (D92's) | `plainly: run and compile need a mode: --working or --final` |
| two modes | ``plainly: `run` takes one mode, but this gives both `--working` and `--final` `` |
| a mode on `check` | ``plainly: `check` takes no mode, since it doesn't compile`` |
| an unknown mode | ``plainly: `--fast` isn't a mode; the modes are `--working` and `--final` `` |

**A file that can't be read** (status 2): `can't read: notes.txt`, then a `what:` that's one of "`` a Plainly file's
name ends in `.plainly` ``", "it isn't UTF-8 text", or the system's own reason (D92).

**Internal errors** (status 7, D82): the first line names the part that went wrong, as
`internal error: PlainCompiler itself went wrong, not your program`, or the same with PlainGC. Then a `what:` with the
problem and D92's `why:`, naming the same part: "this is a bug in PlainGC. Please report it at
https://github.com/Soclets/Plainly/issues, with the program that caused it."

**`NotBuiltYet` and `NotDesignedYet`** (status 3, D56), as a pattern, in D54's layout with no `why:`:
- `NotBuiltYet`'s `what:` says what isn't built, with the decisions that decided it: "dividing and remainders, `/`,
  `div` and `rem` (D70, D71), aren't built yet".
- `NotDesignedYet`'s `what:` says what isn't decided, with no number: "X isn't decided yet".

**An unknown narrowing on a word with no more narrowings**, beside D102's: the `what:` is D102's, as
"`` `be.Whole` has no narrowing `.fmt` ``". The `why:` depends on whether the word is already narrowed:
- a plain word with no narrowings: "`` `random` has no narrowings. ``"
- a word that's already a narrowing: "`` `be.Whole` can't be narrowed further. ``"

**Weighed.**
- Every command mistake as one catch-all, "`` `run --working` isn't a command ``", as PlainCompiler printed them while
  none had a wording. It doesn't say which part is wrong.
- "`` `be.Whole` has no narrowings. ``", as drafted for every word with no more narrowings. `be` is narrowed by the
  type (D22), so `be.Whole` is itself a narrowing, and the sentence contradicts that on its face.
- A decision number on `NotDesignedYet` too. There's no decision to point to.

**Why this won.** Each command mistake says which part of the command is wrong, a `NotBuiltYet` points to the decision
that will be built, and "further" admits a narrowing that's already there while saying nothing more goes after it.

**Tankun's words.** Shown part two, and then the row for words with no narrowings, Tankun asked: "`be` does have
narrowings, right?". Asked "For an already-narrowed word with nothing more allowed, should the `why:` be "`be.Whole`
can't be narrowed further"?", the owner chose: "yea". Then, asked "Do they all read right as drafted?" of the rest of
part two, the owner chose: "yea".

(Changed by D130: there's no PlainGC, so the internal error naming PlainGC goes.)

(Changed by D135: `cplus:` in place of `plainly:`, and `Clang\n` in place of PlainCompiler.)

(Changed by the repository's rename on 2026-11-21: the report address is https://github.com/Soclets/Unio-lang/issues.)

## D104. A program that stops with its line open finishes the line on standard output before the message

2026-11-20.

**Chosen.** When a program stops at runtime with a message, such as `check failed:`, while its output's last line is
still open, as after `show_msg.same_line("Your guess: ")`, the runtime first writes the missing line break to standard
output. Then the message goes to standard error as always, starting with its kind:

```
Your guess: 
check failed: game.plainly:9:21, line 9 column 21
```

Every message still goes to standard error, and the program's own output to standard output.

**Weighed.**
- Leaving it, so the message starts on the open line, as in `Your guess: check failed: ...`. The kind, the first word
  of every message (D54), is buried.
- A line break at the start of the message, on standard error, whenever a line was open. The open line belongs to
  standard output, and a message's first line would sometimes be blank, depending on what the program printed before.

**Why this won.** The open line is standard output's, so it's closed there: the program's output always ends with a
complete line, and a message always starts with its kind, in a terminal or read by a tool.

**Tankun's words.** Asked "When a program stops with its line still open, should the runtime finish that line on
standard output before the message?", Tankun wrote: "WHATATTTAYSIUJKSL":", then "Waht?". Shown an example, they asked
"Do we err on stdout or stderr", and told errors go to standard error and that the suggestion was to close the open
line on standard output, the owner chose: "yea".

## D105. `extern.rust` code holds one-call handles, checked by Rust's borrow checker, and kept handles for longer

2026-11-20.

**Chosen.** How `extern.rust` code (D36) holds Plainly values that live in PlainGC's heap (D69):
- **A handle lasts for one call.** The Rust procedure is given a handle for each such value, and Rust's compiler
  refuses code that keeps it past the call.
- **A handle gives a direct look at the value,** such as a `Text`'s letters, with no copying. The look is allowed only
  while nothing can start a collection. Making a new value can start one, so Rust's borrow checker refuses code that
  makes a value while a look is still held, and a look never crosses a collection.
- **A kept handle** holds a value Rust stores beyond one call. PlainGC counts it as a root, so the value stays alive,
  and it's released when the Rust code drops it.

For example, with `call` standing for the current call:

```rust
fn shout(call: &mut Call, text: Handle<Text>) -> Handle<Text> {
    let loud = text.read(call).to_uppercase();
    call.new_text(&loud)
}
```

Only people writing Rust for `extern.rust` procedures see handles; someone writing Plainly never does. The Rust names
in the example are a sketch, PlainGC's to choose under the Code rules.

**Weighed.**
- Copying every value into Rust and back, with no handles. The simplest to build, but every call copies, which grows
  costly once lists like game boards exist, and D69 already chose handles.
- Pinning objects during a call, so PlainGC can't move them. A pinned object blocks compaction, against ZGC's design,
  and nothing checks that the Rust code unpins.

**Why this won.** It keeps D69's moving collector safe with no copying, and the mistakes it guards against are caught
by Rust's own compiler before the program runs, rather than turning up as garbage read at runtime.

**Tankun's words.** Asked "Should handles last for one call, with Rust's borrow checker stopping any look at a value
from crossing a collection, plus kept handles for values Rust stores beyond a call?", the owner chose: "yea. Is there a
rule about including optimizations from the start?" (the question is answered in chat, not a decision).

(Replaced by D130: Hylo-style values.)

## D106. After `ask`, the line counts as ended when the answer was typed at a terminal

2026-11-20.

**Chosen.** For D104, after `ask` the output's line counts as ended when the answer was typed at a terminal, since the
player's Enter has already moved the cursor down, and as still open when the answer came from a file or another
program, since nothing was shown on screen. The runtime checks whether its standard input is a terminal.

**Weighed.**
- Counting the line as still open after every `ask`, as D104 read literally. In a terminal, a message right after an
  `ask` would follow a stray blank line.
- Counting it as ended after every `ask`. With answers fed from a file, as in
  `plainly run game.plainly --working < answers.txt`, a message would land right after `Your guess: `.

**Why this won.** It follows what the player actually saw, so a message starts on a fresh line with no blank line
before it in both cases. Tests feed their input from files, so they keep the line break D104 gives them.

**Tankun's words.** Asked "After `ask`, should the line count as ended when the answer was typed at a terminal, and as
still open when it came from a file?", the owner chose: "yea".

## D107. `extern.rust` code lives in a `rust` folder holding a Cargo project, built and linked by PlainCompiler

2026-11-20.

**Chosen.** The Rust code for a program's `extern.rust` procedures (D36) lives in a folder named `rust` in the
program's folder, beside its `.plainly` files (D64), holding an ordinary Cargo project:

```
my_game/
    game.plainly
    board.plainly
    rust/
        Cargo.toml
        src/lib.rs
```

- PlainCompiler builds it with Cargo and links it into the program.
- Each `extern.rust proc` matches the Rust function with the same name, which takes the call and its handles (D105).
  (Changed by D108: the match is made by a macro naming the procedure, not by the function's name.)
- Since it's a Cargo project, the Rust code can use other crates, like `crossterm` for the terminal.
- Rust needs to be installed only for a program with a `rust` folder.

(How a procedure name with a narrowing, like `show_msg.same_line`, is written as a Rust function's name isn't decided
yet.)

**Weighed.**
- Loose `.rs` files beside the `.plainly` files. Simpler, but a lone Rust file can't use other crates, which is the
  main reason to write Rust at all.
- A separate tool to build the Rust part. One more command, and two builds that can fall out of step.

**Why this won.** It mirrors D64, where a program is what's in its folder, and as an ordinary Cargo project it can reach
the crates games need for the terminal, with one command still building everything.

**Tankun's words.** Asked "Should `extern.rust` code live in a `rust` folder holding a Cargo project, beside the
program's `.plainly` files, built and linked by PlainCompiler?", the owner chose: "yea".

(Replaced by D131: PlainCompiler is C++ on LLVM, and `extern.rust` becomes `extern.cpp`, whose details are open again.)

## D108. An `extern.rust` procedure's Rust function is marked with `#[plainly::procedure("...")]`

2026-11-20.

**Chosen.** Each Rust function for an `extern.rust` procedure is marked with a macro naming its Plainly procedure
exactly as written, replacing D107's match by name:

```rust
#[plainly::procedure("show_msg.same_line")]
fn show_msg_same_line(call: &mut Call, text: Handle<Text>) { ... }
```

- The macro writes the linking glue: a fixed symbol for Cranelift's code to call, and the conversion from the raw
  values passed in into D105's handles, so no `unsafe` lands in the Rust writer's code.
- It checks the Rust function's parameters when the Rust is built.
- The Rust function's own name is free, since the macro's text does the matching, so any Plainly name works, narrowed
  or not.
- PlainCompiler provides the macro, as a small crate the `rust` project depends on.

**Weighed.**
- The Rust function with the same name, as D107 had it, with each narrowing a Rust module: `show_msg.same_line` as
  `show_msg::same_line`. Rust scrambles a module path's symbol (mangling), and `#[no_mangle]` keeps only the last
  name, so `same_line` on two words would clash; every function would also need hand-written `unsafe` glue; and a
  narrowing like `.Text` would make a module named `Text`, which Rust warns about.
- `show_msg_same_line`, `.` written as `_`. It can clash with a procedure really named that.
- `show_msg__same_line`, `.` written as `__`, which can't clash, since D99 bans `__` in names. Rust's compiler warns
  that it "should have a snake case name".

**Why this won.** One line names the procedure exactly and does the linking and the conversion to handles, which the
other ways leave to hand-written `unsafe` code, at the cost of a small crate that PlainCompiler provides.

**Tankun's words.** Shown the module way as the recommendation, Tankun asked: "Why not macro?". Asked "Should each
`extern.rust` procedure's Rust function be marked with `#[plainly::procedure("...")]` naming its Plainly procedure,
with the macro writing the glue that links it?", the owner chose: "yea".

(Replaced by D131: PlainCompiler is C++ on LLVM, and `extern.rust` becomes `extern.cpp`, whose details are open again.)

## D109. `Whole` crosses into Rust as `i64` and `Bool` as `bool`, passed and returned directly

2026-11-20.

**Chosen.** An `extern.rust` procedure's `Whole` values are Rust's `i64` (a 64-bit signed integer, with the same range,
D92) and its `Bool` values Rust's `bool`, as parameters and as what it returns, copied in and out with no handle.
`Text`, which lives in PlainGC's heap, crosses as a handle (D105).

**Weighed.**
- Handles for every value, so all of them cross the same way. Numbers and true/false don't live in PlainGC's heap, so
  nothing moves and a handle would hold nothing.

**Why this won.** Each is Rust's own type of the same size and meaning, so nothing is converted or checked on the way.

**Tankun's words.** Asked "Should `Whole` cross into Rust as `i64` and `Bool` as `bool`, both passed and returned
directly?", the owner chose: "yea".

(Replaced by D131: PlainCompiler is C++ on LLVM, and `extern.rust` becomes `extern.cpp`, whose details are open again.)

## D110. A failing `extern.rust` procedure returns Rust's `Result`, its failures named in the macro and checked against the header

2026-11-20.

**Chosen.** An `extern.rust` procedure that can fail lists its failures in its Plainly header as any procedure does
(D38, D39). Its Rust function returns Rust's `Result`: `Ok` with the value, or `Err` with one of the failures. The
failures are named in D108's macro with the header's own words, and spelled in Rust's casing inside Rust (the Code
rules):

```rust
#[plainly::procedure("load_text", fails = "not_found, unreadable")]
fn load_text(call: &mut Call, name: Handle<Text>) -> Result<Handle<Text>, Failure> {
    ...
    Err(Failure::NotFound)
}
```

PlainCompiler checks that the macro's failures match the Plainly header when it builds the program, and refuses a
mismatch. The message's wording isn't decided yet.

What happens when the Rust code itself goes wrong, rather than failing on purpose, isn't decided yet.

**Weighed.**
- Naming the failure as text, as in `Err("not_found")`. A typo would only show when that failure happens.
- `extern.rust` procedures that never fail, with Plainly code checking their results. Too limiting: reading a file
  can really fail, and that's one of the main things Rust is there for.

**Why this won.** `Result` is how Rust code already says "a value or an error", and checking the names against the
header at build time means a failure the Plainly code doesn't expect can't happen.

**Tankun's words.** Asked "Should a failing `extern.rust` procedure return Rust's `Result`, with its failures named in
the macro and checked against the Plainly header when PlainCompiler builds the program?", the owner chose: "yea".

(Replaced by D131: PlainCompiler is C++ on LLVM, and `extern.rust` becomes `extern.cpp`, whose details are open again.)

## D111. A panic in an `extern.rust` procedure stops the program as an internal error, with status 7

2026-11-20.

**Chosen.** When an `extern.rust` procedure's Rust code panics (goes wrong, rather than failing on purpose, D110), D108's
macro catches the panic at the edge, and the program stops with an `internal error:` and exit status 7 (D82):

```
internal error: the Rust code of `load_text` went wrong, not your Plainly code
 7 |     let level: Text = load_text("level1.txt") ?? "";
   |                       ^^^^^^^^^
 what:    index out of bounds: the len is 3 but the index is 5
 why:     this is a bug in `load_text`'s Rust code, in the program's `rust` folder.
```

- The first line names the procedure; the snippet shows the Plainly line that called it.
- `what:` is Rust's own panic message.
- (Changed by D112: the `why:` also says where in the Rust it went wrong, and what to do.)
- It's a bug, not a failure, so Plainly code can't handle it with `?`, `??` or `otherwise:`.
- Status 7 now means code below the program's Plainly went wrong: PlainCompiler, PlainGC, PlainOracle, or an
  `extern.rust` procedure's Rust code.

**Weighed.**
- A new kind and status for Rust bugs, like `rust failed:` with status 8. One more kind to learn, for what's still a
  bug below the Plainly code.
- Turning a panic into an ordinary failure for the caller to handle. Every call to an `extern.rust` procedure would
  need handling for a bug that shouldn't happen.

**Why this won.** A bug is fixed rather than handled, and one kind and status for every bug below the Plainly code
keeps the list short, while the message still says exactly where the bug is.

**Tankun's words.** Asked "Should a panic in an `extern.rust` procedure stop the program as an `internal error:` with
status 7, naming the procedure, showing the Plainly call, and giving Rust's panic message as the `what:`?", the owner
chose: "yea".

(Replaced by D131: PlainCompiler is C++ on LLVM, and `extern.rust` becomes `extern.cpp`, whose details are open again.)

## D112. A Rust panic's `why:` says where in the Rust it happened, and to fix it there or report it

2026-11-20.

**Chosen.** D111's message ends with a `why:` that names the Rust file and line where the panic happened, which Rust's
panic records, and says what to do:

```
 why:     this is a bug in `load_text`'s Rust code, at rust/src/lib.rs line 42; fix it there, or report it to whoever wrote it.
```

This changes D111's `why:`, which said only where the bug was: "this is a bug in `load_text`'s Rust code, in the
program's `rust` folder."

**Weighed.**
- D111's `why:`. It says where the bug is but not what to do, unlike D103's internal errors, which say how to report
  them.

**Why this won.** The person writing the game can go straight to the line and fix it, and a player of a finished game
knows to tell whoever made it.

**Tankun's words.** "Whyb Doesn't say what to do, though.", then, asked "Should D111's `why:` say where in the Rust it
went wrong, and to fix it there or report it to whoever wrote it?", the owner chose: "yea".

(Replaced by D131: PlainCompiler is C++ on LLVM, and `extern.rust` becomes `extern.cpp`, whose details are open again.)

## D113. PlainGC's pacer is ZGC's: it starts each collection just early enough to finish before the heap's limit

2026-11-20.

**Chosen.** PlainGC decides when to start a collection the way ZGC's pacer does:
- it measures how fast the program allocates, and how long a collection takes;
- it predicts when the heap would reach its limit at that speed;
- it starts a collection just early enough to finish before then, with a safety margin;
- it collects early a few times while it has no measurements yet (warm-up), and now and then while the program is
  quiet, so unused memory isn't held for long.

(The heap's limit isn't decided yet; until it is, the pacer aims at a labelled placeholder. Whether the pacer has any
settings isn't decided either.)

**Weighed.**
- Start once the program has allocated as much as was in use after the last collection, and at least 4 MiB, as Go's
  collector does by default and as PlainCompiler's placeholder did. It scales by itself, needs no limit, and is far less
  to build; the design claude first recommended it, since a terminal game never comes near a limit.

**Why this won.** The pacer is invisible to users, so it's the builder's choice, and building ZGC's is part of the fun
of making PlainGC real (D69). It also keeps memory use bounded, rather than letting it grow to twice what's in use.

**Tankun's words.** Shown the Go-style rule as the recommendation, Tankun said: "Bro, ZGC sounds fun". Then, asked
"Should PlainGC's pacer be ZGC's: measure how fast the program allocates and how long a collection takes, and start each
collection just early enough to finish before the heap's limit?", the owner chose: "yea. What's the setting?" (the
question about settings is the next one).

(Replaced by D130: Hylo-style values.)

## D114. The heap's hard limit is the machine's memory less a reserve; the pacer aims at a soft target; no settings yet

2026-11-20.

**Chosen.**
- **The hard limit,** the most the heap may ever use, is the machine's memory less a reserve for the system and other
  programs: 10% or 1 GiB, whichever is bigger.
- **The soft target,** where D113's pacer aims, is about twice what the program is really using, as ZGC's
  `SoftMaxHeapSize` is a target below its limit. The heap goes past it, up to the hard limit, only when the program
  needs that much.
- **No settings** for the pacer or the limits for now. Optional ones can be added later, when a real need shows up.

```
16 GiB machine, game really using 30 MiB:
  soft target ≈ 60 MiB   ← where the pacer aims
  hard limit  ≈ 14.4 GiB ← the most it may ever use
```

(The soft target's smallest size, so a tiny program doesn't collect all the time, is PlainGC's to tune, since users
never see it.)

**Weighed.**
- The machine's memory less a reserve as the only number, which the pacer aims at too. The pacer would see plenty of
  room and rarely collect, so a small game could grow to gigabytes of garbage and slow the rest of the machine.
- Java's default, a quarter of the machine's memory. A game that really needs more would run out early.
- ZGC's settings (`-XX:SoftMaxHeapSize`, `-XX:ZAllocationSpikeTolerance`, `-XX:ZCollectionInterval` and the like) from
  the start. A terminal game never needs them, and each is something a learner might think they have to understand.

**Why this won.** A program can use nearly the whole machine when it truly needs to, while a small game stays small,
and nothing needs setting.

**Tankun's words.** Asked "Should the pacer have no settings, leaving the heap's limit as PlainGC's only number?",
Tankun said: "So, what about optional settings later, and default to utilize the current hardware entirely, but leave a
little". Then, asked "Should the heap's hard limit be the machine's memory minus a reserve, with the pacer aiming at a
soft target of about twice what's in use, and no settings until one is needed?", the owner chose: "yea".

(Replaced by D130: Hylo-style values.)

(Replaced by D134: the cap is 30% of the machine's memory.)

## D115. Running out of memory stops the program as a failed check, status 4

2026-11-20.

**Chosen.** When the program needs memory and everything up to D114's hard limit is still in use, the program stops
with `check failed:` and exit status 4, at the line that needed the memory, with the numbers in `when:`:

```
check failed: game.plainly:12:19, line 12 column 19
12 |         history = history & guess_text;
   |                   ^^^^^^^^^^^^^^^^^^^^
 what:    the program ran out of memory
 when:    14.4 GiB in use, the most it may use on this computer
 why:     everything the program keeps is still in use, so PlainGC can't free any of it.
```

It can't be handled with `?`, `??` or `otherwise:`. This replaces PlainCompiler's placeholder, a `NotDesignedYet` with
status 3. (Changed by D122: the `when:` says how much more was needed, how much was in use, and the limit.)

**Weighed.**
- A new kind and status, like `out of memory:` with status 8. Clear, but one more kind for what works like any other
  failed check.
- An error the program can catch, as in Java. Plainly has no catching, almost any line can need memory, and a game
  rarely has a sensible way to carry on.

**Why this won.** Running out is a limit hit while running, at a line that can be shown, just like overflow, so it
reads and exits the same way.

**Tankun's words.** Asked "Should running out of memory stop the program as a `check failed:` with status 4, at the
line that needed the memory, with the numbers in `when:`?", the owner chose: "yea".

(Changed by D132: the `why:` no longer names PlainGC.)

## D116. A command with several mistakes shows all of them, one line each, before the usage

2026-11-20.

**Chosen.** When a command has more than one mistake, each gets its own `plainly:` line (D103's wordings), and the usage
follows once:

```
plainly: `run` takes one file, but this gives 2
plainly: `--fast` isn't a mode; the modes are `--working` and `--final`
usage:
  ...
```

The lines follow the order of the command as written, with anything missing, like a mode, last. (Changed by D123: with an unknown mode, the
missing-mode line is left out.)

**Weighed.**
- Only the first mistake, as PlainCompiler showed until now, checking in an order it chose. A second mistake shows only
  after the first is fixed and the command run again.

**Why this won.** It's D54's rule for programs, every error shown, applied to the command, and it leaves no order for
an implementation to choose.

**Tankun's words.** Asked "Should a command with several mistakes show all of them, one line each, before the usage?",
the owner chose: "yea".

## D117. A line after `break;` in the same block is refused, as one after `return` is

2026-11-20.

**Chosen.** A line after `break;` in the same block can never run, so it's refused, as D57 refuses a line after
`return`, with D88's wording and `break` in place of `return`:

```
 what:    this line comes after a `break` in the same block, so it can never run
 because: the `break` is here
 why:     nothing may follow `break` in the same block.
```

**Weighed.**
- Allowing it. The line would sit in the program looking as if it runs, and never would.

**Why this won.** `break` leaves the block as surely as `return` does, so the same rule and the same message cover
both.

**Tankun's words.** Asked "Should a line after `break;` in the same block be refused like one after `return`, with the
same wording?", the owner chose: "yea. So, what would `final` optimize? And does PlainCompiler have para, concur,
cache, background yet?" (the questions are answered in chat, not decisions).

## D118. A `rust` folder is built only when an `extern.rust` procedure uses it

2026-11-20.

**Chosen.** A program with a `rust` folder (D107) but no `extern.rust` procedure doesn't build the folder; it's
ignored.

**Weighed.**
- Building it anyway. Rust code nothing calls would slow every `plainly run`, by many seconds the first time, for no
  gain.
- Refusing the program. Annoying while the Rust code is being started, before any header exists.

**Why this won.** Nothing is lost by skipping it: someone who writes Rust and forgets the `extern.rust` header finds out
as soon as their Plainly code calls the procedure, which is refused as unknown.

**Tankun's words.** Asked "Should a `rust` folder be ignored, not built, when no `extern.rust` procedure uses it?", the
owner chose: "yea".

(Replaced by D131: PlainCompiler is C++ on LLVM, and `extern.rust` becomes `extern.cpp`, whose details are open again.)

## D119. The wording of the seventh batch: `extern.rust`'s refusals and its macro's messages

2026-11-20.

**Chosen.** These refusals, at compile time with status 1, in D54's layout with the `^` under the procedure's header,
from `proc` to its name:

| When refused | `what:` | `why:` |
|---|---|---|
| no `rust` folder (D107) | `` `beep` is `extern.rust`, but there's no `rust` folder beside the program ``, or `` ..., but the `rust` folder has no Cargo.toml `` | `` an `extern.rust` procedure's body is Rust code, in a Cargo project in a folder named `rust` beside the program's `.plainly` files. `` |
| a Cargo.toml with no package name (D107) | `` the `rust` folder's Cargo.toml has no package name `` | `` PlainCompiler links the package the `rust` folder's Cargo.toml names, under `[package]`. `` |
| Cargo isn't installed (D107, D118) | `` building the `rust` folder needs Cargo, Rust's build tool, which isn't installed `` | `` Rust is needed for a program with `extern.rust` procedures; it's installed from https://rustup.rs. `` |
| the Rust doesn't build, after Cargo's own messages (D107) | `` the Rust code in the `rust` folder doesn't build `` | Cargo's messages above say what's wrong in the Rust code. |
| no Rust function for a procedure (D108) | `` no Rust function in the `rust` folder is marked `#[plainly::procedure("beep")]` `` | `` an `extern.rust` procedure's body is the Rust function marked with its name. `` |
| a Rust function of another shape (D109, D110) | `` the Rust function for `count_words` takes a `Text` and a `Whole` and gives back a `Whole`, but this header takes a `Text` and gives back a `Whole` ``, with failures as `` and can fail with `empty` or `too_long` `` | `` a Rust function takes and gives what its header says, with `Handle<Text>` for `Text`, `i64` for `Whole` and `bool` for `Bool`, and names the same failures. `` |
| `?? value` after a call that gives nothing (D38) | `` this call gives nothing back, so `??` has no value to carry on with `` | `` `?? value` carries on with a value in place of the one a call that failed would give. `` |

The macro's own messages, shown by Rust while it builds the `rust` folder:
- "`` a Plainly procedure's first parameter is its call: `call: &mut Call` ``"
- "`` a Plainly procedure's parameter is a `Handle<Text>`, an `i64` or a `bool` ``"
- "`` a Plainly procedure gives back a `Handle<Text>`, an `i64`, a `bool`, or nothing ``"
- "`` a Plainly procedure that can fail gives back `Result<..., Failure>` ``"
- "these aren't the names of failures, separated by commas"

**Weighed.**
- "Rust is needed for a program with a `rust` folder", as drafted. Since D118, a `rust` folder no procedure uses isn't
  built, so it's the `extern.rust` procedures that need Rust.
- `.plainly` without backticks, as drafted. It's text typed in a file's name, like other code in messages.

**Tankun's words.** Asked "Do all of these read right, with my two changes?", the owner chose: "yea".

(Replaced by D131: PlainCompiler is C++ on LLVM, and `extern.rust` becomes `extern.cpp`, whose details are open again.)

## D120. A call whose value isn't used is refused

2026-11-20.

**Chosen.** A call to a procedure that gives back a value, standing alone with its value thrown away, is refused:

```
random(from: 1, to: 6);
```

```
 what:    `random` gives back a `Whole`, but nothing uses it
 why:     a call that gives back a value is used: kept in a variable, passed on, or compared.
```

A call that gives nothing, like `show_msg("Hi");`, stands alone as before. There's no way to throw a value away on
purpose for now; one can be added if a procedure ever needs it.

**Weighed.**
- Allowing it, as C and Python do. The mistake, usually a forgotten `let`, runs silently.
- Allowing it with a way to throw the value away on purpose, like Rust's `let _ = ...`. An extra form to learn before
  anything needs it.

**Why this won.** It catches a real beginner mistake at compile time, and Plainly has refusals, not warnings, so the
choice is between refusing and staying silent.

**Tankun's words.** Asked "Should a call whose value isn't used be refused, with no way to throw a value away for
now?", the owner chose: "yea".

## D121. `?? ignore` only follows a call that gives nothing

2026-11-20.

**Chosen.** `?? ignore` is for a call that gives nothing, like `save_game() ?? ignore;`. After a call that gives a value
it's refused, since a failure would leave nothing to carry on with:

```
let guess: Whole = be.Whole(typed) ?? ignore;
```

```
 what:    `be.Whole` gives back a `Whole`, so `?? ignore` leaves `guess` with nothing if it fails
 why:     `?? ignore` is for a call that gives nothing; after one that gives a value, `?? value` says what to carry on with.
```

(On a line of its own, `be.Whole(typed) ?? ignore;` is refused by D120 anyway, its value unused.)

**Weighed.**
- Allowing it, with some value standing in when the call fails. The value would be one nobody chose.

**Why this won.** Ignoring a failure only makes sense when the call had nothing to give, and `?? value` already says
what to carry on with otherwise.

**Tankun's words.** Asked "Should `?? ignore` be refused after a call that gives a value, with the message pointing to
`?? value`?", the owner chose: "yea".

## D122. Running out of memory's `when:` says what was needed, what was in use, and the limit

2026-11-20.

**Chosen.** D115's `when:` is one line that's true whether memory was full or one piece was too big for what was left:

```
 when:    needed 8.0 GiB more, with 7.2 GiB of the 14.4 GiB it may use on this computer in use
 when:    needed 48 bytes more, with 14.4 GiB of the 14.4 GiB it may use on this computer in use
```

Amounts use the unit that reads best: bytes, KiB, MiB or GiB.

**Weighed.**
- D115's "14.4 GiB in use, the most it may use on this computer". False when one big piece runs out with room left.
- A different line for each case, as PlainCompiler did until now. Two wordings, where one covers both.

**Why this won.** One line, always true, gives every number that explains the stop.

**Tankun's words.** Asked "Should D115's `when:` say how much more was needed, how much was in use, and the limit, in
one line for both cases?", the owner chose: "yea".

## D123. With an unknown mode, the missing-mode line is left out

2026-11-20.

**Chosen.** When a command has an unknown mode, as in `plainly run a.plainly --fast`, D116 shows only the unknown-mode
line, not D92's missing-mode line as well:

```
plainly: `--fast` isn't a mode; the modes are `--working` and `--final`
```

Every other mistake still gets its own line (D116).

**Weighed.**
- Both lines, as D116 gave literally. Both are true, but the second repeats the first and makes one mistake look like
  two.

**Why this won.** The writer tried to give a mode and got its name wrong; the unknown-mode line already names the modes
there are.

**Tankun's words.** Asked "Should the missing-mode line be left out when the command has an unknown mode?", the owner
chose: "yea".

## D124. What `final` mode optimizes: twenty-one optimizations, Graphite-style loop nests built last

2026-11-20.

**Chosen.** `final` mode (D46) makes these optimizations, on Plainly IR (D62) unless marked as Cranelift's. Every one
keeps D46's rule: a program behaves exactly as in `working` mode, and no check is dropped unless it's proved unable to
fail.

1. **Cranelift's full optimizing:** working out known values at compile time, doing a repeated calculation once
   (LLVM's GVN), moving what never changes out of a loop (LICM), simplifying arithmetic, and dropping unused code.
2. **Removing checks that can't fail** (D46).
3. **Inlining small procedures** into the places that call them.
4. **Skipping load barriers** (D69) where nothing between two reads can start a collection.
5. **Keeping short-lived values off the heap** (escape analysis): a value that never leaves its procedure lives on the
   stack, and PlainGC never sees it.
6. **gfortran's trick:** working out which procedures have no side effects (GCC's `-fipa-pure-const`), inlining such a
   procedure into itself, and merging its repeated calls with the same values, so recursive `fib` does
   `2 × fib(n - 2) + fib(n - 3)`.
7. **Recursion into loops,** even with a running total (LLVM's TailCallElim).
8. **Using what an `if` proved,** as in knowing `hp` is positive inside `if hp > 0:` (LLVM's CorrelatedValuePropagation
   and JumpThreading), which feeds check removal.
9. **Constants across procedures:** a procedure always called with the same value gets a version with it built in
   (LLVM's IPSCCP, GCC's `-fipa-cp-clone`).
10. **Fast list fills and copies:** a loop that fills or copies a list becomes the CPU's own fill or copy (LLVM's
    LoopIdiomRecognize).
11. **Unrolling small loops** with a known count (LLVM's LoopUnroll).
12. **Vectorization:** doing 4 or 8 numbers in one CPU step, SIMD (LLVM's LoopVectorize and SLPVectorizer).
13. **Moving check-failure code out of the way,** so hot code stays small and inlines well, knowing from Plainly
    itself, not profiling, that a check's failure path is rare (LLVM's HotColdSplitting and PartialInlining).
14. **Merging identical procedures** (LLVM's MergeFunctions, GCC's `-fipa-icf`).
15. **Moving an unchanging `if` out of a loop,** giving two loops with no `if` (GCC's `-funswitch-loops`).
16. **Swapping nested loops** so memory is walked in order (GCC's `-floop-interchange`).
17. **Reusing a value from the loop's last pass,** as with `cells[i + 1]` becoming the next pass's `cells[i]` (GCC's
    `-fpredictive-commoning`).
18. **Doing a calculation once where some paths did it twice** (GCC's `-ftree-pre` and `-ftree-partial-pre`).
19. **Recording what each procedure reads and changes,** extending 6 to procedures that only read, and 4 across calls
    (GCC's `-fipa-modref`).
20. **Passing only the parts of a value a procedure uses** (GCC's `-fipa-sra`).
21. **Graphite-style loop nests** (GCC's Graphite, LLVM's Polly): a nest of loops is modelled exactly, each pass a
    point in a polyhedron and each dependence an arrow, and reordered, as by tiling, skewing or fusing, so it runs
    faster with the same result. Built last, since it needs lists and loops over them first.

`final` isn't built yet; this says what it makes once it is.

**Weighed.**
- The first five only, as the design claude first put it. Fine for a terminal game, but each optimization is
  invisible to users, so fun to build counts (D69's reasoning), and several fit Plainly especially well: 13 needs no
  profiling because Plainly knows its checks' failure paths are rare.
- Profile-guided optimization, which runs the program first to see where time goes. A second build step to learn.
- `-ffast-math`, which changes decimal maths' answers for speed. Out for good: `final` behaves exactly as `working`
  (D46).
- Leaving Graphite out, since even GCC leaves it off by default, and it's huge and slow to compile with. Tankun wanted
  it.

**Why this won.** None of these changes what a program does, only how fast it runs, so the list is the builder's
choice, and building them, from gfortran's trick to polyhedral loops, is the kind of real compiler work that keeps
Plainly v2 from repeating v1 (D69).

**Tankun's words.** "My mf, what would Final optimize?"; shown five, "Borrow Gfortran's FIB trick too. To see? Fucking
make a Fortran shit, and soAW({fuhy'ieqg;qAOfg" (the design claude built and timed it: `fib(44)` in 3 ms at `-O3`
against 2.62 s unoptimized); shown six, "Any more? Maybe look at LLVM's premade passes"; shown eleven, "C'mon 🥺";
shown fourteen, "Look at GCC's premade too"; shown twenty, "What's Graphite? 🥺". Then, asked "Should `final` make
twenty-one: the twenty plus Graphite-style polyhedral loop optimization, built last?", the owner chose: "Pwease 🥺".

(Changed by D131: the first optimization is LLVM's full optimizing, in place of Cranelift's; and by D130: the fourth,
load barriers, has nothing to work on.)

(Clarified on 2026-11-21: optimization 7 turns a running total into a loop only where the sums are proved to fit.
Reordering checked additions can change which check fails, as `MAX + (1 + -1)` fits where `(MAX + 1) + -1` doesn't, and
D46 forbids that; otherwise only real tail calls become loops. Found by the compiler session.)

## D125. Variable names start with `$` again

2026-11-20.

**Chosen.** A variable's name, a parameter's included, starts with `$`, as D11 had it, replacing D58:

```
let $secret: Whole = random(from: 1, to: 100);
var $tries: Whole = 0;
$tries = $tries + 1;
show_msg.fmt("You got it in {$tries} tries.");
```

What follows from it:
- A name after `$` follows D99: lowercase letters and digits, starting with a letter, with `_` only between words.
- A keyword can be a variable's name, as in `$if`, since `$` keeps them apart; D58's refusal of keywords as names goes.
- `.fmt`'s braces hold the name with its `$`, as in `{$tries}` (D29).
- Procedures, labels, narrowings and types have no `$`.
- `*` still multiplies (D59).

**Weighed.**
- No mark (D58). Faster to type and closer to Python, but names look like keywords where there's no colour, a new
  keyword breaks programs using it as a name, and autocomplete can't tell a variable comes next.

**Why this won.** Tankun missed it. The reasons D11 chose it still hold: a variable is never mistaken for a keyword or
a call, keywords can be added without breaking anyone's names, and variables stand out in text. With the compiler
being rewritten from a clean start (2026-11-21), nothing built has to change.

**Tankun's words.** "yea. Mf, yk? I'm missing `$`, and `$a: Whole, $b: Whole`" (in answer to a question about Verus),
then, asked "Should `$` come back on every name, replacing D58?", the owner chose: "yea".

(Replaced by D192: names have no `$` again.)

## D126. Every parameter writes its own type after its name

2026-11-20.

**Chosen.** Each parameter writes its own type, after its name, as a declaration does (D13), replacing D61's shared type
in front:

```
proc add($a: Whole, $b: Whole) returns Whole:
proc draw($x: Whole, $name: Text):
proc double($n: Whole) returns Whole:
```

D61's short form, `proc add(Whole a, b)`, is refused, with this form as the fix; its message's wording comes with a
later batch.

**Weighed.**
- D61's type written once in front when every parameter shares it. Faster to read for short headers, but two forms to
  learn, and adding a parameter of another type rewrites the header.

**Why this won.** One form everywhere, in the same order as `let $a: Whole`, and nothing to rewrite when a header
grows. Tankun missed it, and the clean start (2026-11-21) means nothing built has to change. The cost is a longer header
when many parameters share a type.

**Tankun's words.** "yea. Mf, yk? I'm missing `$`, and `$a: Whole, $b: Whole`" (quoted in D125), then, asked "Should
every parameter write its own type after its name, `$a: Whole, $b: Whole`, replacing D61?", the owner chose: "yea".

## D127. A variable may share a procedure's name, since `$` keeps them apart

2026-11-20.

**Chosen.** A variable or parameter may have the same name as a procedure, as in `let $roll: Whole = roll();`,
replacing D94's second half. D94's first half stands: a name in use can't be declared again. D102's message for a
variable with a procedure's name goes.

**Weighed.**
- Keeping D94's refusal. Its reason was that `roll` and `roll()` would look alike, which `$roll` no longer does
  (D125).

**Why this won.** With `$`, a variable and a call never look alike, and naming a variable after the procedure that
gives its value reads naturally.

**Tankun's words.** Asked "Should a variable be allowed to share a procedure's name, now that `$` keeps them apart?",
the owner chose: "yea".

(Replaced by D192: without `$`, a variable can't take a procedure's name, as D94 had it.)

## D128. One or two calls are written as calls; three or more in a chain are a slide

2026-11-20.

**Chosen.** Whether a chain of calls, each the first argument of the next, is written as calls or as a slide is decided
by its length, so each has one spelling:

```
show_msg("Hi");                                     one call: a call
show_msg(be.Text($n));                              two: a call
$points |> double |> be.Text |> show_msg;           three or more: a slide
```

- One or two calls are written as calls: `$n |> be.Text |> show_msg` is refused, with `show_msg(be.Text($n))` as the
  fix.
- Three or more are written as a slide: `show_msg(be.Text(double($points)))` is refused, with the slide as the fix.
- A call that starts a slide counts, as in `larger(3, 9) |> be.Text |> show_msg`.
- So D81's fix for an operator after a slide's step brackets a slide of three or more, `($x |> f |> g |> h) + 1`; a
  shorter one is a call, `f($x) + 1`.

Both forms stay: `( )` for a call (D4), slides for chains (D5). The refusals' wording comes with a later batch.

**Weighed.**
- Slides replacing `( )` altogether, as Tankun asked. One way to call, and `$` makes a bare procedure name safe, but
  procedures with two equal inputs get lopsided (`3 |> larger(9)`), calls inside expressions need brackets anyway,
  conditions get harder to read, and it's far from the Python Plainly is modelled on.
- No rule, the writer choosing. Two spellings for every chain, against D2's aim.
- Sliding whenever one call is inside another. `show_msg(be.Text($n))` would need a slide, the guessing game's
  `be.Whole(ask(...)) ?? 0` would need `??` after a slide's step (still undecided), and nested calls inside `&` would
  need brackets around slides.
- Only refusing a one-step slide. Chains would still have two spellings.

**Why this won.** Short calls read like Python, and slides appear exactly where reading inside out starts to hurt:
shown three-deep calls next to their slides, the nested ones read from the middle outwards with brackets to match at
the end. The line at three is a judgement: two-deep nesting is still easy to read, and three-deep is where it stops
being.

**Tankun's words.** "What if pipes replaced?", "slides", "I meant what if they replaced ()", "Yeah, they seem both
useful. But should we enforce a rule on when to use `|>`?", "Show me three-deep with no slide", then, shown them after
being asked "Should calls be one or two deep, and three or more always be a slide?", the owner chose: "yea".

## D129. PlainOracle is an OCaml shell around a checker and evaluator proven in Rocq

2026-11-20.

**Chosen.** PlainOracle follows CompCert's pattern, replacing D52's C and D53's guard rails:
- **Rocq** (formerly Coq), a proof assistant, holds the parts that are Plainly's meaning: the checker (types, names,
  every refusal) and the evaluator (statements, procedures, slides, failures, `Whole` arithmetic with D46's checks,
  and `share` and `copy` as abstract values). They're extracted to OCaml to run.
- **OCaml** holds a thin shell around them: reading and decoding the file, the parser, the wording and layout of
  messages (D54), the command, exit statuses, and the real printing, reading and random numbers, which the evaluator
  only asks for.
- What gets proven, and in what order, isn't decided yet: type safety (a program that passes the checker never gets
  stuck), `Whole` arithmetic giving the exact answer or stopping with its check, and determinism are the candidates.
  So is checking the parser with Menhir's Rocq-proven validator, as CompCert does.

The experiment of D52, recording the problems C causes, ends with it; `design/c-problems.md` stays as its record.

**Weighed.**
- C (D52). The oracle decides who's right when it and the compiler disagree (Building rule 12), so it has to be the
  safe one; Tankun: "If we do that, the oracle genuinely has to be safe. So, I think we fuck C off the oracle".
- Plain OCaml, as Plainly v1's oracle was. The plainest and quickest, with nothing proven.
- OCaml with a small pure core, ready to move to Rocq later, as the design claude recommended.
- Rust with some Verus. Proofs where the oracle should be simplest, showing it can't crash but not that it matches the
  standard.
- OCaml with a SPARK bytecode machine. Two toolchains, a bytecode format, and an unproven step between them.
- SPARK alone. Trees and recursion are SPARK's hardest ground.

**Why this won.** With the core in Rocq, the oracle stops being a program that reads the standard and becomes the
standard written as mathematics, so facts about Plainly itself can be proven, and a proof Rocq accepts can't be wrong,
whoever wrote it. Rocq is built for exactly this, as CompCert shows, where SPARK's Platinum level would fight it.

**Tankun's words.** "If we do that, the oracle genuinely has to be safe. So, I think we fuck C off the oracle", "I
wonder if oracle should be [Rust + some Verus], [OCaml + SPARK], or [OCaml], or [SPARK]", "What would OCaml + SPARK
work?", "CompCert ahh situation, C Logic Pro Max garunteed", "Wait, what? Cock is related to OCaml?", "So... Can we use
that?", "How is Rocq harder than SPARK?", "Is it harder than SPARK Plat?", "So, what parts would be Cock?", "So, the
options now", then the owner chose: "Oracle is 3, decided. I can change tmr, dw. And months? You sure?"

## D130. Memory is Hylo-style: every variable owns its own value

2026-11-21.

**Chosen.** Plainly has mutable value semantics, as in Hylo (github.com/hylo-lang/hylo), borrowing the idea, not the
language:
- **Every variable owns its own value.** Nothing can be shared between two names, so after `var $b: List<Whole> =
  $a;`, changing `$b` never touches `$a`.
- **There are no `copy` or `share` words.** The compiler copies where needed, and skips a copy wherever it can prove no
  one would notice, as Swift's copy-on-write does: a big value is only really copied when one of two holders changes it.
- **References can't be stored.** A procedure can be handed a variable to change for the length of a call, but nothing
  keeps a reference afterwards, so there are no lifetimes to track and nothing can dangle or leak.
- **Something that's really one thing,** like the player every monster targets, is referred to by an ID, like a list
  position, and looked up.
- **No garbage collector:** a value is freed when its owner ends. There are no pauses, no stack maps and no load
  barriers, so any backend works.
- **Workers (D68) never share anything,** so data races are impossible with nothing extra.
- Running out of memory still stops the program as D115 and D122 say.

(The words a parameter uses to say how it's used, Hylo's read, change the caller's value, and take it over, aren't
decided yet, nor how a `Text` or a list crosses into `extern` code.)

This replaces D49 (`copy` and `share`), D69 and D113 to D114 (PlainGC, its pacer and its heap's limits), D105
(handles, made for a moving collector), D78's rule on `share`, and D68's rule that `share` can't cross between
workers. D78's deep `let` stays, and so does D124, but for its 4th optimization (load barriers), which has nothing to
work on.

**Weighed.**
- Swift-style reference counting (ARC). Freed at once with no pauses, but cycles leak unless one side is `weak`, a
  concept learners would meet, and every reference copy updates a count.
- A Go-style garbage collector (D48). Invisible to learners and collects cycles, but needs a collector and the
  backend's stack maps.
- ZGC-style PlainGC (D69), built in the first build. Everything Go-style needs, plus moving and load barriers.
- Hylo's mutable value semantics, in D48's own list, called "the purest, but a research design". The design claude
  undersold it: Plainly borrows the idea, so Hylo being experimental hardly matters.

**Why this won.** "Every variable has its own value" is the simplest model to teach, and Python's classic trap, two names
for one list, can't happen. It gives Rust's safety, nothing dangling, nothing leaking and no data races, with none of
Rust's lifetimes, since references can't be stored. Its costs are IDs for shared things, which games use anyway, three
parameter words, and copies that can occasionally hide a slow spot. With no collector, the backend question is open.
The clever work moves to the compiler proving when copies can be skipped.

**Tankun's words.** In multifinity's chat, relayed, as a leaning: "Motherfucker? Hylo? Yeah, please let your Claude
save that. No copy no share words shit."; added "Memory model: Hylo" to the README's ideas. Here: "Wait, what the fuck?
So, you're fucking telling me we're getting mini Rust with the tradeoff being just slow copies hidden sometimes? All
along sitting there?", then, asked "Should Plainly's memory be Hylo-style values, with automatic copies and no `copy`
or `share` words?", the owner chose: "Bless Hylo, yes".

## D131. PlainCompiler is written in C++, on LLVM for both modes, with `extern.cpp`

2026-11-21.

**Chosen.**
- **PlainCompiler and its runtime are written in C++,** calling LLVM directly, replacing D45's Rust and Cranelift.
- **LLVM does both modes:** `working` with LLVM's optimizing off, `final` with it fully on, plus Plainly's own
  optimizations on Plainly IR (D124). One backend and one path, so D62 holds, with LLVM IR in place of Cranelift IR:
  source → syntax tree → typed tree → Plainly IR → LLVM IR → native code.
- **`extern.cpp` replaces `extern.rust`** (D36): a procedure's body can be written in C++. Where that code lives, how
  it's built and linked, how values cross, how it fails and what happens when it crashes are open again, replacing
  D107 to D112, D118 and D119, which were made for Rust. Their thinking is the starting point.
- PlainOracle stays OCaml and Rocq (D129), now in a different language from the compiler.

**Weighed.**
- Rust and Cranelift (D45), as built in the first build. The least upkeep and the fastest `working` compiles, but most
  of D124 would be ours to build, and it isn't the part Tankun is excited about.
- Rust and LLVM through Lyftar, as Cyborg does. Ties Plainly to Cyborg's stack, so a missing piece in Lyftar means
  switching projects; Tankun works on one language at a time.
- Cranelift for `working` and LLVM for `final`, as Rust is moving towards. Two backends and two paths.
- A TypeScript front with a C++ back. Four languages with the oracle, and TypeScript is slow for compilers; it stays
  for the VS Code extension.
- A GCC fork, Plainly as a GCC front end. GPLv3, a fork to keep merging, and huge builds.

**Why this won.** With D130 there's no garbage collector, which was behind both objections to C++: no moving collector
for C++ code to trip over, and no Rust-only handles forcing a second language. Most of D124 comes free from LLVM, the
Rocq oracle checks the compiler from a different language, and LLVM and C++ are new ground Tankun is excited to build
on. The costs: C++ can crash in ways Rust can't, so it needs strict rules; LLVM's C++ interface changes each year, so
one version is pinned and upgraded yearly; and `working` compiles slower than with Cranelift, which D65's cache and
incremental compiling soften.

**Tankun's words.** On the evening of 2026-11-20: "What if the compiler is TypeScript + C++ + LLVM?", "LLVM + C++ is
very exciting for me, there's practically nothing on that by me, aswell as Swift style memory", "We could just make it
`extern.cpp`?", "But it's less effort than with Lyftar, though", "But i don't do pararell, lol. I can't juggle two
fucking langs at the same time". Then, asked "Should PlainCompiler be written in C++, on LLVM for both modes, with
`extern.cpp`?", the owner chose: "yea. What about the C++ rules?"

## D132. Five wordings brought up to date with D125, D126 and D130, and spacing's `why:` made one pattern

2026-11-21.

**Chosen.** A review of every decided message wording against later decisions changes these:

| Message | Was | Now |
|---|---|---|
| a keyword used as a procedure's name (D87) | what: `` `if` is a keyword, so it can't be a name ``; why: "a name can't be one of Plainly's own words." | what: `` `if` is a keyword, so it can't be a procedure's name ``; why: "a procedure's name can't be one of Plainly's own words." |
| D61's shared-type parameter form (D89) | why: "parameters sharing one type write it once, in front, when there are two or more; otherwise each writes its own." | `fix:` the line with each parameter's own type; why: "each parameter writes its own type after its name, as a declaration does." D89's message for both forms in one header goes |
| running out of memory (D115) | why: "everything the program keeps is still in use, so PlainGC can't free any of it." | why: "everything the program keeps is still in use, so none of it can be freed." |
| a missing space around an operator (D85, D102) | D85's "`<`, `>`, `+`, `-` and `*` between two values have a space on each side." for five operators, D102's "`==` has one space on each side." for the rest | one pattern for every operator: "`+` between two values has one space on each side." |
| the missing mode (D92) | `plainly: run and compile need a mode: --working or --final` | ``plainly: `run` and `compile` need a mode: `--working` or `--final` `` |

**Weighed.**
- Leaving them. Three would teach rules that no longer hold (D125 lets a variable be named `$if`, D126 replaced
  D61's form, and D130 has no PlainGC), and spacing would give two different reasons for the same kind of mistake.
- "`+` has one space on each side.", D102's pattern as it stood, for every operator. A negating `-`, as in `-4`, has
  no space after it (D27); "between two values" keeps it out.

**Why this won.** Each message says what's true now, and the same mistake gets the same kind of reason.

**Tankun's words.** "Anyways, you'll be reviewing the err msgs for now, by yourself. Find real problems, not invent
one. If you aren't sure, bring it to me.", then, asked "Should those five wording fixes go in as proposed?", the owner
chose: "yea".

## D133. `{name}` without `$` in `.fmt` text is refused, with the `$` as its fix

2026-11-21.

**Chosen.** In `.fmt` text, braces hold a variable's name with its `$` (D125). A name in braces without its `$` is
refused. When the program has a variable of that name, the fix adds the `$`:

```
show_msg.fmt("You got it in {tries} tries.");
```

```
 fix:     `    show_msg.fmt("You got it in {$tries} tries.");`
 why:     braces in `.fmt` text hold a variable's name, with its `$`.
```

With no such variable, D92's message for a brace that isn't a variable applies. Literal braces are written `\{`, as
before (D30).

**Weighed.**
- `{tries}` as plain text, since only `{$...}` would fill in. Literal braces would never need escaping, but a
  forgotten `$`, the easy mistake right after D125, would show `{tries}` to the player, and nothing would catch it.

**Why this won.** `.fmt` text is checked at compile time (D29), so a forgotten `$` is caught with the fix ready, not
printed wrong.

**Tankun's words.** Asked "Should `{name}` without `$` in `.fmt` text be refused, with the `$` added as its fix?", the
owner chose: "yea".

(Replaced by D192: braces hold the bare name, since names have no `$`.)

## D134. A program may hold at most 30% of the machine's memory

2026-11-21.

**Chosen.** The runtime caps the memory a program holds at 30% of the machine's memory, with no settings. A program that
needs more stops as D115 says, with `check failed:` and status 4 at the line that needed it, and D122's `when:`
naming the cap:

```
 when:    needed 1.0 GiB more, with 6.8 GiB of the 7.2 GiB it may use on this computer in use
```

| Machine's memory | Cap |
|---|---|
| 4 GiB | 1.2 GiB |
| 8 GiB | 2.4 GiB |
| 16 GiB | 4.8 GiB |
| 24 GiB (Tankun's Mac) | 7.2 GiB |
| 32 GiB | 9.6 GiB |

This replaces D114's limit, the machine's memory less 10% or 1 GiB, which D130 had left without a collector to belong
to.

**Weighed.**
- No cap of its own, leaving it to the system. macOS and Linux rarely refuse memory outright: the machine swaps and
  crawls, then the system kills the program with no Plainly message, so D115's message would almost never appear.
- D114's limit, 21.6 GiB on Tankun's Mac. With a browser and an editor open, the machine would swap before a runaway
  program reached it. It suited PlainGC, which paced itself against its limit.
- Half the machine's memory, as the design claude recommended. 30% stops a runaway program sooner, and still leaves
  hundreds of times what a terminal game uses, even on a 2 GiB machine.

**Why this won.** The cap's only job is to stop a runaway program, like a list that grows forever, with a clear message
at the line that did it, before the machine slows down; a terminal game uses a few megabytes, so it never comes close.

**Tankun's words.** "How much?", "Wait, did you just say my MacBook can't handle a browser and editor opened?", "Why
not lower?", "What about 30%?", "What if 4GB machine?", then, asked "Should the runtime cap a program at 30% of the
machine's memory?", the owner chose: "yea".

## D135. The language is C+, with `.cplus` files, and its compiler is `Clang\n`, typed `cplus`

2026-11-21.

**Chosen.**
- **The language is C+.** Its files end in `.cplus`, as in `game.cplus`, replacing D35's `.plainly`.
- **The compiler is `Clang\n`,** with a backslash and an `n` in its name, not a real new line, in the family of
  CyborgPL's `KAYO\n` and Cyborg's `OKAY\n` (Cyborg's D222). It replaces the working name PlainCompiler (D51).
- **It's typed `cplus`,** as in `cplus run game.cplus --working`, `cplus compile game.cplus --final`, `cplus check
  game.cplus` and `cplus oracle game.cplus`, replacing D50's and D91's `plainly`. Cyborg types its compiler's name, as
  `okay`, but `clang` is already LLVM's C compiler on every Mac with Xcode's tools, and the one `Clang\n` is built with
  (Building rule 3); and the command named after the language is the one a learner can guess.
- Plainly IR is now C+ IR. PlainOracle keeps its name for now. The repository, `Soclets/Plainly`, isn't renamed by this.

**Weighed.**
- Keeping Plainly, as the design claude recommended twice: unique, searchable, and it says what it's for. "C+" is
  crowded as a search term, a school grade first and C++ shorthand second, and reads as "a bit more than C", while the
  language is "static Python, built for reading". Tankun weighed it and preferred C+.
- Sabai (Thai for "at ease"), suggested by the design claude, free as a language name.
- AroundBash for the compiler, so that "C+'s performance is AroundBash"; HNGC (Has No GC) for the memory model.
- `Plain\n`, typed `plain`, with Plainly kept.
- A name borrowing Hylo's, which would copy Hylo; and a "C Bust Bust" set, a joke on C++'s name that Cyborg can make
  and C+ couldn't.
- Typing `clang`, as Cyborg types `okay`. It clashes with LLVM's `clang`.

**Why this won.** It's the set Tankun liked most. The name is a joke, in the same spirit as the README's "around Bash"
note and the `\n` compilers of Tankun's other languages, and the typed command stays plain for learners.

**Tankun's words.** "Kinda want to rename lang to C+ (`.cplus`), compiler to AroundBash (So I could say `C+'s
performance is AroundBash`), and its memory model to HNGC (Has No GC)", a screenshot of a Google search for "C+" with
"Huh?", "Where did you get that?", "Here's the thing, `1 + 1` is wrong. It's actually 11", "No, it's a joke. The search
engine is supposed to give 11, by that rule", "Okay, okay. Now, new name suggestions in fr", "My set is still `C+`
(`.cplus`) lang, `Clang\n` compiler (yes, with newline char, not a real newline), lol", "Or another set (forget the GC
name): `Plainly` (`.plainly`), `Plain\n` (same joke as `OKAY\n`and `KAYO\n`)", then:

> Yumminess from most to low in sets:
>
> 1. C+ set
> 2. Hylo's name (which is copying Hylo, which I can't do)
> 3. Plainly set
> 4. Cbb set (C Bust Bust, Cyborg can do those jokes. Plainly would get me sued)

then "`cplus` is a lot easier, they don't have to know cmpiler", and, asked "should I log the full set as decided, C+
with `.cplus` files, compiler `Clang\n`, typed `cplus`?", the owner chose: "yea".

(Changed by D136: the language is Unio, with `.unio` files, typed `unio`.)

## D136. The language is Unio, with `.unio` files, typed `unio`

2026-11-21.

**Chosen.** The language is **Unio**, Latin for "oneness": one owner each, as D130's memory gives every variable its
own value. Its files end in `.unio`, as in `game.unio`, and the command is `unio`, as in `unio run game.unio
--working`. This replaces C+, `.cplus` and `cplus` from D135; the compiler stays `Clang\n` for now. C+ IR is now Unio
IR.

**Weighed.**
- C+ (D135). Crowded as a search term, a school grade first and C++ shorthand second, and it reads as "a bit more than
  C".
- Unlo, Tankun's first spelling. Free too, but it means nothing, and looks nearly the same as Unio in many fonts.
- Plainly and Sabai, as in D135.

**Why this won.** The name says the language's central idea, one owner for each value, and nothing else uses it as a
language's name, so it searches cleanly.

**Tankun's words.** "What about Unlo? (`.unlo`)", then "Unio: Latin for “oneness”, one owner each", then, asked
"Should the language be Unio, with `.unio` files and the command `unio`?", the owner chose: "yea. What about the
compiler? `Unlo\n`?"

(Changed by D137: the compiler is `Unlo\n`.)

## D137. The compiler is `Unlo\n`, typed `unio`

2026-11-21.

**Chosen.** The compiler is **`Unlo\n`**, with a backslash and an `n` in its name, not a real new line, replacing
D135's `Clang\n`. It's typed `unio`, the language's name (D136). In many fonts, Unlo and Unio are hard to tell apart,
as CyborgPL's `KAYO\n` and Cyborg's `OKAY\n` swap letters (Cyborg's D222).

**Weighed.**
- `Clang\n` (D135). Every message and build log would mix it up with LLVM's real Clang, which builds the compiler
  itself (Building rule 3).

**Why this won.** It keeps the family's `\n` joke, now as a near-lookalike of the language's own name, with no clash
with any real tool, and learners only ever type `unio`.

(Changed by D191: the compiler is `Beta++`.)

**Tankun's words.** "yea. What about the compiler? `Unlo\n`?" (in D136's answer), then, asked "Should the compiler be
`Unlo\n`, typed `unio`?", the owner chose: "yea".

## D138. Three licences: Apache-2.0 WITH LLVM-exception for the implementation, MIT-0 for examples, CC BY 4.0 for prose

2026-11-21.

**Chosen.**
- **The implementation,** meaning the compiler, its runtime, PlainOracle, `check/` and the tools: Apache-2.0 WITH
  LLVM-exception (`LICENSE`), as D1 had it for all code.
- **Examples and demos:** MIT-0 (`LICENSE-MIT-0`), with no conditions at all, not even credit: everything in
  `examples/`, the test programs in `tests/`, `design/benchmarks/`, and every code sample inside the Markdown files.
- **Prose,** the text of the Markdown files apart from their code samples: CC BY 4.0 (`LICENSE-CC-BY-4.0`), as D1 had
  it.
- The README says which is which, as Google's, Mozilla's and Microsoft's docs do for their code samples, and
  `REUSE.toml` maps each file to its licence for `reuse lint`. An example file starts with
  `// SPDX-License-Identifier: MIT-0`, so the licence travels with a copy.

Whether Unio takes code contributions isn't decided yet.

**Weighed.**
- D1 as it stood. Code samples in the docs and the examples counted as writing, under CC BY 4.0, so a kid copying one
  would owe credit.
- MIT-0 OR Apache-2.0 for all code. Kids would have nothing to worry about, but nobody would owe credit for the
  compiler's source either, and Cyborg, CyborgPL and Lyftar all use D1's pair.
- CC0. Gives up CC BY's protection for the prose: reusers must mark their changes and may not imply Tankun endorses
  them. And for code, CC0 grants no patent rights, which is why the OSI never approved it and Fedora stopped accepting
  it for code.

**Why this won.** Each kind of material gets what it needs: a beginner or a kid remixing an example has no legal
strings at all; the implementation keeps D1's three reasons, compiled programs owing nothing, GPLv2 compatibility and a
patent promise, with credit on its source; and the prose keeps its protection against being passed off as Tankun's.

**Tankun's words.** "What license is it?", "What about MIT0 OR Apache 2.0 for code?", "It's just because beginner or
kids copying the shit to remix don't have to worry about legal stuff.", "I only chose CC BY 4.0 because of "pretend to
be use" protection", "What is Apache 2.0 there for? What if we do MIT0 and CC0", "Would we accept contributions,
though?", "How about Apache 2.0 WITH LLVM exception for impl, MIT0 for examples & demos, CC BY 4.0 for prose", "How do
you even use it like that?", "What's the legal way to do that? The codeblock thingy", then, asked "should the licences
be Apache-2.0 WITH LLVM-exception for the implementation, MIT-0 for examples and demos, including code blocks in the
docs, and CC BY 4.0 for the prose, with a notice in the README saying which is which?", the owner chose: "yes".

## D139. The oracle is named `oracle`

2026-11-21.

**Chosen.** The reference implementation is called **`oracle`**, replacing the working name PlainOracle (D51). It runs
as `unio oracle game.unio` (D50, D136), as before.

**Weighed.**
- PlainOracle, the working name from Plainly's naming, which D136 and D137 left behind: the language is Unio and the
  compiler `Unlo\n`.

**Why this won.** It says what it is, and it's already the word in the command.

**Tankun's words.** "It's actually just `oracle`".

(Changed by D141: the oracle's name is Ralph; `oracle` stays its role and its command.)

## D140. `oracle` is built first, to a finish line, then `Unlo\n`

2026-11-21.

**Chosen.** `oracle` (D129, D139) is built before `Unlo\n`, changing D12's order. Its first milestone is done when
it passes every test in `tests/` and runs the guessing game, with type safety and the exactness of `Whole`
arithmetic proven for that subset. Then `Unlo\n` starts, and `oracle` keeps growing alongside it.

The subset is what the tests and the guessing game use: `Whole`, `Bool` and `Text`; `let` and `var` with `$` names and
`=`; `+`, `-` and `*`, negatives and overflow; `&`, `be.Text`, `be.Whole` and `.fmt`; text escapes; `if`, `else if`
and `else`; comparisons; `and`, `or` and `not`; `while` and `break`; procedures with `returns`, `return`, labels and
`labels` lines; slides; `show_msg`, `show_msg.same_line`, `ask`, `??` and `random`; and the refusals the tests check.

**Weighed.**
- The compiler first, as D12 had it. A usable fast language sooner, but the part Tankun is excited about right now
  is the Rocq core.
- `oracle` first with no finish line, as Plainly v1 built its oracle and never started its compiler. Proofs make an
  easy rabbit hole, since there's always one more theorem.

**Why this won.** Building what excites Tankun is what kept v2 going, and its absence is what ended v1. Formalizing the
checker and evaluator first makes every rule of the standard exact, so vague or contradictory rules surface before a
compiler is built on a wrong reading; the compiler then has a referee from its first day (Building rule 12); and
programs can already run through `unio oracle`. The finish line keeps it from swallowing the compiler, as it did in v1.

**Tankun's words.** "Feeling like doing oracle first, why? It's geuinely exciting rn, it's gonna rock my cock (Rocq)",
"What does the subset have?", then, asked "should `oracle` be built first, until it passes every test, runs the
guessing game, and has type safety and exact `Whole` arithmetic proven for that subset, with `Unlo\n` starting right
after?", the owner chose: "yea, oracle first. Give me the prompt link, make sure the prompt is aligned with Anthropic's"

## D141. The oracle is named Ralph

2026-11-21.

**Chosen.** The oracle is named **Ralph**, for Rocq Alpha: alpha as in the first one, since it's built first (D140).
`oracle` stays its role, and you still run it as `unio oracle game.unio`, so learners never need the name, as with
`Unlo\n`. Prompts and docs call it "Ralph, the oracle". This changes D139's name.

**Weighed.**
- `oracle` alone (D139). Plain and already in the command, but, in Tankun's words, the effort deserves a name.
- Gallus, Latin for rooster, Rocq's mascot, suggested by the design claude to match Unio's Latin. Free as a name.
- Verum, Latin for truth. Already a verified systems language.
- Pythia, the priestess of the oracle at Delphi. Already a well-known family of AI language models.
- The design claude's concerns about Ralph: "alpha" can read as an unfinished early release, the opposite of a
  reference; and "Ralph" is a known name in Claude Code for running an agent in an endless loop (the "Ralph Wiggum"
  technique), which "Ralph, the oracle" keeps apart in prompts and docs.

**Why this won.** Tankun liked it best, and the reasoning holds on its own terms: alpha is the first letter, and Ralph is
the first part of Unio built.

**Tankun's words.** "Should the oracle be `Ralph` instead? Rocq Alpha (Alpha because it's first)", "The effort deserves
a name, though.", "I like Ralph, though.", then, asked "Should the oracle be named Ralph, still run as `unio oracle`?",
the owner chose: "yea".

## D142. The eighth batch: negation's overflow, four bad names, and D128's slide refusals

2026-11-21.

**Chosen.** These wordings, in D54's layout with D86's label column, D89's "but" and D101's `fix:`:

| Message | Wording |
|---|---|
| overflow from a negating `-` (D46, D92) | `when:` `` -(-9223372036854775808) ``, the value brought into the calculation, in brackets since it starts with `-` |
| a name starting with a digit (D99) | what: `` `$2x` starts with a digit, but names start with a letter ``; why: D102's |
| a name starting with `_` (D99) | what: `` `$_x` starts with `_`, but names start with a letter ``; why: D102's |
| a name ending with `_` (D99) | what: `` `$x_` ends with `_`, but `_` only goes between words ``; why: D102's |
| a name with two `_` in a row (D99) | what: `` `$a__b` has two `_` in a row, but `_` only goes between words ``; why: D102's |
| one or two calls written as a slide (D128) | `fix:` the line as calls, as in `` `    show_msg(be.Text($n));` ``; why: "one or two calls are written as calls; a chain of three or more is a slide." |
| three or more calls nested, or a chain mixing calls and a slide (D128) | `fix:` the line as one slide, as in `` `    $points |> double |> be.Text |> show_msg;` ``; why: the same |

**Weighed.**
- `--9223372036854775808`, with no brackets. `--` reads as C's "subtract one", and the two signs blur together.

**Why this won.** Each says exactly what was found against the rule, and D128's two refusals share one `why:`, so the
rule reads the same whichever way it's broken. Ralph, building the oracle, found these were never worded.

**Tankun's words.** "What's `-(-9223372036854775808)`", "What about no `()`", then, asked "Should the `when:` keep the
brackets, `-(-9223372036854775808)`, as part of that batch?", the owner chose: "yea"; then, asked "Do those read right
as proposed?" of the rest, the owner chose: "yea".

## D143. `be.Whole` ignores tabs around the number too

2026-11-21.

**Chosen.** D95's "spaces around it are ignored" covers tabs as well: any spaces and tabs before and after the number
are ignored, as Python's `int(" \t42 ")` gives 42.

**Weighed.**
- Spaces only. A stray tab in what a player types or pastes would turn "42" into a failure.

**Why this won.** The text comes from players, not programmers, and D95 ignores spaces to forgive what people type;
D10's ban on tabs is about indentation in source code, not about input. Ralph, building the oracle, asked.

**Tankun's words.** Asked "Should `be.Whole` ignore tabs around the number as well as spaces?", the owner chose: "yea".

## D144. `\r\n` counts as one line break, in `ask` and in source files

2026-11-21.

**Chosen.** A Windows line ending, `\r\n`, counts as one line break everywhere: `ask` drops a `\r` right before the
line break, so a player on Windows typing `42` gives back `42`, and a `.unio` file with `\r\n` endings reads exactly
like one with `\n`.

**Weighed.**
- Keeping the `\r` in `ask`'s answer, as Ralph did meanwhile. `be.Whole("42\r")` would fail on exactly what the player
  typed.
- Refusing `\r\n` in source files, as D98 refuses wrong spacing. The `\r` is invisible, Windows editors add it by
  default, and git can add it on checkout, so a learner would be refused for something they can't see and didn't type.

**Why this won.** It's how Python's, Go's and Rust's line readers treat it, and nobody using Unio on Windows has to know
`\r` exists. Ralph, building the oracle, asked.

**Tankun's words.** Asked "Should `\r\n` count as one line break, in `ask` and in source files?", the owner chose:
"yea".

## D145. A comment on its own line is indented like the line after it, or one level in before a closer or `else:`

2026-11-21.

**Chosen.** A `//` comment on a line of its own (D74) is indented like the line after it. Right before a closer, like
`end if`, or before `else:`, it's indented one level in, like the lines in the block it ends. Any other indentation is
refused, with the corrected line as the fix, as D10 refuses wrong indentation.

```
proc.main:
    // greet the player
    show_msg("Hi");
    if $won:
        show_msg("You win");
        // the end of the winning way
    end if
end proc.main
```

**Weighed.**
- Comments at any indentation. Flexible, but the one exception to D10's fixed indentation, and a stray comment makes
  the block structure harder to read.
- Always like the line after, even before a closer. A comment about the block would line up with `end if` and look
  like it's outside the block.

**Why this won.** A comment usually describes what comes next, and one before a closer is almost always about the
block it ends; either way it sits where the eye expects it, and indentation stays fixed. Ralph, building the oracle,
read it this way and asked.

**Tankun's words.** Asked "Should a comment on its own line be indented like the line after it, or one level in before
a closer or `else:`?", the owner chose: "yea".

## D146. Each statement goes on a line of its own

2026-11-21.

**Chosen.** Two statements on one line, as in `show_msg("Hi"); show_msg("Bye");`, are refused. The fix is two lines, so
by D101 the message has a `what:`:

```
 what:    this line has two statements
 why:     each statement goes on a line of its own.
```

**Weighed.**
- Allowing it. A second statement at the end of a line is easy to miss, and the same code would have a one-line and a
  two-line form.

**Why this won.** Unio is built for reading, and one statement per line keeps each one in plain sight, with one spelling
for the code (D2's aim). Ralph, building the oracle, asked.

**Tankun's words.** Asked "Should two statements on one line be refused, with that wording?", the owner chose: "yea".

## D147. A plain parameter is read-only, like a `let`

2026-11-21.

**Chosen.** Giving a plain parameter a new value is refused, as D14 refuses `=` on a `let`:

```
 what:    `$n` can't be given a new value
 because: `$n` is a parameter
 1 | proc count_down($n: Whole):
   |                 ^^
 why:     a parameter can't be given a new value; to change a copy, declare a `var` from it.
```

The way round it is a `var` copy: `var $left: Whole = $n;`. The words a parameter will use to say how it's used (D130:
read, change the caller's value, or take it over) are still undecided; this is what a plain parameter means.

**Weighed.**
- Letting a parameter change, as a local copy, as Python and C do. Someone writing `$n = $n - 1` might expect the
  caller's variable to change too, and it wouldn't.

**Why this won.** It's Hylo's own default, a plain parameter only read, it avoids that trap, and it leaves room for a
"change the caller's value" word to mean exactly that. Ralph, building the oracle, asked.

**Tankun's words.** Asked "Should a plain parameter be read-only, refused like a `let`, with that wording?", the owner
chose: "yea".

## D148. A program with refusals exits with status 1, even with `NotBuiltYet` or `NotDesignedYet` too

2026-11-21.

**Chosen.** When a program has both refusals and `NotBuiltYet` or `NotDesignedYet` messages, every message is shown
(D54) and the exit status is 1, refused. Status 3 then means only that the program is fine as far as the tool can tell,
but the tool can't handle part of it yet.

**Weighed.**
- Status 3, as Ralph had it meanwhile. It would hide that the program itself has mistakes to fix.

**Why this won.** A refusal is the program's own mistake, which the writer has to fix whatever else happens; "not built
yet" is a limit of the tool. Keeping 3 for the tool alone gives scripts and editors one clear meaning for it. Ralph,
building the oracle, asked; the first build's compiler had asked it too, as its Q5.

**Tankun's words.** Asked "Should a program with both refusals and `NotBuiltYet` or `NotDesignedYet` exit with status
1?", the owner chose: "yea".

## D149. Every `while` counts as able to end, whatever its condition

2026-11-21.

**Chosen.** For D57's rule that every way through a procedure with `returns` ends in `return`, every `while` counts
as able to end, whatever its condition. The checker never judges whether a condition is always true, so a procedure
that loops with `while true:` and returns from inside the loop still needs a `return` after it:

```
proc first_big($start: Whole) returns Whole:
    var $n: Whole = $start;
    while true:
        if $n > 100:
            return $n;
        else:
            $n = $n + 1;
        end if
    end while
    return $n;
end proc first_big
```

(Corrected on 2026-11-21: the example first had `$n = $n + 1;` after `end if`, which D9 refuses, since that `if` can
leave. Ralph found it. The rule itself is unchanged.)

**Weighed.**
- Java's special case: `while true:` with no `break` counts as never ending. Smarter, but then a line after such a
  loop can never run and needs a refusal of its own, one more rule to learn.

**Why this won.** One simple rule, with nothing for a learner to guess about how clever the checker is. The cost, a
closing `return` that never runs, rarely comes up, since game loops usually live in `proc.main`, which has no
`returns`. Ralph, building the oracle, read it this way and asked.

**Tankun's words.** Asked "Should every `while` count as able to end, whatever its condition?", the owner chose: "yea.
New rule: design claude asks before msging"

## D150. `unio compile` writes the program beside the source file, named after it

2026-11-21.

**Chosen.** `unio compile` writes the program it makes beside the source file, named after it without `.unio`:
`unio compile games/guess.unio --final` makes `games/guess`, run as `./games/guess`.

**Weighed.**
- The folder the command is run from, as Go does. Where the program lands would depend on where you happened to be.
- A separate `build/` folder, as Rust's Cargo uses. One more thing to learn and to find.

**Why this won.** It's what a learner expects: compile `guess.unio`, get `guess`, right next to it. The compiler
session built it this way meanwhile, since D91 didn't say.

**Tankun's words.** "Why is Unio named Unio?", then, asked "Should `unio compile` write the program beside the source
file, named after it without `.unio`?", the owner chose: "yea".

## D151. The compile cache lives in each system's standard cache folder

2026-11-21.

**Chosen.** D65's shared cache lives in the system's own cache folder: `~/Library/Caches/unio` on macOS,
`$XDG_CACHE_HOME/unio` on Linux (`~/.cache/unio` when that isn't set), and `%LOCALAPPDATA%\unio\cache` on Windows.

**Weighed.**
- A `.unio` folder in the home directory. Clutter that cleanup tools don't know is safe to delete.

**Why this won.** Those folders are where each system and its cleanup tools expect disposable data, and emptying one
breaks nothing: `unio` compiles everything again next time. The compiler session built the macOS one meanwhile, since
D65 left the place open.

**Tankun's words.** Asked "Should the cache live in each system's standard cache folder?", the owner chose: "yea".

## D152. `?? crash` stops with a `failed:` message, status 5

2026-11-21.

**Chosen.** When the call before `?? crash` fails (D23), the program stops with status 5 and a message in D54's layout
whose kind is `failed:`:

```
failed: game.unio:7:43, line 7 column 43
 7 |     let $level: Level = load_level($name) ?? crash;
   |                                           ^^^^^^^^
 what:    `load_level` failed with `not_found`
 why:     `?? crash` stops the program when the call before it fails.
```

The `what:` names the procedure and its failure. What a failure leaving `proc.main` unhandled shows isn't decided yet;
`failed:` would suit it too.

**Weighed.**
- `check failed:`, the runtime kind. A failed check is something the language caught; this is the program choosing to
  stop, and the first word should tell them apart.

**Why this won.** A distinct kind says at once which kind of stop it is, and matches status 5's meaning; the failure's
name is the one thing needed to fix it. The compiler session refused `?? crash` with `NotDesignedYet` meanwhile.

**Tankun's words.** Asked "Should `?? crash` stop with a `failed:` message like that, status 5?", the owner chose:
"yea".

## D153. `be.Text` turns a `Bool` into `"true"` or `"false"`

2026-11-21.

**Chosen.** `be.Text` converts a `Bool` to text, giving `"true"` or `"false"`, the words Unio writes them with:

```
show_msg("Won: " & be.Text($won));
```

shows `Won: true`.

**Weighed.**
- Leaving it out, so a `Bool` is shown only through an `if`. D89's message for a `Bool` joined with `&` already says
  "anything else becomes text only where `be.Text` says so", pointing at `be.Text` as the way.

**Why this won.** It's handy in games, for showing a flag while testing, as Python's `str(True)` is, and with Unio's
own spelling what's shown is what's typed. Ralph stopped with `NotDesignedYet` here, and `Unlo\n` crashed, which is how
it surfaced.

**Tankun's words.** Asked "Should `be.Text` turn a `Bool` into `"true"` or `"false"`?", the owner chose: "yea".

## D154. Calls nesting too deep stop as a failed check, status 4

2026-11-21.

**Chosen.** When calls nest deeper than the room the machine gives them, as when a procedure keeps calling itself
without stopping, the program stops with `check failed:` and status 4, at the call that went too deep:

```
check failed: game.unio:5:16, line 5 column 16
 5 |         return count($n + 1);
   |                ^^^^^^^^^^^^^
 what:    calls went too deep
 when:    100000 calls deep, inside `count`
 why:     every call still waiting for another needs a little memory, and the room for them is limited; a procedure that keeps calling itself without stopping fills it.
```

How deep is too deep depends on the machine; the compiler can give a program a large stack, so real programs never
come close.

**Weighed.**
- An internal error, status 7, as Ralph had it meanwhile. It blames the tool for the program's own mistake.
- D115's out-of-memory message. The room for waiting calls, the stack, is a small separate area, so a runaway
  recursion fills it while the program as a whole uses almost nothing, and "out of memory" with gigabytes to spare
  confuses.
- "runs out" in the `why:`, as first drafted. Tankun asked what runs out; the room for waiting calls is what fills.

**Why this won.** It names the actual mistake, a recursion with no way out, with the depth and the procedure to find
it, in the same kind and status as overflow and running out of memory. The word "stack" stays out of the `why:` so a
beginner can read it; the docs can explain it. Ralph, building the oracle, asked.

**Tankun's words.** "Is it out of mem?", then ""every call that's waiting for another uses memory; a procedure that
keeps calling itself without stopping runs out." What runs out", then, asked "Should calls nesting too deep stop as
`check failed:`, status 4, with "calls went too deep" and this `why:`?", the owner chose: "yea".

(Changed by D158: the limit is a fixed 1,000,000 calls, counted by Unio, not the machine.)

## D155. Binary float types need `~` on inexact literals and show it on inexact values

2026-11-21.

**Chosen.** For a binary float type, whenever Unio has one:
- a decimal literal that can't be stored exactly needs `~`: `~0.1` is accepted, `0.1` is refused with `~0.1` as the
  fix, and a literal stored exactly, like `0.5`, takes no `~`;
- printing gives the shortest text that reads back as the same number, as Python, JavaScript, Rust and Java do, with
  `~` in front when the stored value isn't exactly that: `~0.1 + ~0.2` shows `~0.30000000000000004`, and `0.5 + 0.25`
  shows `0.75`.

An exact decimal type never needs `~`, since its `0.1` is 0.1. Which decimal types Unio has, and a rounded, `~`-free
way to show a decimal to a player, aren't decided yet.

**Weighed.**
- Printing the exact stored value, as in `0.1000000000000000055511151231257827021181583404541015625`. True, but
  unreadable.
- The shortest round-tripping text with no mark, as most languages print. `0.1 + 0.2` then surprises every beginner,
  with nothing on the page to warn them.
- A fixed number of digits, as C's `%f` or `%.17g`. Hides or exaggerates, depending on the count.
- Tying `~` to decimals in general. Tankun: it depends on the type, since an exact decimal type has no inexact values.

**Why this won.** It makes binary floats honest: the `~` tells a learner a number is approximate before `0.1 + 0.2`
bites, in code and in output, and whether a literal is exact is known at compile time, so the refusal has a clear fix.

**Tankun's words.** "What does `show_msg` print? Stored or useful", "No, stored means stored in hardware. `0.1` in
Float isn't that", "We should print `~0.1` because Floats would require `~` when inexact", "no, it depends on the
type", then, asked "Should binary float types require `~` on inexact literals and show it on inexact printed values,
with exact decimal types never needing it?", the owner chose: "yea".

## D156. `be.Whole`'s failure is `not_a_whole`

2026-11-21.

**Chosen.** When `be.Whole` fails (D95), its failure is named `not_a_whole`: for text that isn't a number, like
`"abc"`, a number that isn't whole, like `"4.5"`, and a whole number too big or too small for a `Whole`. D152's
message reads "`` `be.Whole` failed with `not_a_whole` ``".

**Weighed.**
- `not_a_number`. False for `4.5` and for a number too big, which are numbers.
- Two failures, `not_a_whole` and `out_of_range`, so a game could tell a player their number was too big. Every
  `be.Whole(...) otherwise:` would need both cases (D40), for a case that's rare.
- `not_a_Whole`, with the type's capital, as Tankun wondered. Names are lowercase (D39, D99); in a name, "whole" is a
  word, while `Whole` the type is spelled as the type, as in `be.Whole`.

**Why this won.** One honest name covers every way the conversion fails, reads as a sentence in D152's message, and sets
a pattern for later conversions that can fail. Ralph and the compiler session both needed it for `?? crash`.

**Tankun's words.** "big case?", "No, I meant **W**hole", "Why is it `be.Text`", then, asked "Should `be.Whole`'s
failure be called `not_a_whole`?", the owner chose: "yea".

## D157. Unio's decimal type is `Float`, IEEE 754 binary64; `Decimal` is kept for an exact type

2026-11-21.

**Chosen.** Unio's first type for numbers with a point is **`Float`**, a binary floating-point number stored as IEEE
754 binary64, with no second name (as `Whole`, D15). It's approximate, and D155's `~` shows where. `Decimal` is kept
for an exact decimal type, where `0.1 + 0.2` is `0.3`, if Unio adds one later.

```
let $speed: Float = ~0.1;
```

**Weighed.**
- An exact decimal type first. Several times slower, in software, where games mostly want speed for positions, speeds
  and timing; D155's `~` removes most of the reason to need one.
- `BinFloat`, Tankun's first idea, pairing with a later `DecFloat`. Accurate, but a word no learner meets anywhere
  else.
- `Binary64`, IEEE 754's own name. Puts a size in the name, where `Whole` has none, and names a storage format rather
  than a kind of number.
- `Decimal` for this type, following D15's school-maths rule. Wrong: it isn't decimal, it's stored in binary, which is
  why `0.1` can't be exact.

**Why this won.** `Float` is accurate, the word learners meet everywhere, and pairs with `Decimal` for an exact type,
each name meaning what it says; the `~` covers what the name doesn't. Digging further for a perfect name wasn't worth
it.

**Tankun's words.** The messages quoted in D155, then "It's actually IEEE 754 Binary", a code block (has code),
"`Bool` is shortened", "families don't exist mainstream either", "It's not a Decimal, c'mon", "What is a float", "Now,
here's the thing. Is that rabbit hole worth it? Rather than just saying `Float` is ..., and `Decimal` is well... A
real one", then, asked "Should the type be `Float`, IEEE 754 binary64, with `Decimal` kept for an exact type later?",
the owner chose: "Fair enough".

## D158. The call-depth limit is a fixed 1,000,000 calls, counted by Unio itself

2026-11-21.

**Chosen.** D154's stop comes at a fixed 1,000,000 calls waiting for one another, counted by Unio itself rather than
when the machine's stack runs out: `when:` reads "1000000 calls deep, inside `count`" on every machine, in both modes,
in Ralph and in `Unlo\n` alike. This replaces D154's "depends on the machine".

**Weighed.**
- The machine's own limit, as D154 had it. It differs between machines, can't be tested, and `final` turning a
  recursion into a loop would change where or whether a program stops, which D46 forbids.

**Why this won.** Counting gives the same stop at the same call everywhere, so it can be tested and compared (Building
rule 12), for one compare per call: `fib(44)` still takes about 3 ms in `final`, and 2.9 s in `working`, from 1.95 s.
A real program rarely goes ten thousand calls deep, and a runaway recursion reaches a million in under a second. Ralph
and the compiler session each chose 1,000,000 on their own.

**Tankun's words.** Asked "Should it be a fixed 1,000,000 calls?", the owner chose: "yea".

## D159. `unio run` keeps the program it builds in the compile cache

2026-11-21.

**Chosen.** `unio run` keeps the program it links in the compile cache (D65, D151), keyed by its compiled pieces and
the runtime, instead of a temporary file, replacing that detail of D45 and D50. An unchanged program then starts in
about 0.1 s instead of 0.4 s, skipping linking and macOS's first-launch check.

**Weighed.**
- A temporary file each run, as D45 and D50 said. Every run links again and pays macOS's first-launch check.

**Why this won.** Nothing changes for the user, the same output and nothing beside their files, and the cache already
holds the compiled pieces, so keeping the last step there makes every rerun faster. The cache lives in the system's
cache folder, which is safe to empty. The compiler session built it this way and asked.

**Tankun's words.** Asked "Should `unio run` keep the program it builds in the compile cache, instead of a temporary
file?", the owner chose: "yea".

## D160. `random` with `from:` above `to:` is refused when it's plain numbers, and a failed check otherwise

2026-11-21.

**Chosen.** `random` with `from:` above `to:`, which no number can satisfy (D26):
- **When both are plain numbers** written in the code, as in `random(from: 6, to: 1)`, it's refused at compile time,
  with the two swapped as the fix:

  ```
   fix:     `    let $roll: Whole = random(from: 1, to: 6);`
   why:     `random` gives a whole number from `from:` up to `to:`, so `from:` can't be above `to:`.
  ```
- **Otherwise,** as in `random(from: $low, to: $high)`, it stops at runtime with `check failed:` and status 4:

  ```
   what:    `random`'s `from:` is above its `to:`
   when:    from: 7, to: 3
   why:     `random` gives a whole number from `from:` up to `to:`, so `from:` can't be above `to:`.
  ```

`from:` equal to `to:` is fine, and gives that number.

**Weighed.**
- Swapping them quietly. Friendly, but hides what's almost always a mix-up of two variables.
- A failure the caller must handle. A `??` after every `random` for a mistake that should never happen.
- Only at runtime. When the mistake is visible in the code itself, the writer should hear before running anything.

**Why this won.** The writer is told as early as it can be known: at compile time when the code alone shows it, at
runtime otherwise, with both values to spot the mix-up. Both implementations stopped with `NotDesignedYet` here.

**Tankun's words.** "yea?", "I meant to ask what you're asking", "Stop when? Comp?", "So, boh ties?", then, asked
"Should it work that way, refused at compile time when both are plain numbers, and stopping at runtime otherwise?", the
owner chose: "yea".

## D161. The ninth batch: lines outside procedures, unknown types, `not`/`and`/`or`, value-only lines, other files, `unio oracle` and usage

2026-11-21.

**Chosen.** A line that only works out a value, like `$score + 1;` or `$score;`, is refused, as D120 refuses a call
whose value is thrown away. With these wordings, in D54's layout with D86's column and D89's "but":

| When | `what:` | `why:` |
|---|---|---|
| a line outside any procedure | this line isn't inside a procedure | a program is made of procedures, and every statement goes inside one. |
| an unknown type | ``there's no type named `Number` `` | a type is one Unio has, like `Whole`, `Float`, `Bool` or `Text`. |
| `not` on something that isn't a `Bool` | ``` `not` works on a `Bool`, but this is a `Whole` ``` | `` `not`, `and` and `or` work on `Bool`s. `` |
| `and` or `or` on something that isn't a `Bool` | ``` `and` joins two `Bool`s, but this is a `Whole` ``` | the same |
| a line that only works out a value | ``` `$score + 1` works out a `Whole`, but nothing uses it ``` | `` a line that only works out a value does nothing; keep the value with `let` or `var`, or give it to a variable with `=`. `` |

- **A `because:` pointing into another file** (D54) names it: ``because: the first is here, in `board.unio` ``.
- **`unio oracle` with Ralph not built:** ``unio: `oracle` needs Ralph, the oracle, which isn't built here``, status 3.
- **The usage text** after a command mistake:

```
usage:
  unio run game.unio --working       compile it and run it
  unio compile game.unio --final     make the program to ship
  unio check game.unio               only check it
  unio oracle game.unio              run it on Ralph, the oracle
```

**Weighed.**
- Allowing a value-only line. It does nothing, and is almost always a slip for `$score = $score + 1;`.
- "true-or-false values" in the `why:` for `not`, `and` and `or`. Tankun: just say `Bool`, as the `what:` does.
- "`$score + 1` works out a `Whole` with nowhere to go", from Tankun's "has no place to be in". Kept D120's "but
  nothing uses it", so both throw-away mistakes read alike.
- Status 6 for `unio oracle` without Ralph, as the compiler session drafted. Status 6 means the command was written
  wrong; here the tool just can't run it, which is status 3's meaning.

**Why this won.** Each names what's wrong in the reader's terms, and the value-only line joins D120 in catching a line
that looks like it does something and does nothing. The compiler session drafted most of these.

**Tankun's words.** "?", "Just say bool?", "What is the 5th err msg about", ""`$score + 1` works out a `Whole`, but
nothing uses it" What about "`$score + 1` has no place to be in"? Or something", "Nah, it's fine. I was just asking",
then, asked "Do they all read right, including refusing a value-only line?", the owner chose: "approved".

## D162. `Whole` and `Float` don't mix without `be.Float`

2026-11-21.

**Chosen.** A calculation can't mix a `Whole` and a `Float`: `$lives * $speed` is refused, and the `Whole` is
converted explicitly, as in `be.Float($lives) * $speed`, the way a number joins text only through `be.Text` (D28).

**Weighed.**
- Mixing them freely, the `Whole` turned into a `Float`, as Python does. Quiet, but the moment an exact number turns
  approximate would be invisible, and a count could quietly lose its fraction the other way round.

**Why this won.** It follows Unio's existing rule for text, keeps the `~` honest by making the step from exact to
approximate visible, and catches real bugs, for the cost of a few `be.Float(...)`s, as in Rust.

**Tankun's words.** Asked "Should mixing `Whole` and `Float` need an explicit `be.Float`?", the owner chose: "yea. Our
floats aren't stable like Cyborg's, right?"

## D163. Unio makes no same-bits promise for `Float`

2026-11-21.

**Chosen.** Unio doesn't promise that `Float` maths gives the same bits on every machine. `+`, `-`, `*`, `/` and the
square root do anyway, as a side effect of D46 (`final` behaves exactly as `working`) and D124 (no fast-math): the
compiler never fuses or reorders them, and IEEE 754 rounds them the same everywhere. Maths functions, like `sin`, when
Unio has them, use what the platform gives, and may differ in the last digit between machines; where they do, Ralph and
`Unlo\n` compare their results as close rather than identical.

**Weighed.**
- Promising same bits everywhere, maths functions included, as Cyborg's `.stable` floats do (its D158, D161), through a
  correctly rounded library like CORE-MATH, as the design claude recommended. Cyborg's design session listed what it
  takes: a rule for float to whole number, NaN's bits, building and covering every function and keeping the system
  library out, flush-to-zero sneaking in through foreign code, and fixed order in parallel sums. And Ralph's core is
  proven in Rocq, so it would have to produce and prove correctly rounded maths functions itself: research-grade work,
  landing on the part of Unio Tankun is most excited about.

**Why this won.** Unio's audience doesn't need bit-identical floats across machines, and the cost would fall on Ralph's
proofs. The basic maths matches everywhere anyway; nothing has to be defended to keep it so.

**Tankun's words.** In Cyborg's design session, on reading its answer, relayed by it: "Why the fuck did you suggest
stable floats back again. Oh hell no". Here, asked "Should Unio make no same-bits promise for `Float`?", the owner
chose: "yea".

## D164. Unio's pitch: "Full concepts, plain words & ease where there should be"

2026-11-21.

**Chosen.** Unio's one-line pitch, and the GitHub repository's description, is "Full concepts, plain words & ease where
there should be". It joins the README's two lines, "Learn concepts in full, type them shortly." and "the goal isn't no
learning, rather it's plain words and ease where there should be".

**Weighed.**
- "Static Python, built for reading", the idea this version started from, never logged as a decision. Unio has moved
  far from Python's look since (`end` closers, `;`, `$`, slides, labels, Hylo-style values), and the phrase says what
  Unio resembles rather than what it's for.
- "Learn concepts in full, type them shortly.", the README's first line alone.
- "... & ease where possible", Tankun's first wording. The README's "where there should be" is more exact: ease only
  where it belongs, so learners still learn the real thing.
- Leaving out "Full concepts". It would read like any "easy" beginner language, the kind the README pushes back on.

**Why this won.** It says what Unio is for, in Tankun's own README words: the real ideas, in plain words, made easy only
where ease belongs.

**Tankun's words.** "Wait, I swear, I thought our GH description changed", "Isn't static Python ol?", "How about "Full
concepts, plain words & ease where possible"?", "Follow README on last msg?", "Remove full concepts from desc?", then,
asked "Should the description stay "Full concepts, plain words & ease where there should be"?", the owner chose: "yea".

## D165. `( )` calls, `[ ]` holds or describes values, parameters included; grouping is `( )`'s one exception

2026-11-21.

**Chosen.** Each bracket has one meaning, following Cyborg's (its D23 and D460), except for grouping:

| Bracket | Means | Examples |
|---|---|---|
| `( )` | calls a procedure; and, as school maths writes it, groups in maths | `add(1, 2)`, `($a + $b) * 2` |
| `[ ]` | values, listed or described: a list, reaching an item, a type's settings, a procedure's parameters, building a record | `[1, 2, 3]`, `$bag[pos: 1]`, `List<Text>[max: 10]`, `proc add[$a: Whole, $b: Whole]`, `Reading[celsius = 21]` |
| `< >` | a type, filled in | `List<Whole>` |

```
proc add[$a: Whole, $b: Whole] returns Whole:
    return $a + $b;
end proc add

let $sum: Whole = add(1, 2);
```

`( )` marks where a procedure is called, code with a name and a body. Built-in operations, like `+`, reaching an item
and reading `.len`, don't take it, though they're done at runtime too. Grouping in maths is the one exception, kept
because it's how school maths writes it. A list's limits, records and how a record is built aren't decided here; this
says only where they go. This replaces D3's `( )` for parameters, and D4's "a definition writes `( )`" now reads `[ ]`.

**Weighed.**
- D3 as it stood: `( )` for parameters, matching Python, and `[ ]` for lists alone. A type's settings had nowhere
  clean to go: in `< >` they'd put a value among types (`List<Text, max: 10>`), and in `( )` they'd read as calling
  `List` (`List<Text>(max: 10)`). D3's reason, matching Python, gave way with D164, and Tankun's worry then, a kid
  asking why the brackets differ with no real reason, now has one.
- Following Cyborg entirely, grouping in `{ }` too. Purer, but a new symbol for what every child learns at school as
  `(2 + 3) × 4`.
- Keeping parameters in `( )` and moving only a type's settings, as the design claude first suggested. A second
  exception in `( )` with no school-maths reason behind it.

**Why this won.** One sentence each tells a learner what a bracket means: `( )` makes a procedure run, `[ ]` lists or
describes values, `< >` says what type. A definition and its call look different at a glance, `[ ]` after a value
reaches an item while after a type or a name it describes, as in Cyborg, and Unio's `$` keeps the two apart. It also
means one less difference between Tankun's languages. The cost is learners going on to languages that define with
`( )`, and a sweep of the standard, the tests and both implementations.

**Tankun's words.** "It's not generic, though", "Ask Cyborg Design Claude about its brackets rules. Now, what are our
brackets rule", "So... How about we follow Cyborg, except grouping. So, change the rule?", "Why not param too?", "How
does `()` in grouping not an exception?", "So, what do the brackets mean with tha", "Wait, does idx count as call or
?", "Wait, wait. So, that doesn't run at runtime?", then, asked "Should Unio's brackets work that way: `( )` for calls,
plus grouping, `[ ]` for values, parameters included, and `< >` for types?", the owner chose: "yea".

## D166. A definition with its parameters in `( )` is refused with the `[ ]` form as its fix

2026-11-21.

**Chosen.** A procedure header that writes its parameters in `( )`, as before D165, is refused with the `[ ]` form as
its fix:

```
refused: game.unio:1:9, line 1 column 9
 1 | proc add($a: Whole, $b: Whole) returns Whole:
   |         ^
 fix:     `proc add[$a: Whole, $b: Whole] returns Whole:`
 why:     a definition writes its parameters in `[ ]`; `( )` calls a procedure.
```

**Weighed.**
- D92's generic message, "`` `:` should be here, not `(` ``", as Ralph gave. True to the parser, but its fix,
  `proc add:(...)`, is nonsense: advice that doesn't work is worse than none. The two implementations disagreed, which
  Building rule 12 treats as a bug in one of them.

**Why this won.** Anyone used to Python, or to Unio before D165, writes `( )` out of habit, and the message hands them
the corrected line and the reason in one sentence. The compiler session drafted it.

**Tankun's words.** "": should be here, not (”
Motherfucker, isn't that a bug?", then, asked "Should old-style headers
be refused with that `fix:` and `why:`, in both implementations?", the owner chose: "yea".

## D167. `Array<Type>[len: n]` holds exactly `n`; a list's limit is `List<Type>[len.max: n]`

2026-11-21.

**Chosen.**
- **`Array<Type>[len: n]`** is its own type, holding exactly `n` items: its length is part of its type. `.add` and
  `.remove` are refused on it; its items can still change, as `$board[pos: 5] = 1`; it shares `pos:`, `offset:` and
  `.len` with lists.
- **`List<Type>[len.max: n]`** is a list that may hold at most `n` items. A `List` with no setting has no limit.

```
let $week: Array<Text>[len: 7] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
var $bag: List<Text>[len.max: 10] = [];
```

Settings go in `[ ]` after the type (D165). What `.add` does on a full list isn't decided yet.

**Weighed.**
- One type, `List`, with `len:` as a setting for a fixed length, as the design claude first recommended, calling
  "array" jargon. Tankun: "An array of solar panels, it doesn't sound like more is addable. While a shopping list
  does". The everyday words already carry the difference, as D15's rule asks of a name.
- `max:` alone for a list's limit. On a `List<Whole>` it could read as a limit on the items' values, the way Cyborg's
  `min:` and `max:` bound values; `len.max` says it's the length.
- A type's settings in `< >` or `( )`, before D165 put them in `[ ]`.

**Why this won.** Each name teaches itself: an array is set out and fixed, a list grows. It matches Cyborg's split
(its list and array) and its `len.max`, and the checker can refuse `.add` on an array from the type alone.

**Tankun's words.** "No, let's design lists and arrays more. Like how to limit a list", "An array of solar panels, it
doesn't sound like more is addable. While a shopping list does", "Isn't it `len.max` on list?", then, asked "Should
fixed-length collections be `Array<Text>[len: 7]`, and a list's limit be `List<Text>[len.max: 10]`?", the owner chose:
"Oh hell no, I'm a guy, bro. Anyways, yea".

## D168. `.add` on a list with `len.max` can fail with `full`

2026-11-21.

**Chosen.** On a `List` with `len.max` (D167), `.add` can fail, with the failure `full` when the list already holds
its most, and the program deals with it like any failure (D23): `?`, `??` or `otherwise:`.

```
$bag.add("Gem") otherwise:
    case full:
        show_msg("Your bag is full!");
end otherwise
```

A `List` with no limit never fails on `.add`.

(This example's case just ends, which D40 refused; D186 allows it, since `.add` gives back no value.)

**Weighed.**
- A failed check that stops the program, as a bad position does. A full bag is a normal game event, not a bug, and
  a player picking up an eleventh item shouldn't crash the game.
- Ignoring the extra item quietly. Nothing would tell the program, or the player, that it was lost.

**Why this won.** It puts a full list with the things a program is made to deal with, and the checker makes every
`.add` on a limited list say what happens when it's full, while unlimited lists stay as simple as before.

**Tankun's words.** Asked "Should `.add` on a list with `len.max` be able to fail with `full`, handled like any
failure?", the owner chose: "yea".

## D169. `[all: value]` starts every item of an array the same

2026-11-21.

**Chosen.** `[all: value]` is a list literal in which every item is `value`, its length taken from the type it's given
to, as `[]` takes its type from where it goes (D76). It's allowed only where the length is known, as for an `Array`
(D167); on a plain `List`, with no length to fill, it's refused.

```
var $board: Array<Whole>[len: 64] = [all: 0];
var $seen: Array<Bool>[len: 100] = [all: false];
```

**Weighed.**
- Rust's `[0; 64]`. A new meaning for `;` inside brackets, with no hint of what it does, and the count written a
  second time.
- A method, as in `.filled(0)`. A call where nothing needs to run (D165).
- `[all 0]`, with no `:`. A bare word followed by a value appears nowhere else in Unio and would make `all` a keyword;
  `all:` is one more label, read like `pos:` or `len:`.

**Why this won.** It's `[ ]` describing values, D165's job for it, reads aloud as "all zero", and writes the length
once, in the type, where it can't disagree with a count written elsewhere.

**Tankun's words.** "With `:` or not?", then, asked "Should it be `[all: 0]`, with the `:`?", the owner chose: "yea".

## D170. `range[from: …, to: …]` includes its top, and `range[from: …, before: …]` leaves it out

2026-11-21.

**Chosen.** A range of whole numbers is written `range[…]`, in `[ ]` since it describes values and nothing runs
(D165). It takes `from:`, the first number, and exactly one of:
- `to:`, which includes the top: `range[from: 1, to: 3]` is 1, 2, 3;
- `before:`, which stops short of it: `range[from: 0, before: 10]` is 0 to 9, as for going through every `offset:`.

**Weighed.**
- Another name, as the design claude suggested, `numbers` or `count`, since Python's `range` leaves out its top and
  Unio's `to:` includes it. Tankun: the labels already say which; `to:` and `before:` spell out in plain English what
  Python's `range(0, 10)` leaves to memory, so nobody misreads either, and `range` keeps the word programmers know.
- Only `to:`. Counting from 0 to just short of a length is common enough to deserve its own word.

**Why this won.** The labels carry the meaning, so there's no off-by-one to remember, and "a range from 1 to 3" is
everyday English. Tankun proposed `range` in `[ ]` and `before:`.

**Tankun's words.** "Oh wait, now we could do `for $i in range[from: 1, to: 3]` with `step_by` needed when needed",
"Another name for `range`? Or just use `range`?", "Doesn't `to:` already say it? And the alt is `before:`", "Why is it
named range?", then, asked "Should it be `range`, taking `from:` plus exactly one of `to:` (top included) or `before:`
(top left out)?", the owner chose: "yea".

## D171. `for each $x in …:` loops, closed by `end for`

2026-11-21.

**Chosen.** Unio's loop through a collection is `for each`:

```
for each $name in $students:
    show_msg($name);
end for
```

- It goes through a `List`, an `Array` or a `range[…]` (D167, D170), in order, running its body once per item.
- `$name` is a new variable for each pass, declared by the `for each` as a `let`, ending with the loop (D93).
- It closes with `end for` (D8), and `break` leaves it, as it leaves a `while` (D32).

What happens if the body changes the list being gone through, going through text, and getting the position as well as
the item aren't decided yet.

**Weighed.**
- `for $name in $students:`, Python's shape, as the design claude first proposed. Tankun: it doesn't communicate the
  logic well; it's maths' "for all x in S" in shorthand, and "for name in students" isn't an English sentence.
- `each $name in $students:`. Shorter, but less of a sentence.
- `repeat with $name in $students:`, as HyperTalk and Scratch's family say. Stresses the repeating over the
  one-at-a-time.
- `go through $students as $name:`. Reads well, but three words, with the name at the end.

**Why this won.** "For each name in students, show the name" is exactly what the loop does, read aloud; the words are
Visual Basic's and C#'s, and how teachers describe Python's loop anyway.

**Tankun's words.** A message with a code block (has code), then another (has code), then, asked "Should the loop be
`for each $x in …:`, closed by `end for`?", the owner chose: "yea. Lol, I though `i` was for integer".

## D172. `range` takes an optional `step_by:`, counting by 1, negative to count down

2026-11-21.

**Chosen.**
- **`step_by:`** is optional; when it's left out, a range counts by 1. It's the first optional label in Unio; whether
  a program's own procedures can have them is still open (chapter 4).
- **A negative step counts down:** `range[from: 10, to: 1, step_by: -1]` is 10, 9, … 1.
- **The range goes as far as it can without passing its end,** so `range[from: 0, to: 9, step_by: 2]` is 0, 2, 4, 6,
  8.
- **A step of 0, or one pointing away from the end,** as in `range[from: 10, to: 1]` with no step, is refused at
  compile time when it's plain numbers, and stops with `check failed:` and status 4 otherwise, as D160 does for
  `random`. Their wording comes with a later batch.

**Weighed.**
- `step_by:` always written. Most ranges count by 1, and writing it every time adds nothing.
- An empty range when it points the wrong way, as Python's `range(10, 1)` quietly is. Almost always a mistake, hidden.
- A separate word for counting down, like `down_to:`. One more label, where a negative step already says it.

**Why this won.** The common case stays short, a countdown is written once with its direction, and a step that can't
get anywhere is caught as early as it can be known. Tankun suggested `step_by` "needed when needed".

**Tankun's words.** "Oh wait, now we could do `for $i in range[from: 1, to: 3]` with `step_by` needed when needed"
(quoted in D170), then, asked "Should `range` take an optional `step_by:` that counts by 1 when left out, can be
negative to count down, and is refused when it's 0 or points the wrong way?", the owner chose: "yea".

## D173. A `for each` can't change the list it's going through

2026-11-21.

**Chosen.**
- **Inside a `for each`, the variable it's going through can't change.** Anything in the body that would change it,
  such as `.add`, setting one of its items or setting the whole variable, is refused at compile time.
- **To change a list while looping,** a `while` loop over its positions says so plainly.
- The refusal's wording comes with a later batch (D54), and its test with it.

```
for each $name in $players:
    $players.add("Bob");   // refused: $players is being gone through
end for
```

**Weighed.**
- Going through a copy, as Swift does: the loop sees the list as it was when it started, and the change still happens
  to `$players`. Safe under D130's values, but a reader may expect the loop to reach "Bob" too, and nothing says it
  won't.
- Python's way, where the loop sees the change and may skip items or never end. A classic bug, and impossible under
  D130 anyway.

**Why this won.** Nearly every program that changes a list inside its own `for each` is a mistake, and a message says
so at once, where a copy would be a silent surprise. A program that means it has `while`.

**Tankun's words.** Asked "Should changing the list being gone through inside its own `for each` be refused at compile
time?", the owner chose: "yea".

## D174. `for each` gets the position with `at pos` or `at offset`

2026-11-21.

**Chosen.**
- **`at pos $i` or `at offset $i`, between the item and `in`,** gives the item's position as well: `pos` counts from 1
  and `offset` from 0, as D75 has them for reaching an item.
- **`$i` is made by the `for each` line,** a `let` like the item, new for each pass and ended with the loop (D171).
- **It fits the matching label:** with `at offset $i`, `$students[offset: $i]` is the item; with `at pos $i`,
  `$students[pos: $i]` is.

```
for each $name at pos $i in $students:
    show_msg.fmt("{$i}. {$name}");
end for
```

With `["Fern", "Plern", "Churn"]`, this prints `1. Fern`, `2. Plern` and `3. Churn`.

**Weighed.**
- A pair, as in Python's `for i, name in enumerate(students)`. Nothing on the page says it counts from 0, which is
  what D75 set out to avoid.
- Only one of the two counts. D75 keeps both for items, and a position from the loop is most often used to reach an
  item, so the loop keeps both too, with the same words.

**Why this won.** The line reads as a sentence, it says which way it counts, and the number it gives goes straight
back into the label of the same name.

**Tankun's words.** Tankun asked whether `offset` means the same in both places ("Actually, looking again. I think
it's a bit weird. `$xs[offset: $x]` treats `$x` as starting from 0. Wait, idk, does that too?"). After hearing that it
does, asked "Should `for each` allow both `at pos $i` and `at offset $i`, as D75 does for items?", the owner chose:
"yea".

## D175. `places:` in `.fmt` braces rounds a `Float` for showing, with no `~`

2026-11-21.

**Chosen.** In `.fmt` text, a `Float`'s name in braces can take `places:` after a comma, the setting D29 left open:

```
let $speed: Float = ~0.1 + ~0.2;
show_msg.fmt("Speed: {$speed, places: 2}");   // Speed: 0.30
let $line: Text = be.Text.fmt("{$speed, places: 2}");
```

- **It rounds to that many digits after the point,** the decimal places, and always shows that many: `0.5` with
  `places: 3` shows `0.500`, and `places: 0` shows no point.
- **It rounds to the nearest, and an exact tie goes to the even digit,** as C's `printf` and Python's format do:
  `0.125` with `places: 2` shows `0.12`.
  (Changed by D178: a tie goes away from zero, so `0.125` shows `0.13`.)
- **No `~`:** the text is exactly the rounding asked for, so nothing is hidden. Plain `be.Text($speed)` and
  `{$speed}` keep D155's honest `~0.30000000000000004`.
- **Braces stay names-only** (D29): `places: 2` says how the name is shown, and holds no calculation or call.
- **`places:` on anything but a `Float` is refused** at compile time, as the rest of `.fmt` text is checked.

How a negative value that rounds to zero shows, as `-0.001` with `places: 2`, isn't decided yet. (Decided by D176: `0.00`.)

**Weighed.**
- `be.Text($speed, places: 2)`, as the design claude first proposed. Tankun: `be` converts a value to another type,
  and rounding for a player is formatting, which is `.fmt`'s job.
- `{$speed[places: 2]}`. Reads like reaching an item, as `$list[pos: 2]` does (D75, D165).
- `precision:`, as C and Python call it. Jargon, and in `%.2g` it counts all significant digits, not those after the
  point.
- `digits:`, which doesn't say which digits, and `decimals:`, read two ways next to the future `Decimal` type (D157).

**Why this won.** A game can show a speed or a percentage cleanly, the `~` keeps its meaning wherever it appears, and
`places` is the school word for exactly this, "round to 2 decimal places", from place value, where each position in a
number is a place.

**Tankun's words.** "Idk if `~0.30000000000000004` is correct. Is that exact or est", "Isn't `be` conversion? Rather
than formatting", "Why is it called places?", "Why is it called places? Further down", then, asked "Should `.fmt`
braces take a `places:` setting, as in `{$speed, places: 2}`, which rounds a `Float` and shows it without `~`?", the
owner chose: "yea".

## D176. With `places:`, a value that rounds to zero shows no minus

2026-11-21.

**Chosen.** When `places:` (D175) rounds a negative `Float` to all zeros, the text has no minus: `-0.001` with
`places: 2` shows `0.00`. A value that doesn't round to zero keeps its minus, so `-0.006` shows `-0.01`.

**Weighed.**
- `-0.00`, as C's `printf` and Python's format show it. They write the sign of the value before rounding; some science
  tables keep it on purpose, to mean "a tiny bit below zero". A player reads it as a bug.

**Why this won.** In maths there's one zero, with no sign, so `0.00` is the correct rounding; `-0.00` comes from
IEEE 754's two zeros and from `printf` keeping the sign. Python added a `z` option in 3.11 (PEP 682) to get `0.00`,
because people kept wanting it; Unio makes it the only behaviour. How `be.Text` shows IEEE 754's negative zero itself
isn't decided yet.

**Tankun's words.** "What's correct", then, asked "Should `places:` drop the minus when a value rounds to zero, showing
`0.00` and not `-0.00`?", the owner chose: "yea".

## D177. A `Float` that would become infinite stops with a failed check, so a `Float` is always a real number

2026-11-21.

**Chosen.**
- **A result too big for a `Float`,** which IEEE 754 would make +∞ or −∞, stops the program with a failed check and
  status 4, as D46 already does for NaN and for a `Whole` that overflows.
- **Dividing a `Float` by zero** is D46's division-by-zero check, so it never gives infinity or NaN either.
- **So a `Float` only ever holds a real number:** no infinities, no NaN. IEEE 754's negative zero is the one special
  value left, and how `be.Text` shows it isn't decided yet. (Decided by D183: `0.0`.)
- The check's wording comes with a later batch (D54), and its test with it.

```
var $size: Float = 2.0;
while true:
    $size = $size * $size;   // stops once the result is too big for a Float
end while
```

**Weighed.**
- Infinity as a value, as IEEE 754, C, Python's floats and most languages have it. A speed or position of ∞ is a bug
  that spreads silently through every calculation it touches, as NaN does, and games have no use for it.
- Clamping to the largest `Float`. Quietly wrong, and hides the bug.

**Why this won.** It's the same mistake as `Whole` overflow, so it gets the same stop, and it costs almost nothing, since
the CPU's flags that D46 reads for NaN also record overflow. What's given up is a few numeric tricks, like starting a
search from ∞; a game starts from the first item instead.

**Tankun's words.** Asked "Should a `Float` that would become infinite stop the program with a failed check, as NaN
already does, so a `Float` is always a real number?", the owner chose: "yea".

## D178. `be.Whole` on a `Float` says how the fraction goes, and `.nearest` rounds as at school

2026-11-21.

**Chosen.**
- **`be.Whole` on a `Float` names how the fraction goes:** `.floor` down, `.ceil` up, `.trunc` cutting it off toward
  zero, or `.nearest`. A bare `be.Whole($distance)` on a `Float` is refused, with a fix listing them.
- **`.nearest` sends an exact tie away from zero,** as at school: 2.5 gives 3 and -2.5 gives -3.
- **`.nearest.even` is the option** that sends a tie to the even number, 2.5 to 2 and 3.5 to 4, for adding up many
  rounded values, where always going away from zero would push the total off.
- **`places:` (D175) sends ties away from zero too,** changing D175's ties-to-even, so `{$x, places: 0}` and
  `be.Whole.nearest($x)` always agree.
- **A `Float` too big for a `Whole`** stops the program with a failed check, as overflow does (D46).

```
let $steps: Whole = be.Whole.floor($distance);     // 2.7 → 2,  -2.7 → -3
let $shown: Whole = be.Whole.trunc($distance);     // 2.7 → 2,  -2.7 → -2
let $tiles: Whole = be.Whole.ceil($distance);      // 2.3 → 3,  -2.3 → -2
let $score: Whole = be.Whole.nearest($distance);   // 2.5 → 3,  -2.5 → -3
let $total: Whole = be.Whole.nearest.even($sum);   // 2.5 → 2,   3.5 → 4
```

**Weighed.**
- A bare `be.Whole` that cuts the fraction off, as C and Rust do. Which way it goes is a real choice, and with
  negatives `.floor` and `.trunc` differ, as D70 found for division.
- `.round`, as C, Python, JavaScript and Rust call it. Floor, ceil and trunc are all rounding too, IEEE 754's
  "rounding directions", so `.round` names the family, not the rule; `.nearest` says what it does.
- Ties to even as the default, as IEEE 754 and Python 3's `round` have it. Python's `round(2.5)` giving 2 is a classic
  beginner surprise, and a terminal game isn't summing millions of values.
- Always choosing the tie rule, as Cyborg's `as.round.even` and `as.round.away` do (its D425). The two differ only on
  exact halves, where one answer is what nearly everyone expects, so it's a default with an option, unlike D70's
  division, where `.floor` and `.trunc` differ on every negative.

**Why this won.** Every way of dropping a fraction is named for what it does, the common one gives what players learnt
at school, and the rare need for even ties is one word away. Tankun asked whether `.round` was accurate, which led to
`.nearest`, and proposed the school default with the option.

**Tankun's words.** "What does `.round` do?", "Is it accurate? The name", "You said `.nearest` needed decidied anoter
thihG?", "Make them choose?", "Wait, we're CLI game focused, right? So, we could have that opt, and default to
school?", then, asked "Should I log it like that?", the owner chose: "yea".

## D179. `/` on two `Float`s divides and rounds to the nearest `Float`

2026-11-21.

**Chosen.** On two `Float`s, `/` divides and rounds to the nearest `Float`, as `+`, `-` and `*` do:

```
let $share: Float = 10.0 / 3.0;   // ~3.3333333333333335
let $half: Float = $speed / 2.0;
```

- **Dividing by zero still stops** the program, by D46, so `/` never gives infinity or NaN (D177).
- **`div.floor` and `div.trunc` stay for `Whole`.** On a `Float`, dividing and then `be.Whole.floor` (D178) says the
  same in two steps.
- D70's exact `/`, where a remainder stops the program, stays as it is for `Whole`.

**Weighed.**
- D70's rule carried over, stopping when the result isn't exact. Most float divisions, even `1.0 / 3.0`, aren't, so
  it would stop nearly every one.

**Why this won.** A `Float` is approximate by design (D155), and every other operation on it already rounds to the
nearest; `/` is no different. Cyborg's D164 chose the same for its floats.

**Tankun's words.** Asked "Should `/` on two `Float`s divide and round to the nearest `Float`, like `+`, `-` and `*`?",
the owner chose: "yea".

## D180. A number literal's type comes from its point alone

2026-11-21.

**Chosen.** A number written with a point is a `Float`, and one without is a `Whole`, wherever it's written. A
literal never takes its type from where it goes:

```
let $speed: Float = 7.0;          // 7 is refused, fix: 7.0
let $fast: Float = $speed * 2.0;  // 2 is refused, fix: 2.0
let $half: Float = 7.0 / 2.0;     // 3.5
let $each: Whole = 7 / 2;         // Whole maths: stops on the remainder (D70)
let $lives: Whole = 3;            // 3.0 is refused, fix: 3
```

**Weighed.**
- A lone literal taking its type from where it goes, as `[]` does (D76), with the point deciding inside calculations.
  Tankun: "It says Float, though", and `let $speed: Float = 7` can't be misread. But then `$speed * 2` would be
  refused while `= 7` wasn't, and the rule would have two halves.
- Every literal without a point taking the type its place needs, `Whole` by default, as Swift has it. `$speed * 2`
  has only one reading under D162, but `7 / 2` would be 3.5 in `let $half: Float = 7 / 2` and `Whole` maths in
  `be.Text(7 / 2)`, so its meaning would depend on what's around it. Tankun: "Ah, so the problem is defaulting to
  Whole when there's no type. So, `.0` does look okay after all".

**Why this won.** A reader can tell a number's type by looking at it, `7 / 2` means the same everywhere, and D162's
"no quiet mixing" has no exception. The cost is typing `.0` on float literals, and each refusal gives the fix. Rust
does the same.

**Tankun's words.** "When did that mean Float?", "Why?", "It says Float, though", "Wait, why bullet 2?", "Ah, so the
problem is defaulting to Whole when there's no type. So, `.0` does look okay after all", then, asked "Should every
number literal's type come from the point alone, with a point a `Float` and without one a `Whole`, everywhere?", the
owner chose: "yea".

## D181. `be.Text` shows a `Float` with no fraction with `.0`

2026-11-21.

**Chosen.** `be.Text` shows a `Float` with no fraction with `.0`, as `7.0`, so the text reads back as a `Float`
(D180). D155's "shortest text that reads back as the same number" means the same number and the same type.

```
let $whole_speed: Float = 6.0 + 1.0;
show_msg(be.Text($whole_speed));             // 7.0
show_msg.fmt("{$whole_speed, places: 0}");   // 7, for a player
```

**Weighed.**
- `7`, as JavaScript prints it. JavaScript has one number type, so it has nothing to tell apart; in Unio, `7` is a
  `Whole`.

**Why this won.** The text is how that `Float` is written in a program, so it tells a programmer what kind of number
they're looking at, as the `~` does. Python and Rust print `7.0` too. A player sees `places:` (D175).

How a `Float` too big or too small to write out in full shows, like 10³⁰⁰, isn't decided yet. (Decided by D182: in full.)

**Tankun's words.** Asked "Should `be.Text` show a `Float` with no fraction as `7.0`, so it reads back as a `Float`?",
the owner chose: "yea".

## D182. `be.Text` writes a `Float` out in full, with no `e` notation

2026-11-21.

**Chosen.** However big or small a `Float` is, `be.Text` writes it out in full: the shortest digits that read back as
the same `Float` (D155), with zeros filling out to the point, never in `e` notation. 10²² shows as
`10000000000000000000000.0`, and 0.00001 as `~0.00001`. Where the zeros after the shortest digits aren't exactly what's
stored, the `~` says so: 2⁷⁰ shows as `~1180591620717411300000.0`. Unio has no `e` notation in literals either.

**Weighed.**
- `e` notation past a point, as Python's `1e+16` and `1e-05`, which would need `1.0e16` as a literal too, so the text
  reads back. A new form for beginners, mainly for science-sized numbers, and it can be added on its own later, say for
  a space game.

**Why this won.** Terminal games almost never meet numbers past a few million. A long run of zeros is honest and needs
nothing new to read, where `1e+16` puzzles anyone who hasn't met it. The largest `Float` is 309 digits long, a rare
cost.

**Tankun's words.** Asked "Should `be.Text` always write a `Float` out in full, with no `e` notation?", the owner chose:
"yea".

## D183. `be.Text` shows IEEE 754's negative zero as `0.0`

2026-11-21.

**Chosen.** `be.Text` shows IEEE 754's negative zero, as from `0.0 * -1.0`, as `0.0`, with no minus. Only the printing
hides the sign: if Unio adds maths functions where the sign of zero changes the answer, such as `atan2`, they follow
IEEE 754 on the bits.

**Weighed.**
- `-0.0`, as Python and Rust show it. True to the bits, but −0.0 and 0.0 are equal in every comparison, and the one
  operation IEEE 754 treats differently, dividing by them, already stops in Unio (D177).

**Why this won.** In Unio a negative zero behaves as zero in every way, maths has one zero, and `places:` already shows
no minus on a zero (D176), so the two ways of showing a `Float` agree.

**Tankun's words.** Asked "Should `be.Text` show IEEE 754's negative zero as `0.0`, with no minus?", the owner chose:
"yea".

## D184. Comparisons on `Float`s are exact, and `==` and `!=` on them are refused in a `while` condition

2026-11-21.

**Chosen.**
- **`==`, `!=`, `<`, `>`, `at_least` and `at_most` work on two `Float`s,** comparing the stored values exactly, as
  IEEE 754 does. `~0.1 + ~0.2 == ~0.3` is `false`: the sum is stored as ~0.30000000000000004 and `~0.3` as the
  `Float` just below it, two neighbours. IEEE 754's two zeros are equal (D183).
- **`==` and `!=` between two `Float`s are refused in a `while` condition,** with `<`, `>`, `at_least` or `at_most`
  as the fix. `if` keeps them.
- The refusal's wording comes with a later batch (D54), and its test with it.

```
var $timer: Float = 0.0;
while $timer != 1.0:          // refused, fix: while $timer < 1.0:
    $timer = $timer + ~0.1;
end while
```

Ten steps of `~0.1` make ~0.9999999999999999, not 1.0, and the eleventh skips past it, so with `!=` the loop never
stops.

**Weighed.**
- `==` refused on `Float`s everywhere. It also blocks exact checks that are right, like `$speed == 0.0` after setting
  the speed to `0.0`.
- An approximate `==`, true when close enough. "Close" has no one size, since neighbouring `Float`s are further apart
  the bigger they are, and it breaks equality's chain: a near b and b near c, but not a near c.
- `equal.exact`, a word with narrowings, as Tankun proposed, with bare `==` refused on `Float`s. It behaves exactly as
  `==` does, and unlike D70's `div.floor` and `div.trunc` there's nothing yet to choose between: "near enough" needs a
  tolerance, so it waits for float maths, and could be `equal.near` then.
- `==` exact everywhere with no refusal, as the design claude first recommended. The freezing loop is the worst form of
  the trap, with no message and nothing to point at, and its shape is easy to spot.

**Why this won.** `==` means "the same value" for every type, and tells the truth about what's stored, while the one
shape where float equality is nearly always a bug, a loop waiting to land on a value, is caught with its fix. Elsewhere
Unio's `~` on inexact literals and in printing shows why a comparison came out `false`.

**Tankun's words.** "Why?", "Why not a word? Like `equal` with narrowings", "What does `equal.exact` do?", "Why not
`==`?", "is `~0.3` and `~0.30000004` or whatever it is the same?", "why?", "I meant ==\", "What is the trap?", "So, do
we refuse tha?", then, asked "Should `==` and `!=` between two `Float`s be refused in a `while` condition, with `<`,
`>`, `at_least` or `at_most` as the fix, while working exactly everywhere else?", the owner chose: "ye".

## D185. `sqrt` gives a `Float`'s square root, and stops on a negative number

2026-11-21.

**Chosen.** `sqrt($x)` gives the square root of a `Float`, as a call like `random`:

```
let $distance: Float = sqrt($dx * $dx + $dy * $dy);
```

- **It gives the nearest `Float` to the true answer,** the same on every machine: IEEE 754 requires it, as it does for
  `+`, and every CPU does it in one instruction (D163).
- **A negative number stops the program** with a failed check and status 4: its square root isn't a real number, and
  IEEE 754's NaN isn't allowed (D177). The wording comes with a later batch.
- **It takes a `Float` only:** `sqrt(9)` is refused, with `sqrt(9.0)` as the fix (D180).
- The docs teach "`sqrt` is short for square root" (D2).

**Weighed.**
- `square_root`. Clearer to someone who's never seen it, but `sqrt` is the name in every language, calculator and
  tutorial a learner will meet, as `fmt` and `pos` are short forms already (D2).
- NaN for a negative number, as IEEE 754 and most languages give. D177 keeps NaN out.

**Why this won.** Games need it constantly, for the distance between two points, and it costs nothing to make exact.
Cyborg's D405 and D406 chose the same: correctly rounded, and stopping on a negative number.

**Tankun's words.** Asked "Should Unio have `sqrt` for a `Float`, giving the nearest `Float` and stopping with a failed
check on a negative number?", the owner chose: "yea. Should stdlib not be a lib".

## D186. A case may just end when the call it handles gives back no value

2026-11-21.

**Chosen.** In an `otherwise:` block after a call that gives back no value, as `.add` does, a case may end without
`instead`, `return`, `break` or failing on purpose, and the program carries on after `end otherwise`, as if the call
had worked. Calls that give back a value keep D40's rule.

```
$bag.add("Gem") otherwise:
    case full:
        show_msg("Your bag is full!");
end otherwise
show_msg("Onward!");
```

**Weighed.**
- D40 as it stood, with no way to carry on. D168's own example broke it, and a program telling the player "your bag is
  full" and going on is the common case.
- A closing word for such a case, like `carry_on;`. Every case would still end deliberately, but the word could only
  ever mean one thing, so it would be noise each time, and a second do-nothing ending next to `?? ignore`.

**Why this won.** D40's rule protects a value: a case after `let $best = load() otherwise:` that just ended would leave
`$best` holding nothing. After a call that gives back nothing, no value can be missing, and carrying on is the only
meaning an ending could have. The case is still written out, so the failure is never ignored silently (D23). Found
while writing D168's test.

**Tankun's words.** "why?", then, asked "Should a case be allowed to just end when the call it handles gives back no
value?", the owner chose: "yea".

## D187. An `if` or `while` condition must be a `Bool`

2026-11-21.

**Chosen.** The condition of an `if`, `else if` or `while` must be a `Bool`. A number or text doesn't stand for true
or false:

```
if $lives:              // refused, fix: if $lives != 0:
if $lives != 0:         // fine
if $found:              // fine, when $found is a Bool
```

The refusal's wording comes with a later batch (D54).

**Weighed.**
- Python's truthiness, where 0, empty text and an empty list count as false. A reader has to know the rule, and
  `if score:` being false for a real score of 0 is a classic bug.

**Why this won.** The condition says what it means, it fits Unio's other conversions, which are never quiet (D28,
D162), and Rust, Swift, Go and Java all do the same. Ralph raised it while building the oracle.

**Tankun's words.** Asked "Should an `if` or `while` condition have to be a `Bool`?", the owner chose: "yea".

## D188. A program's files are read in the byte order of their names

2026-11-21.

**Chosen.** The `.unio` files of a program (D64) are read in the byte order of their names, whichever file is named on
the command line: `Map.unio` before `map.unio`, and `enemies.unio` before `game.unio`. Running a program never depends
on the order; its messages do, such as which of two definitions of one name came first (D94) and which mistake is
reported first.

**Weighed.**
- The file named on the command line first, then the rest, as `Unlo\n` had it. The same program would give different
  messages depending on which file was named.
- The order the operating system sorts names in. It differs between macOS, Linux and Windows.

**Why this won.** The same folder always gives the same messages, on every system and however it's run. Found as a
disagreement between Ralph, which read in name order, and `Unlo\n`.

**Tankun's words.** Asked "Should a program's files be read in the byte order of their names, whichever file is named
on the command line?", the owner chose: "yea".

## D189. Ralph proves floats with Flocq, accepting its four standard axioms

2026-11-21.

**Chosen.** Ralph proves Unio's `Float` with Flocq, Rocq's standard IEEE 754 library, as CompCert does, so a theorem
can say in plain terms "`+` gives the nearest `Float` to the true sum". Flocq 4.2.2 is installed in the `ralph` switch,
from Rocq's own opam repository, added to that switch only. Its theorems rest on four axioms, which go on Ralph's list
of believed axioms (rule 14), each with its reason:
- **`classic`,** excluded middle: every statement is true or false.
- **`functional_extensionality_dep`:** functions giving the same output for every input are equal.
- **`sig_not_dec` and `sig_forall_dec`,** from Rocq's real numbers, which let reals be compared as school maths does.

They're independent of Rocq's own logic, so Rocq can neither prove nor disprove them, and Rocq with them is known to
be consistent if ordinary set theory (ZFC) is. They appear only in proofs: Ralph's running code does plain arithmetic
on the bits.

**Weighed.**
- Proving floats directly on their bits, with no real numbers and no axioms. Far more work, and no theorem could speak
  of the true sum, which is a real number.
- Trusting OCaml's own floats, unproven. Breaks the promise that Ralph's meaning is proven.

**Why this won.** It keeps Ralph's trusted base small, standard and written down: these four, Rocq's kernel, extraction
and OCaml. MetaRocq has proven Rocq's logic sound, given its consistency, which no logic can prove of itself.

**Tankun's words.** "install", "Was the tester proved?", "That is so unresponsible, ugh", "Ah, they aren't proven,
right?", "Is Rocq proven by SPARK Platinum and Rocq?", then, asked "Should Ralph accept these four standard axioms, listed in its axioms
file, for proving floats?", the owner chose: "yea".

## D190. `eq` and `not_eq` compare, `-> Type` gives a procedure's result, and `! [ … ]` its failures

2026-11-23.

**Chosen.**
- **`eq` and `not_eq` replace `==` and `!=`:** `if $guess eq $secret:`. `<` and `>` stay, as school maths writes them,
  beside D17's `at_least` and `at_most`.
- **`-> Type` replaces `returns`:** `proc double[$n: Whole] -> Whole:`. A procedure that gives nothing back writes no
  `->`.
- **`! [ … ]` replaces `fails`,** its failures in `[ ]`, after `-> Type` when there is one:
  `proc load_level[$name: Text] -> Level ! [not_found, broken]:`.
- **So `!` has one job, failures** (D60), now that nothing uses it for "not".

```
proc load_level[$name: Text] -> Level ! [not_found, broken]:
proc save_game[$state: Text] ! [disk_full]:
if $guess not_eq $secret:
```

D14's refusal of `=` in a condition now gives `eq` as its fix and says "`eq` compares". This matches Seal's D45, and
Cyborg's `->`. Ralph and `Unlo\n` build the old spellings, so the tests changing under them need telling; Seal's
comparisons, which came from Unio (Seal D22), are a separate question.

**Weighed.**
- `returns` and `fails`, as words, as Unio had them: they read aloud and explain themselves, which matters most in the
  beginner language. But `->` is familiar, and `!` stops being a trap once `!=` is gone.
- `-> Type` with `fails` kept as a word, as the design claude first recommended, because `!` beside `!=` would mean
  two things. Tankun's `eq` and `not_eq` remove `!=`, which removes the reason.
- `==` and `!=` kept: `=` against `==` is the classic beginner mistake, which needed D14's special refusal; with `eq`
  there's no `==` to confuse with `=`.

**Why this won.** The comparisons finish what D17 started with `at_least` and `at_most`, turning programming symbols
into words while keeping school maths' `<` and `>`, and that frees `!` for one job, so Unio's procedures can read as
Seal's and Cyborg's do. C++ has `not_eq` as a real spelling of `!=`, and Perl compares text with `eq`.

**Tankun's words.** "Honestly? I kinda want `eq` for `==` in Unio, and `->` & `!` for `proc`", "That's why `eq` for
`==`, and then it would `not_eq`", "What about the arrow?", then, asked "Should Unio take all three, `-> Type`, `! [ …
]`, and `eq` and `not_eq`, in place of `returns`, `fails`, `==` and `!=`?", the owner chose: "yes".

## D191. Unio's compiler is called `Beta++`

2026-11-23.

**Chosen.** Unio's compiler, written in C++ on LLVM (D131), is called `Beta++`, replacing D137's `Unlo\n`. It pairs with the
oracle's name: Ralph is from "Rocq Alpha", the first implementation, in Rocq; `Beta++` is the second, in C++. A third,
someday, would be Gamma. People still type `unio` to run it (D136, D137).

**Weighed.**
- `Unlo\n`, Unio with its `i` swapped for an `l`, in the family of Cyborg's `OKAY\n` and CyborgPL's `KAYO\n`.
- `Un1o\n`, `Oinu\n` and `Unus\n`, the design claude's suggestions: more `\n` look-alikes and anagrams.
- "Beta" also means unfinished software, and BETA is a dormant 1980s language from Norway; neither matters much for
  an in-joke that tells the implementations' story.

**Why this won.** The two names tell the order and the language of each implementation, the proven one first and the
fast one second, which suits Unio, whose implementations are built as a pair.

**Tankun's words.** "Any new compiler names?", "I meant Unio's", "`Beta++`?
Impl in C++, and is the second impl.", "What is c letter full name? Cockimus?", "Gamma means three? Shit, why is it not
cm", then, asked "Should Unio's compiler be renamed from `Unlo\n` to `Beta++`?", the owner chose: "Yea".

## D192. Names have no `$` again, and the `unio` command and the docs colour code

2026-11-24.

**Chosen.** A variable's name, a parameter's included, is a plain word with no mark, replacing D125:

```
let secret: Whole = random(from: 1, to: 100);
var tries: Whole = 0;
tries = tries + 1;
show_msg.fmt("You got it in {tries} tries.");
proc add[a: Whole, b: Whole] -> Whole:
```

What follows from it:
- **A name can't be a keyword,** a variable's or a procedure's, as D58 had it: `let if: Whole = 1;` is refused, with
  D87's wording. A keyword added later breaks programs already using that word as a name.
- **A variable can't take a procedure's name,** D94's second half again, replacing D127: `let roll: Whole = roll();`
  is refused, with D102's wording.
- **`.fmt`'s braces hold the bare name,** as in `{tries}`. D133's refusal of a name without `$` goes.
- **The `unio` command and the docs colour code** wherever they show it, so names, keywords, procedures, methods and
  types look different. Which colours, and when the command uses them, aren't decided yet.

**Weighed.**
- Keeping `$` (D125). Names, keywords and methods stay apart in text with no colour, in chats, screenshots and plain
  terminals, as in `if $hp eq $max and not $won:`, and in `$scores.len` beside `show_msg.fmt`. Shown the same program
  four ways, with and without `$`, plain and highlighted, Tankun found the highlighted one without `$` the easiest to
  read.
- Dropping `$` with no promise of colour. Where Unio's code shows up bare, words like `eq`, `and` and `not` blend into
  the names around them.

**Why this won.** With colour, `$` does work the colours already do, and D58's reason, that code is mostly read where
it can be coloured, still holds. Making colour part of Unio's own command and docs covers the places a learner reads
code first. Nothing built has to change: Ralph's next prompt isn't pasted yet, and the tests and the standard change
with this entry. The costs are D58's: names can't be keywords, a new keyword can break programs, and a variable can't
share a procedure's name.

**Tankun's words.** "Honestly? Not really, thinking again. Having Unio add var type infer, and removing `$` would
likely do it. But we already did `$` and came back. So, I might look like I'm fucking mental. It was with methods,
right? Like, wait, don't they have `()`?", "But highlighting solves it, though. But yk? I'd rather see both side by
side, with and without highlighting. And btw, don't use the logo tool thingy, them fucking makers used a fucking shit
prompt", "No fucking way, highlighting absolutely blessed my eyes, even without sigil", then, asked "Should `$` go,
replacing D125, with the `unio` command and docs colouring code?", the owner chose: "yea. But what colors do we use,
are there a standard?"

## D193. Unio has its own fixed colours, the same in the docs, the `unio` command and its editor theme

2026-11-24.

**Chosen.** Unio's code colours are Unio's own, one fixed set, so the docs, the `unio` command and Unio's editor theme
show code the same way, and the docs can teach what each colour means:
- **The `unio` command uses the exact colours** where the terminal can show any colour (24-bit colour), and the nearest
  of the 16 basic ones where it can't.
- **They read on dark and light backgrounds,** with a version for each where one set can't do both.
- **The command colours only what goes to a terminal,** never output going to a file or another program, so the tests
  compare the same bytes, and nothing when `NO_COLOR` is set.

The colours themselves aren't decided yet.

**Weighed.**
- Unio naming only the kinds (keyword, variable, procedure and so on, using the Language Server Protocol's standard
  kinds), with the editor's and the terminal's theme picking the colours, as most languages do. The colours would differ
  between the docs and each learner's screen, so the docs couldn't teach "names are blue".

**Why this won.** A learner sees the same colour for the same kind in the book, in the command's messages and in
Unio's editor theme. Other editors may colour differently, and the docs say so once: they still colour by the same kinds.

**Tankun's words.** "That's pretty weird, then how are we gonna teach colors?", then, asked "Should Unio have its own
fixed colours, the same in the docs, the `unio` command and its editor theme?", the owner chose: "yea. But even fucking
ISO doesn't have a standard for this shit?"

## D194. Unio's colours: Solarized's, made readable on common backgrounds, with red only for errors

2026-11-24.

**Chosen.** D193's fixed colours are:

| Kind | Looks | Dark version | Light version |
|---|---|---|---|
| keywords, as in `if`, `let`, `eq` | green, bold | `#859900` | `#687700` |
| variables and parameters | blue | `#3a95d6` | `#2073ae` |
| procedures and narrowings, as in `heal`, `show_msg.fmt` | yellow | `#b58900` | `#8b6900` |
| methods, as in `bag.len` | orange | `#d7744c` | `#c14715` |
| types, as in `Whole`, `List<Text>` | pink | `#de66a0` | `#c8337c` |
| labels, as in `by:` | violet, italic | `#8589ce` | `#6368b4` |
| text and numbers | cyan | `#2aa198` | `#207c75` |
| comments | grey, italic | `#8f8f8f` | `#6e6e6e` |
| brackets, punctuation and operators | grey | `#8f8f8f` | `#6e6e6e` |
| errors only: `refused:`, `check failed:`, `failed:` and the `^` under the cause | red | `#e56765` | `#d3302d` |

- **Each colour starts from Solarized's,** brightened for the dark version or darkened for the light one only as far as
  it takes to reach a contrast ratio of 4.5 (the web's accessibility line for easy-to-read text) on every common
  background of its kind: black, Solarized dark (`#002b36`) and VS Code's dark (`#1f1f1f`); white, which is also VS
  Code's light, and Solarized light (`#fdf6e3`).
- **Red means an error** and nothing else.
- **Brackets and punctuation are a plain grey,** with no blue in it, so they fade behind the names.

How the command tells a dark background from a light one isn't decided yet.

**Weighed.**
- A first draft with procedures violet and punctuation Solarized's blue-grey. Tankun: the `[` next to `heal` looked
  too alike, so procedures became yellow, types pink and labels violet, with punctuation a plain grey.
- Solarized's colours as they are. Several fall well short of 4.5 on Solarized light, cyan at 2.9 among them.
- Higher contrast throughout. Solarized's softer contrast is what's comfortable for Tankun's eyes, so each colour moves
  only as far as it must.

**Why this won.** Solarized is the theme Tankun reads code in, every kind gets its own colour on all five backgrounds,
and keeping red for errors means an error always looks like one.

**Tankun's words.** "What do these numbers even mean, bro? Are we fucking benchmarking color now?", "Idk what those
mean, just do shit, and show them in backgrounds", "Holy shit, that `[` color being close to `heal` is not helping",
"Better, but types and labels look too alike

No, they don't. I think it's good now", then, asked "Should the second draft become Unio's colours?", the owner
chose: "yea. Btw, you forgot `[]` on labels. And I also think we should remove `:` block starters. What about the
font?"

(Changed by D197: a narrowing takes the colour of what it narrows. Changed by D196: `be` is a built-in procedure, and `.len` a fact.)

## D195. The `labels` line puts its pairs in `[ ]`

2026-11-24.

**Chosen.** A `labels` line writes its pairs in `[ ]`, with one space after `labels`, replacing D25's line with no
brackets:

```
proc heal[hp: Whole, amount: Whole, max: Whole] -> Whole:
    labels [amount as by, max as up_to];
```

A `labels` line without its `[ ]` is refused; its wording comes with a later batch. Everything else in D25 stands: the
line is the body's first, and callers write the labels as before, as in `heal(hp, by: 30, up_to: 100)`.

**Weighed.**
- No brackets (D25). Its reason was that `[ ]` meant a list, and these pairs aren't one. D165 then widened `[ ]` to
  values listed or described, a procedure's parameters included, which aren't a list the program works with either,
  so the reason no longer holds.

**Why this won.** The pairs describe the procedure's parameters, the same job `[ ]` does in the header just above, so
the brackets rule (D165) covers them. It also matches Seal's `labels [ ]` (Seal D42).

**Tankun's words.** "yea. Btw, you forgot `[]` on labels. And I also think we should remove `:` block starters. What
about the font?" (quoted whole in D194), "You sure with the labels?", "Look at the brackets rule", then, asked "Should
the `labels` line put its pairs in `[ ]`, replacing D25?", the owner chose: "change"

## D196. Keywords are Unio's grammar words; `be`, `.fmt`, `.same_line` and `.len` are built-ins

2026-11-24.

**Chosen.** Two words for Unio's own names:
- **A keyword** is a word of Unio's grammar, like `if`, `let`, `proc`, `eq` or `labels`.
- **A built-in** comes with every program to be used: a procedure like `show_msg`, `ask`, `be`, `random` or `sqrt`,
  with its narrowings, a fact like `.len`, or `range`. Chapter 9 lists them.

`be` (D22), `.fmt` (D29), `.same_line` (D6) and `.len` (D79) leave the keyword list and become built-ins. What follows:
- **A built-in is coloured as what it is** (D194): `be.Whole` is a procedure's yellow, with no exception to explain,
  and `.len` a fact's orange. Chapter 3's colour table now says "methods and facts" where it said "methods", since
  `.len` is a fact (D79).
- **`let be: Whole = 1;` is still refused,** now because a variable can't take a procedure's name (D94, D192) rather
  than because `be` is a keyword. `fmt`, `same_line` and `len` only ever follow a `.`, so they can now be names.
- **The docs still teach a built-in's full word,** as D2 has them do for keywords: `.fmt` is short for format.

**Weighed.**
- Keeping them as keywords, with `be` coloured as a procedure anyway. The docs would need a sentence on why a keyword
  isn't coloured like one, which is the mismatch Tankun pointed out.
- "Built-in procedures" for the second word. `.len` is a fact and `range` isn't called, so "built-ins" covers them all.

**Why this won.** Each name is what it looks like: a keyword shapes the program, and a built-in is used like anything
written in Unio, coloured the same way. Chapter 9 was already called "Built in".

**Tankun's words.** "". It's listed as a keyword but coloured as a procedure, so the docs need one sentence on why:
"be.Whole(x) is called like a procedure,"

so, then we should differentiate keyword vs built-in proc, or use another term", "So, `keywords` and `built-in
procedures`?", then, asked "Should Unio have keywords and built-ins, with `be`, `.fmt`, `.same_line` and `.len`
moving to the built-ins?", the owner chose: "yea"

(Changed by D200: `.fmt` goes, since every text fills its braces.)

## D197. A narrowing takes the colour of what it narrows

2026-11-24.

**Chosen.** A narrowing is coloured like the name it narrows, so a narrowed name is one colour across its `.`,
replacing D194's yellow for every narrowing:

```
show_msg.fmt("Hi {name}")   // all yellow: a procedure
proc.main:                  // all green, bold: a keyword
bag.len                     // blue, then orange: a fact
```

A method or a fact still changes colour at its `.`, so whether the colour changes tells a narrowed name from a method
or fact on a value. A type with a narrowing, should Unio have one, would be all pink.

**Weighed.**
- Every narrowing yellow, as D194 had it. `proc.main` would be green then yellow, and a narrowing on a type, like a
  `Text.utf16`, would look like a procedure.
- A colour of its own for narrowings, so long chains like `be.Whole.nearest.even` show each part. An eleventh colour,
  hard to keep apart from yellow, orange, pink and violet on five backgrounds.

**Why this won.** A narrowed name is one thing, so it gets one colour, and the rule works for narrowings not yet
decided. A learner needn't remember which words are narrowings: the colour staying the same or changing at the `.`
shows it.

**Tankun's words.** "Wait, before I continue, Why is `.main` orange?", "They look different enough. But wait, I
thought that yellow meant proc", "Why narrowings the same? Just asking", "`Text.utf16` when needed?", "Good?", "Would
that be confused with meth?", then, asked "Should a narrowing take the colour of what it narrows?", the owner chose:
"yea"

## D198. The docs show code in Atkinson Hyperlegible Mono, with no ligatures

2026-11-24.

**Chosen.** Unio's docs show code in Atkinson Hyperlegible Mono, in its regular, bold and italic, with ligatures off,
so `->`, `!=` and the like always show as the characters a learner types. The terminal and editors keep the learner's
own font; the docs are the one place Unio picks it.

**Weighed.**
- JetBrains Mono, a popular font made for code, and Menlo, the Mac's default, shown side by side in D194's colours.
- A font of Tankun's own, released as CC0. A project of its own, and it can't start from an existing font under the
  SIL Open Font License, which keeps anything made from one under the same licence. Swapping the docs' font later is
  one line, so it stays open for later.

**Why this won.** The Braille Institute made the Atkinson Hyperlegible family for readers with low vision, and the
Mono version keeps look-alikes apart (`0` and `O`, `1`, `l` and `I`), which suits a teaching language. It's free under
the SIL Open Font License, so the docs can carry it, and it has the bold and italic D194 uses.

**Tankun's words.** "Lol, kinda want my own CC0 font?", "Bro, I think I'm seeing the same fonts here", then, shown the
three fonts again, the owner chose: "Atkin. Btw, why is `.main` still yellow?"

## D199. A block's opening line ends with nothing, no `:`

2026-11-24.

**Chosen.** A block's opening line ends with nothing, replacing D8's `:`. Its closer is still `end` and what it closes
(D8):

```
proc heal[hp: Whole, amount: Whole] -> Whole
    if hp + amount at_least 100
        return 100;
    else
        return hp + amount;
    end if
end proc heal
```

What follows from it:
- **Every opening line drops its `:`:** `proc.main`, `else`, `while true`, `for each name in students`, `otherwise`,
  `case full`, `comment old_scoring`, `fam.proc show_msg`.
- **An opening line ending with `:`, as Python writes it, is refused,** with the line without it as the fix; its
  wording comes with a later batch. D8's message for a missing `:` goes, and so does its test.
- **`:` has one meaning left:** a name, then what it is, as in `hp: Whole`, `by: 30` and `[pos: 1]`.

**Weighed.**
- Keeping `:` (D8). Python's look, the language most learners meet next, and an opening line could someday run over
  several lines with `:` marking where it ends. Unio hasn't decided whether a condition can span lines, so nothing is
  lost today.

**Why this won.** `end` already marks where every block ends, so the `:` only repeated what the line's first word
says, and a missing one was a common beginner mistake. Without it, `:` means one thing, as Unio's symbols do (D3,
D165). Ruby and Seal (Seal D9) open blocks the same way.

**Tankun's words.** "yea. Btw, you forgot `[]` on labels. And I also think we should remove `:` block starters. What
about the font?" (quoted whole in D194), then, asked "Should block openers lose their `:`, as in `if hp at_least max`
and `else`, replacing D8's `:`?", the owner chose: "yea. How do i switch Claude to atkin for code"

## D200. Every text fills in what's in braces, with `\{` for a brace as it is; `.fmt` goes

2026-11-24.

**Chosen.** Text fills in the names in its braces wherever it's written, replacing D29's `.fmt`:

```
show_msg("Found the {item}!");
let line: Text = "{name}: {score}";
show_msg("Type \{help} for commands");
```

- **A brace to show as it is is written `\{`,** D30's escape, so the last line shows `Type {help} for commands`.
- **Everything else D29 and D175 say about braces stands:** they hold only a variable's name, a number in them becomes
  text by itself, a name that isn't a variable is refused while building, and a `Float` can take `places:`.
- **`.fmt` goes,** from `show_msg` and `be.Text`, and from D196's built-ins. `show_msg.same_line` stays.

**Weighed.**
- `.fmt` (D29). Plain text stays plain, so text full of braces needs no `\`, but there are two kinds of text, and
  `show_msg("{tries}")` showing `{tries}` is a beginner trap.
- A form for whole text taken as it is, with no filling. `\{` already covers each brace, and text full of braces is
  rare in terminal games.

**Why this won.** One kind of text, filled the same way in a call or a variable, as Swift, Kotlin, Ruby and
JavaScript's template text do. A brace that wasn't meant to fill gets caught while building, since a name in braces
must be a variable, and the fix is a `\`.

**Tankun's words.** "Should we make Unio have only format text? Even in like vars? And an non-default way to be
literal", then, asked "Should every text fill `{name}` by itself, with `\{` for a literal brace, replacing `.fmt`?",
the owner chose: "yea"

## D201. Text is joined only with braces; `&` goes

2026-11-24.

**Chosen.** Unio has no operator for joining text, replacing D28's `&`. Text is joined by filling it in (D200):

```
show_msg("{first} {last}");
line = "{line}*";
let total: Whole = sum(scores);
show_msg("Total: {total}");
```

What follows from it:
- **A call's result is named before it's shown,** as `total` above, since braces hold only names (D29).
- **`+` on text is still refused** (D28), with the braces form as its fix. D87's wording keeps its shape with a new
  `why:`: "`+` is only for numbers; text is joined by filling it in with braces."
- **`&` in a program is refused;** its wording comes with a later batch. D72's rule and D89's message for `&` next to
  maths go, and so does D28's test.

**Weighed.**
- Keeping `&` for joining texts already in hand, as in `first & " " & last`, and call results, as in
  `"Total: " & be.Text(sum(scores))`. Two ways to build the same text, and learners meet both.

**Why this won.** `"{first} {last}"` looks like what it shows, spaces and all, and with braces working everywhere
(D200), `&` would be a second spelling for the same job, where Unio keeps one (D2, D128). Naming a call's result first
gives every shown value a name.

**Tankun's words.** has code, "Why?", then, asked "Should `&` go, so text is joined only with braces?", the owner
chose: "yea"

## D202. Braces fill in a `Bool` by itself, as `true` or `false`

2026-11-24.

**Chosen.** A `Bool` in braces becomes text by itself, as a number does (D29), showing `true` or `false`, as
`be.Text` gives (D153):

```
let won: Bool = true;
show_msg("Won: {won}");         // Won: true
```

**Weighed.**
- Only numbers filling in, as D29 had it, so a `Bool` is converted first with `be.Text` and named. A line more for
  each, with nothing gained since D153 already says how a `Bool` shows.

**Why this won.** Braces treat every simple value the same, and since D201 a shown value is often filled into text,
so the extra line would come up often.

**Tankun's words.** "?", meaning "What?", to the first wording of the question, then, asked "Should braces fill in a `Bool` by itself, as `true` or `false`?", the
owner chose: "yea"

## D203. Variables keep their written type: no type inference, as D13 has it

2026-11-24.

**Chosen.** D13 stands: every `let` and `var` writes its type, with no type worked out from the value.

```
let name: Text = "Tankun";
let names: List<Text> = ["M", "M"];
```

**Weighed.**
- A `let` or `var` taking its type from its value, writing it only where the value can't show the whole type, after
  Keel, a sketch from Mult. Shorter lines, but a plain `[ … ]` can be a `List` or an `Array` and can carry a limit,
  so an `Array`, a list with a limit and an empty `[]` would still write theirs: a list of exceptions to learn.
- Inference with the type optional everywhere. Every line gets two spellings.

**Why this won.** One rule with no exceptions, types on the page where a learner sees them, and Mult's reason from D13
still holds: nothing looks typeless and then surprises a learner later.

**Tankun's words.** "yea" (to taking the question up), "`["M", "M"]` is infer?", "Or just no ty infe?", then, asked
"Should Unio keep D13, with every `let` and `var` writing its type?", the owner chose: "Y"

## D204. The wording of the tenth batch: today's new refusals, and four wordings brought up to date

2026-11-24.

**Chosen.** Drafted by the oracle session and reviewed by the design session, as Tankun asked for wordings (D132):

| Refusal | `what:` or `fix:` | `why:` |
|---|---|---|
| a `$` in a name (D192) | `fix:` the line without the `$`s | a name is a plain word, with no `$`. |
| `==` or `!=` (D190) | `fix:` the line with `eq` or `not_eq` | `` `eq` and `not_eq` compare two values; Unio has no `==` or `!=`. `` |
| `&` (D201) | `` `&` isn't how Unio joins text `` | `` text is joined by filling it in with braces, as in `"{first} {last}"`. `` |
| an opening line ending in `:` (D199) | `fix:` the line without it | `` a block's opening line ends with nothing; `end` shows where the block ends. `` |
| a `labels` line without `[ ]` (D195) | `fix:` the line with them | `` a `labels` line puts its pairs in `[ ]`. `` |
| a `Whole` as a condition (D187) | `fix:` the line with `not_eq 0` after the condition | `` a condition is a `Bool`; a number or text doesn't stand for true or false. `` |
| any other non-`Bool` condition (D187) | `` this condition is a `Text`, but a condition is a `Bool` ``, naming its type | the same |
| `places:` on a non-`Float` (D175) | `` `places:` rounds a `Float`, but `won` is a `Bool` `` | `` `places:` says how many digits after the point a `Float` shows. `` |
| `+` on two texts where no braces fix can be shown, as for a call's result (D201) | D89's `` `+` works on two `Whole`s, but this is a `Text` and a `Text` `` | D201's: "`+` is only for numbers; text is joined by filling it in with braces." |
| a variable with a built-in procedure's name (D102, D196) | D102's wording | D102's, with no `because:`, since a built-in has no line to point at |

Four decided wordings follow later decisions: D88's five messages say `->` where they said `returns` (D190); D87's
"`?`, `??` or `otherwise:`" and D102's `else:` read `otherwise` and `else` (D199); and D92's "braces in `.fmt` text"
reads "braces in text" (D200).

**Weighed.** Nothing else was weighed: each draft follows D54's layout, D89's "but" for what's found against what's
expected, and the wording already decided for the nearest refusal.

**Why this won.** Each says what's wrong and names the rule, as every decided message does.

**Tankun's words.** "Anyways, you'll be reviewing the err msgs for now, by yourself. Find real problems, not invent
one. If you aren't sure, bring it to me." (quoted in D132), then, shown the drafts, Tankun said: "Bro, aren't you
fucking review them yourself? And give them to me when you're unsure?"

## D205. The wording of the eleventh batch: failures, dividing, lists, `for each` and `range`

2026-11-24.

**Chosen.** Drafted by the oracle session (its `PROGRESS.md`, "Batch 2", has the full list) and reviewed by the design
session, as Tankun asked for wordings (D132). The main ones:

| Refusal or check | `what:` | `why:` |
|---|---|---|
| `?`, `?? crash`, `?? ignore` or `otherwise` after no failing call | D102's `??` sentence with the word swapped | as in "`` `otherwise` deals with the failures of the call right before it. ``" |
| `?` passing up a failure its procedure doesn't list (D23) | `` `load` can fail with `missing`, which this procedure doesn't list ``, with `because:` "its failures are listed here" | `` `?` passes a failure up to the caller, so the procedure lists it after `!`. `` |
| a failure no case deals with (D40) | `` `load` can fail with `broken`, and no case here deals with it `` | |
| a case for a failure the call doesn't have | `` `load` can't fail with `gone` `` | |
| a case that can reach its end with no value (D40) | `` this case can reach its end without `instead`, `return` or `break` `` | `` after a call that gives back a value, each case ends with `instead` a value, `return` or `break`, so there's always a value to carry on with. `` |
| a bare `div` (D70) | `` `div` needs to say how it rounds: `div.floor` or `div.trunc` `` | |
| dividing by zero (D72) | `` a `Whole` can't be divided by zero ``, `when:` as in `7 div.floor 0` | dividing by zero has no answer. |
| `/` that isn't exact (D70) | `7 doesn't divide exactly by 2`, `when:` `7 / 2` | `` `/` is for numbers that divide exactly; `div.floor` and `div.trunc` round. `` |
| a position past the end (D75) | `` this list has no item at `pos: 4` ``, `when:` "the list holds 3 items" | `` `pos:` counts from 1 up to the list's length. `` |
| `pos: 0`, `.add` on an array, a literal of the wrong length for an array, a bare number in `[ ]` (D75, D167) | `` no list has an item at `pos: 0` ``, `` an array has no `.add` ``, "this has 3 items, but the array holds exactly 2", `` an item is reached with `pos:` or `offset:` `` | |
| changing a list inside its own `for each` (D173) | `` `players` can't change here, since this `for each` is going through it ``, with `because:` "the `for each` is here" | `` a `for each` can't change the list it's going through; to change it while looping, use `while`. `` |
| a range that never reaches its end (D172) | `` this `range` never reaches its end ``, with `when:` as in "from: 10, to: 1, step_by: 1" when it's found at runtime | `` a range counts from `from:` toward its end, so `step_by:` points that way, and isn't 0. `` |

**Weighed.** Nothing else was weighed: each follows D54's layout and the wording already decided for the nearest
refusal, and the `for each` one says what D173 itself says to do instead.

**Why this won.** Each says what's wrong and names the rule, as every decided message does.

**Tankun's words.** "Anyways, you'll be reviewing the err msgs for now, by yourself. Find real problems, not invent
one. If you aren't sure, bring it to me." (quoted in D132), and "Bro, aren't you fucking review them yourself? And give
them to me when you're unsure?" (quoted in D204).

## D206. The wording of the twelfth batch: floats

2026-11-24.

**Chosen.** Drafted by the oracle session and reviewed by the design session, as Tankun asked for wordings (D132):

| Refusal or check | `what:` or `fix:` | `why:` |
|---|---|---|
| an inexact literal without `~` (D155) | `fix:` the line with the `~` added | `` `0.1` can't be stored exactly in a `Float`, so it's written `~0.1`, to show it's approximate. `` |
| a number without a point where a `Float` goes, or with one where a `Whole` goes (D180), as in `speed * 2` or `sqrt(9)` | `fix:` the line with the point added or taken away | `` a number written with a point is a `Float`, and one without is a `Whole`. `` |
| a `Whole` and a `Float` in one calculation (D162) | `fix:` the `Whole` wrapped in `be.Float(...)` | `` a `Whole` and a `Float` don't mix in one calculation; `be.Float` makes the `Whole` a `Float`. `` |
| a bare `be.Whole` on a `Float` (D178) | `` `be.Whole` on a `Float` says how the fraction goes: `.floor`, `.trunc`, `.ceil`, `.nearest` or `.nearest.even` `` | `` each gives a different whole number for a `Float` with a fraction, so the program says which. `` |
| `eq` or `not_eq` between `Float`s in a `while` condition (D184) | `` this `while` condition compares two `Float`s with `not_eq` ``, with no `fix:`, since which comparison fits depends on which way the value moves | `` a `Float` that changes each pass rarely lands exactly on a value, so the loop could pass it and never stop; `<`, `>`, `at_least` or `at_most` say "until it reaches". `` |
| a `Float` as a condition (D187) | `fix:` the line with `not_eq 0.0` after the condition | D204's |
| a `Float` result too big (D177) | `` the result is too big for a `Float` ``, `when:` as in `x * y` with the values | `` a `Float` is always a real number, and this one is past the largest a `Float` holds. `` |
| a `Float` divided by zero (D46) | `` a `Float` can't be divided by zero `` | D205's |
| `sqrt` of a negative number (D185) | a negative number has no square root, `when:` as in `sqrt(-4.0)` | a `Float` is always a real number, and no real number squared is negative. |
| `be.Whole` of a `Float` too big for a `Whole` (D178) | `` the result is too big for a `Whole` ``, `when:` as in `be.Whole.floor(x)` with the value | D92's |

**Weighed.** Nothing else was weighed: each follows D54's layout and the wording already decided for the nearest
refusal. Whether `~` on an exactly stored number, as in `~0.5`, is refused at all is a design question, not a wording,
and goes to Tankun.

**Why this won.** Each says what's wrong and names the rule, as every decided message does.

**Tankun's words.** "Anyways, you'll be reviewing the err msgs for now, by yourself. Find real problems, not invent
one. If you aren't sure, bring it to me." (quoted in D132), and "Bro, aren't you fucking review them yourself? And give
them to me when you're unsure?" (quoted in D204).
