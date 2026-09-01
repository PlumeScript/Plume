# Plume Debug Tools

Debug/profiling tools for the Plume VM. They are **not** part of the Plume runtime:
they must be imported manually in a Lua script (see [Loading](#loading)).

---

## Loading

```lua
local plume = require "plume-data/engine/init"
require "debug-tools/core" (plume)   -- defines plume.debug.*
```

`debug-tools/core.lua` loads `utils`, `run`, `tools` and exposes everything under `plume.debug`.

---

## CLI (`plume-debug.bat`)

```
plume-debug <action> <srcfile>
```

The CLI runs with the system `luajit` from the PATH.

| Action | Description |
|--------|-------------|
| `decomp <srcfile>` | Disassembles the bytecode (one instruction per line, with source mapping). |
| `hotspots <srcfile>` | Runs the program and prints the source lines sorted by number of executed instructions (hotspots). |
| `opusage1..X <srcfile>` | Runs the program in devmode and prints the most used opcode sequences, sorted by occurrence. `X` = sequence depth (e.g. `opusage3` = triplets). |
| `profile-quick <srcfile>` | Statistical JIT profile: % of time in compiled code, top 5 hot lines, and JIT NYI aborts. **Requires a LuaJIT build with a working `jit.profile`.** |
| `profile <srcfile>` | Full JIT profile: JIT health, all hot lines, and the JIT traces (from `jit.dump`, IR + machine code) sorted by hotness, each with status, abort reason, source snippet and full dump. Two passes (clean timing + trace capture). Also requires a LuaJIT build with a working `jit.profile`. |

---

## Functions (`plume.debug.*`)

### utils.lua
| Function | Description |
|----------|-------------|
| `escapeString(s, maxlength)` | Compact representation of a value (escapes `\n`/`\t`, truncates). |
| `invTable(t)` | Inverts a table (keys ↔ values). |
| `bytecodeGrid(runtime)` | Bytecode grid: `{raw, name, arg1, arg2, source}` per ip. |
| `printAST(node, indent)` | Prints the AST tree (recursive). |
| `repr(obj, maxlength)` | Compact single-line representation of a value. |
| `getInstrInfos(instr, runtime)` | Decodes an instruction into `{op, name, arg1, arg2, value}`. |

### tools.lua
| Function | Description |
|----------|-------------|
| `wrap(title, fn)` | Prints a section with header/footer, if `fn` produces output. |
| `printStack(vm, stack, name)` | Prints a stack, grouped by frames. |
| `printVMState(vm)` | Prints the current state: ip, opcode, jump/error. |
| `printCallstack(vm)` | Prints the runtime callstack (innermost call first). |
| `printVM(vm, filter)` | Prints the full VM state, filterable (`"state"`, `"stacks"`, `"callstack"`). |
| `decomp(code, filename)` | Compiles a source and prints its bytecode. |
| `getOpcodeUsageReport()` | Report of the most used opcode sequences (sorted). |

### run.lua
| Function | Description |
|----------|-------------|
| `executeFile(input, output, isMain)` | HTML execution trace (AST + bytecode + stacks + error), written to `output.html`. |

### profile.lua
| Function | Description |
|----------|-------------|
| `profileQuick(srcfile)` | Statistical JIT profile of a program: % of time in compiled code (vmstate distribution), top 5 hot lines (via `jit.profile` + `dumpstack`), and JIT NYI aborts (via `jit.attach`). Returns the report string. |
| `profileFull(srcfile)` | Full JIT profile: JIT health, all hot lines, and the JIT traces (from `jit.dump`, IR + machine code) sorted by hotness of their root line, each with status, abort reason, source snippet and full dump. Two passes: clean timing (`jit.profile`) + trace capture (`jit.dump` + `jit.attach`). Returns the report string. |

---

## Flags

| Flag | Description |
|------|-------------|
| `plume.runStatFlag` | Enables statistics collection (forces devmode). Required for `opusage` and `hotspots`. |
| `plume.runStatDeep` | Depth of the counted opcode sequences (default 1). |
| `plume.runDevFlag` | Forces the dev VM (`_run_dev`) instead of the opt VM. |
| `plume.hook` | Function called at each VM instruction (used by the HTML trace). |

Statistics are collected in `vm.stats` (devmode only):
- `vm.stats.opseq` — opcode sequence counter (key = encoded sequence)
- `vm.stats.ipcount` — instruction counter per ip (used by `hotspots`)
