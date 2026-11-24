# 11. Messages

```
refused: game.unio:5:5, line 5 column 5
 5 |     lives = lives - 1;
   |     ^^^^^
 what:    `lives` can't be given a new value
 because: line 2 declares it with `let`
 2 |     let lives: Whole = 3;
   |     ^^^
 why:     only a `var` can be given a new value.
```

- **The first word is the kind:** `refused:` at compile time, `check failed:` at runtime (D54), and `failed:` when
  `?? crash` stops the program on a failure (D152).
- **The place is written twice:** `file:line:column` for tools, then `line N column M` for people (D54).
- **The source line is shown,** with `^` under exactly the part in question (D54).
- **Then labelled lines, each only when known, in this order** (D54):
  1. `fix:` when there's exactly one fix and it can be shown as a corrected line, showing the whole line (D84, D101);
     otherwise `what:`, saying what's wrong;
  2. `when:`, the values that broke a check at runtime;
  3. `because:`, the earlier place the error comes from, as a sentence, then that line with `^` under the cause;
  4. `why:`, the rule, as a plain sentence.
- **No error codes, and no "did you mean" guesses** (D54).
- **A message never starts mid-line:** every message goes to standard error, and when a program stops while its
  output's last line is still open, as after `show_msg.same_line`, the runtime first ends that line on standard
  output (D104). After `ask`, the line counts as ended when the answer was typed at a terminal, and as still open
  when it came from a file or another program (D106).
- **Every error is shown** (D54).

## One mistake, one message

1. **After an error, only that statement is skipped,** and checking carries on (D55).
2. **A refused declaration still creates its variable** with its written type (D54, D55).
3. **A refused expression's type becomes unknown,** and nothing is refused for using an unknown value (D55).
4. **Knock-on errors are sorted out:** the first error's single fix is applied in memory and the program checked
   again. Anything that disappears is still shown as a message of its own, with a `because:` line pointing back to
   the first error (D55, D83).
5. **A broken block opener:** checking carries on into the body if it's clear what was meant, and stops there if it
   isn't (D55).

## Wording

Each message's wording is decided in batches, recorded in the decisions: D85 for lines, blocks and variables, D87 for
declarations, comparing, converting, unhandled failures, joining text and keywords used as names, D88 for procedures,
calls and `return`, D89 for types, labels lines, narrowing order, parameter forms and `&` beside maths, D92 for filling in text,
a program's shape, names, unreadable code, overflow and the tools' own messages, D102 for parameters, narrowings,
`else`, D81's refusals, names in use, knock-on errors, names, blank lines and spacing, D103 for the command's own
messages, words with no more narrowings, and `NotBuiltYet` and `NotDesignedYet`, D132 for five brought up to date, D142
for negation's overflow, bad names and D128's slides, D161 for lines outside procedures, unknown types, `not`, `and` and
`or`, value-only lines, other files, `unio oracle` and usage, D204 for the refusals D187 to D201 brought and four
brought up to date, D205 for failures, dividing, lists, `for each` and `range`, D206
for floats, and D119 for `extern.rust`'s refusals and its macro's
messages, since replaced by D131. Where a `what:` sets what's expected against what was found, it says "but" (D89).

The text after every label starts at the same column, one space after the longest label, `because:`, in every message
(D86).

**Not decided:** the wording of every other message; how columns are counted in text
beyond plain English letters.

## Exit statuses

| Status | When |
|---|---|
| 0 | the program ran to its end, or `ask` found no more input (D96) |
| 1 | it was refused at compile time, even if `NotBuiltYet` or `NotDesignedYet` messages came too (D148) |
| 2 | the file couldn't be read |
| 3 | `NotBuiltYet` or `NotDesignedYet` with no refusals: the program is fine as far as the tool can tell, but `Beta++` or Ralph can't handle part of it yet |
| 4 | a check failed at runtime, the program ran out of memory, or its calls went too deep (D115, D154) |
| 5 | a failure left `proc.main`, or `?? crash` stopped the program on purpose |
| 6 | the command itself was written wrong, like a missing mode or an unknown command, with every mistake shown, one line each (D82, D116) |
| 7 | code below the program's Unio went wrong: `Beta++`, its runtime or Ralph itself, with a message naming it and saying how to report it, or an `extern.cpp` procedure's C++ code (D82, D103, D131) |

`NotBuiltYet` is for something decided but not built, and `NotDesignedYet` for something no decision covers. They use
the same layout, with their name as the kind (D56). A `NotBuiltYet`'s `what:` names the decisions that decided what
isn't built, as in "dividing and remainders, `/`, `div` and `rem` (D70, D71), aren't built yet"; a `NotDesignedYet`'s
says "X isn't decided yet". Neither has a `why:` (D103).

**Not decided:** what a failure leaving `proc.main` shows.
