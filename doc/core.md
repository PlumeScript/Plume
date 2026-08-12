# Plume — Core

This document covers the **core** of Plume: the minimum set of concepts and syntax needed to write useful programs.

*   For more advanced constructs (destructuring, variadic macros, modules, closures, error handling...), see [advanced.md](advanced.md).
*   For features intended for library authors (metatables, contextual variables, directives...), see [expert.md](expert.md).
*   Standard library functions (`String`, `Table`, `Math`...) are documented separately in [reference_std.md](reference_std.md).

## Development Warnings: `use #devWarnings`

Plume can warn you about common mistakes while you develop. Enable the warnings at the top of a program with:

```plume
use #devWarnings
```

The output is verbose and may include false positives, so it is not always pleasant to develop with. But it catches and explains many frequent errors — for example `x = 5` instead of `set x = 5`, `function wing` instead of `macro wing`, or `let x = "a"` instead of `let x = a`. Turn it on systematically for your first programs, and switch it back on whenever you encounter surprising results. (The `-w` CLI flag is equivalent; see [advanced.md](advanced.md) for the full warning system.)

## Text-First: Text and Statements

Plume is a text-first language: any sequence of characters that is not part of a language construct is literal text. Writing content requires no quoting or special delimiters.

A line is treated as a **statement** — code, not text — when it begins (after any leading whitespace) with one of the following:

*   `if`, `elseif`, `else`, `for`, `while`, `macro`, `end`, `do`, `raw`
*   `let`, `set`, `use`, `run`, `leave`, `break`, `continue`, `raise`
*   `-` (list item), `key:` (named item), `$key:` (dynamic named item), `...` (table expansion)
*   `@name` (block call)
*   `with`, `ref`, `meta` (used by advanced and expert features)

Anywhere else, these very words are rendered as plain text.

Running a program means evaluating its top-level block. The result of the program is the value this block accumulates — most often, text (see *Accumulation Blocks*).

```plume
This is a valid Plume program.
if 1 + 1 == 2
    Your wing is fine.
else
    Your wing needs more ink!
end
// → This is a valid Plume program.Your wing is fine.
```

Note the absence of any line break between the text line and the `if` result: lines concatenate without separator, as explained in the next section.

## Whitespace and Escaping

The parser ignores the following whitespace:

*   Leading spaces and tabs at the beginning of a line (indentation is free).
*   Spaces and the newline character at the end of a line.

As a consequence, **consecutive text lines concatenate with no separator**. To insert whitespace into the output, use escape sequences:

| Sequence | Result           |
|----------|------------------|
| `\n`     | Newline          |
| `\t`     | Tab              |
| `\s`     | Space            |
| `\r`     | Carriage return  |
| `\$`     | Literal `$`      |
| `\(`     | Literal `(`      |
| `\)`     | Literal `)`      |
| `\:`     | Literal `:`      |
| `\,`     | Literal `,`      |
| `\\`     | Literal `\`      |
| `\/`     | Literal `/`      |
| `\0`     | Empty text (prevents keyword recognition) |

Escapes are restricted to this fixed set: any other `\X` is an error — escaping an ordinary letter (`\a`) is no longer allowed. `\0` produces empty text and prevents keyword recognition: write `\0set` instead of `\set`.

```plume
wing
nib
// → wingnib
```

```plume
wing\nnib
// →
wing
nib
```

```plume
wing\s\sink
// → wing  ink
```

```plume
The \$wing variable, price\: 5
// → The $wing variable, price: 5
```

## Comments

Plume supports two kinds of comments:

*   **Line comments:** `//` extends to the end of the line. It can stand on its own line or follow code.
*   **Block comments:** `/* ... */` may span several lines.

Comments are not always discarded: a comment written without a blank line immediately before a macro definition is captured and stored as that macro's documentation. This *docstring* mechanism is covered in [expert.md](expert.md) — until then, write comments freely.

```plume
// A full-line comment.
let wing = 5 // An inline comment.

/*
   Nothing here is parsed:
   $wing, if, - item...
*/
let nib = 2
```

## Interpolation and Evaluation

By default, Plume text is inert. Two constructs switch to an **evaluation context**:

*   **`$name`** evaluates the variable `name` and inserts its value as text.
*   **`$(expression)`** evaluates any expression and inserts its result.

Inside `$(...)`, the full expression syntax is available:

*   Arithmetic: `+`, `-`, `*`, `/`, `%`, `^`
*   Comparison: `==`, `!=`, `<`, `>`, `<=`, `>=`
*   Logic: `and`, `or`, `not` — with short-circuit evaluation. `and` and `or` return the value of the deciding operand, not necessarily a boolean: `$(true and 1)` is `1`.
*   Parentheses, variable names, and macro calls — written **without** the `$` prefix inside an evaluation context.

As a shortcut, `$` directly followed by a number literal evaluates that literal: `$100` is equivalent to `$(100)`.

```plume
let wing = 5
let nib = 2
wing + nib = $(wing + nib)\n
$(wing * nib) and $wing\n
macro double (x)
    $(2 * x)
end
$(double(wing) + 1)
// →
wing + nib = 7
10 and 5
11
```

If you need a literal `$` character, escape it: `\$`. A bare `$` that starts no valid evaluation is an error — always escape intended literal `$`. A `$` followed by a space evaluates the rest of the line: `let x = $ 1 + 1`.

## Accumulation Blocks

Every executable block in Plume — the program itself, a macro body, a `do` block, a loop body used as a value — implicitly builds a return value by **accumulation**. The type of the accumulated result is inferred from the block's content:

*   **TEXT block** — the block contains text and/or several expressions, but no table items. All results are converted to strings and concatenated.
    ```plume
    // This program is a TEXT block; it returns "wingnib".
    wing
    nib
    ```

*   **TABLE block** — the block contains at least one table item: a list item (`- value`), a named item (`key: value`) or an expansion (`...table`). It returns a table. Plain text and `$()` evaluations are **not allowed** at the same level as table items.
    ```plume
    // This block returns the table ("wing", "nib", color: "red").
    - wing
    - nib
    color: red
    ```

*   **VALUE block** — the block contains **exactly one** expression. It returns that value *unchanged*, without any string conversion. This is how a macro can return a table, a number or another macro.
    ```plume
    macro getWing ()
        $baseWing
    end
    // getWing returns the value of baseWing itself — if it is
    // a table, the caller receives the table, not its text form.
    ```

*   **EMPTY block** — the block contains no expression at all. It returns the `empty` constant.

Mixing text and table items at the same level of a block is a compile-time error (a *mixed block* error):

```plume
- wing
some text
// → SYNTAX ERROR: Invalid 'TEXT' content in a 'TABLE' block.
```

A TABLE block forbids raw text and bare evaluations at item level, but **statements remain allowed** — `let`, `set`, `if`, `for`... can appear between items, making it possible to compute values while building a table:

```plume
let t = do
    - Item 1
    - Item 2
    let x = $(2 * 5)
    - Item $x
end
// t is the table ("Item 1", "Item 2", "Item 10")
```

(A `do ... end` block evaluates its body and returns the accumulated value — see *Building Tables*.)

The `run` statement goes one step further: it executes **any** expression or call purely for its side effects, leaving the current accumulation untouched (see *Side-Effect Calls: `run`*).

## Values and Constants

Plume values have one of six types: `empty`, `boolean`, `number`, `string`, `table` and `macro`. The standard macro `type(x)` returns the type of a value as a string.

*   **`empty`** — the absence of a value. A declared-but-unassigned variable is `empty`. Concatenating `empty` produces nothing. It is one of the two falsy values (see below).
*   **Booleans** — `true` and `false`. **Only `false` and `empty` are falsy**: every other value, including `0` and the empty string `""`, is truthy in a condition.
*   **Numbers** — integers and floats such as `5`, `-3`, `1.5`. Arithmetic follows the usual rules.
*   **Strings** — text lines are strings. Inside an evaluation context, string literals are written with double or single quotes, supporting the escape sequences `\n`, `\t`, `\r`, `\"`, `\'` and `\\`. Any other escape sequence inside quotes is an error.
*   **Bare words** — where a value is expected (e.g. the right-hand side of `let`), a bare word is read as a value: a word that looks like a number becomes a number (`let wing = 5` binds the number `5`), any other word becomes a string (`let wing = quill` binds `"quill"`). Inside an explicit evaluation context (`$(...)`, `if`, `for ... in`), a bare word is instead read as a variable name — write `"quill"` when you mean the string.

These constants are accessed with the usual prefix: `$empty`, `$true`, `$false`.

```plume
let wing
// wing is empty
Wing is $(wing).
// → Wing is .
```

```plume
if 0
    Zero is truthy in Plume.
end
// → Zero is truthy in Plume.
```

```plume
quill\tink
// →
quill	ink
```

```plume
let color = red // bare word: the string "red"
$(color == "red")
// → true
```

**Coercion.** Plume converts between numbers and strings automatically, both when reading a literal (as just seen, `let wing = 5` binds a number, not the text `"5"`) and when executing an operation: a string that looks like a number is converted back on demand in arithmetic and comparisons. A string that cannot be converted raises a runtime error. Explicit conversions are provided by the standard macros `Number` and `String` (see [reference_std.md](reference_std.md)).

```plume
let wing = 1
$type($wing)\n
set wing = $String($wing)
$type($wing)\n
$(wing + 1)
// no error: "1" is converted back to a number
// →
number
string
2
```

```plume
let wing = 1
$(wing + "abc")
// → RUNTIME ERROR: Cannot convert the string value 'abc' to a number. (i) Consider using the `..` concat operator.
```

## Variables: `let` and `set`

`let` declares new variables in the current scope:

```plume
let wing              // declared, set to empty
let nib, quill, ink   // several at once, all empty
let sing = 5          // declared and initialized
let const write = 2   // a constant: must be initialized, cannot be reassigned
```

Redeclaring an existing name in the same scope is a compile-time error.

`set` assigns new values to existing variables. It looks up each name in the current scope, then in enclosing scopes. Assigning an unknown name, or any `const`, is an error.

```plume
let wing = 1
set wing = 2
set wing += 3   // wing is now 5
```

The compound operators `+=`, `-=`, `*=` and `/=` combine arithmetic and assignment, and work on any assignable target, including table paths:

```plume
set t[1] *= 7
set t.stats.ink += 1
```

Every block body (`if`, `for`, `while`, `macro`, `do`...) creates a new scope. A `let` in an inner scope shadows an outer variable of the same name without modifying it:

```plume
let wing = outer
if true
    let wing = inner   // shadows the outer wing
    $wing\n            // → inner
end
$wing
// → outer
```

`let` and `set` can also extract several values at once from a table — see *Destructuring* in [advanced.md](advanced.md).

## Conditional Branching: `if`

```plume
if evaluation
    ...
elseif evaluation
    ...
else
    ...
end
```

*   The condition after `if` / `elseif` is an evaluation — no `$(...)` needed. It is tested for truthiness (remember: only `false` and `empty` are falsy).
*   `elseif` and `else` are optional and start on their own lines.

Like every block, an `if` accumulates a value, so it can be assigned. Branches must produce compatible content (text with text, items with items); an empty branch yields `empty`.

```plume
let wing = 3
if wing > 2
    Big wing.
elseif wing == 2
    Medium wing.
else
    Small wing.
end
// → Big wing.
```

```plume
let size = if wing > 2
    big
else
    small
end
// size is the string "big"
```

## Loops: `while` and `for`

`while` repeats its body as long as the condition is truthy:

```plume
let count = 0
while count < 3
    wing\s
    set count += 1
end
// → wing wing wing
```

`for name in evaluation` iterates the list items of a table, or the values produced by an iterator:

```plume
let colors = (red, green, blue)
for nib in colors
    $nib\s
end
// → red green blue
```

To count, use the standard iterator `seq` — `for i in seq(1, 5)` — and to iterate with indices or keys, `enumerate` and `items` (see [reference_std.md](reference_std.md)).

Loops are accumulation blocks like any other, so they can build text or be used as values:

```plume
let squares = for i in seq(1, 4)
    - $(i * i)
end
// squares is the table (1, 4, 9, 16)
```

`for` can also declare several variables to unpack each item — see *Destructuring* in [advanced.md](advanced.md).

## `break` and `continue`

Inside a loop, `break` terminates the innermost loop immediately, and `continue` skips to the next iteration. Both must appear on their own line.

```plume
let colors = (red, green, blue, ink)
for nib in colors
    if nib == "blue"
        break
    end
    if nib == "green"
        continue
    end
    $nib\s
end
// → red
```

Using them outside any loop is an error — as is using them inside a macro defined in a loop body: loop control cannot cross a macro boundary.

## Side-Effect Calls: `run`

Every expression in Plume contributes its value to the current accumulation block. To execute an expression or a call purely for its side effects — printing, writing a file, mutating state — prefix it with `run`: the result is discarded and the accumulation is left untouched.

```plume
let config = do
    run $print(Loading config...)
    - wing
    port: 8080
end
// config is a clean table; the print did not leak into it
```

`run` works with any expression, standard calls and block calls:

```plume
run $cleanup(temporary)
run @rebuildIndex
    - wings
    - nibs
end
```

## Defining Macros

Macros are Plume's reusable units of logic. A macro takes parameters and returns the value accumulated by its body:

```plume
macro praise (wing, adjective: great, ?loud)
    The $wing is $adjective.
end
```

A signature can contain:

*   **Positional parameters** (`wing`) — required, filled in order.
*   **Named parameters** (`adjective: great`) — optional; the default applies when the caller omits them.
*   **Flags** (`?loud`) — syntactic sugar for a boolean named parameter defaulting to `$false`; the caller writes `?loud` to set it to `$true`.

A variadic `...rest` parameter can also collect all leftover arguments — see [advanced.md](advanced.md).

Other definition forms:

```plume
macro noop
    // No parentheses needed for a parameterless macro.
end

let double = macro (x) $(2 * x)
// `macro name ...` is sugar for `let name = macro ...`;
// a single-expression body fits on one line (see advanced.md).
```

Inside its body, a macro sees the variables of its enclosing scopes (parameters, outer locals, other macros). This capture mechanism — closures — is detailed in [advanced.md](advanced.md).

## Calling Macros

**Standard call** — `$name(...)`, with positional arguments in order, named arguments as `key: value`, flags as `?flag`. Inside a `$(...)` evaluation, calls are written without the `$` prefix:

```plume
macro praise (wing, adjective: great, ?loud)
    The $wing is $adjective.
end
$praise(quill)\n
$praise(nib, adjective: splendid)\n
$praise(ink, adjective: dark, ?loud)\n
let wing = wing
$(praise(wing))
// →
The quill is great.
The nib is splendid.
The ink is dark.
The wing is great.
```

**Block call** — `@name ... end`: the block supplies the last missings parameters. This is the foundation of Plume's DSL style:

```plume
macro wrap (tag, content, class:)
    <$tag class="$class">$content</$tag>
end

// All theses call return "<b class="note">Sharp nib</b>"

$wrap(b, Sharp nib, class: note)
@wrap(b, class: note)
    Sharp nib
end
@wrap(class: note)
    - b
    - Sharp nib
end
@wrap(b)
    class: note
    - Sharp nib
end
@wrap
    class: note
    - b
    - Sharp nib
end
```

Inline arguments and block content can also be mixed, and block calls chained on one line — see *Advanced Macro Calls* in [advanced.md](advanced.md).

## Early Exit: `leave`

`leave` exits the current accumulation block immediately, returning the value accumulated so far — Plume's equivalent of an early `return`. Inside a loop, it terminates the loop's block, not the whole macro.

```plume
macro collect (limit)
    - for i in seq(1, 100)
        if i > limit
            leave
            // exits the loop with the items gathered so far
        end
        - $(i * 10)
    end
end
$collect(3)
// → $Table((10, 20, 30))
```

*   `leave` must appear on its own line.
*   In a TABLE block it returns the table accumulated so far (empty if none); otherwise it returns the accumulated text (or `empty`).
*   It is forbidden inside a VALUE block, an assignment, a block call or a `raise` — these are compile-time errors.

## Building Tables

Tables are Plume's single data structure: list and key-value map in one. Several ways to build one:

**Table blocks.** Any accumulation block containing items returns a table. List items start with `-`, named items are `key: value`. A `do ... end` block evaluates such a body as a value:

```plume
let inventory = do
    - wing
    - nib
    quality: sharp
end
```

Statements can be mixed freely between items — including `if` and `for`, which then contribute their own items:

```plume
let colors = (red, green, blue)
let palette = do
    - for color in colors
        - $color
    end
    - if wing
        - ink
    end
end
```

**Inline tables.** `(item1, item2, key: value)` builds a table inside an expression. An inline table needs at least two items; for empty or single-item tables, use the standard constructor `$Table()`:

```plume
let pair = (red, blue)
let nothing = $Table()
let one = $Table(wing)
```

**Empty content.** A `-` alone adds an `empty` item; a `key:` alone assigns `empty`.

Table contents can also be expanded from another table with `...`, and keys computed at runtime with `$key:` — see [advanced.md](advanced.md).

## Reading and Writing Tables

*   `$t[1]` — index access. **Indices are 1-based**; the brackets accept any expression: `$t[i + 1]`.
*   `$t.key` — member access, sugar for `$t["key"]`.
*   Reading a missing key or index raises an error (often with a `Perhaps you mean ...?` suggestion).
*   `set t[2] = value`, `set t.key = value` — creates or updates the field. Paths chain: `set t[1].wing = value`.

```plume
let wing = do
    - red
    - green
    nib: sharp
end
$(wing[1])\n     // → red
$(wing.nib)\n    // → sharp
set wing[2] = blue
set wing.ink = dark
$(wing[2])\n     // → blue
$(wing.ink)\n    // → dark
```

When a missing key should yield `empty` instead of an error, use the safe accessors `t.key?` / `t["key"]?` — see [advanced.md](advanced.md).

## Using a Library: `use`

`use path` loads a Plume file **at compile time** and injects every key of the table it returns into the current scope, as `const` variables. This is the standard way to consume a library:

```plume
use document

@Document
    My great document
end
```

The path is written literally — no quotes, no extension (`.plume` or `.🪶` is found automatically). `use` is convenient but deliberately pollutes the namespace; its runtime sibling `$import(...)` offers more control. Parameters, path resolution and the trade-offs are covered in *Modules* in [advanced.md](advanced.md).

## Running a Program: the CLI

```text
plume -i script.plume            Run the file and print its result.
plume -i script.plume -o out.txt Write the result to a file instead.
plume -s "let x = 1 $(x)"        Run a string as the program.
plume -h                         Full help.
plume -v                         Current version.
```

Additional options (file parameters, error styling, colors) are covered in [advanced.md](advanced.md).

## Editions and Versioning

Plume versions follow an **Edition–Build** scheme, e.g. `Plume Raven 64`:

*   An **edition** (`Lark`, `Sparrow`, `Owl`...) is a named release line. Within an edition, code keeps running unchanged.
*   A **build** is a monotonically increasing number; higher is newer, always compatible within the same edition.

A new edition may introduce breaking changes: see [migration.md](migration.md) and the changelog when upgrading. Behavior scheduled for the next edition can be enabled early with `use #future(...)` — see [expert.md](expert.md). This documentation describes the **Raven** edition.

Next: [advanced.md](advanced.md)