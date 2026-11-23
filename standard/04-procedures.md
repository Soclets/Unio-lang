# 4. Procedures

## Definitions

```
proc name[parameters] -> Type:
    body
end proc name
```

where `name` is the procedure's name, `parameters` its parameters separated by commas, `Type` the type it gives back,
and `body` its statements. `proc`, `->`, the brackets, the `:` and `end proc` are written as they are (D3, D8, D190).

A definition writes its parameters in `[ ]` (D165), and only when it has some; written in `( )`, they're refused,
with the `[ ]` form as the fix (D166). One that takes nothing has no brackets
(D4):

```
proc roll_dice -> Whole:
    ...
end proc roll_dice
```

where `...` stands for the procedure's body.

A procedure that gives back a value says so at the end of its header, with `->` and the type (D37, D190).

A procedure that gives nothing back writes no `->` (D38, D190):

```
proc greet[$name: Text]:
```

Using what such a procedure gives as a value is refused (D38).

### `return`

- **`return value;`** gives back a value of the header's type, and every way through a procedure with `->` must
  end in one (D57). Every `while` counts as able to end, whatever its condition, so a procedure that loops with
  `while true:` still needs a `return` after the loop (D149).
- **A bare `return;`** leaves early, in a procedure with no `->` (D57).
- **Nothing may follow `return` in the same block** (D57).
- **A bare `return;` as a procedure's last line is refused** (D57).

### Parameters

Each parameter is written as its name, with its `$`, then `:` and its type, as a declaration is, even when several share
a type (D125, D126). Writing a shared type once in front, as in `proc add[Whole a, b]`, is refused (D126): A plain
parameter is read-only, like a `let` (D147).

```
proc add[$a: Whole, $b: Whole] -> Whole:
proc draw[$x: Whole, $name: Text]:
proc double[$n: Whole] -> Whole:
```

Failures in a header: chapter 8.

## Procedures written in C++

`extern.cpp` in front of `proc` says the procedure's body is written in C++, outside the Unio file. Its body is
empty, or holds only a `labels` line, and its closer doesn't repeat `extern.cpp` (D36, D131):

```
extern.cpp proc beep -> Bool:
end proc beep
```

Callers can't tell it apart from any other procedure. `extern` is short for external (D2, D36).

**Not decided:** where the C++ code lives, and how it's built and linked; how it's matched to its procedure; how
values cross; how it fails on purpose, and what happens when it crashes (D131).

## Families

A family declares a word and its kinds together, in a block saying what kind of thing it holds, and holding only that
(D41):

```
fam.kind word:
    members
end fam.kind word
```

where `kind` is what the family holds (`proc` for a procedure and its narrowings, `handler` for a failure's handlers),
`word` the word, and `members` its declarations.

```
fam.proc show_msg:
    proc show_msg[$text: Text]:
        ...
    end proc show_msg

    proc show_msg.same_line[$text: Text]:
        ...
    end proc show_msg.same_line
end fam.proc show_msg
```

where each `...` stands for that procedure's body.

- **Every member is the word itself, or reads as "a Y kind of X" for its name `X.Y`.** Anything else is refused:
  `geometry.area` isn't a kind of geometry (D41).
- **A narrowed procedure is declared inside its word's family** (D41).
- **Each member keeps its full name** (D41).

`fam` is short for family (D2).

Handler families: chapter 8.

## Calls

A call writes the procedure's name and `( )`, with its arguments inside, even when there are none (D3, D4):

```
let $total: Whole = add(1, 2);
show_score();
```

A call that gives back a value has its value used: kept in a variable, passed on, or compared. One standing alone, its
value thrown away, is refused; a call that gives nothing stands alone (D120). A line that only works out a value, like
`$score + 1;`, is refused too (D161).

### Labels

A procedure can give its arguments labels, and every call writes them, with `:` after each (D24):

```
let $secret: Whole = random(from: 1, to: 100);
```

- **The procedure's writer chooses each label.** A call can't leave one off, or write one the procedure doesn't have
  (D24).
- **By convention, the first argument has no label,** as in `show_msg("Hi")` (D24).

A procedure declares its labels on a `labels` line, the first line of its body, with no brackets (D25):

```
labels parameter as label, parameter as label;
```

where each `parameter` is one of the procedure's parameters and `label` the word callers write for it. `labels`, `as`,
the commas and the `;` are written as they are.

```
proc random[$low: Whole, $high: Whole] -> Whole:
    labels $low as from, $high as to;
    ...
end proc random
```

where `...` stands for the rest of the body. Inside, the procedure uses `$low` and `$high`, and callers write `from:`
and `to:` (D25).

**Not decided:** defaults; label order.

## `proc.main`

`proc.main` is the procedure the program starts with. It takes nothing, so it has no brackets, and it's never called,
since only the program's start runs it (D4):

```
proc.main:
    show_msg("Hello, World!");
end proc.main
```

## Slides

A slide passes the value on the left of `|>` into the next step as its first argument, so a chain reads left to right
in the order it runs (D5):

```
$points |> double |> be.Text |> show_msg;
$score |> clamp(min: 0, max: 100) |> be.Text |> show_msg;
```

When to slide is decided by length, so each chain has one spelling (D128): one or two calls are written as calls, and
three or more in a chain, each the first argument of the next, are written as a slide.

```
show_msg("Hi");
show_msg(be.Text($n));
$points |> double |> be.Text |> show_msg;
```

So `$n |> be.Text |> show_msg` is refused, with `show_msg(be.Text($n))` as the fix, and
`show_msg(be.Text(double($points)))` is refused, with the slide as the fix. When the innermost call takes one value,
that value starts the fix's slide, as in `$points |> double`; when it takes more, the innermost call starts it whole, as
in `larger(3, 9) |> be.Text |> show_msg`, since `3 |> larger(9)` would make its two values lopsided (D128).

- **A step with nothing else to pass is bare,** with no `( )`: `|> be.Text`.
- **A step with more arguments takes `( )` for those only:** `|> clamp(min: 0, max: 100)`, and the slid value goes in
  first.

A step isn't a whole call, so it doesn't write `()` as a call does: the step names the procedure, and the slide calls
it (D4, D5).

`|>` comes last in the order of operators, so a slide takes everything on its left, as in `$a + 1 |> double |> be.Text
|> show_msg` (D73).

**Not decided:** `clamp`, which the example uses.

## Showing text

`show_msg` shows text and ends the line. `show_msg.same_line` shows text and leaves the line open, for prompts (D6):

```
show_msg("Hello, World!");
show_msg.same_line("Your guess: ");
```

## Asking

`ask` shows a question, leaves the cursor on its line, waits until the player presses Enter, and gives back what they
typed, without the Enter (D20). A Windows line ending, `\r\n`, counts as the Enter, so the `\r` isn't part of the
answer (D144):

```
ask(question)
```

where `question` is the text shown.

```
let $typed: Text = ask("Your guess: ");
```

What's typed always comes back as text, even digits: typing `42` gives `"42"`, not the number 42 (D20).

When there's no more input (the end-of-input key, or a file of answers running out), `ask` ends the program right
there, quietly, with exit status 0. A last line with no Enter after it still counts as an answer (D96).

**Not decided:** asking with no question; reading single key presses; what Ctrl+C does.
