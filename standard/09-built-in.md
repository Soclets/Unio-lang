# 9. Built in

Procedures that are part of every Unio program, with nothing to import or list. They come with Unio's compiler and
runtime rather than being written in Unio: most are doors to the operating system, like showing text, or to the
machine, like `sqrt`'s one instruction (D131). Libraries are packages, written in Unio on top of these, or in C++
through `extern.cpp` (D64). The built-in procedures target the terminal: showing text, asking, single key presses,
colours, drawing at a position and clearing the screen, on Windows, macOS and Linux. A GUI, if ever, is a separate
package (D63). What the terminal part is built on isn't decided since D131 moved the runtime to C++.

The built-ins are (D196):
- **Procedures:** `show_msg`, with its narrowings `.fmt` (short for format) and `.same_line` (D6, D29); `ask` (D20);
  `be`, which converts, as in `be.Whole(typed)` (D22); `random` and `sqrt`, below.
- **Facts:** `.len`, short for length, a list's number of items (D79).
- **Others:** `range`, below.

They aren't keywords. A variable can't take a built-in procedure's name, as with any procedure's (D94), and they're
coloured as what they are, so `be.Whole` is a procedure's yellow (D194). The docs teach a short name's full word, as
for keywords (D2).

## `range`

A range describes a run of whole numbers, written in `[ ]` since nothing runs (D165, D170):

```
range[from: 1, to: 3]
range[from: 0, before: 10]
```

- **`from:`** is the first number.
- **Exactly one of `to:` or `before:`** says where it ends: `to: 3` includes 3, giving 1, 2, 3, and `before: 10` stops
  short of 10, giving 0 to 9, as for going through every `offset:` (D170).
- **`step_by:`** is optional, counting by 1 when it's left out. A negative step counts down, and the range goes as far
  as it can without passing its end: `range[from: 0, to: 9, step_by: 2]` is 0, 2, 4, 6, 8 (D172).

```
range[from: 0, to: 10, step_by: 2]
range[from: 10, to: 1, step_by: -1]
```

A step of 0, or one pointing away from the end, as in `range[from: 10, to: 1]`, is refused at compile time when it's
plain numbers, and stops the program with `check failed:` and status 4 otherwise (D172).

A range is gone through with `for each` (D171).

## `sqrt`

```
sqrt(x)
```

where `x` is a `Float`. It gives the square root, the nearest `Float` to the true answer, the same on every machine,
since IEEE 754 requires it as it does for `+` (D163, D185):

```
let distance: Float = sqrt(dx * dx + dy * dy);
```

- **A negative number stops the program** with a failed check and status 4, since its square root isn't a real number
  (D177, D185).
- **It takes a `Float` only:** `sqrt(9)` is refused, with `sqrt(9.0)` as the fix (D180, D185).

`sqrt` is short for square root (D2).

## `random`

```
random(from: low, to: high)
```

where `low` and `high` are whole numbers. It gives a whole number from `low` to `high`, both included, each equally
likely (D26).

```
let secret: Whole = random(from: 1, to: 100);
```

It's game randomness, fine for dice and loot, not for anything that must be unguessable (D26).

`from:` may equal `to:`, giving that number. `from:` above `to:` is refused at compile time when both are plain numbers,
with the two swapped as the fix, and otherwise stops at runtime with `check failed:` and status 4, showing both values
(D160).

**Not decided:** seeding; randomness for secrets; random numbers of other types.
