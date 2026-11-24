# 7. Types

## `Whole`

A whole number from -9223372036854775808 to 9223372036854775807, negatives included: a 64-bit signed integer, C++'s
`std::int64_t` (D15, D131).

```
let secret: Whole = 42;
```

`Whole` has no second name. Other sizes, if they come, are different types with names of their own (D15).

### Arithmetic

`+` adds and `-` subtracts, with a space on each side. A `-` with no space after it makes a number or a name negative
(D27):

```
tries = tries + 1;
let left: Whole = 5 - tries;
let back: Whole = -speed;
```

`+` is only for numbers (D27). `*` multiplies, with a space on each side (D59):

```
let total: Whole = price * count;
```

### Dividing

```
let half: Whole = 8 / 2;
let share: Whole = 7 div.floor 2;
let part: Whole = 7 div.trunc 2;
```

These give 4, 3 and 3. With -7 in place of 7, `div.floor` gives -4 and `div.trunc` gives -3.

- **`/` divides exactly.** A remainder is a failed check that stops the program in both modes (D46, D70).
- **`div.floor` rounds down to the nearest whole number below;** **`div.trunc` cuts the fraction off,** toward zero
  (D70).
- **A bare `div` is refused** (D70).

`div` is short for divide and `trunc` for truncate (D2).

### Remainders

`rem.floor` and `rem.trunc` give what's left after dividing, each matching its division (D71):

```
let left: Whole = 7 rem.floor 2;
let left: Whole = 7 rem.trunc 2;
```

Both give 1. With -7, `rem.floor` gives 1, with the sign of the number divided by, so `-1 rem.floor 8` is 7; and
`rem.trunc` gives -1, with the sign of the number divided. A bare `rem` is refused (D71). `rem` is short for remainder
(D2).

### Maths order

Without brackets, operators go in school maths' order (D72):
1. a `-` negating, as in `-7`;
2. `*`, `/`, `div` and `rem`, left to right;
3. `+` and `-`, left to right;
4. comparisons, then `not`, `and` and `or`;
5. `|>`, last, so a slide takes everything on its left (D73).

So `2 + 3 * 4` is 14. Where maths doesn't say, brackets are required: `&` next to an unbracketed `+`, `-`, `*`, `/`,
`div` or `rem` is refused (D72).

Dividing by zero is a failed check that stops the program (D46, D72).

`??` belongs to the call right before it and takes a single value after it, so `score + be.Whole(t) ?? 0` means
`score + (be.Whole(t) ?? 0)` (D81). Two comparisons in a row, as in `1 < x < 10`, are refused, with `1 < x and x <
10` as the fix; and an operator after a slide's last step, as in `x |> f |> g |> h + 1`, is refused, with `(x |> f |>
g |> h) + 1` as the fix (D81). A shorter one, like `x |> f + 1`, is written as a call, `f(x) + 1` (D128).

**Not decided:** going past the range; how whole numbers are written; other
number types.

## `Bool`

`true` or `false` (D33):

```
var won: Bool = false;
won = guess eq secret;
```

A comparison gives a `Bool`, and that's what `if` and `while` check (D33). `Bool` is short for Boolean (D2).

**Not decided:** whether a condition must be a `Bool`.

## `Text`

Text, written in double quotes (D21):

```
let name: Text = "Mia";
show_msg("Don't give up!");
```

Single quotes aren't used for text (D21).

`&` joins two pieces of text. A number joined with `&` is refused, with `be.Text(...)` as the fix, so it's always
visible where a number becomes text (D22, D28):

```
show_msg("You got it in " & be.Text(tries) & " tries.");
```

### Filling in text

`.fmt` fills in what's in braces. It narrows `show_msg` to show the result, and `be.Text` to give it back as `Text`
(D29):

```
show_msg.fmt("You got it in {tries} tries.");
let line: Text = be.Text.fmt("{name}: {score}");
```

- **Braces hold only a variable's name;** a calculation or a call in them is refused (D29).
- **A number in braces becomes text by itself** (D29).
- **The text is checked at compile time:** a name in braces that isn't a variable is refused (D29).
- **Without `.fmt`, text is plain,** so `show_msg("{tries}")` shows exactly `{tries}` (D29).

A `Float` in braces can take a `places:` setting after a comma, rounding it to that many digits after the point, the
decimal places, and showing it with no `~`, since the text is exactly the rounding asked for (D175):

```
let speed: Float = ~0.1 + ~0.2;
show_msg.fmt("Speed: {speed, places: 2}");   // Speed: 0.30
```

- **It always shows that many places,** so `{half, places: 3}` with `0.5` shows `0.500`, and `places: 0` shows no
  point (D175).
- **It rounds to the nearest,** and an exact tie goes away from zero, as at school: `0.125` with `places: 2` shows
  `0.13` (D175, D178).
- **A value that rounds to zero shows no minus:** `-0.001` with `places: 2` shows `0.00`, while `-0.006` shows `-0.01`
  (D176).
- **`places:` on anything but a `Float` is refused** at compile time (D175).

`fmt` is short for format (D2). With `.same_line` as well, it's `show_msg.fmt.same_line`, the stronger narrowing first
(D31).

### `\`

Inside text, `\` makes the next character literal, and does nothing else: `\{` is a brace in `.fmt` text, `\"` a quote,
and `\\` a backslash. Only `{` needs escaping in `.fmt` text, since a `}` with no open `{` is just a character. `\`
doesn't start C-style codes, so `\n` isn't a new line (D30).

```
show_msg.fmt("Type \{help} to see the commands, {name}.");
show_msg("She said \"hi\".");
```

Empty text is `""` (D76).

**Not decided:** a new line or a tab inside text; `\` before a letter; settings in braces; comparing text.

## `Float`

`Float` is a binary floating-point number, stored as IEEE 754 binary64: about 15 to 17 significant digits, from about
10⁻³⁰⁸ to 10³⁰⁸ (D157). Like `Whole`, it has no second name. It's approximate, and honest about it (D155):
- **An inexact literal needs `~`:** `~0.1` is accepted, and `0.1` is refused with `~0.1` as the fix, since 0.1 can't
  be stored exactly in binary. A literal stored exactly, like `0.5`, takes no `~`.
- **An inexact value shows its `~` when printed:** the shortest text that reads back as the same number, with `~` in
  front when the stored value isn't exactly that, as in `~0.30000000000000004`.
- **A `Float` with no fraction shows `.0`,** as `7.0`, so the text reads back as a `Float` (D180, D181).
- **It's always written out in full,** with no `e` notation: 10²² shows as `10000000000000000000000.0`, and 2⁷⁰,
  whose shortest digits are followed by zeros that aren't exactly what's stored, as `~1180591620717411300000.0` (D182).
- **IEEE 754's negative zero shows as `0.0`,** since in Unio it behaves as zero in every way (D177, D183).

```
let speed: Float = ~0.1;
```

A number written with a point is a `Float`, and one without is a `Whole`, wherever it's written: `let speed: Float =
7` is refused with `7.0` as the fix, and `let lives: Whole = 7.0` with `7` (D180). So `7 / 2` is always `Whole`
maths, and `7.0 / 2.0` is 3.5.


Unio doesn't promise a `Float` gives the same bits on every machine (D163). `+`, `-`, `*`, `/` and the square root
do anyway, since `final` never fuses or reorders float maths (D46, D124); maths functions, when Unio has them, may
differ in the last digit between machines.

A `Float` is always a real number: a result too big for it, which IEEE 754 would make infinite, stops the program
with a failed check, as NaN does (D46, D177). Dividing a `Float` by zero is already a failed check (D46), so neither
infinity nor NaN is ever held:

```
var size: Float = 2.0;
while true:
    size = size * size;   // stops once the result is too big for a Float
end while
```

On two `Float`s, `/` divides and rounds to the nearest `Float`, as `+`, `-` and `*` do, since most divisions don't
come out exact; D70's exact `/` and `div.floor` and `div.trunc` are for `Whole` (D179):

```
let share: Float = 10.0 / 3.0;   // ~3.3333333333333335
```

`Whole` and `Float` don't mix in one calculation: `lives * speed` is refused, and `be.Float(lives) * speed` says
so (D162).

`Decimal` is kept for an exact decimal type, if Unio adds one; it would never need `~` (D155, D157).

A `Float` is shown to a player rounded, with `places:` in `.fmt` braces (D175).

**Not decided:** `Float`'s maths and its other conversions; the wording of D177's check; maths functions such as
square roots.

## Lists

`List<Type>` is a list of one type, written in `[ ]` with commas (D3, D75):

```
var students: List<Text> = ["Fern", "Plern", "Churn"];
let first: Text = students[pos: 1];
let also_first: Text = students[offset: 0];
```

- **An item is reached with `pos:`, counting from 1, or `offset:`, counting from 0.** A bare number is refused (D75).
- **A bad position is a failed check** that stops the program, or is refused where the checker can see it (D46,
  D75).

`pos` is short for position (D2).

A list can be given a most it may hold, in `[ ]` after its type, as a setting (D165, D167):

```
var bag: List<Text>[len.max: 10] = [];
```

`len.max` is the max kind of length (D41), so it can't be mistaken for a limit on the items' values. On such a list,
`.add` can fail with the failure `full`, which the program deals with like any failure (D23, D168):

```
bag.add("Gem") otherwise:
    case full:
        show_msg("Your bag is full!");
end otherwise
```

A list with no limit never fails on `.add`.

## Arrays

`Array<Type>[len: n]` holds exactly `n` items, always: its length is part of its type, given by `len:` (D167). Like an
array of solar panels, nothing is added or taken away, so `.add` and `.remove` are refused on it, but its items can
still change, as `board[pos: 5] = 1`. Items are reached by `pos:` or `offset:`, and `.len` reads its length, as for a
list.

```
let week: Array<Text>[len: 7] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
```

Every item can start the same with `[all: value]`, which takes its length from the type, the way `[]` takes its type
from where it goes (D76, D169). It's only allowed where the length is known, as for an `Array`:

```
var board: Array<Whole>[len: 64] = [all: 0];
```

An empty list is `[]`, taking its type from where it goes (D76).

A value's methods are called with a plain `.` after it, and a method that changes its value can only be called on a
`var` (D77):

```
students.add("Churn");
students.add("Tankun", pos: 1);
students.remove(pos: 2);
students[pos: 1] = "Mia";
```

- **`.add(item)`** puts it at the end, and **`.add(item, pos: n)`** or `offset: n` at that place (D80).
- **`.remove(pos: n)`** or `offset: n` takes an item out (D80).
- **`list[pos: n] = value`** changes one item (D80).

After a value's `.`, a name with no `( )` is a fact the value already knows, read without running anything. A list's
number of items is `.len` (D79):

```
let count: Whole = students.len;
```

A list or an array is gone through with `for each` (chapter 5, D171).

**Not decided:** which other methods and facts lists and text have; how a type's methods are declared.

## Converting

A value is converted with `be` narrowed by the type it becomes (D22):

```
be.Type(value)
```

where `Type` is the type it becomes and `value` the value converted.

```
let guess: Whole = be.Whole(typed);
show_msg(be.Text(guess));
```

- **Converting to the type a value already is, is refused,** since it does nothing (D22).
- **A conversion can fail,** as `be.Whole("abc")` does (D22).
- **`be.Text` turns a `Bool` into `"true"` or `"false"`,** Unio's own spelling of them (D153).

`be.Whole` reads a whole number from text: spaces and tabs around it are ignored (D143), and a `+` or `-` in front and
leading zeros are fine, so ` 42`, `-7`, `+5` and `007` all work. Anything else fails, including `4.5`, `1,000` and a
number too big or too small for a `Whole` (D95), with the failure `not_a_whole` (D156).

`be.Whole` on a `Float` says how the fraction goes, and a bare `be.Whole(distance)` is refused, with a fix listing
the ways (D178):

```
let steps: Whole = be.Whole.floor(distance);     // 2.7 → 2,  -2.7 → -3
let shown: Whole = be.Whole.trunc(distance);     // 2.7 → 2,  -2.7 → -2
let tiles: Whole = be.Whole.ceil(distance);      // 2.3 → 3,  -2.3 → -2
let score: Whole = be.Whole.nearest(distance);   // 2.5 → 3,  -2.5 → -3
let total: Whole = be.Whole.nearest.even(sum);   // 2.5 → 2,   3.5 → 4
```

- **`.floor`** goes down, **`.ceil`** up, and **`.trunc`** cuts the fraction off, toward zero (D178).
- **`.nearest`** goes to the nearest whole number, and an exact tie goes away from zero, as at school; **`.nearest.even`**
  sends a tie to the even one, for sums where always going up would add up (D178).
- **A `Float` too big for a `Whole`** stops the program with a failed check, as overflow does (D46, D178).

**Not decided:** what may be converted to what, beyond D153 and D156, and what other conversions' failures are
called (chapter 8).
