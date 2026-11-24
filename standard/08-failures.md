# 8. Failures

A **failure** is something a procedure can give back instead of its result, like text that isn't a number. A procedure
that can fail says so, and every call to it must deal with the failure, or the program is refused at compile time
(D23).

```
let guess: Whole = be.Whole(typed);
```

On its own, that line is refused, since `be.Whole` can fail and nothing handles it.

## Listing failures

A procedure that can fail lists its failures at the end of its header, after `!`, in `[ ]` separated by commas, and
after `-> Type` when it gives back a value (D38, D39, D190):

```
proc load_level[name: Text] -> Level ! [not_found, broken]:
proc save_game[state: Text] ! [disk_full]:
```

A failure's name is a plain word, like `not_found` (D39).

## `?`

`?` passes the failure up to whoever called this procedure, which must list that failure itself (D23):

```
let level: Text = load_text("level1.txt")?;
```

## `??`

`??` handles the failure on one line (D23):

```
call ?? value
call ?? ignore
call ?? crash
```

where `call` is the call that can fail, and `value` the value to carry on with instead.

```
let guess: Whole = be.Whole(typed) ?? 0;
save_text(line, "save.txt") ?? ignore;
load_level(name) ?? crash;
```

- **`?? value`** carries on with that value.
- **`?? ignore`** ignores the failure on purpose, after a call that gives nothing; after one that gives a value it's
  refused, since there'd be nothing to carry on with (D121).
- **`?? crash`** stops the program on purpose, with a `failed:` message naming the procedure and its failure, and
  status 5 (D152).

## `otherwise:`

`otherwise:` handles each failure in its own `case` (D23, D40):

```
call otherwise:
    case failure:
        body
end otherwise
```

where `call` is the call that can fail, each `failure` one of its failures' names, and each `body` the statements run
for it.

```
let best: Whole = load_best_score() otherwise:
    case not_found:
        show_msg("No high score yet.");
        instead 0;
    case unreadable:
        instead 0;
end otherwise
```

- **The cases must cover every failure still possible at that call** (D40).
- **Each case ends in one of four ways:** `instead` a value, carrying on with it; `return`; `break`; or failing on
  purpose. A case that could fall off its end is refused (D40).
- **When the call gives back no value,** as `.add` does, a case may also just end, and the program carries on after
  `end otherwise` (D186):

```
bag.add("Gem") otherwise:
    case full:
        show_msg("Your bag is full!");
end otherwise
show_msg("Onward!");
```
- **`case` is indented one level in, and its body one level further** (D10, D40).

## Handler families

A handler is a named set of `case`s, declared with `handler` inside a `fam.handler`, whose word names what fails
(D41, D42):

```
fam.handler word_failed:
    handler word_failed.use_placeholder:
        case too_long:
            instead "...";
        case no_words:
            instead "(none)";
    end handler word_failed.use_placeholder
end fam.handler word_failed
```

It's used with `otherwise` and its full name, as if its cases were written at the call, so they must cover every
failure still possible there (D40, D42):

```
let title: Text = first_word(heading) otherwise word_failed.use_placeholder;
```

A handler that can `return` or `break` is marked `*` where it's used, as in `otherwise word_failed.*give_up;`. The mark
is required on a handler that can jump, and refused on one that can't (D42).

Inside an `otherwise:` block, `include family.handler;` brings in a handler's cases as if written there, and the
block's own `case`s cover the failures it doesn't. Together they must cover every failure, none twice (D43):

```
let title: Text = load_word(file) otherwise:
    include word_failed.use_placeholder;
    case disk_full:
        instead "?";
end otherwise
```

A handler can take parameters, written as a procedure's are, and is given arguments where it's used (D44):

```
let title: Text = first_word(heading) otherwise word_failed.use_default(with: "Untitled");
```

**Not decided:** how a procedure fails on purpose; `return`; whether failing on purpose inside a case counts as a jump.
