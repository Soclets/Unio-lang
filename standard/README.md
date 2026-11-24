# The Unio standard

What Unio is now, by topic. [`DECISIONS.md`](../DECISIONS.md) records how each rule was decided, in the order it
happened; this standard says what the rules are today (D12).

## How it's written

- **`DECISIONS.md` is the source.** Every rule here names its decision, as in "(D7)". Where the two disagree, the
  decision wins and the standard is wrong.
- **It changes with the decisions.** A decision that changes a rule updates the standard in the same commit (D12).
- **Undecided means "Not decided".** Anything the decisions leave open is marked **Not decided** where it would go,
  never filled in here.
- **Terms come first.** Every word the standard relies on is defined in [Terms](01-terms.md) before a chapter uses it
  (D12).
- **Placeholders are explained.** A general form says right after it what each placeholder stands for. A real example,
  with no placeholders, needs no such line (D12).

## Chapters

1. [Terms](01-terms.md)
2. [Lines and blocks](02-lines-and-blocks.md): `;` and `end`, comments, indentation, files and packages
3. [Words](03-words.md): keywords, names and brackets
4. [Procedures](04-procedures.md): definitions, families, calls, `proc.main`, slides, `show_msg` and `ask`
5. [Control flow](05-control-flow.md): `if`, comparisons, `while`, and what may follow an `if`
6. [Variables](06-variables.md): `let`, `var`, changing, and values
7. [Types](07-types.md): `Whole`, `Bool`, `Text`, lists and converting
8. [Failures](08-failures.md): `?`, `??`, `otherwise` and handler families
9. [Built in](09-built-in.md): `range`, `sqrt`, `random`
10. [Tools](10-tools.md): the compiler, the command, memory and build modes
11. [Messages](11-messages.md): the layout, one mistake giving one message, and exit statuses
