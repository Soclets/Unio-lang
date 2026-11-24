# What check/'s generator doesn't make yet

All passing doesn't mean all covered (Building rule 12). The generator (generator.ml) makes valid programs with:
procedures with parameters and `->`, `let` and `var`, `=`, `Whole` maths with `+ - *`, `/`, `div` and `rem`, negation,
comparisons, `and`, `or`, `not`, text with names in braces, `be.Text`, `be.Whole(...) ?? n`, `ask` in `proc.main`,
`show_msg` and `.same_line`, `if` and `else`, counted `while` loops, and `break` as the last line of an `if`.

Not yet, roughly in the order they'd be added:
- `else if`; `return` anywhere but a procedure's last line; a bare `return;`.
- Procedures calling themselves, or each other in a circle; calls nested two deep in a first argument.
- Labels and `labels [ … ]` lines; slides with `|>`.
- `random` (whose output differs between runs; only `from:` equal to `to:` could be compared).
- A `Bool` in braces (D202), and text with `\{`, `\"` or `\\`: Beta++ is from before D200 and D202.
- Lists, arrays, `[all: …]`, `.len`, `.add`, `.remove`, items, `range`, `for each`.
- `Float`, its literals, maths, `sqrt`, `be.Float`, `be.Whole.floor` and the rest, `places:`.
- Failures of the program's own: `! [ … ]`, `?`, `?? ignore`, `?? crash`, `otherwise`, `instead`, handler families.
- Procedure families, comments, doc comments, comment blocks, and programs of several files.
- Programs that should be refused: every generated program is meant to be accepted, so refusals and their messages
  are compared only through the tests.

While Beta++ is from before D190 to D203, it's given each program in the spelling from before them (printer.ml), and
messages are compared by their kind and line only.
