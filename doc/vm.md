## Plume Virtual Machine Architecture

This document outlines the technical architecture of the Plume VM. It is a concise reference intended for developers familiar with compiler and virtual machine concepts.

### 1. Core Architecture: Dual-Stack Design

The Plume VM is a stack-based machine that operates on a unified bytecode stream. Its key architectural feature is the use of two distinct primary stacks:

*   **Value Stack (`mainStack`):** The primary work stack. Operands are pushed here for calculations, and values are assembled by *Accumulation Blocks*. A companion `mainStack.frames` stack tracks accumulation frame boundaries.
*   **Variable Stack (`variableStack`):** A separate primary stack dedicated to local variables, managing lexical scope. Its `variableStack.frames` companion tracks scope boundaries.

This separation is the core design choice of the VM: accumulation frames and scope frames are fully decoupled. In most stack-based VMs, a single stack serves both roles; in Plume, a `while` loop creates a scope but is not an accumulation block, so `LEAVE_SCOPE` can clean up the variable stack without altering a pending accumulation on the value stack — and vice versa, a `CONCAT_TEXT` can finalize an accumulation block without touching the variable stack.

Several specialized stacks support specific mechanisms:

*   **Macro Stack (`macroStack`):** Stores return instruction pointers for macro and file calls.
*   **File Stack (`fileStack`):** Tracks the chain of imported files during execution.
*   **Closure Stack (`closureStack`):** Holds the upvalue table for the currently executing macro, enabling closure access to captured variables.
*   **Injection Stack (`injectionStack`):** Holds deferred opcodes to be executed before the next bytecode instruction, used for meta-macro dispatch and host callbacks.
*   **Tag Stack (`tagStack`):** Parallel to the value stack; marks stack entries as `key` or `metakey` during table accumulation.
*   **Context Cache (`contextStackCache`):** Tracks pushed context variables for restoration on `POP_CONTEXT`.

### 2. Scope and Memory Management

#### Lexical Scopes
Scopes are managed on the variable stack via two opcodes:

*   `ENTER_SCOPE A X`: Saves the current variable stack pointer (adjusted by `A`, the number of variables already stacked) and reserves `X - A` new slots, initialized to `empty`.
*   `LEAVE_SCOPE`: Restores the variable stack pointer to its state before `ENTER_SCOPE`, discarding all local variables for the current scope.

```bytecode
-- A `while` loop illustrates scope management without value accumulation.
:loop_start
    -- ... bytecode for condition evaluation ...
    JUMP_IF_NOT :loop_end
    ENTER_SCOPE 0 1  -- New scope for the loop body, 1 local variable.
    -- ... loop body bytecode ...
    LEAVE_SCOPE      -- Discard loop scope.
    JUMP :loop_start
:loop_end
```

#### File Handling
There is no dedicated "static memory" region. File-level parameters are managed through the file stack:

*   `STD_IMPORT`: Compiles (or retrieves cached) the imported file, pushes its fileID onto `fileStack`, pushes the return address onto `macroStack`, and jumps to the file's code offset. File parameters are saved in `vm.fileParams` for `FILE_INIT_PARAMS` to distribute.
*   `FILE_INIT_PARAMS`: Distributes saved file parameters into local variable slots at the start of file execution.
*   `RETURN_FILE`: Pops the file stack, pops the callstack, caches the result if applicable, and jumps back to the caller. If the file stack is empty, signals program termination.

#### Program Termination
There are two paths for VM termination:

*   **`RETURN_FILE` with empty file stack:** As described above, returning from a file when no file is active signals program termination.
*   **Jump past bytecode end (#1076):** Since #1076, the compiler guarantees that the last byte of any compiled unit is an `END` opcode. This allows the VM to terminate by setting `jump = #bytecode`, effectively jumping to the position just after the END instruction. The VM exit condition checks if the jump offset reaches or exceeds the bytecode length, providing a clean termination without requiring a dedicated terminal instruction in the source code.

#### The `vm.jump` Register and Pending-Jump Fragility

`vm.jump` is a deferred jump register: opcodes like `JUMP`, `JUMP_IF`, etc. set it, and `_VM_TICK` consumes it at the start of the next instruction cycle (setting `vm.ip = vm.jump` then resetting `vm.jump = 0`). This deferral is necessary because multiple opcodes may need to influence control flow within a single dispatch cycle (e.g., an injection taking precedence over a return jump).

This design has a critical invariant: **a pending `vm.jump > 0` must not be silently overwritten**. Several opcodes unconditionally write `vm.jump`, and if a previous jump is still pending, it is lost. This is particularly fragile in the following situations:

*   **`RETURN` and `RETURN_FILE`**: Both call `_POP_CALLSTACK` (which may set `vm.jump` via `_JUMP_END` to end a recursive run) and then unconditionally call `JUMP` with the return address from `macroStack`. If the recursive-exit jump is pending, the `JUMP` call overwrites it. `RETURN` guards against this by checking the return value of `_POP_CALLSTACK`; `RETURN_FILE` does not (it is not concerned by recursive runs per #1075, but a dev-mode guard checks `vm.jump > 0` and raises an error if this invariant is violated).
*   **`_ERROR`**: Sets `vm.jump` to `#bytecode` via `_JUMP_END` to skip to `END`. The `JUMP` opcode itself has a guard: if `vm.jump > 0` and `vm.err` is set, it refuses to overwrite the jump. This ensures error jumps survive any intervening `JUMP` opcodes between the error site and the `END` label.
*   **`HOST_NEXT`**: Checks `vm.jump == #vm.bytecode` (the error/end jump) and injects `END` + `HOST_UPDATE` instead of resetting, to handle the interaction between host callbacks and error termination.

When adding new opcodes or modifying existing ones that call `JUMP`, always consider whether a pending `vm.jump` could be overwritten. The dev-mode guards in `RETURN_FILE` and the guard in `JUMP` itself exist to catch violations of this invariant.

### 3. The Accumulation Mechanism

The "Accumulation Block" is Plume's core evaluation model, implemented on the value stack.

1.  **Initiation:** `BEGIN_ACC` pushes the current value stack pointer onto `mainStack.frames`, marking the block's boundary.

2.  **Execution & Finalization:**
    *   **`TEXT` Block:** Expressions are evaluated and results pushed onto the value stack. `CONCAT_TEXT` pops all values down to the frame marker, concatenates them, and pushes the result. Small, flat concatenations are optimized into a direct `table.concat`; larger ones produce a *fragment* (a lazy array of parts). `FORCE_FRAGMENT` recursively flattens a fragment into a single string.
        ```bytecode
        -- For a block like `Hello, $name!`
        BEGIN_ACC
        LOAD_CONSTANT "Hello, " -- Pushes string onto value stack.
        LOAD_LOCAL 0 name      -- Pushes variable's value onto value stack.
        CONCAT_TEXT            -- Pops both, concatenates, pushes "Hello, John!".
        ```
    *   **`TABLE` Block:** `TABLE_NEW` pushes a raw Lua hash table to collect key-value pairs. List-style items are pushed directly onto the value stack, while key-value items are tagged with `TAG_KEY` / `TAG_META_KEY` and stored into the raw table via `TABLE_SET_ACC`. `CONCAT_TABLE` then pops the list items, merges them with the key-value table, and pushes the final Plume table.
        ```bytecode
        -- For a block building a table
        BEGIN_ACC
        TABLE_NEW               -- Pushes a raw table for k-v pairs.
        LOAD_CONSTANT "item1"   -- Pushes a list item onto the value stack.
        -- ... TAG_KEY + TABLE_SET_ACC for key-value pairs ...
        CONCAT_TABLE            -- Pops "item1", merges with the k-v table.
        ```

3.  **Text Coercion:** `CHECK_IS_TEXT` ensures the stack top can participate in text concatenation. It converts `empty` to `""`, numbers to localized strings, and booleans to their string form. Tables with a `tostring` metafield trigger a meta-macro call; other types raise an error.

### 4. Data Transfer: LOAD/STORE Opcodes

Data is moved between stacks and the constant table using `LOAD_*` and `STORE_*` opcodes.

*   `LOAD_CONSTANT`: Pushes a value from the constant pool (literals, native functions) onto the value stack.
*   `LOAD_LOCAL` / `STORE_LOCAL`: Accesses a variable in the current scope or a parent scope. `arg1` is the scope offset (0 = current, 1 = parent, etc.); `arg2` is the variable offset within that scope.
*   `LOAD_REF` / `STORE_REF`: Reads or writes a value in the current accumulation table by key. The key is popped from the value stack; the position is found by scanning the tag stack for the matching key.
*   `LOAD_TRUE` / `LOAD_FALSE` / `LOAD_EMPTY`: Push literal boolean or empty values.
*   `STORE_VOID`: Pops and discards the stack top, used to discard expression results.

```bytecode
-- `let new_var = old_var`
LOAD_LOCAL 0 old_var   -- Pushes `old_var`'s value from Variable Stack to Value Stack.
STORE_LOCAL 0 new_var  -- Pops value from Value Stack and stores it in `new_var`'s slot.
```

### 5. Macro Calls

#### Bytecode Layout Convention

By convention, **the first element of any compiled bytecode unit (index 1) is always a `CONCAT_CALL` opcode**. This is used to launch a macro via a recursive call: you push the macro onto the stack, then call `run` starting at `ip = 1`. The `CONCAT_CALL` at position 1 will then invoke that macro.

The VM does not hardcode this convention. Instead, it reads `vm.plume.sops.CONCAT_CALL` to discover the opcode address at runtime.

#### Standard Invocation

Standard calls (`$m()`) and block calls (`@m ... end`) generate similar bytecode.

1.  **Argument Preparation:** Arguments are prepared on the value stack as if for a `TABLE` accumulation (positional items + tagged key-value items).
2.  **Invocation:** The macro object itself is pushed, followed by `CONCAT_CALL`.
3.  **Execution (`CONCAT_CALL`):** This opcode dispatches on the type of the callable:
    *   **`macro`**: Creates a new scope via `ENTER_SCOPE`, distributes arguments into local variable slots via `_CONCAT_TABLE`, saves the return address on `macroStack`, and jumps to the macro body.
    *   **`closure`**: Same as macro, but also pushes the closure's captured upvalue table onto `closureStack`.
    *   **`luaMacro`**: Concatenates arguments into a Plume table, calls the Lua function directly, and pushes the result.
    *   **`stdMacro`**: Concatenates arguments, validates argument count, and injects the dedicated opcode (e.g., `STD_LEN`).
    *   **`context`**: Evaluates the context variable's current value.
    *   **Tables with `call` or `validate` metafields**: Redirects to the metafield macro.

**Default Argument Handling:** Default values are evaluated inside the macro body only if an argument was not provided (i.e., the slot still holds `empty`).

```bytecode
-- For `macro fn(arg: 1 + 2)`, where `arg` is the first local variable.
-- Start of macro body:
LOAD_LOCAL 0 1                -- Load the received value for `arg`.
JUMP_IF_NOT_EMPTY :end_default -- If not empty, a value was passed. Skip default.

-- Default value calculation:
LOAD_CONSTANT 1
LOAD_CONSTANT 2
OP_ADD
STORE_LOCAL 0 1               -- Store the result in `arg`.
:end_default
-- ... rest of macro code ...
```

### 6. Control Flow & Operations

*   **Jumps:** Control flow is standard. `JUMP` is unconditional. `JUMP_IF_NOT` pops a value and jumps if it is falsy (false or empty). `JUMP_IF` pops and jumps if truthy. `JUMP_IF_PEEK` / `JUMP_IF_NOT_PEEK` peek without popping. `JUMP_IF_EMPTY` / `JUMP_IF_NOT_EMPTY` test specifically for the `empty` value.
*   **ALU Operations:** Standard stack machine arithmetic. Operands are pushed, and an opcode like `OP_ADD` pops them, performs the calculation, and pushes the result. The VM provides `OP_ADD`, `OP_SUB`, `OP_MUL`, `OP_DIV`, `OP_MOD`, `OP_POW`, `OP_NEG` for arithmetic; `OP_AND`, `OP_OR`, `OP_NOT` for boolean; `OP_LT` for `<` and `OP_EQ` for `==`. There is no `OP_GT`; `a > b` is compiled as `b < a`.

```bytecode
-- `if x > 0 ...`  is compiled as `if 0 < x ...`
LOAD_CONSTANT 0
LOAD_LOCAL x
OP_LT               -- Pops 0 and x, pushes (0 < x).
JUMP_IF_NOT :else   -- Jumps if result is false.
```

If operands are not numbers, the VM attempts conversion via `tonumber` or a `tonumber` metafield. If that fails, it looks for a meta-macro named after the operator (e.g., `add`, `lt`, `minus`) on the operand's table, including reversed-operand variants (`addl`, `addr`).

### 7. Upvalues and Closures

Closures capture variables from their defining scope that would otherwise be lost when the scope closes.

*   **`OPEN_UPVALUE`**: Registers a local variable slot in `upvalueMap` by its absolute offset, marking it as capturable.
*   **`CLOSE_UPVALUE`**: Freezes an open upvalue by copying the variable's current value into a cell; the upvalue now references the cell instead of the live stack.
*   **`OPEN_REF_UPVALUE` / `CLOSE_REF_UPVALUE`**: Variants for *reference upvalues* — upvalues that capture a table field by key rather than a local variable. The key is popped from the stack; the reference is resolved when the table is created.
*   **`LOAD_UPVALUE` / `STORE_UPVALUE`**: Read or write through the upvalue cell stored in the current closure's upvalue table on `closureStack`. `arg2` indexes into that table.
*   **`CLOSURE`**: Creates a closure object from a macro reference on the stack top, binding the appropriate upvalue cells (by parent offset, ref key, or local offset).

### 8. Context Variables

Context variables are scoped, dynamically-bindable values.

*   **`PUSH_CONTEXT`**: Pops a table from the value stack where each key is a context variable and each value is the temporary binding. Pushes each variable's current value onto a cache stack, then updates the variable.
*   **`POP_CONTEXT`**: Restores all context variables from the cache stack to their previous values.

### 9. Iteration

Iteration is built around a three-local-variable protocol: an object, a state, and a flag.

*   **`GET_ITER`**: Pops an iterable from the value stack and pushes the iterator triple (flag, state, value). Tables use a built-in sequence iterator; objects with a `next` or `iter` metafield use custom iteration.
*   **`FOR_ITER`**: Advances the iterator by one step. If the result is `empty`, jumps past the loop body. Otherwise pushes the next value. Supports five iteration modes: `ITER_TABLE` (sequence), `ITER_SEQ` (arithmetic range), `ITER_ITEMS` (key-value pairs), `ITER_ENUMS` (index-value pairs), and `ITER_CUSTOM` (metafield-driven).
*   **`JUMP_FOR`**: Used after a custom iterator's `next` meta-macro call. If the result is falsy, pops it and jumps to the loop end; otherwise leaves the value on the stack for the loop body.

### 10. Table Operations

*   **`TABLE_INDEX`**: Pops a table and key, pushes `table[key]`. In safe mode (`arg1=1`), returns `empty` if the key is missing; otherwise raises an error. String, number, and empty values are redirected to their respective standard library tables.
*   **`TABLE_SET`**: Pops table, key, and value, and sets `table[key] = value`. Respects `readonly` and `setindex` metafields. `arg1=1` reverses the pop order for internal use after a `setindex` meta-macro call.
*   **`TABLE_SET_META`**: Sets a metafield on a table (pops table, key, value).
*   **`TABLE_EXPAND`**: Pops a table and pushes all its list items onto the value stack, followed by its hash items tagged with `TAG_KEY`.
*   **`CALL_INDEX_REGISTER_SELF`**: Inserts `self` (the table) into the call arguments, used for method-style calls like `$t.method(...)`.
*   **`TABLE_CUSTOM_FIELD`**: Sets a custom field (from the constant pool) on the table at stack top, without popping.

### 11. Stack Manipulation

*   **`SWITCH`**: Swaps the two top values on the value stack.
*   **`DUPLICATE`**: Pushes a copy of the current stack top.

### 12. Standard Library Opcodes

Some standard library functions are implemented as dedicated opcodes rather than `luaMacro` calls:

*   **`STD_LEN`**: Returns the length of a table or string.
*   **`STD_TYPE`**: Returns the type name of a value.
*   **`STD_SEQ`**: Creates an arithmetic sequence iterator (start, stop, step).
*   **`STD_ITEMS`**: Creates a key-value iterator over a table.
*   **`STD_ENUMERATE`**: Creates an index-value iterator over a table.
*   **`STD_IMPORT`**: Imports and executes another Plume file, managing the file stack and parameter distribution.

### 13. Error Handling

*   **`RAISE`**: Pops a message from the value stack and raises a runtime error.
*   **Safe calls**: `CONCAT_CALL` with `arg2=1` wraps the call in a safe mode. If the call (or any nested call) errors, the error is caught, the callstack is unwound to the safe call boundary, and a table `{success: false, result: msg}` is pushed instead.

### 14. Instruction Injection

The injection stack allows the VM to queue opcodes that execute before the next bytecode instruction. This mechanism is used when a single source-level operation requires multiple VM steps — for example, dispatching to a meta-macro and then processing its result.

*   `_INJECTION_PUSH`: Queues an opcode (with its arguments) tagged with the current `macroStack` depth.
*   `_CAN_INJECT`: Returns true if the injection stack is non-empty and the top entry's depth matches the current `macroStack` depth, ensuring injections execute within the correct macro context.

### 15. Instruction Format

Each bytecode instruction is a 32-bit word:
*   **OP** (7 bits): Opcode identifier.
*   **ARG1** (5 bits): First argument (scope offset, flags, etc.).
*   **ARG2** (20 bits): Second argument (jump offset, constant index, variable index, etc.).

The VM decodes instructions via bit operations and dispatches through a generated binary search tree for O(log n) opcode lookup.

---
## Opcode Reference

### vm/acc.lua

#### BEGIN_ACC
<br>Create a new accumulation frame 

#### CONCAT_TEXT
<br>Concatenate all values in the current frame into a single fragment. <br>Pops every value down to the frame marker, concatenates them, and pushes the result. <br>Small, flat sequences of strings/numbers are optimized via direct `table.concat`; larger or nested sequences produce a *fragment* (a lazy array of parts). 

#### FORCE_FRAGMENT
<br>Recursively flatten a fragment on stack top into a single string. <br>If the value is not a fragment, does nothing. 

#### CONCAT_TABLE
<br>Make a table from elements of the current frame <br>Unstack all element in current frame, remove the last frame. <br>Make a new table <br>First unstacked element must be a table, containing in order key, value, ismeta to insert in the new table <br>All following elements are appended to the new table. 

#### CHECK_IS_TEXT
<br>Check if stack top can be concatened <br>Get stack top. If neither empty, number or string, try to convert it, else throw an error. 

### vm/alu.lua

#### _BIN_OP_NUMBER
<br>Unstack 2 value, apply an operation, stack the result. <br>Try to convert values to number. <br>If cannot, try to call meta macro based on operator name 
- **op** *(function)*: Operation to apply
- **name** *(string)*: Name used to find meta macro and debug messages

#### OP_ADD
<br>Add two stack top value and stack the result based on `_BIN_OP_NUMBER`. 

#### OP_MUL
<br>Multiply two stack top value and stack the result based on `_BIN_OP_NUMBER`. 

#### OP_SUB
<br>Substract two stack top value and stack the result based on `_BIN_OP_NUMBER`. 

#### OP_DIV
<br>Divide two stack top value and stack the result based on `_BIN_OP_NUMBER`. 

#### OP_MOD
<br>Take the modulo of stack top value and stack the result based on `_BIN_OP_NUMBER`. 

#### OP_POW
<br>Take the power of two stack top value and stack the result based on `_BIN_OP_NUMBER`. 

#### OP_NEG
<br>Give opposite of a value 

#### OP_AND
<br>Do boolean `and` between two stack top values based on `_BIN_OP_BOOL`. 

#### OP_OR
<br>Do boolean `or` between two stack top values based on `_BIN_OP_BOOL`. 

#### OP_NOT
<br>Do boolean `not` between stack top value based on `_BIN_OP_BOOL`. 

#### OP_LT
<br>Do comparison `<` between two stack top values based on `_BIN_OP_NUMBER`. 

#### OP_EQ
<br>Do comparison `==` between two values. <br>If both value are string representations of number, return the comparison between theses two numbers. 

### vm/call.lua

#### CONCAT_CALL
<br>Take the stack top to call, with all elements of the current frame as parameters. <br>Stack the call result (or empty if nil) <br>Handle macros and luaMacro 

#### RETURN
<br>Return from the current macro call. <br>Closes the macro scope, pops the closure stack, pops the callstack, and jumps back to the saved return address. 

### vm/closures.lua

#### OPEN_UPVALUE
<br>Register a local variable slot as an open upvalue by its absolute offset. <br>Future `CLOSURE` calls will bind the cell at this offset. 
- **arg2** *(local)*: offset

#### OPEN_REF_UPVALUE
<br>Pop a key from the stack and register a pending reference upvalue for it. <br>The reference is resolved to a table field when `CLOSE_REF_UPVALUE` runs. 

#### CLOSE_UPVALUE
<br>Freeze an open upvalue by copying the variable's current value into a cell. <br>The upvalue cell then references the cell instead of the live variable stack. 
- **arg2** *(local)*: offset

#### CLOSE_REF_UPVALUE
<br>Pop a key from the stack and resolve the matching reference upvalue. <br>Binds it to the table field at that key (stack top is the newly created table). 

#### LOAD_UPVALUE
<br>Push the value of an upvalue from the current closure's upvalue table. 
- **arg2** *(local)*: offset

#### STORE_UPVALUE
<br>Pop a value and store it into an upvalue cell in the current closure's upvalue table. 

#### CLOSURE
<br>Create a closure object from the macro reference on stack top. <br>Binds all declared upvalues (by parent offset, ref key, or local offset) into a new upvalue table. Replaces the macro with the closure on the stack. 

### vm/context.lua

#### PUSH_CONTEXT
<br>Pop a table of context-variable bindings from the stack. <br>For each key-value pair, pushes the variable's current value onto a cache stack and updates the variable to the new value. 

#### POP_CONTEXT
<br>Restore all context variables to their previous values by popping the cache stack filled by `PUSH_CONTEXT`. 

### vm/iter.lua

#### GET_ITER
<br>Pop 1 iterable object and push its iterator triple (flag, state, value). <br>If object has a meta field `next`, it's already an iterator, and will be returned as-is. <br>If object has a meta field `iter`, call it. <br>Else, push the default sequence iterator. <br>Raise an error if the object isn't a table. 

#### FOR_ITER
<br>Advance the iterator stored in local variables (obj, state, flag). <br>If the result is empty, jump to the loop end. <br>Otherwise, push the next value onto the value stack. 
- **arg2** *(number)*: Offset of the loop end

#### JUMP_FOR
<br>Check the result of a custom iterator's `next` meta-macro call. <br>If the value is falsy (false or empty), pop it and jump to the loop end. <br>Otherwise, leave the value on the stack for the loop body. 
- **arg2** *(jump)*: offset

### vm/jump.lua

#### JUMP
<br>Jump to a given instruction 
- **arg2** *(jump)*: offset

#### JUMP_IF_NOT
<br>Pop 1, and jump to a given instruction if falsy (false or empty) 
- **arg2** *(jump)*: offset

#### JUMP_IF
<br>Unstack 1, and jump to a given instruction if true 
- **arg2** *(jump)*: offset

#### JUMP_IF_PEEK
<br>Jump to a given instruction if stack top is true 
- **arg2** *(jump)*: offset

#### JUMP_IF_NOT_PEEK
<br>Jump to a given instruction if stack top is falsy (false or empty), without popping 
- **arg2** *(jump)*: offset

#### JUMP_IF_EMPTY
<br>Unstack 1, and jump to a given instruction if empty 
- **arg2** *(jump)*: offset

#### JUMP_IF_NOT_EMPTY
<br>Unstack 1, and jump to a given instruction if any different from empty 
- **arg2** *(jump)*: offset

### vm/load.lua

#### LOAD_CONSTANT
<br>Stack 1 from the constants table 
- **arg2** *(Constant)*: offset

#### LOAD_LOCAL
<br>Stack 1 variable value 
- **arg1** *(Scope)*: offset
- **arg2** *(Variable)*: offset

#### LOAD_REF
<br>Unstack 1, key <br>Stack 1, key value in target accumulator 
- **arg1** *(Scope)*: offset

#### LOAD_TRUE
<br>Stack 1, `true` 

#### LOAD_FALSE
<br>Stack 1, `false` 

#### LOAD_EMPTY
<br>Stack 1, `empty` 

### vm/others.lua

#### SWITCH
<br>Switch two top stack values 

#### DUPLICATE
<br>Stack 1 more top stack value 

### vm/scope.lua

#### ENTER_SCOPE
<br>Create a new frame and set all it's variable to empty 
- **arg1** *(number)*: Number of local variables already stacked
- **arg2** *(number)*: Number of local variables

#### LEAVE_SCOPE
<br>Close a frame 

#### RETURN_FILE
<br>Return from the current file execution. <br>Closes the file scope, pops the file stack and the callstack. <br>If the file stack is empty, signals program termination. <br>Otherwise jumps back to the caller and caches the result if applicable. 

#### FILE_INIT_PARAMS
<br>Distribute file parameters (saved by `STD_IMPORT`) into local variable slots. <br>Runs once at the start of file execution, then clears the parameter list. 

#### RAISE
<br>Pop a message from the stack and raise a runtime error. 

### vm/std.lua

#### STD_IMPORT
<br>Import and execute another Plume file. <br>Compiles (or retrieves cached) the file, distributes its parameters, pushes the fileID onto `fileStack`, and jumps to the file's code offset. <br>Results are cached by parameter identity for future imports. 

### vm/store.lua

#### STORE_LOCAL
<br>Set a local value <br>Unstack 1, the value to set 
- **arg1** *(frame)*: offset
- **arg2** *(variable)*: offset

#### STORE_VOID
<br>Unstack 1, do nothing with it. <br>Used to remove a value at stack top. 

#### STORE_REF
<br>Unstack 2, value, key <br>Stack 1, key value in target accumulator 
- **arg1** *(Scope)*: offset

### vm/table.lua

#### TABLE_NEW
<br>Create a new table, waiting CONCAT_TABLE or CALL 
- **arg1** *(number)*: Number of hash slot to allocate

#### TAG_KEY
<br>Mark the last element of the stack as a key 

#### TAG_META_KEY
<br>Mark the last element of the stack as a meta-key 

#### TABLE_SET_ACC
<br>Add a key to the current accumulation table (bottom of the current frame) <br>Unstack 2: a key, then a value 
- **arg2** *(number)*: 1 if the key should be registered as metafield

#### TABLE_SET_META
<br>Unstack 3, in order: table, key, value <br>Set the table.key to value 

#### TABLE_INDEX
<br>Index a table <br>Unstack 2, in order: table, key <br>Stack 1, `table[key]` 
- **arg1** *(number)*: 1 if "safe mode" (return empty if key not exit), 0 else (raise error if key not exist)

#### TABLE_INDEX_CHECK_IS_NIL
<br>Check the return value of a `getindex` meta-macro call. <br>If the result is empty, raise an error (the key was not found). 

#### CALL_INDEX_REGISTER_SELF
<br>The stack may be [(frame begin)| call arguments | index | table] <br>Insert self | table in the call arguments 

#### TABLE_SET
<br>Unstack 3, in order: table, key, value <br>Set the table.key to value 

#### TABLE_EXPAND
<br>Unstack 1: a table <br>Stack all list item <br>Put all hash item on the stack 

#### TABLE_CUSTOM_FIELD
<br>Set a custom field (from the constant pool) on the table at stack top. <br>The table is not popped. Used internally by the engine for table metadata. 
