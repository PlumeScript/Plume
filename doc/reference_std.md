## Standard Library

Plume provides a set of built-in macros to handle common tasks such as I/O, table manipulation, and iteration.

### Basic Functions

*   `print(...items)`: A wrapper for the underlying lua `print` function.
*   `type(x)`: Returns the type of `x` as a string: `"empty"`, `"table"`, `"number"`, or `"string"`.
*   `tostring(x)`: Converts the value `x` to its string representation.
*   `len(table)`: Returns the number of items in a table.
*   `repr(x)`: Give a string representation of any object.

### Table Manipulation

*   **`table`**:
    *   `table(...items)`: Explicitly creates and returns a table containing the provided items. This function can be called directly.
    *   `table.append(table, item)`: Adds `item` to the end of the specified `table`.
    *   `table.remove(table, [index])`: Removes the `index`-th item of `table` (default: table length) and return it.
    *   `table.removeKey(table, key)`: Removes a key from `table`. Contrary to `table.remove`, no shift is applied.
    *   `table.hasKey(table, key)`: Check if `table` as a field `key`. Behave exactly like `table.key?`, except if `table.key` exists but is `empty`.
    *   `table.find(table, v)`: Search for a `k` such that `table[k] = v` and return the first found. Return `empty` if not found.
    *   `table.finds(table, v)`: Search for all `k` such that `table[k] = v`. Return a table.
    *   `table.count(table, ?named)`: Total number of elements (all keys or named keys only).
    *   `table.entry(table, index)`: Returns the key and value at the given position in insertion order.
    *   **Edge Cases:** Use this function specifically when creating empty tables (`table()`) or tables with a single element.
*   `rawset(table, key, value)`: Sets the value of `key` in `table` to `value` without triggering any `setindex` metafield.
*   `join(sep: "", ...items)`: Returns a string produced by concatenating `items`, optionally separated by `sep`.

Note: For multi-element inline tables, the parentheses syntax `(a, b, ...)` is the preferred method against `$table(a, b, ...)` and evaluates to the same result.

Use `$table` specifically when creating empty tables or tables with a single element.

### String manipulation
*   **`String`** _`$String.method(string)` and `$string.method()` are both valids._
    *  `trim(s)`: Removes leading and trailing whitespace from the string.
    *  `ltrim(s)`: Removes leading whitespace from the beginning of the string.
    *  `rtrim(s)`: Removes trailing whitespace from the end of the string.
    *  `indent(s, sep:\t)`: Prepends the specified separator (default: tab) to each line of the string.
    *  `dedent(s)`: Removes first line leading whitespace from all lines in a multi-line string.
    *  `collapse(s)`: Replaces consecutive whitespace characters (including newlines) with single spaces.
    *  `lower(s)`: Converts all characters in the string to lowercase.
    *  `upper(s)`: Converts all characters in the string to uppercase.
    *  `replace(s, pattern, sub, ?rich)`: Replaces occurrences of pattern with sub. If the rich flag is set, pattern is interpreted as a Lua pattern; otherwise, exact string matching is used.

### Iterators

*   `seq(start, stop)` or `seq(stop)`: Returns an inclusive iterator from `start` to `stop`. If only one argument is provided, `start` defaults to `1`.
*   `enumerate(table)`: Returns an iterator yielding pairs of `(index, value)` for each list item in the table.
*   `items(table, ?named)`: Returns an iterator yielding `(key, value)` pairs for all entries in the table (only non-numeric entries if `?named` flag is on).

### Module System and Imports

#### `import(path, ...params)`
The `import` function is the **default mechanism** for modularity in Plume. It executes a Plume file at runtime and returns its final accumulated value. 

**Key Features:**
*   **Runtime Evaluation:** Unlike `use`, `import` is called during execution. This means the `path` can be a dynamic expression (e.g., `$import(./configs/$(env).plume)`).
*   **Parameter Passing:** It allows passing values to variables declared with `let param` in the target file.
*   **Encapsulation:** The returned value (usually a table) is contained within the variable it is assigned to, keeping the local namespace clean.

**Path Resolution Logic:**
The `import` statement follows a specific lookup order to locate files:
1.  **Relative Search:** If `path` starts with `./` or `../`, Plume searches for the file relative to the directory of the currently executing file.
2.  **Breadth Search:** Otherwise, it searches from the root file's directory and then through the directories listed in `plume_path`.
3.  **File Patterns:** For any given directory, Plume looks for `[path].plume` and `[path]/init.plume`

**Environment and Path Management:**
*   The initial `plume_path` is populated from the `PLUME_PATH` environment variable (paths are separated by commas).
*   `setPlumePath(path)`: Replaces the current `plume_path` with a new value.
*   `addToPlumePath(path)`: Appends a new directory to the existing `plume_path`.

#### Module Lifecycle and Performance
Plume balances performance and safety through its loading strategy:
1.  **Parsing/Compilation:** Occurs only once per file path. The resulting bytecode is cached.
2.  **Execution (Chunking):** Occurs every time `import` or `use` is invoked. A new environment is initialized for each call.

### File System I/O

Unlike `import`, the following functions do not use the `plume_path` resolution logic and expect direct file system paths.

*   `read(path)`: Reads the content of the file at `path` and returns it as a string.
*   `write(path, ...items)`: Writes the concatenated string representation of `items` to the file at `path`.

### Lua Integration

Plume provides a `lua` variable that acts as a bridge to the underlying Lua environment. This variable contains wrappers for essential Lua functions and libraries, allowing for advanced operations not covered by the Plume standard library.

The `lua` table includes:
*   **Module Loading**: `lua.require(path)` (used to load Lua modules, use same Path resolution as `import`).
*   **System functions**: `lua.error`, `lua.assert`.
*   **Libraries**:
    *   `lua.string.*` (string manipulation)
    *   `lua.math.*` (mathematical constants and functions)
    *   `lua.os.*` (operating system facilities)
    *   `lua.io.*` (input and output)

**Important Note on Type Stability:**
The automatic type conversion between Plume and Lua is currently considered **unstable**. This applies particularly to:
*   **Tables**: Mapping between Plume tables and Lua tables.
*   **Functionality**: Mapping between Plume macros and Lua functions.

As a result, some features or data transfers may be entirely non-functional or unusable in the current version.