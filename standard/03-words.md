# 3. Words

## Keywords

Each keyword has exactly one spelling, the short one: `proc`, never `procedure` (D2). The docs, and error messages,
teach the full word where a keyword first appears, as in "`proc` is short for procedure" and "`msg` is short for
message".

| Keyword | Short for | Decided in |
|---|---|---|
| `proc` | procedure | D2, D4 |
| `end` | | D8 |
| `.main` | | D4 |
| `.same_line` | | D6 |
| `let` | | D13 |
| `var` | variable | D2, D13 |
| `if`, `else` | | D16 |
| `at_least`, `at_most` | | D17 |
| `while` | | D19 |
| `break` | | D32 |
| `for`, `each`, `in` | | D171 |
| `true`, `false` | | D33 |
| `and`, `or`, `not` | | D34 |
| `be` | | D22 |
| `ignore`, `crash`, `otherwise`, `case` | | D23, D40 |
| `instead` | | D40 |
| `labels`, `as` | | D25 |
| `.fmt` | format | D2, D29 |
| `extern`, `.cpp` | external | D2, D36, D131 |
| `eq`, `not_eq` | equal, not equal | D190 |
| `return` | | D57 |
| `fam` | family | D2, D41 |
| `div`, `.floor`, `.trunc` | divide, truncate | D2, D70 |
| `rem` | remainder | D2, D71 |
| `.len` | length | D2, D79 |
| `handler` | | D42 |
| `include` | | D43 |
| `comment` | | D74 |

**Not decided:** every other keyword.

## Names

A variable's name starts with `$`, like `$secret` or `$tries`, written the same where it's made and where it's used. A
parameter is a variable too, so its name has the `$`. A procedure's name is a plain word, like `larger` or `roll_dice`,
with no `$` (D125).

Since `$` keeps them apart, a variable's name can be a keyword, as in `$if`, and a keyword added later never breaks a
program's names; a variable can also share a procedure's name, as in `let $roll: Whole = roll();` (D125, D127). A
procedure's name can't be a keyword (D58, for procedures).

A name, after a variable's `$`, is lowercase English letters `a` to `z`, digits, and `_` between words, starting with
a letter: `$player2`, `$hp_max_2`, `roll_dice`. No capitals, and `_` never at the start or end, nor two in a row (D99).

**Not decided:** letters beyond English.

## Brackets

Each kind of bracket has one meaning (D3, D165):

| Bracket | Means | Examples |
|---|---|---|
| `( )` | calls a procedure; and, as school maths writes it, groups in maths | `add(1, 2)`, `($a + $b) * 2` |
| `[ ]` | values, listed or described: a list, reaching an item, a type's settings, a procedure's parameters, building a record | `[1, 2, 3]`, `$bag[pos: 1]`, `List<Text>[max: 10]`, `proc add[$a: Whole, $b: Whole]` |
| `< >` | a type, filled in | `List<Whole>` |

`( )` marks where a procedure is called, code with a name and a body; built-in operations, like `+`, reaching an item
and reading `.len`, don't take it, though they're done at runtime too. Grouping in maths is the one exception, kept
because it's how school maths writes it (D165).

**Not decided:** types themselves, maths.

## Symbols

A symbol has one job in any one place: `-` between two values subtracts and right before one negates, and `*` between
two values multiplies and right after a dot marks a handler. A longer symbol, like `->` or `|>`, is a symbol of its
own (D60).

| Symbol | Meaning | Decided in |
|---|---|---|
| `;` | ends a statement | D7 |
| `//`, `///` | a comment to the end of the line; a doc comment before a declaration | D74 |
| `:` | ends an opening line | D8 |
| `=` | gives a variable its first value, or a `var` a new one | D13, D14 |
| `.` | after a word, names a kind (narrows); after a value, calls a method; touching both sides | D4, D6, D18, D41, D77 |
| `::` | names a package, when two packages share a name | D64 |
| `<`, `>` | compare, with a space on each side | D17 |
| `->` | comes before the type a procedure gives back | D37, D190 |
| `!` | comes before the failures a procedure can give, in `[ ]` | D39, D190 |
| `\|>` | passes a value along a slide | D5 |
| `+`, `-` | add and subtract, with a space on each side; a `-` with no space after it negates | D27 |
| `*` | multiplies, with a space on each side | D59 |
| `/` | divides exactly, with a space on each side | D70 |
| `&` | joins text | D28 |
| `?` | passes a failure up | D23 |
| `??` | handles a failure on one line | D23 |
| `.*` | marks a handler that can jump, where it's used; one symbol, stuck to the dot | D42, D59 |
