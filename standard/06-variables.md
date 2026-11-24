# 6. Variables

## Declaring

A new variable is declared with `let` or `var`, its name, its type and its first value (D13):

```
let name: Type = value;
var name: Type = value;
```

where `name` is the variable's name (D192), `Type` its type, and `value` its first value. `let` or
`var`, the `:`, the `=` and the `;` are written as they are.

```
let secret: Whole = 42;
var tries: Whole = 0;
```

- **`let`:** the value never changes after this line, all the way down (D13, D78).
- **`var`:** the value can change. `var` is short for variable (D2, D13).
- **The type is always written,** never worked out from the value (D13).

## Blocks

A variable declared inside a block (an `if`'s way, an `else`, a loop's body, an `otherwise` case) ends where the block
ends. After it, the name can be declared again as a new variable, and a `var` from outside that was changed inside
keeps its new value (D93).

While a variable is in use, in its own block or any block inside it, its name can't be declared again (D94). A variable
can't take a procedure's name (D94, D192).

## Changing

A `var` gets a new value with its name, `=` and the value, as a statement of its own (D14):

```
name = value;
```

where `name` is a `var`'s name and `value` its new value.

```
var tries: Whole = 0;
tries = tries + 1;
```

- **`=` on a `let` is refused,** since a `let` never changes (D13, D14).
- **`=` on a parameter is refused too:** a plain parameter is read-only, like a `let`. To change a copy, declare a
  `var` from it, as in `var left: Whole = n;` (D147).
- **`=` never appears inside a condition,** so `if tries = 3` is refused (D14).

## Values

Every variable owns its own value (D130). Giving a list or a record to a new name makes the new name's own value:

```
var b: List<Whole> = a;
```

Changing `b` never changes `a`. There are no words for copying or sharing: the compiler copies only where it's
needed, and skips a copy wherever no one would notice (D130). Something that's really one thing, like the player every
monster targets, is referred to by an ID, like a list position, and looked up (D130).

`let` is deep: nothing reachable through a `let` can ever change, not its items nor the items inside them (D78).

**Not decided:** the words a parameter uses to say whether it reads, changes or takes over its argument (D130);
shorthand like `+=`; constants known at compile time, like `const`; the types themselves; declaring a variable without a
first value.
