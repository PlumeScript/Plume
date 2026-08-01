# Plume — Expert

This document covers features normally needed only by **library authors**: metatables and operator overloading, custom iterators, validators, contextual variables, compile-time directives, dynamic code execution, Lua interoperability and docstrings.

*   For the fundamentals, see [core.md](core.md); for advanced features, see [advanced.md](advanced.md).
*   Standard library functions are documented in [reference_std.md](reference_std.md); a few of them appear here where unavoidable (`rawset`, `Table.getMeta`, `eval`...).

## Metatables: Operator Overloading

Inside a table block, `meta <field>: <macro>` defines a **metafield** — a hook intercepting language operations such as arithmetic, indexing or iteration.

```plume
let ink = do
    level: 10
    meta addr: macro (x)
        $(self.level + x)
    end
end

$(ink + 5)
// → 15
```

**Binary arithmetic operators** (`add`, `sub`, `mul`, `div`, `mod`, `pow`) each accept three variants, tried in order when evaluating `A + B`:

1. `A.addr(B)` — the right variant; `self` is `A`, the only parameter is the other operand.
2. `B.addl(A)` — the left variant; `self` is `B`.
3. `A.add(A, B)` then `B.add(A, B)` — the common variant, receiving both operands explicitly.

**Unary operator:** `minus` — a parameterless macro with `self`, computing `-A`.

**Comparison operators:** `eq` — `macro(a, b)`; `!=` is derived from it by negation. `lt` — `macro(a, b)`; `>`, `<=` and `>=` are derived from it.

Constraints enforced at compile time: right/left variants take exactly one parameter, common variants exactly two; named arguments are forbidden in operator metamacros; the metafield value must be a macro; unknown metafield names are rejected.

## Custom Indexing: `getindex` and `setindex`

These metafields trigger only when the accessed key is **missing** from the table.

*   `getindex` — `macro(name)`: the returned value becomes the result of the access. Returning `empty` raises an index error.
*   `setindex` — `macro(name, value)`: a *value transformer* — the assignment stores whatever the macro returns.

```plume
let t = do
    meta setindex: macro (name, value)
        Modified: $value
    end
end

set t.nib = 5
$(t.nib)
// → Modified: 5
```

`getindex` is handy for defaulting or logging tables:

```plume
let config = do
    host: localhost
    meta getindex: macro (name)
        Unknown setting '$name'.
    end
end

$(config.port)
// → Unknown setting 'port'.
```

The standard macro `rawset(table, key, value)` writes a field without triggering `setindex`.

## Callable Tables and String Representation: `call` and `tostring`

*   `call` makes a table invokable like a macro, with `self` bound to the table:

```plume
let counter = do
    count: 0
    meta call: macro ()
        set self.count += 1
        $(self.count)
    end
end

$counter()$counter()
// → 12
```

*   `tostring` customizes how the table renders when interpolated into text or passed to `String`:

```plume
let wing = do
    size: 12
    meta tostring: macro ()
        wing(size $(self.size))
    end
end

The $wing is ready.
// → The wing(size 12) is ready.
```

## Lazy Rendering: `fragment`

When the VM needs a concrete value from a table — for arithmetic, comparison or final text output — it calls `FORCE_FRAGMENT`. If the table has a `fragment` metafield, that macro runs first, replacing the table with its return value. The result is **cached**: the meta macro runs at most once per table instance.

The real payoff is nested rendering. Because `fragment` fires at the last possible moment, the deepest fragments run first — so a nested structure renders with intuitive, correct nesting:

```plume
let depth = 0
let item_count = 0
macro List(...items)
    meta fragment: macro
        set depth += 1
        <$depth>
        for x in items
            set item_count += 1
            $item_count$x
        end
        </$depth>
        set depth -= 1
    end
end

@List
    - a
    - @List
        - b
        - c
    end
    - d
end
// → <1>1a2<2>3b4c</2>5d</1>
```

With a plain macro (eager), the inner `List` would render while `depth` is still `1`, producing wrong nesting (`<1>...<1>...</1>...</1>`). Here the inner fragment runs to completion first, so the tags nest correctly.

Unlike `tostring`, which renders the table eagerly at each text interpolation, `fragment` renders **lazily** — once, at the last possible moment — and may return any type: a number, a restructured table, `empty` — not just text.

```plume
let counter = do
    meta fragment: macro ()
        42
    end
end

$(counter + 8)
// → 50
```

A fragment-table is best understood as a **lazy value**: its render is deferred until a concrete value is needed. The table's other fields are generation parameters for that deferred render — they stay inspectable (indexing, iteration) even after rendering, and `Table.materialize` (below) processes them as data.

Constraints: the metafield value must be a macro. Because `fragment` intercepts the very triggers these other metafields rely on, defining it alongside any of them is an error:

*   `tostring` — both define how the table becomes text; `fragment` would shadow it.
*   `call` — the table is rendered before the call, so `call` would never fire.
*   Arithmetic operators (`add`, `sub`, `mul`, `div`, `mod`, `pow` and their `r`/`l` variants, `minus`) — the table is rendered before the operation, so the operator metamacro would never fire.
*   Comparison operators (`eq`, `lt`) — the table is rendered before the comparison, for the same reason.

The `fragment` metafield does **not** fire on table operations that access structure rather than rendering — iteration (`for x in t`), indexing (`t.field`), or table expansion (`...t`) leave the table untouched. Only the explicit need for a concrete value triggers it.

To force rendering across an entire tree — flattening every `fragment` meta and lazy fragment in a table's children — use `Table.materialize(x)`:

```plume
let deep = do
    - do
        meta fragment: macro ()
            inner-rendered
        end
    end
    - plain
end

let m = $Table.materialize($deep)
// m is a table whose first item is the string "inner-rendered"
// and second item is the string "plain"
```

`Table.materialize` returns a **new** table; the original is never mutated. Non-table values pass through unchanged.

## Custom Iterators: `next` and `iter`

A table becomes usable in a `for` loop through two metafields:

*   `next` — `macro()` called repeatedly; iteration stops when it returns `empty`. State typically lives on `self`.
*   `iter` — `macro()` returning a fresh iterator object, called when the table has no `next`. The default `iter` traverses the table's list items.

```plume
macro span (first, last)
    current: $first
    stop: $last
    meta next: macro ()
        if self.current <= self.stop
            $self.current
            set self.current += 1
        end
    end
end

for i in span(1, 4)
    $i
end
// → 1234
```

Defining `iter` instead of `next` lets one collection be traversed independently by several loops at once.

## Readonly Tables and Meta Management

`meta readonly: $true` freezes a table: any write raises `Cannot set index of a readonly table.`

The standard library's own tables (`Table`, `String`, `Math`...) are readonly, so user code cannot patch them accidentally.

The standard macros `Table.getMeta(t)` and `Table.setMeta(t, meta)` read and replace a table's metafields (see [reference_std.md](reference_std.md)) — including, deliberately, clearing `readonly` when a table must be unlocked.

## Parameter Validators

Prefixing a parameter with an identifier applies a **validator** at call time:

```plume
macro wing (Number size)
    $type($size)
end

let x = $String(1)
$wing($x)
// → string — the argument was converted before entering the body
```

`macro wing (Number size)` is syntactic sugar for:

```plume
macro wing (size)
    set size = $(Number(size)) // with a custom error in case of Number fail
end
```

Rules:

*   The validator must be an identifier (not an expression) naming a visible variable.
*   It applies to positional and named parameters — defaults are validated too — and to variadics, which are validated as a single table.
*   The validator is either a one-parameter macro (it returns the transformed value, or raises an error to reject the input), or a table with a `validate` metafield — preferred over a generic `call` metafield when both exist.
*   A failure raises `Validator 'Number' failed: ...` at the call site.

The standard `List` and `Map` validators check the shape of a table; on a variadic, they restrict it to positional-only or named-only arguments:

```plume
macro wing (List ...items)   // positional arguments only
```

Writing a custom validator is just writing a one-parameter macro:

```plume
let Positive = macro (Number x)
    if x <= 0
        raise Expected a positive number.
    end
    $x
end

macro area (Positive w, Positive h)
    $(w * h)
end
```

## Contextual Variables

Contextual variables pass implicit parameters through nested calls — a scoped, dynamic alternative to globals.

```plume
let ink = $Context(blue)   // declared with a default value

macro paint ()
    Painted in $ink().\n   // read by calling the variable
end

$paint()
with ($ink: red)
    $paint()
    with ($ink: green)
        $paint()
    end
    $paint()
end
// → Painted in blue.
// → Painted in red.
// → Painted in green.
// → Painted in red.
```

*   `$Context([default])` creates the variable; `$ctx()` reads its current value.
*   `with ($ctx: value, ...) ... end` pushes values for the duration of a block; nested `with` blocks shadow outer ones; values are restored on exit — including exits via `break` or `raise`.
*   The scope is **dynamic**, not lexical: any code *called* inside the `with` — macros, imported files — sees the current value at call time.

Plume's own behavior is configurable through built-in contexts:

*   `plume.locale` (`en`, `fr`, `custom`, `none`) — automatic number formatting when a number is concatenated into text, plus `plume.localeNumberFormat`, `plume.localeThousandsSeparator` and `plume.localeDecimalSeparator` for the `custom` case (see `Number.format` in [reference_std.md](reference_std.md)).
*   `timeZone` and `timeLocale` — defaults for `Time.date`.

Use contextual variables sparingly: configuration that permeates many layers (locale, theme), or DSL internals. They make data flow less explicit than plain parameters.

## Library Isolation: `#rawNumbers` and `#context`

Two compile-time directives protect a library from its caller's environment.

`use #rawNumbers` disables locale-based number formatting **for the current file only** — essential when generating formats where numbers must stay raw:

```plume
// svg.plume
use #rawNumbers

macro circle (x, y, r)
    <circle cx="$(x)" cy="$(y)" r="$(r)" />
end
```

`use #context(key: value, ...)` wraps the whole file in a `with` block. Only built-in `plume.*` contexts are accepted:

```plume
use #context(locale: none)
```

## Opt-in Features: `#future`

`use #future(name)` enables today a behavior that will become the default in a future edition:

```plume
use #future(newLeave)
use #future(all)        // every feature of the next edition
use #future(raven)      // every feature of a named edition
```

Currently available features:

*   `newLeave` — `leave` exits the **current accumulation block** instead of the whole macro or file.
*   `lineEval` — `$ ` (a dollar followed by a space) evaluates the rest of the line: `let x = $ 1 + 1`. A non-escaped `$` then becomes an error.
*   `importCache` — `import` and `use` results are cached per file + parameters combination instead of being re-executed. Passing a mutable object as parameter triggers a dedicated warning.
*   `unknownParamError` — enabled **in a module**, it turns passing an undeclared file parameter into an error listing the valid ones.
*   `positionnalFileParam` — `let param x` binds positional arguments passed to `import` / `use`, in declaration order.

## Dynamic Code: `eval` and `lua.eval`

`eval(code, filename:, ?safe)` executes Plume source at runtime:

```plume
$eval(\$(1 + 1))
// → 2

let outcome = $(eval(raise wing, ?safe))
// outcome is (success: false, result: ...wing...)
```

*   Without `?safe`, errors raise; with `?safe`, `eval` returns a `(success:, result:)` table like `attempt`.
*   Error positions point into `<string>` — or into the provided `filename`.

`lua.eval(code, ?safe)` does the same for Lua code, with the same `?safe` protocol. The result must be convertible to Plume values — for now, only strings, numbers and `empty` are supported.

## Lua Modules: `lua.require`

`lua.require(path)` loads a Lua file using the same path resolution as `import`. The file must return a **function**, which Plume calls with its API object; the function's return value becomes the module value — typically a Lua-backed macro built with `plume.obj.luaMacro`:

```lua
-- double.lua
return function (plume)
    return plume.obj.luaMacro("double", function (args)
        local x = args.table[1]
        return true, 2 * x -- success, result
    end)
end
```

```plume
let double = $lua.require(./double.lua)
$double(21)
// → 42
```

Inside the callback, `args.table` holds the positional arguments; returning `true, value` yields `value` back to Plume.

## Docstrings: `plume.doc` and `help`

Comments are not always discarded: a comment written **without a blank line** immediately before a macro, a table, or at the very top of a file, is captured and stored as that object's documentation.

```plume
// Double a number.
// @param x number The value to double.
macro double (x)
    $(2 * x)
end

run $help(double)
// prints the macro's documentation
```

*   `plume.doc(x)` returns the captured documentation as a string; `help(x)` prints it.
*   Docstrings attach to macros, tables and whole files — and the standard library's own macros carry them, so `help` works everywhere.
*   `@param name type description` is the conventional tag for documenting parameters.
