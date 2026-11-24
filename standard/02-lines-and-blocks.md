# 2. Lines and blocks

```
proc.main:
    show_msg("Hello, World!");
end proc.main
```

## Statements

Every statement ends with `;` (D7), and each statement goes on a line of its own: two on one line are refused (D146).
A statement can run over several lines, and ends only at its `;`:

```
score
|> clamp(min: 0, max: 100)
|> be.Text
|> show_msg;
```

A missing `;` is refused, with the place it goes as the fix (D7).

## Blocks

A block's opening line ends with `:`, and its closer is `end` followed by what it closes, standing alone with no `;`
(D8):

```
opening line:
    body
end what
```

where `opening line` is the block's first line, like `proc.main` or `if a > b`; `body` is its statements; and `what`
is what the block is, like `proc.main`, `proc larger` or `if`. The `:`, the word `end` and the line breaks are written
as they are.

**Not decided:** what a closer says for every kind of block besides procedures and `if`.

## Indentation

A body is indented one level inside its opening line and closer, and a block inside a body one level further. One level
is 4 spaces. Any other indentation, a tab included, is refused at compile time, with the whole corrected line as the fix
(D10).

Since every block ends with its closer, indentation never decides where a block ends (D8, D10).

## Spacing

Spacing is fixed, and anything else is refused with the corrected line as the fix (D17, D18, D27, D59, D98):

| Where | Rule | Right |
|---|---|---|
| around `=`, `<`, `>`, `+`, `-`, `*`, `/`, `&`, `\|>`, `??`, `->`, `!` and word operators like `eq` | one space each side | `a eq b` |
| a narrowing's `.` | none | `show_msg.same_line` |
| a negating `-` | none after it | `-speed` |
| after `,` and `:` | one space | `add(1, 2)` |
| inside `( )` and `[ ]`, and before a call's `(` or the `[` after a name or a type | none | `roll()`, `[1, 2]`, `add[a: Whole]`, `List<Text>[max: 10]` |
| anywhere but indentation | never two spaces in a row | |
| at the end of a line, and on a blank line | no spaces | |

Spacing inside text is the program's own. Every spacing mistake on one line gives one message, whose `fix:` corrects
them all (D100).

## Comments

- **`//` comments to the end of the line** (D74).
- **A comment on a line of its own is indented like the line after it,** or, right before a closer or `else:`, one
  level in, like the lines in the block it ends. Any other indentation is refused, with the corrected line as the fix
  (D10, D145).
- **`///` is a doc comment** on the lines right before a declaration; one with no declaration after it is refused
  (D74).
- **`comment name:` to `end comment name` is a block comment.** Everything between is ignored, and it ends only at its
  own `end comment` with its name, so comment blocks can sit inside each other (D74).

```
/// Gives the larger of two whole numbers.
proc larger[a: Whole, b: Whole] -> Whole:
    // the tie goes to b
    ...
end proc larger

comment old_scoring:
    let bonus: Whole = tries * 10;
end comment old_scoring
```

where `...` stands for the procedure's body.

A blank line may separate parts of a procedure, or procedures, anywhere; two or more in a row are refused (D97).

**Not decided:** how a statement's later lines are indented.

## Files

A Unio file's name ends in `.unio`, as in `game.unio` (D35, D135, D136). A Windows line ending, `\r\n`, counts as one
line break, the same as `\n` (D144).

A program is every `.unio` file in its folder, with exactly one `proc.main` across them. There are no imports: a
procedure in one file calls one in another directly, in any order (D64).

The files are read in the byte order of their names, whichever file is named on the command line, so `Map.unio` comes
before `map.unio` and `enemies.unio` before `game.unio`. Running a program never depends on the order, but its messages
do: which of two definitions of one name came first, and which mistake is reported first (D188).

## Packages

Packages are listed once, in a manifest file in the program's folder, and their procedures are then usable in every
file (D64). Names are used bare. When two packages both have a name, the bare name is refused, and the package's name
goes in front with `::`, one level deep (D64):

```
crossterm::draw(...);
```

**Not decided:** the manifest's name and format; versions; where packages come from.
