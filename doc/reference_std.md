## Standard Library

Plume provides a set of built-in macros to handle common tasks such as I/O, table manipulation, and iteration.

### Basic Functions

*   `print(...items, ?pretty)`: A wrapper for the underlying lua `print` function.
*   `type(x)`: Returns the type of `x` as a string: `empty`, `table`, `number`, or `string`.
*   `len(table)`: Returns the number of items in a table.
*   `repr(x, ?pretty)`: Give a string representation of any object.
*   `help(x)`: A shortcut for `print(plume.doc(x))`
*   `Number(x)`: Convert to a number. Raise an error if fail.
*   `String(x)`: Convert to a string.
*   `min(...numbers)`
*   `max(...numbers)`

### Table Manipulation

*   `List(table)`: return a table with only array part. If used as validator, raise an error if table contains a map element.
*   `Map(table)`: return a table with only map part. If used as validator, raise an error if table contains a array element.
*   **`Table`**:
    *   `Table(...items)`: Explicitly creates and returns a table containing the provided items. This function can be called directly.
    *   `Table.sort(table, compare:)`: In place sort. Doesn't change keys order. Optional `compare` accept a `macro` that take two arguments and return `true` if `a<b`. 
    *   `Table.append(table, item)`: Adds `item` to the end of the specified `table`.
    *   `Table.remove(table, [index])`: Removes the `index`-th item of `table` (default: table length) and return it.
    *   `Table.removeKey(table, key)`: Removes a key from `table`. Contrary to `table.remove`, no shift is applied.
    *   `Table.hasKey(table, key)`: Check if `table` as a field `key`. Behave exactly like `table.key?`, except if `table.key` exists but is `empty`.
    *   `Table.find(table, v)`: Search for a `k` such that `table[k] = v` and return the first found. Return `empty` if not found.
    *   `Table.findAll(table, v)`: Search for all `k` such that `table[k] = v`. Return a table.
    *   `Table.count(table, ?named)`: Total number of elements (all keys or named keys only).
    *   `Table.entry(table, index)`: Returns the key and value at the given position in insertion order.
    *   `Table.join(sep:, ...items)`: Returns a string produced by concatenating `items`, separated by `sep` (default empty).
    *   `Table.sum(...items)`
    *   `Table.copy(table)`: Returns a superficial copy of `table`.
    *   `Table.deepcopy(table)`: Returns a deepcopy copy of `table`. Support self-referencing table.
    *   **Edge Cases:** Use this function specifically when creating empty tables (`Table()`) or tables with a single element.
*   `rawset(table, key, value)`: Sets the value of `key` in `table` to `value` without triggering any `setindex` metafield.

Note: For multi-element inline tables, the parentheses syntax `(a, b, ...)` is the preferred method against `$Table(a, b, ...)` and evaluates to the same result.

Use `$Table` specifically when creating empty tables or tables with a single element.

### String manipulation

`$String.method($s)` and `$s.method()` are both valids way to call `method` on a string named `s`.

For all macro that take a `pattern` parameter, `?rich` flag enable `lua` pattern, when no `?rich` flag match the exact string.

#### Normalization
*  `trim(s)`: Removes leading and trailing whitespace from the string.
*  `ltrim(s)`: Removes leading whitespace from the beginning of the string.
*  `rtrim(s)`: Removes trailing whitespace from the end of the string.
*  `indent(s, sep:\t)`: Prepends the specified separator (default: tab) to each line of the string.
*  `dedent(s)`: Removes first line leading whitespace from all lines in a multi-line string.
*  `collapse(s)`: Replaces consecutive whitespace characters (including newlines) with single spaces.

#### Manipulation
*  `lower(s)`: Converts all characters in the string to lowercase.
*  `upper(s)`: Converts all characters in the string to uppercase.
*  `replace(s, pattern, sub, ?rich)`: Replaces occurrences of pattern with sub. sub can be a `string`, or a macro that take one `match` parameter and return a `string`.
*  `rep(s, count, sep:)`: Repeat the string `count`, separate with `sep` if provided.
*  `sub(s, start, end)`: Return a substring for `s`, starting at position `start`, ending at position `end`. `end` could be `-1`, representing string end.

#### Search
* `find(s, pattern, ?rich)`: Returns tthe first match, or empty if not found.
* `contains(s, pattern, ?rich)`: Returns true if the pattern is found within the string.
* `startsWith(s, pattern, ?rich)`: Returns true if the string begins with the pattern.
* `endsWith(s, pattern, ?rich)`: Returns true if the string ends with the pattern.
* `count(s, pattern, ?rich)`: Returns the number of non-overlapping occurrences of the pattern.

#### tests
* `isNumber(s)`: Return true if s can be converted to a number.

#### Tables related
* `split(s, sep:\s, ?rich)`: Splits the string into a slice of substrings separated by the specified delimiter (default: whitespace).
* `lines(s)`: Splits the string into a slice of individual lines.
* `findAll(s, pattern, ?rich)`: Returns a slice of all non-overlapping matches of the pattern found in the string.
* `partition(s, pattern, ?rich)`: Splits the string into three parts around the first occurrence of the pattern: the text before the match, the match itself, and the text after.

### Number manipulation

`$Number.method($n)` and `$n.method()` are both valids way to call `method` on a number named `n`.

#### Manipulation
* `abs(n)`
* `floor(n, digit: 0)`: Rounds the number down to the nearest integer or to the specified number of decimal places.
* `ceil(n, digit: 0)`: Rounds the number up to the nearest integer or to the specified number of decimal places.
* `round(n, digit: 0)`: Rounds the number to the nearest integer or to the specified number of decimal places.
* `clamp(n, min, max)`: Restricts the number to lie within the inclusive range [min, max].
* `localize(n, local)`: Proxy to `format(n, %s, local: local)`
* `format(n, format, locale:, thousandsSeparator:, decimalSeparator:., thousandthsSeparator:)`: Formats the number according to the specified format string (uses Lua `string.format`). `local` can be `empty` (1055.2 → 1055.2), `en` or `us` (1055.2 → 1,055.2) or `fr` (1055.2 → 1 055,2). `local` can also be set to `custom`, and `thousandsSeparator`, etc... will be used. This macro will be automatically called for any concatenation of a string and a number. Options used can be customised using the contextual variables `locale`, `localeNumberFormat`, `localeThousandsSeparator`, `localeDecimalSeparator`, and `localeThousandthsSeparator`.

#### Test
* `sign(n)`: Return `1`, `-1` or `0` depending of `n` sign.

**Note:** `Number` methods operate directly on numeric values for formatting, rounding, and basic operations, while `Math` provides pure mathematical functions (trigonometry, logarithms) and universal constants.

### Math

_All trigonometry functions works in radians._

#### Functions

* `Math.cos(x)`
* `Math.sin(x)`
* `Math.tan(x)`
* `Math.acos(x)`
* `Math.asin(x)`
* `Math.atan(x)`
* `Math.atan2(x)`
* `Math.log(x)`
* `Math.log10(x)`

#### Constants
* `Math.pi`
* `Math.e`
* `Math.huge`

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
*   The initial `plume.path` is populated from the `PLUME_PATH` environment variable (paths are separated by commas).
*   You can add, remove or replace by editing the `plume.path` table.

#### Module Lifecycle and Performance
Plume balances performance and safety through its loading strategy:
1.  **Parsing/Compilation:** Occurs only once per file path. The resulting bytecode is cached.
2.  **Execution (Chunking):** Occurs every time `import` or `use` is invoked. A new environment is initialized for each call.

### System and I/O

#### Read and write
Unlike `import`, the following functions do not use the `plume.path` resolution logic and expect direct file system paths.

*   `read(path)`: Reads the content of the file at `path` and returns it as a string.
*   `write(path, ...items)`: Writes the concatenated string representation of `items` to the file at `path`.

> **Note:** `write(path)` provides a quick shortcut for simple file writes, while `os.Path.write()` offers more control when you're already working with Path objects.

#### File system

**Creation**
*   `os.Path([path])`: Return a `Path` table. Without `path` args, return the current directory.

**Exploration**
*   `Path.getChildren()`: If `Path` is a directory, return all it's children. You can also directly iterate over: `for path in Path`.
*   `Path.isDirectory()`: Return `true` if `Path` is a directory.
*   `Path.isFile()`: Return `true` if `Path` is a file.
*   `Path.exists()`: Return `true` if `Path` exists.

**Action**
*   `Path.mkdir()`: Create a directory.
*   `Path.touch()`: Create a file.
*   `Path.remove()`: Remove a file or a directory.
*   `Path.copy(dest)`: Copies a file to destination path. Return the new path.
*   `Path.move(dest)`: Moves or renames a file/directory from source to destination. Return the new path.
*   `Path.read()`: If `Path` is a file, return it's content.
*   `Path.write(...content)`: If `Path` is a file or don't exists, write it.
*   `Path.walk`: Return a table of all childs.

**Manipulation**
*   `Path.getParent()`: Return the parent directory
*   `Path.getName()`: Return the last path component as string.
*   `String(Path)`: Get path as string

#### Environment and commands
*   `os.execute(command)`: Executes a shell command and returns its exit status code.
*   `os.getEnv(name)`: Retrieves the value of an environment variable by name.

### Random Generation

*   `Random([seed])`: Creates a new random generator with optional seed. Returns an object holding internal state.
    *   If no seed provided, uses current time automatically.
    
#### Generator Methods

Assume `let random = $Random()`.

* `random()`: Returns float between 0 and 1.
* `random(max)`: Integer in [0, max] inclusive (both bounds included).
* `random(min, max)`: Integer in [min, max] inclusive (both bounds included).
* `random.seed(seed)`: set the seed.
* `random.choice(table)`: Random element from items list.
* `random.pchoice(table: weight)`: Random key weighted by values.
* `random.shuffle(table)`: Shuffle table in place
* `random.sample(table, count:)` Returns count unique elements.

### Time manipulation

*   `Time.now()`: same as `Time.date(timestamp: currentTimestamp)`.

**Constructor**
*   `Time.date(year: 1970, month: 1, day: 1, hour: 0, minute: 0, second: 0, zone:, locale:, timestamp: 0)`: Create a `Date` object. `zone` and `locale` default to context variables `timeZone` and `timeLocale`. Cannot use `timestamp` and `year, month, etc...` at the same time.
*   `Time.duration(second)`: return a `Duration` object. In most case, you should use `Time.SECOND`, etc...

**Constants (for duration arithmetic)**
*   `Time.SECOND = 1`
*   `Time.MINUTE = 60`
*   `Time.HOUR   = 3600`
*   `Time.DAY    = 86400`
*   `Time.Week   = 604800`


**Properties**
All properties can be read or written. Writing one field automatically updates all other fields synchronously. Raises an error if the resulting date is invalid.

*   `time.timestamp`: Unix timestamp (seconds since epoch)
*   `time.year`, `month`, `day`, `hour`, `minute`, `second`
*   `time.locale`: Locale for formatting and parsing
*   `time.zone`: Time zone identifier or offset
*   `duration.day`, `hour`, `minute`, `second`

**Methods**

Assume `let time = $Time()`

*   `Time.parse(string, template:)`: Parse a string into a Time object. If no template provided, uses default format based on current locale context. Raises an error if the string cannot be parsed according to the template.
*   `time.format(template:)`: Format the time as a string using the specified template. Uses `%` symbols (see below). Defaults to locale-specific format if no template is provided.

**Available format symbols**

| symbol | meaning | example output |
|---|---|---|
| %y | year (4 digits) | 2026 |
| %m | month (1-12, zero-padded) | 04 |
| %mm | month name (locale-aware) | April / Apr |
| %d | day of month (1-31, zero-padded) | 20 |
| %dd | day name (locale-aware) | Monday / Mon |
| %h | hour (0-23, zero-padded) | 14 |
| %min | minute (0-59, zero-padded) | 30 |
| %s | second (0-59, zero-padded) | 45 |

**Meta operations**

*   `String(time)`: Same as `time.format()` with default locale template.
*   `time1 + time2` ; `time1 - time2`: Add or subtract timestamps (returns a Time object).
*   `time * number` ; `time / number`: Multiply or divide the underlying timestamp by a scalar value.


### Lua Integration

* `lua.require(path)` (used to load Lua modules, use same Path resolution as `import`). Required file must return a function.

### Others
*   **plume.doc(m)**: Return the documentation for a macro, generated from all comments — without blank lines — located immediately before the macro declaration.