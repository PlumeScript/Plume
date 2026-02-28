# Plume Technical Documentation

_For version 1.0.beta.12_

This document provides a technical specification of the Plume programming language. It assumes the reader has prior programming experience. For a guided introduction, you may prefer to start with the dedicated tutorial (WIP).

## Core Principles

### 1. Text and Statements

Plume is designed around a text-first principle. Any sequence of characters that is not identified as a language construct is treated as literal text. This means simple text requires no special quoting or escaping.

```plume
This is a valid Plume program.
```

To distinguish control flow and logic from text, Plume recognizes a set of **statements**. A line is treated as a statement if it begins (after any leading whitespace) with one of the following keywords:

*   `if`, `elseif`, `else`, `for`, `while`, `macro`, `end`, `run`, `leave`, `break`, `continue`, `do`, `raw`
*   `let`, `set`, `use`
*   `meta` (defines a metatable field within a table block)
*   `-` (initiates a table item)
*   `key:` (initiates a named table item, where `key` is any valid identifier)
*   `$key:` (initiates a dynamic named table item, where key is an expression to be evaluated)
*   `...` (expand a table)
*   `@name` (initiates a block call)

Anywhere else, these keywords are rendered as plain text.

```plume
This is another valid Plume program:
if 1 + 1 == 2
    Your CPU is okay.
else
    Your CPU needs more love!
end
```

### 2. Evaluation Contexts

By default, Plume treats input as text. To perform computations and use logic, certain parts of the code are parsed within an **evaluation context**. This occurs in two places:

1.  Inside an evaluation block: `$(...)`
2.  Following a statement that requires an expression, such as `if ...`, `elseif ...`, `while ...`, and `for varlist in ...`.

Within an evaluation context:
*   Standard operators are available: `+`, `-`, `*`, `/`, `%`, `^`, `==`, `!=`, `<`, `>`, `<=`, `>=`, `and`, `or`, `not`.
*   Variables can be accessed directly without the `$` prefix.
*   Macros can be called using standard syntax.

```plume
let x = 5
// y will be assigned the number 6, not the string "x+1"
let y = $(x + 1)

let myMacro = macro(wing, song)
    $(wing * song)
end

// The expression is evaluated before being assigned to z
let z = $(1 + myMacro(x, y))
```

### 3. Accumulation Blocks

Every executable block in Plume (the program itself, a macro body, or a block call) implicitly builds a return value in what is known as an **accumulation block**. The type of the block is determined by its content. The `leave` statement can be used to exit the block prematurely, returning the value that has been accumulated at that point.


There are four types of accumulation blocks:

*   **`TEXT` Block:** Contains one or more expressions but **no** table items (`-` or `key:`). All expression results are converted to strings and concatenated.
    ```plume
    // The program returns the string "Hello,World!"
    Hello,
    World!
    ```
*   **`TABLE` Block:** Contains one or more table items. A line in a `TABLE` block must be one of the following:
    *   A list item, starting with `-`.
    *   A named item, starting with `key:`.
    *   A table expansion, starting with `...` (see *Syntax > Table Expansion and Unpacking*).

    Text or `$(...)` evaluations are not allowed at the same level as table items. The block returns a table.
    ```plume
    - First item
    - Second item
    id: 123
    // Returns {"First item", "Second item", "id": "123"}
    ```
*   **`VALUE` Block:** Contains **exactly one** expression. The block returns the value of this single expression *without any type conversion*. This is essential for preserving data types like tables or numbers.
    ```plume
    let myTable = @getData
        - wing
    end

    // This block returns the table itself, not a string representation of it.
    let sameTable = $myTable 
    ```
*   **`EMPTY` Block:** Contains no expressions. The block returns the `empty` constant.

## Syntax

### Comments

Comments start with `//` and extend to the end of the line.

```plume
// This is a comment.
let x = 1 // This is also a comment.
```

### Statements

All statements must start at the beginning of a line, though they may be preceded by whitespace.

Some statements that initiate a value assignment or a data structure (`let`, `set`, `-`, `key:`, `$key:`) can be **chained** on the same line with a statement that produces a value (`if`, `for`, `while`, `macro`, `@name`).

```plume
// Assigning the result of an @-call to a variable
let config = @loadConfig
    port: 8080
end

// Adding a conditional item to a table
- if quill.isAdmin
    Admin Panel
  end
```

#### `if`
Executes a block of code conditionally. Note that `elseif` and `else` must also start on new lines.

```plume
if evaluation
    ...
elseif evaluation
    ...
else
    ...
end
```

#### `for`
Iterates over the elements of a collection. The loop variable can be a single identifier or a list of identifiers for positional unpacking.

```plume
for varname in evaluation
    ...
end

// Positional unpacking
for index, item in enumerationTable
    ...
end
```

If multiple variables are provided (e.g., `for x, y in list`), Plume expects each item in the evaluated expression to be a table (or list). The items of that sub-table are unpacked positionally into the defined variables.
*   Extra items in the sub-table are ignored.
*   An error is raised if the sub-table has fewer items than the number of declared variables.

See the **Iterators** section for how iterables works.

You can use the underscore `_` to ignore loop variables.
```plume
for _, _, _ in seq(1, 3) // The last '_' overwrites the previous ones
    // Code
end
```

#### `while`
Executes a block of code as long as a condition is true.

```plume
while evaluation
    ...
end
```

#### `raw`
Creates a block where content is treated as literal text and injected directly without Plume parsing. This is useful for outputting code examples or text containing Plume syntax that should not be interpreted.

**Standard Syntax:**
```plume
raw
    ...
end
```
The content is appended to the current accumulation block as literal, escaped text. No statement recognition, variable interpolation, or expression evaluation occurs within the block.

**Delimited Syntax:**
To include the literal word `end` within the block without terminating it, use the bracketed form:

```plume
raw[
    ...
]end
```
The delimiters `raw[` and `]end` must match exactly. This form allows the literal text to contain the sequence `end` without closing the block.

**Example:**
```plume
// Standard form - useful for code examples
raw
    // This comment and if-statement are treated as literal text
    if user.isActive()
        renderDashboard()
    end
end

// Delimited form - required when content contains 'end'
raw[
    Configuration example:
    backend: enable
    backend_end_point: /api  // Contains 'end'
]end
```

**Behavior Notes:**
*   The block respects standard indentation rules; the body must be indented relative to the `raw` keyword.
*   The content is added to the accumulation context as a string, similar to text lines, but without any processing of `$`, `@`, or statement keywords.
*   Escape sequences (e.g., `\n`, `\t`) are treated as literal backslash characters.

#### `break` and `continue`
The `break` and `continue` statements provide fine-grained control over the execution of `for` and `while` loops. They only affect the innermost loop in which they are placed.

*   **`break`**
    The `break` statement immediately terminates the execution of the innermost `for` or `while` loop. Program execution resumes at the statement following the loop's `end`.

    ```plume
    // Search for a specific user ID
    let foundUser = for user in userList
        if user.id == targetId
            $user
            // User found, no need to continue looping
            break
        end
    end
    ```

*   **`continue`**
    The `continue` statement immediately stops the current iteration of the loop and proceeds to the next one.
    *   In a `for` loop, it advances to the next element in the sequence.
    *   In a `while` loop, it jumps back to the condition evaluation.

    ```plume
    // Process only positive numbers
    for number in dataSet
        if number <= 0
            // Skip this item and move to the next
            continue
        end
        run $process(number)
    end
    ```

Both `break` and `continue` must appear on their own lines. Using either statement outside of a `for` or `while` loop will result in an error.

#### `macro` and Calls
Macros are the primary way to create reusable logic in Plume. A macro is a block of code that accepts arguments and produces a return value. By default, a macro returns the final value of its implicit accumulation block. However, execution can be terminated at any point using the `leave` statement, which causes the macro to return the value accumulated up to that moment.

**Definition:**
```plume
macro name(positional, named: defaultValue, ?flag, ...variadicArgs)
    ...
end
```
A macro signature can include positional parameters, named parameters with default values, boolean flags, and a final variadic parameter.

*   `positional`: An argument must be provided positionally.
*   `named: defaultValue`: A named argument. If not provided in the call, it takes its default value.
*   `?flag`: Syntactic sugar for a boolean flag. It is equivalent to defining `flag: $false` and allows the call to use the shorthand `?flag` instead of `flag: $true`.
*   `...variadicArgs`: A variadic parameter, which must be the last parameter in the signature. It captures all arguments passed to the macro that were not assigned to another parameter. These leftover arguments are collected into a single `TABLE` variable.
    *   Positional arguments are added as list items (e.g., `- "value"`).
    *   Named arguments are added as named items (e.g., `key: "value"`).
    *   The order of items in the table respects the order in which they were provided in the call.

Macros support **closures**: they can access variables from their parent scopes, capturing the values at the point of definition. This allows macros to reference outer variables, parameters, and other macros defined in enclosing scopes. The only exception to this rule is that macros **cannot capture** variables declared with the `ref` keyword; attempting to do so will result in a compilation error.

The statement `macro name ...` is syntactic sugar for `let name = macro ...`.

**Calls:**
Given the following macro:
```plume
macro buildTag(name, id, class: default, ?active)
    ...
end
```
The following call formats are available:

1.  **Standard Call:** Arguments are passed in a parenthesized list. This format supports positional arguments, named arguments (including dynamic keys), and table unpacking using the `...` operator (see *Syntax > Table Expansion and Unpacking*).
    ```plume
    $buildTag(div, mainContent, ...default)
    ```
2.  **Block Call (`@`)**: Arguments are passed as an accumulation block.
    ```plume
    @buildTag
        - div
        - main-content
        class: container
        active: $true
    end
    ```
3.  **Mixed Block Call**: Some arguments are passed positionally, and the rest are provided in the block.
    ```plume
    @buildTag(div, class: container)
        - main-content
        active: $true
    end
    ```
#### `leave`
Exits the current execution block (macro or file) and immediately returns the value accumulated up to that point. It provides a mechanism for an early return, similar to a `return` statement in other languages.

```plume
leave
```

The `leave` statement must appear on its own line. When executed, it stops all further processing within its block. If `leave` is executed inside a nested structure like a `for` or `while` loop, it terminates the entire macro or file, not just the loop.

The type of the returned value depends on the accumulation block's context at the time `leave` is called:
*   If the block has already been identified as a `TABLE` block (i.e., it contains at least one table item like `-` or `key:`), `leave` will return the table accumulated so far. If no items have been accumulated, it returns an empty table.
*   Otherwise, it returns accumulated text (or the `empty` constant).

```plume
macro generateList(source, limit: 100)
    let i = 0
    - for item in source
        - if i >= limit
            // Return the partially built list if limit is reached
            leave
        end
        - $processItem(item)
        set i = $(i + 1)
    end
    // This item is only added if the loop completes without 'leave' being called.
    status: Completed
end
```

#### `let`
Declares new variables in the **current scope**.

```plume
// 1. Multiple Declaration
let [const] name1, name2, ...

// 2. Positional Destructuring
let [const] name1, name2, ... = expression

// 3. Named Destructuring (from)
let [const] key1, sourceKey as alias, key: default, ... from expression

// 4. Parameter Declaration
let param name [= value]

// 5. Context Variable Declaration
let context name
// Declares a variable that acts as an immutable proxy to a context variable. The variable reflects the current value from the context stack at the point of access.
// Unlike standard variables, a context variable reads its value dynamically from a global context stack. If no value has been pushed onto the stack, the variable evaluates to `empty`.
```

```plume
macro greet()
    let context locale
    Message in $locale.
end

with locale: en
    $greet()  // Output: Message in en.
end
```

**Rules:**
*   The `context` keyword creates an immutable binding. The variable cannot be reassigned with `set`.
*   The value is resolved at access time, not at declaration time.
```

**1. Multiple Declaration**
Declares one or more variables without assigning values immediately. They are initialized to `empty`.
```plume
let x, y, z
// x, y, and z are defined and set to empty
```

It is forbidden to declare a variable twice within the same scope.

*Exception*: The underscore character `_` is reserved for unused loop variables in `for` loops. While `for i, i in ...` is invalid, `for _, _ in ...` is valid. The last `_` will overwrite the previous ones.

**2. Positional Destructuring (`=`)**
Assigns values based on the result of an expression.
*   If a **single variable** is declared, it receives the result of the expression directly.
*   If **multiple variables** are declared, the expression must evaluate to a `TABLE`. Plume unpacks the list items of the table into the variables in order.
    *   **Error:** An error is raised if the table contains fewer items than the number of variables.
    *   **Excess:** If the table contains more items than variables, the excess items are ignored.

```plume
let coord = $table(10, 20, 30)

// 'z' is ignored here
let x, y = $coord 

// Error: 'coord' only has 3 items, but 4 variables are requested
let a, b, c, d = $coord
```

**3. Named Destructuring (`from`)**
Extracts values from a table based on specific keys. The `from` keyword must be followed by an expression that evaluates to a table. This syntax supports **renaming** and **default values**, promoting a robust, structured approach to data extraction.

The general pattern for an item is: `SourceKey [as AliasVariable] [: DefaultValue]`.

*   **`name`**: Tries to retrieve `$table["name"]`. If missing, `name` is set to `empty`.
*   **`name: default`**: Tries to retrieve `$table["name"]`. If missing or `empty`, assigns `default` to variable `name`. **Note:** If the `default` value contains spaces, it must be enclosed in parentheses, e.g., `name: (Default Value)`.
*   **`key as alias`**: Tries to retrieve `$table["key"]` and assigns it to variable `alias`.
*   **`key as alias: default`**: The ultimate combo. Retrieves `$table["key"]`. If missing, uses `default`. The result is stored in variable `alias`.

```plume
// Assume user = { id: 450, role: "admin" } (name is missing)
let user = $getUser()

// 1. Simple extraction
// let id = $user.id
let id from $user

// 2. Renaming
// Extracts 'role', but names the variable 'group'
let role as group from $user

// 3. Default values
// 'name' is missing in the table, so it takes the default value "Anonymous"
let name: Anonymous from $user

// 4. If the default value contains spaces, parentheses are required
let status: (Not Available) from $user

// 5. Combined (Renaming + Default)
// Tries to get 'avatar', rename it to 'icon', doubles back to "default.png" if missing
let avatar as icon: default.png from $user

// All in one line:
let id, role as group, name: Anonymous from $user
```

**4. Parameters declaration**
Variables can be declared as module parameters using the `param` keyword. A `param` variable is automatically `const`.

```plume
let param varname [= defaultValue]
```
These variables are intended to be populated by the caller during an `import`. If no value is provided during the import and no `defaultValue` is specified, the variable defaults to `empty`.


**Common Rules:**
*   **Modifiers:** `const` apply to all variables declared in the statement.
*   **Validation:** An error is raised if a variable with the same name already exists in the current scope, or if a `const` variable is declared without a value (in the standard declaration form).

#### `set`
Assigns new values to **existing** variables. `set` searches for each variable first in the current scope, then in parent scopes.

```plume
// 1. Single Assignment
set name = value

// 2. Positional Destructuring
set name1, name2, ... = expression

// 3. Named Destructuring (from)
set key1, sourceKey as alias, key: default, ... from expression
```

**General Rules:**
For all forms of `set`, an error is raised if any specified target variable:
*   Cannot be found in any active scope.
*   Was declared as `const`.

**1. Single Assignment / Positional Destructuring (`=`)**
Updates variables based on the result of an expression.
*   If a **single variable** is specified (`set x = 1`), it takes the value directly.
*   If **multiple variables** are specified (`set x, y = $coords`), the expression must evaluate to a `TABLE`. Values are unpacked data positionally.
    *   **Error:** An error is raised if the table contains fewer items than the number of variables to update.
    *   **Excess:** If the table contains more items, the extras are ignored.

```plume
// Assume x and y exist
set x, y = $(10, 20)
```

**2. Named Destructuring (`from`)**
Updates variables by extracting values from a table using specific keys. The syntax matches `let`, allowing usage of `as` for renaming source keys to target variables, and `:` for default values if the source key is missing.

```plume
// Assume 'host' exists, and 'port' is a variable used for the connection
let config = @table
    host: 127.0.0.1
    // 'p' is defined in config, but not 'port'
    p: 8080
end

// We assume 'host', 'port' and 'protocol' are already declared variables.

// - Update 'host' with config["host"]
// - Update variable 'port' with config["p"] (Renaming)
// - If config["protocol"] is missing, use "http" (Default value)
set host, p as port, protocol: http from config
```

### Table Expansion and Unpacking (`...`)

Plume provides a `...` operator to expand or unpack a table's contents into another structure. This is applicable in two contexts: table accumulation blocks and macro calls.

The expression following `...` must evaluate to a table. Attempting to expand any other data type (number, string, etc.) will result in an error.

### Dynamic Keys (`$key:`)

Plume allows table keys to be determined at runtime by evaluating an expression. This is available in both table accumulation blocks and macro calls.

*   **In Tables:** The expression after the `$` is evaluated, and the result is used as the key for the following value.
*   **In Calls:** It allows passing named arguments where the name is stored in a variable.

```plume
let dynamicField = status
let val = 200

let response = @table
    code: $val
    $dynamicField: Success
end
// Result: { "code": 200, "status": "Success" }

// Also works in standard macro calls
run $print($dynamicField: All green)
```

#### In Table Accumulation Blocks (Expansion)

When used inside a `TABLE` accumulation block, the `...` operator inserts all items (list and named) from the specified table into the table being constructed.

The items are inserted at the position of the `...` statement. If there are key collisions, the principle of "last write wins" applies:

*   If a key is defined in the block *before* being expanded from another table, the value from the expanded table will overwrite it.
*   If a key from an expanded table is later redefined in the block, the final value will be the one defined last.

```plume
let defaults = @table
    host: localhost
    port: 8000
    - write
end

let config = @table
    port: 9090
    ...defaults
    - paint
    host: production.server
end

// The final 'config' table will be:
// { "write", "paint", host: "production.server", port: 8000 }
```

#### In Macro Calls (Unpacking)

When used inside the argument list of a standard macro call, the `...` operator unpacks the items of a table into arguments for the call.

*   **List items** (e.g., `- value`) are passed as positional arguments.
*   **Named items** (e.g., `key: value`) are passed as named arguments.

The items are unpacked in the order they were declared in the source table. If an unpacked argument does not match any parameter in the target macro's signature, it will be captured by the macro's variadic parameter, if one is defined.

```plume
let myMacro = macro(write, paint, namedArg: "default", ?flag)
    // ...
end

let params = @table
    - quill
    flag: $true
end

// This call:
$myMacro(song, ...params, namedArg: override)

// Is equivalent to:
$myMacro(song, quill, ?flag, namedArg: override)
```

#### In Macro Definitions (Variadic Parameters)

When used as the final parameter in a macro definition, the `...` operator creates a **variadic parameter**. This syntax does not unpack a value but instead instructs the macro to collect all unassigned arguments from a call into a single `TABLE`. A macro definition cannot contain more than one variadic parameter.

```plume
// Defines a variadic macro that accepts any number of trailing arguments
macro wing (write, paint, song: bird, ...ink)
    for quill in ink
        // 'ink' is a table containing all unused arguments
    end
end
```
For a complete explanation, see `Syntax > macro and Calls`.


### Expressions and Value Access

*   **`$name`:** Evaluates the variable `name` and interpolates its value as text.
*   **`$(...)`:** Evaluates the code within the parentheses and returns the resulting value.
*   **`do`** Can be used to evaluate a multiline block.
    ```plume
    // Creates a multiline block and assigns its return value to text
    let t = do
        - Wing
        - Nib
        write: quill
    end

    let text = do
        This is a text.\n
        (a multiline one)
    end
    ```
*   **Accessors:** A variable or code evaluation can be followed by accessors:
    *   **Call:** `$songMacro(write, paint)`
    *   **Index:** `$wingTable[0]`, `$wingTable[keyName]`. Raises an error if the specified key or index does not exist in the table.
    *   **Member:** `$quillObject.property`. Syntactic sugar for `$quillObject["property"]`. Raises an error if `property` does not exist.
    *   **Safe Index (`?`):** Appending `?` to an index or member accessor prevents errors when a key is missing.
        *   `$quillObject.property?`
        *   `$wingTable["key"]?`
        
        If the key exists, the value is returned. If the key is missing, the expression evaluates to `empty` instead of halting execution.

#### References and Aliases (`ref`)
**`ref` Keyword: Creating References to Table Fields**

The `ref` keyword allows creating a variable that acts as a **reference** to a specific field in the current table. This variable will automatically reflect changes to the referenced field.

**Syntax:**
- `ref x`: Creates a variable `x` that references the field `x` of the current table.
- `ref x as y`: Creates a variable `y` that references the field `x` of the current table (aliasing).
- `ref x: value`: Shorthand for `ref x` followed by `x: value` (sets the value of the referenced field).

**Example:**

```plume
let t = @table
    ref x
    y: $x  // y is `empty` (x is not yet set)
    x: 5   // x is now 5
    z: $x  // z is 5 (references the updated x)
end
```

**Behavior:**
- The `ref` variable is a **live reference** to the table field. If the field is modified later, the `ref` variable will reflect the change.
- If the referenced field is `empty` or undefined, the `ref` variable will return `empty`.

#### Inline Tables
Plume allows you to define table literals directly within expressions using parentheses. The syntax mirrors the argument table syntax used in macro calls.

*   **Syntax:** `(items...)`
*   **Evaluation:** The content within the parentheses is evaluated to produce the values for the table items.

```plume
// Assigning an inline table to a variable
let t = (a, b, c, d: e)

// Evaluating expressions inside the inline table
let t = $((1, 2, 3, key: 4))
```

**Constraints:**
*   **Multi-element requirement:** An inline table must contain at least two items. It cannot be used for empty tables or single-element tables.
*   **Fallback:** For empty tables or single-element tables, use the `$table()` function instead.

### Calls for Side-Effects (`run`)

By default, every expression in Plume, including macro calls, contributes its return value to the current accumulation block. This can be undesirable for macros that are executed solely for their side-effects (e.g., printing to the console, writing to a file).

To execute a macro call without its return value affecting the accumulation context, prefix the call with the `do` keyword. The `do` statement ensures the macro is executed, but its return value is discarded.

```plume
let myTable = @table
    // $print returns 'empty', but 'run' prevents it from converting
    // this block into a TEXT block.
    run $print(Initializing table definition...)

    // This remains a valid TABLE block
    id: 42
    name: Plume
end
```

The `run` statement can be used with both standard and block calls:

```plume
// Standard call
run $myMacro(arg1)

// Block call
run @myMacro
    - arg1
    - arg2
end
```

Using `run` allows for imperative-style procedure calls within Plume's expression-oriented architecture, providing a clear and safe way to manage side-effects.

### Context Variables and `with` Statement

Context variables provide a mechanism for passing implicit parameters through nested scopes, similar to a scoped global variable stack. They are useful for reducing boilerplate when a configuration value needs to be accessed deep in a call chain.

#### Declaration

A context variable is declared using the `let context` syntax:

```plume
let context name
```

This creates an immutable proxy that reads from the context stack. The value is resolved at each access, reflecting the most recently pushed value.

#### Setting Context: `with` Statement

The `with` statement pushes one or more values onto the context stack for the duration of a block:

```plume
with name1: value1, name2: value2, ...
    ...
end
```

**Example:**

```plume
macro greet()
    let context locale
    Message in $locale.
end

with locale: en
    $greet()       // Output: Message in en.
    
    with locale: fr
        $greet()   // Output: Message in fr.
    end
    
    $greet()       // Output: Message in en.
end

$greet()           // Output: Message in .
```

#### Behavior

*   **Stack Semantics:** Context values are pushed onto a stack. Nested `with` blocks shadow outer values, and the stack is restored when exiting a block.
*   **Scope Independence:** A macro can read a context variable even if it was not passed as an argument, provided it declares the context binding.
*   **Immutability:** The `let context` binding cannot be reassigned. The variable always reflects the current stack value.
*   **Default Value:** If no `with` statement has pushed a value for a context variable, it evaluates to `empty`.

#### Use Cases and Cautions

Context variables should be used sparingly. They are appropriate for:

*   Configuration values that permeate multiple layers of abstraction (e.g., locale, formatting preferences).
*   Implicit parameters in Domain Specific Languages.

**Trade-off:** While context variables reduce parameter passing overhead, they can make data flow less explicit. Use them judiciously.

#### Built-in Context Variable: `locale`

Plume defines a built-in context variable named `locael` that controls automatic number formatting. When a number is concatenated into text, Plume checks the current value of `locale` and applies locale-specific formatting (e.g., thousands separators, decimal markers).

```plume
with locale: fr
    The value is $(1000.5).
end
// Output: The value is 1 000,5.

with locale: en
    The value is $(1000.5).
end
// Output: The value is 1,000.5.
```

If `locale` is not set, is `none` or is `empty`, numbers are concatenated without formatting.

**Disabling Formatting:**

To prevent automatic formatting in contexts where raw numbers are required (e.g., generating SVG coordinates, JSON output), set `locale` to `none`:

```plume
// SVG library - coordinates must remain unformatted
use #context(locale: none)

macro circle(x, y, r)
    <circle cx="$(x)" cy="$(y)" r="$(r)" />
end

$circle(1000, 2000, 50)// Output: <circle cx="1000" cy="2000" r="50" />
```

This pattern is essential for library authors who need to isolate their code from the caller's localization context.

### Context Injection (`use <path>`)

The `use` directive allows injecting the keys of a table returned by a module directly into the current file’s scope as `const` variables.

**Syntax:**
```plume
use path
use path1, path2, ...
```

**Implementation Details:**
*   **Compilation-time Directive:** `use` is a compiler directive, not a function. It is executed during the compilation phase to resolve symbols. Consequently, `path` must be a literal string; it **cannot** be a dynamic expression evaluated at runtime.
*   **Namespace Impact:** Because `use` injects all keys from the target module into the local namespace, it can lead to "namespace pollution." It should be used sparingly.
*   **Scope:** All keys from the table returned by the file at `path` are made available in the current file as if they were declared locally.

```plume
// math.plume
pi: 3.14

// main.plume
use math
// pi is now directly accessible
The value is $pi
```
### Choosing Between `import` and `use`

While both mechanisms allow code reuse, they serve different purposes:

| Feature | `import` | `use` |
| :--- | :--- | :--- |
| **Execution** | Runtime | Compilation time |
| **Flexibility** | High (dynamic paths, parameters) | Low (literal paths only) |
| **Scope** | User choice | const |
| **Namespace** | Clean (returns a value) | Polluted (injects all keys) |
| **Type** | Macro | Compiler Directive |

**When to use `import` (Recommended):**
This should be your default reflex. It is safer, supports parameters, and allows you to control exactly how the imported data is accessed (e.g., `let math = $import(math)`).

**When to use `use`:**
Only use this when you need to import a large number of symbols that are central to the current file's logic, and where prefixing every call would be detrimental to readability. A typical use case is a **Domain Specific Language (DSL)**, such as a module providing all HTML tags as macros:

```plume
// This avoids writing $tags.div, $tags.span, etc.
use html

@div
    style: @table
        background: red
    end

    - $span(Hello World)
end
```
**Note:** since div is const, it cannot be overwritten.
This is intentional behavior. If you want to monkey-patch a library, you must create a new file:

```

// mylib.plume
let lib = $import(lib)
set lib.div = macro(body)
    [...]
end

...lib

// job.plume
use mylib
```


### Directives (`use #name`)
`use #directive(...params)` is executed during compilation and allows specific behaviors to be enabled/disabled.

**Existing directives**:
*   **warning**
    *   **Options**
        *   `mode: strict`: the first warning encountered raises an error
        *   `mode: ignore`: does not display warnings
        *   `issues: n1 n2 n3`: applies the directive only to warnings related to issue `n1`, `n2` or `n3`
    *   **Exemples**
        *   `use #warning(mode: ignore)` suppresses all warnings
        *   `use #warning(mode: strict, issues: 75 76)` raises an error at the first warning related to issues #75 or #76
*   **devWarnings**
    *   Shorcut for `#warning(mode: normal, issues: 381)`.
    *   Enable warnings about non-const never-modified variables (#381, #382) and never used variables (#381, #473).
    *   **Options**
        *   `mode: strict`: the first warning encountered raises an error
    *   **Exemples**
        *   `use #devWarnings`
        *   `use #devWarnings(mode: strict)`
*   **context**
    Pushes context variables onto the stack for the entire file scope. This is syntactic sugar for a `with` block wrapping the whole file.
    
    **Syntax:**
    ```plume
    use #context(name1: value1, name2: value2, ...)
    ```
    
    **Example:**
    ```plume
    // svg-utils.plume
    // Prevent automatic number formatting in this library
    use #context(local: none)
    
    macro circle(x, y, r)
        <circle cx="$(x)" cy="$(y)" r="$(r)" />
    end
    ```
### Metatables

#### Metatables and Operator Overloading

Plume allows tables to define special behaviors called "metafields". By prefixing a key with the `meta` keyword during table definition, you can intercept language operations such as arithmetic, indexing, or iteration.

```plume
let t = @table
    meta addr: macro(x)
        $(x + 1)
    end
end

// This will call the 'addr' meta-method
$(t + 1)
```

##### Available Metafields

Only a specific set of identifiers can be used as metafields:

*   **Binary Operators:** `add`, `sub`, `mul`, `div`, `mod`, `pow`, `eq`, `lt`.
*   **Unary Operator:** `minus`.
*   **Accessors & Logic:** `getindex`, `setindex`, `call`, `iter`, `next`.

Note: `neq` and `gt` are emulated from `eq`, `lt`.

##### Arithmetic Resolution (Left, Right, and Common)

For binary arithmetic operators (excluding comparison operators), Plume supports three variants for fine-grained dispatching: **Right** (`-r`), **Left** (`-l`), and **Common** (no suffix).

When evaluating an expression like `A + B`, Plume follows this resolution order:
1.  **A.addr(B)**
2.  **B.addl(A)**
3.  **A.add(A, B)**
4.  **B.add(A, B)**

*Note: In `addr` and `addl`, the macro must use the `self` variable to access the table itself. In the common `add` variant, both operands are passed as explicit arguments.*

##### Custom Indexing: `getindex` and `setindex`

The indexing metafields are triggered only when accessing or modifying a key that **does not already exist** in the table.

*   **`getindex(key)`**: Acts as a standard getter. It is called when a missing key is accessed. The value returned by the macro becomes the result of the access.
*   **`setindex(key, value)`**: Acts as a **value transformer**. When assigning to a missing key (`t.key = val`), Plume assigns the result of the `setindex` call to that key. 

**Example of `setindex` transformation:**
```plume
let t = @table
    meta setindex: macro(name, value)
        // Wraps any new assigned value in a prefix
        Modified: $value
    end
end

set t.nib = 5
// External set 't.nib = 5' became 't.nib = $t.setindex("nib", 5)'
$t.nib // Returns: Modified: 5
```

##### Advanced Hooks

*   **`call`**: Allows a table to be invoked like a macro: `$myTable(args)`.

##### Iterators

An iterator in Plume is a table that contain a `next` meta-field, which is a macro. When used in a `for` loop, this macro is called repeatedly until it returns the `empty` constant, signaling the end of the iteration.

```plume
// Example of a custom iterator
set seq = macro(a, b)
  state: $a
  stop: $b
  meta next: macro()
    if self.state <= self.stop
      $self.state
      set self.state += 1
    end
  end
end

for i in seq(1, 5)
  $i
end
// Output:12345
```

If the table does not contain a next meta field, it calls the iter meta field, defined by default, which will create an iterator that traverses the table.


### Escaping

Any character can be escaped with a backslash (`\`) to be treated as a literal. Special escape sequences exist for whitespace:

*   `\n`: Newline
*   `\t`: Tab
*   `\s`: Space

For large blocks of literal text that should not be parsed, consider using the [`raw`](#raw) block statement instead of escaping individual characters.

### Whitespace Handling

The Plume parser ignores the following whitespace by default:

*   Leading spaces and tabs at the beginning of a line.
*   Spaces and the newline character at the end of a line.
*   Spaces surrounding operators or argument separators (`,`) in an evaluation context.

To explicitly insert whitespace characters, use the escape sequences `\s`, `\t`, and `\n`.