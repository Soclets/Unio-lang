# 1. Terms

The words this standard uses, each defined before a chapter relies on it.

## Programs and lines

- **Program:** everything that's built and run together, starting from `proc.main` (chapter 4).
- **Statement:** one instruction, ending with `;`, as in `show_msg("Hi");` (chapter 2).
- **Block:** a group of statements with an opening line and a closer, like a procedure or an `if`.
- **Opening line:** the line that starts a block, ending with nothing, as in `proc.main` (D199).
- **Closer:** the line that ends a block: `end` and what it closes, as in `end proc.main`.
- **Body:** the statements between a block's opening line and its closer.
- **Indentation:** the spaces at the start of a line.

## Words

- **Keyword:** a word that's part of Unio itself, like `proc`, `end` or `if`. A program can't choose its own
  keywords.
- **Name:** a word a program chooses, for a variable or a procedure.
- **Variable:** a named place holding a value, as in `score`; its name is a plain word (D192).
- **Declaration:** the statement that makes a new variable, starting with `let` or `var` (chapter 6).
- **Value:** a piece of data, like a number or a piece of text.
- **Type:** the kind of a value, like a whole number or text, as in `Whole` (chapter 7).
- **Narrowing:** a word after a `.` that makes another word more specific, as `.main` makes `proc` mean the procedure
  the program starts with, and `.same_line` makes `show_msg` leave its line open. The `.` has no spaces around it (D18).
  A narrowing names a kind: `X.Y` reads as "a Y kind of X" (D41). When a word has several, the one that changes the
  action most comes first, as in `show_msg.fmt.same_line`, and any other order is refused (D31).

## Procedures

- **Procedure:** a named block of statements that can be run from elsewhere. `proc` is short for procedure (D2).
- **Method:** a procedure called on a value with a `.` after it, as in `students.add("Mult")` (chapter 7).
- **Family:** a word and its kinds, declared together, as `show_msg` and `show_msg.same_line` (chapter 4).
- **Definition:** the block that writes a procedure, starting with `proc`.
- **Parameter:** a name in a definition's `[ ]`, standing for a value the procedure is given (D165).
- **Argument:** a value given to a procedure when it's called.
- **Label:** a name for an argument, chosen by the procedure and written at every call, as `from:` in
  `random(from: 1, to: 100)` (chapter 4).
- **Call:** running a procedure, written as its name and `( )`, as in `roll_dice()`.
- **Slide:** a chain of steps joined by `|>`, passing a value along (chapter 4).
- **Step:** one procedure in a slide.

## Checking and running

- **Garbage collector:** the part of a running program that frees memory nothing uses any more (chapter 10).

- **Compile time:** when `Beta++` checks a program and turns it into something that can run, before it runs
  (D90).
- **Runtime:** when the compiled program runs (D90).
- **Failure:** something a procedure can give back instead of its result, which every call must deal with (chapter
  8).
- **Refused:** rejected at compile time, with a message saying why. A refused program doesn't run.
- **Placeholder:** a part of a general form that stands for something you fill in. Each one is explained where it's
  used (D12).
