# Plume — Advanced

This document covers Plume features that are not needed for a first program but quickly become valuable as projects grow: destructuring, variadic macros, modules, closures, error handling...

*   For the fundamentals, see [core.md](core.md).
*   For features intended for library authors (metatables, contextual variables, directives...), see [expert.md](expert.md).
*   Standard library functions are documented in [reference_std.md](reference_std.md); a few of them appear here where a concept cannot be explained without (`seq`, `items`, `attempt`, `import`...).

## Destructuring

`let` and `set` can extract several values at once from a table.

**Positional destructuring** unpacks the list items of a table, in order:

```plume
let coords = (10, 20, 30)
let x, y = $coords
// x is 10, y is 20; the extra item (30) is ignored.
```

Requesting more variables than available items is an error.

**Named destructuring** uses `from` and reads specific keys, with optional renaming (`as`) and default values (`:`):

```plume
let user = (id: 450, role: admin)

let id from $user                           // id = 450
let role as group from $user                // group = "admin"
let name: Anonymous from $user              // missing key → name = "Anonymous"
let avatar as icon: default.png from $user  // renaming and default combined
let id, role as group, name: Anonymous from $user   // all at once
```

*   A default value applies when the key is missing or `empty`.
*   A default containing spaces needs parentheses: `name: (Default Value)`.
*   Defaults are only allowed in the `from` form.

`set` accepts exactly the same forms, for variables that already exist:

```plume
set x, y = (1, 2)
set host, p as port, protocol: http from $config
```

**In `for` loops**, declaring several variables unpacks each item positionally — every item must then be a table. The dummy name `_` ignores a slot:

```plume
let pairs = ((1, red), (2, blue))
for _, wing in pairs
    $wing\s
end
// → red blue
```

To iterate with indices or keys, use the standard iterators `enumerate` and `items` (see [reference_std.md](reference_std.md)):

```plume
for i, wing in enumerate($wings) ...
for key, value in items($table) ...
```

## Variadic Parameters and Table Expansion

**Definition.** A final `...name` parameter collects every argument not captured by the other parameters into a single table:

```plume
macro list (title, ...items)
    $title\:\n
    for item in items
        $item\n
    end
end

$list(Wings, quill, nib, mode: dark)
// items is the table ("quill", "nib", mode: "dark") — note how
// the named argument is captured too (in the table's map part).
// →
Wings:
quill
nib
```

*   Leftover positional arguments become list items, leftover named arguments become named items, in call order.
*   A macro has at most one variadic parameter, declared last, with no default value.
*   Both in definitions and in calls, argument order is: positional → named → flags (`?f`) → variadic. Breaking this order is a compile-time error.

**Expansion in calls.** `...expr` unpacks a table into arguments — list items become positional arguments, named items become named arguments:

```plume
let params = (quill, mode: fast)
$wing(ink, ...params)
// ≡ $wing(ink, quill, mode: fast)
```

**Expansion in table blocks.** `...expr` inserts all the items of a table at the statement's position. On key collisions, the last write wins:

```plume
let defaults = (host: localhost, port: 8000)

let config = do
    port: 9090
    ...defaults
    host: prod
end
// config is (host: "prod", port: 8000)
```

In every context, the expression after `...` must evaluate to a table.

## Dynamic Keys and Safe Indexing

**Dynamic keys.** Prefixing a key with `$` evaluates it at runtime — in table blocks and in calls alike:

```plume
let field = color

let t = do
    $field: red
end
// t is (color: "red")

$wing($field: blue)   // passes the named argument color: blue
```

**Safe indexing.** Appending `?` to an index or member access returns `empty` instead of raising an error when the key is missing:

```plume
$ t.nib?          // empty if nib is absent
$ t["nib"]?       // same, with brackets
$ t.nib? or 1     // handy for defaults
```

## String Concatenation: `..`

Inside an evaluation context, the `..` operator concatenates two values as text:

```plume
let a = hello
let b = world
$ a .. b
// → helloworld
```

Numbers are converted to text, so `$(1 .. 2)` is `12`. The compound form `..=` appends to any assignable target:

```plume
let s = foo
set s ..= bar
$s
// → foobar
```

**This operator is niche.** Plume's text accumulation already concatenates for you in most cases — `let c = $a$b` or `let d = prefix_$c` is enough and reads more naturally. Reach for `..` only in the rare cases where you must build a string *inside* an evaluation, where text accumulation can't help — for example a dynamic table key:

```plume
let t = do
    item_1: first
    item_2: second
end
let n = 2
$t["item_"..n]
// → second
```

## Closures

A macro captures the variables of its enclosing scopes at the point of definition. The capture is a *live binding*: the macro and its birth scope share the same variable, and mutations are visible on both sides. The capture survives the end of the enclosing scope, which enables factory patterns:

```plume
macro makeCounter
    let count = 0
    macro ()
        set count += 1
        $count
    end
end

let c1 = $makeCounter()
let c2 = $makeCounter()
$c1()$c1()$c2()
// each counter owns its private count
// → 121
```

Captures chain through any number of nested scopes, and a macro can return another macro — calls then chain naturally: `$factory()()`.

## Table Field References: `ref`

Inside a table-accumulating block (a `do` block, or the program itself when it builds a table), `ref` declares a variable that is a **live alias** of a table field:

```plume
let t = do
    ref x
    y: $x    // empty — x is not set yet
    x: 5
    z: $x    // 5 — the ref reflects the current field value
end
```

Available forms:

*   `ref x` — aliases the field `x`.
*   `ref x as y` — the variable `y` aliases the field `x`.
*   `ref x: 5` — shorthand for `ref x` followed by `x: 5`.
*   `ref x, y, z` — several at once.

Constraints: a ref cannot be assigned with `set` (write `x: 5` instead — assigning a ref raises an error that says so), and `ref` is only valid in a table-accumulating block — not in an inline table, an inline call, or a TEXT block.

When the program itself builds a table, `ref` lets macros see their sibling fields — a common shape for modules:

```plume
// a module file
ref wing: macro
    Wing!
end

nib: macro
    $wing()$wing()
end
```

## Advanced Macro Calls

**Chained block calls.** Several `@` calls may share one line; each inherits the block's indentation:

```plume
@Document @Section
    My great text
end
// ≡ @Document
//       @Section
//           My great text
//       end
//   end
```

Table-qualified names chain the same way:

```plume
@Table @Math.sin
    5
end
// → $Table(-0.95892427466314)
```

**Inline block calls.** A `@` call can also take the rest of its line as its body, without `end`:

```plume
macro bold(x)
    <strong>$x</strong>
end

@bold This whole line is the argument of bold.
// → <strong>This whole line is the argument of bold.</strong>
```

The whole line is read as the body, so commas and unbalanced parentheses no longer need escaping:

```plume
@call(a, b) A line with, commas and (unbalanced) parens
```

Inline calls chain like block calls, and can take arguments:

```plume
@bold @italic Mon texte
@style(fontWeight: bold) Mon texte
```

Prefer the block form as soon as the content grows beyond a single line — it keeps the body readable and lets it span several lines.

**Dynamic block call.** Instead of a name, a block call can take an expression — `@(expression) ... end`. The expression is evaluated in script mode (the syntax of `$(...)`, newlines included) and its value is called with the block as its last missing parameter:

```plume
macro getCall()
    $Table
end
@(getCall()) @Math.cos
    0
end
// → $Table(1)
```

Inline arguments can follow the expression — `@(bold)(class: note) ... end` is the block call of `bold` with the inline argument `class: note` — and dynamic calls chain with named ones on the same line, like every block call.

The end-of-line form (see *Calling Macros* in [core.md](core.md)) may also start an inline body: an `@name` — optionally with inline arguments — at the end of the line opens a block call whose body spans the following lines up to `end`.

```plume
macro outer(x)
    [O:$x]
end
macro inner(content)
    [I:$content]
end
@outer intro @inner
    corps
end
// → [O:intro [I:corps]]
```

**Empty arguments.** An empty slot between commas is read as `$empty`: `$wing(,,)` ≡ `$wing($empty, $empty, $empty)`.

**Macros stored in tables: methods.** Calling a macro through a table — `$t.method()` or `$t[1]()` — binds the implicit variable `self` to that table:

```plume
let bird = do
    wings: 2
    describe: macro ()
        $(self.wings) wings
    end
end

$bird.describe()
// → 2 wings
```

`self` is reserved: it cannot be declared as a variable or a parameter.

## Anonymous and Short-Form Macros

Macros are ordinary values: they can be stored in tables, passed as arguments, returned from other macros. A macro without a name is an *anonymous macro*; its string representation is `macro<???>`.

When the body is a single expression, it can be written on the same line as the signature, dropping `end`:

```plume
let double = macro (x) $(2 * x)

run $Table.sort($wings, compare: macro (a, b) $(a < b))
```

(The second line passes an anonymous comparison macro to the standard `Table.sort` — see [reference_std.md](reference_std.md).)

## Raw Blocks

`raw` injects its body as literal text: no statement recognition, no interpolation, escape sequences stay literal.

```plume
raw
    Everything here is output as-is: $wing, if, - item, \n
end
```

The delimited form `raw[ ... ]end` allows the content itself to contain the word `end`:

```plume
raw[
    Example:
    if condition
        do something
    end
]end
```

In both forms, the body must be indented relative to the `raw` keyword.

## Error Handling: `raise` and `attempt`

**Raising.** `raise <message>` stops the current execution and propagates an error. The message is the rest of the line — interpolations allowed — or a `do` block for computed messages:

```plume
if not wing
    raise Missing wing in slot $slot.
end

raise do
    Detailed report: $(buildReport())
end
```

An uncaught `raise` terminates the program with a traceback. `leave`, `break` and `continue` are forbidden inside a `raise`.

**Catching.** The standard macro `attempt(macro, args...)` calls a macro in protected mode and returns a result table:

```plume
let outcome = $(attempt(riskyWing, ink))

if outcome.success
    Got: $outcome.result.
else
    Failed: $outcome.result.
end
```

*   On success, `success` is `true` and `result` holds the macro's return value; otherwise `success` is `false` and `result` holds the error message.
*   Errors are caught at any call depth; output accumulated before the call and contextual state are preserved.

## Returning Values: `return`

A macro normally returns whatever its body accumulates. The `return` keyword makes a macro return a single value and stop immediately:

```plume
macro wing(x)
    if x>5
        return yes
    else
        return no
    end
end
$wing(10)\n
$wing(2)
// →
yes
no
```

*   `return <value>` evaluates the value, then exits the macro and returns it.
*   `return` with no value returns `empty`.
*   If no `return` is reached, the macro returns `empty`.
*   A `return` block is incompatible with text or table accumulation in the same block — mixing them is a compile-time error.

## Modules: `import`

`import(path, ...params)` is the default modularity mechanism: it executes a file **at runtime** and returns the value that file accumulates — usually a table.

```plume
// geometry.plume
pi: 3.14159
double: macro (x) $(2 * x)
```

```plume
// main.plume
let geometry = $import(tests/plume/toimport/geometry)
$ geometry.pi\n
$geometry.double(21)
// →
3.14159
42
```

*   **Dynamic paths:** the path is an ordinary expression, so `$import(./themes/$themeName)` works.
*   **Resolution:** a path starting with `./` or `../` is relative to the current file. Otherwise Plume searches the root file's directory, then each directory of `plume.path` (seeded from the `PLUME_PATH` environment variable, semicolon-separated; it is a regular table you can edit). For each directory, Plume tries `<path>.plume`, `<path>/init.plume`, and the `.🪶` extension variants.
*   **Parameters:** extra arguments feed the target file's `let param` declarations — see *File Parameters*.
*   **Lifecycle:** a file is compiled once per path, and its result is **cached** per file + parameters combination — re-importing the same file with the same parameters reuses the cached result instead of re-executing it. Passing a mutable object as a parameter can lead to unexpected behavior and triggers a dedicated warning.

Since the result is an ordinary value, it can be destructured on the spot:

```plume
let pi, double from $import(./geometry)
```

## Modules: `use` in Depth

`use` is the compile-time counterpart of `import`: it executes a file and injects every key of its result into the current scope as `const` variables.

```plume
use geometry        // literal path — no quotes, no extension
$ pi
$double(21)
```

*   The path must be **literal** — a dynamic path is a compile-time error (the message suggests `$import`).
*   `use a, b` loads several files; `use path(x: 5)` passes parameters (raw text values, trimmed; escapes allowed).
*   Each `use` executes the file again — state is **not** shared between two `use` sites.
*   A `use` cycle is a compile-time error naming the whole chain; injecting a name that already exists is an error as well.

Choosing between the two:

|                | `import`                  | `use`                        |
|----------------|---------------------------|------------------------------|
| Execution      | runtime                   | compile-time                 |
| Path           | dynamic allowed           | literal only                 |
| Result         | a value you assign        | keys injected as `const`     |
| Namespace      | clean                     | deliberately polluted        |

Default to `import`. Reach for `use` when a file's symbols are pervasive — typically a DSL library:

```plume
use html

@div
    - $span(Hello wing)
end
```

To monkey-patch a library, wrap it: import it, modify the table, re-export it with `...`:

```plume
// myhtml.plume
let lib = $import(html)
set lib.div = macro (body)
    <div class="mine">$body</div>
end
...lib

// job.plume
use myhtml
```

## File Parameters

A file declares its parameters with `let param`:

```plume
// greeter.plume
let param name = world
Hello, $name!
```

```plume
$import(tests/plume/toimport/greeter, name: wing)
// →
Hello, wing!
```

*   A `param` variable is implicitly `const`. Without a caller-provided value, it takes its default — or `empty` when no default is declared.
*   `let param ...leftover` collects every otherwise-unmatched named parameter into a table.
*   From the command line: `plume -i main.plume --params --name=wing --verbose` — named values as `--key=value`, flags as `--flag`, positionals as bare words.
*   Passing an undeclared parameter raises an error listing the valid ones.
*   `let param x` binds positional arguments passed to `import` / `use`, in declaration order.

## Warnings and Development Directives

Warnings are controlled per file with the `#warning` directive:

```plume
use #warning(mode: ignore)                  // silence all warnings
use #warning(mode: strict)                  // the first warning becomes an error
use #warning(mode: strict, issues: 230)     // ...only for the listed issue numbers
use #warning(scope: global)                 // also report warnings from imported files
```

`#devWarnings` enables two extra code-quality warnings — variables never reassigned that could be `const`, and variables never used:

```plume
use #devWarnings
use #devWarnings(mode: strict)
```

## Additional CLI Options

Beyond the basic `-i`, `-o`, `-s`, `-h` and `-v` (see [core.md](core.md)):

*   `--params ...` — file parameters (see *File Parameters*).
*   `--color auto|always|never` — colored error output.
*   `--error-style auto|fancy|plain` — rich or plain-text error layout.

Next: [expert.md](expert.md)
