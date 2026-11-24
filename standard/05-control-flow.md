# 5. Control flow

## `if`

```
if condition:
    body
else if condition:
    body
else:
    body
end if
```

where each `condition` is what's checked and each `body` the statements run when it holds. There can be any number of
`else if` parts and at most one `else:`, and both are optional. One `end if` closes the whole chain (D8, D16).

```
if guess < secret:
    show_msg("Too low");
else if guess > secret:
    show_msg("Too high");
else:
    show_msg("Correct!");
end if
```

## Comparisons

```
lives eq 0
guess not_eq secret
guess < secret
score > best
hp at_least 1
hp at_most 100
```

- **`eq` and `not_eq`:** equal and not equal (D17, D190).
- **`<` and `>`:** less and greater, with a space on each side, so they're never mistaken for a type's `< >`, which has
  none (D3, D17).
- **`at_least` and `at_most`:** instead of `>=` and `<=` (D17).
- **A lone `=` in a condition is refused** (D14).
- **On two `Float`s, every comparison is exact,** comparing the stored values: `~0.1 + ~0.2 eq ~0.3` is `false`,
  since the two are neighbouring `Float`s (D184).

**A condition must be a `Bool`** (D187). A number or text doesn't stand for true or false: `if lives:` is refused,
with `if lives not_eq 0:` as the fix.

**Not decided:** comparing two pieces of text.

## `and`, `or` and `not`

Conditions combine with `and`, `or` and `not`: `not` first, then `and`, then `or`, with comparisons before all three
(D34):

```
if not won:
    show_msg.fmt("Out of tries! It was {secret}.");
end if

if hp at_least 1 and lives > 0 or cheat eq true:
```

The second means `(hp at_least 1 and lives > 0) or cheat eq true`.

`and` and `or` stop early: the right side runs only if it can still change the answer (D34).

**Not decided:** a form that always works out both sides.

## `while`

```
while condition:
    body
end while
```

where `condition` is checked before each pass, and `body` is run again as long as it holds (D19).

```
var tries: Whole = 0;
while tries < 5:
    show_msg("Guess!");
    tries = tries + 1;
end while
```

**`eq` and `not_eq` between two `Float`s are refused in a `while` condition** (D184, D190). A `Float` that changes each pass
rarely lands exactly on a value, so the loop could skip past it and never stop; `<`, `>`, `at_least` or `at_most` say
"until it reaches", and the refusal's fix gives one:

```
var timer: Float = 0.0;
while timer < 1.0:          // `while timer not_eq 1.0:` is refused
    timer = timer + ~0.1;
end while
```

## `for each`

`for each` runs its body once for each item, in order (D171):

```
for each name in students:
    show_msg(name);
end for

for each round in range[from: 1, to: 3]:
    show_msg.fmt("Round {round}!");
end for
```

- **It goes through a `List`, an `Array` or a `range[…]`** (D167, D170, D171).
- **`name` is a new variable for each pass,** declared by the `for each` itself as a `let`, and it ends with the loop
  (D93, D171).
- **It closes with `end for`,** and `break` leaves it, as it leaves a `while` (D8, D32, D171).
- **The list it's going through can't change inside it.** Anything in the body that changes that variable, such as
  `players.add(…)`, setting an item or setting the whole variable, is refused at compile time (D173). To change a list
  while looping, use `while` over its positions.

```
for each name in players:
    players.add("Bob");   // refused: players is being gone through
end for
```

The position comes with the item when the line says `at pos` (counting from 1) or `at offset` (counting from 0),
between the item and `in`, the same two words as for reaching an item (D75, D174):

```
for each name at pos i in students:
    show_msg.fmt("{i}. {name}");
end for
```

- **`i` is made by the line too,** a `let` like `name`, new for each pass and ended with the loop (D174).
- **It fits the matching label:** with `at offset i`, `students[offset: i]` is the same item as `name`; with
  `at pos i`, `students[pos: i]` is (D174).

**Not decided:** going through text; the wording of D173's refusal.

## `break`

`break;` leaves the innermost loop it's in. There's no `continue`: ending one pass early is an `if` around the rest
(D32). Nothing may follow `break;` in the same block, as nothing may follow `return` (D57, D117).

```
while tries < 7:
    let guess: Whole = be.Whole(ask("Your guess: ")) ?? 0;
    tries = tries + 1;
    if guess < secret:
        show_msg("Too low");
    else if guess > secret:
        show_msg("Too high");
    else:
        show_msg.fmt("Correct! You got it in {tries} tries.");
        break;
    end if
end while
```

## Running several things at once

A Unio program can run several parts of itself at once (D66), in two ways (D67):

1. **Tasks on one thread, the everyday way:** tasks take turns, each handing over only at points it chooses, like
   waiting for a key or a timer, so nothing changes behind a task's back and the turns go the same way every run.
2. **Real threads on several cores, opt-in,** for speed.

Real threads are **workers** (D68):
- **Each worker has its own variables;** nothing changeable is shared between two workers.
- **Workers talk by sending values,** which arrive as copies.
- **Nothing is ever shared between workers,** since every variable owns its own value, so data races are impossible
  (D130).
- **Values that can never change, like a `let`, may be read by every worker** without copying.

Messages from several workers can still arrive in different orders between runs, and two workers each waiting on the
other freeze (D68).

**Not decided:** the words for starting a task, handing over, starting a worker, sending and receiving.

## After an `if` that leaves

When any way through an `if` leaves, by `return`, `break` or a failure, nothing may follow its `end if` in the same
block, and code that should run afterwards goes in the ways that don't leave (D9). That covers:

- **every way leaving, with no `else`,** the guard clause;
- **only some ways leaving,** where code after `end if` would run only after the others;
- **every way leaving, `else` included,** where code after `end if` could never run.

Each is refused at compile time (D9).

```
proc larger[a: Whole, b: Whole] -> Whole:
    if a > b:
        return a;
    else:
        return b;
    end if
end proc larger
```

**Not decided:** failing on purpose, other loops, leaving an outer loop, and every other part of control flow. `return`:
chapter 4.
