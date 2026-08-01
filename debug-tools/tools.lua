--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function (plume)
	--- Lightweight wrapper: prints a header, the output of fn, then returns the
	--- footer line. Prints nothing and returns nil if fn produces no output.
	--- @param title string Section title
	--- @param fn function Produces the section content
	--- @return string|nil The footer line, or nil if the section was empty
	function plume.debug.wrap(title, fn)
		local buffer = {}
		local oldPrint = print
		print = function(...)
			local parts = {}
			for i = 1, select("#", ...) do
				parts[i] = tostring(select(i, ...))
			end
			table.insert(buffer, table.concat(parts, "\t"))
		end
		fn()
		print = oldPrint

		if #buffer > 0 then
			local line = "--- " .. title .. " ----"
			print(line)
			for _, v in ipairs(buffer) do
				print(v)
			end
			return string.rep("-", #line)
		end
	end

	--- Print a single stack, bottom to top, grouped by frames.
	--- Empty stacks print nothing.
	--- @param vm table The VM instance
	--- @param stack table The stack to display
	--- @param name string Display name of the stack
	function plume.debug.printStack(vm, stack, name)
		local pointer = stack.pointer or #stack
		if pointer == 0 then
			return
		end

		local frames = stack.frames
		local frameCount = frames and (frames.pointer or #frames) or 0

		local groups = {}
		local current = {}
		for i = 1, pointer do
			local isFrameStart = false
			if frames then
				for k = 2, frameCount do
					if frames[k] == i then
						isFrameStart = true
						break
					end
				end
			end
			if isFrameStart then
				table.insert(groups, current)
				current = {}
			end
			table.insert(current, plume.debug.repr(stack[i], 60))
		end
		table.insert(groups, current)

		local parts = {}
		for _, g in ipairs(groups) do
			table.insert(parts, "[" .. table.concat(g, ", ") .. "]")
		end
		print(string.format("%s: %s", name, table.concat(parts, " | ")))
	end

	--- Print the current VM state: ip, opcode, and jump/error if any.
	function plume.debug.printVMState(vm)
		local function instrStr(ip)
			local instr = vm.bytecode[ip]
			if not instr then
				return ""
			end
			local infos = plume.debug.getInstrInfos(instr, vm.runtime)
			return string.format("[%d] %s %d %d", ip, infos.name, infos.arg1, infos.arg2)
		end

		local line = instrStr(vm.ip)
		if vm.err then
			line = line .. string.format(" /!\\ [%d] %s", vm.errip or vm.ip, vm.err)
		end
		print(line)

		if vm.jump and vm.jump > 0 then
			print("-> " .. instrStr(vm.jump))
		end
	end

	--- Print the runtime callstack, innermost call first.
	function plume.debug.printCallstack(vm)
		local callstack = vm.runtime.callstack
		if not callstack or #callstack == 0 then
			return
		end
		for i = #callstack, 1, -1 do
			local call = callstack[i]
			local macro = call.macro
			local mtype = macro and macro.type or "???"
			local name  = macro and (macro.name or "???") or "???"
			local flags = {}
			if call.safe then table.insert(flags, "safe") end
			if call.base then table.insert(flags, "base=" .. call.base) end
			local flagStr = #flags > 0 and (" [" .. table.concat(flags, " ") .. "]") or ""
			print(string.format("  [%d] %s<%s> ip=%d%s", i, mtype, name, call.ip or 0, flagStr))
		end
	end

	--- Print the whole VM state, organized into filterable categories.
	--- @param vm table The VM instance
	--- @param filter nil|string|table Categories to display:
	---   "state", "stacks", "callstack". nil = all.
	function plume.debug.printVM(vm, filter)
		local stacksName = {
			"mainStack", "variableStack", "closureStack",
			"fileStack", "macroStack", "recursiveStack",
			"contextStackCache", "tagStack"
		}

		local order = { "state", "stacks", "callstack" }

		local categories = {
			state = function()
				return plume.debug.wrap("VMSTATE Instruction #" .. vm.tic, function()
					plume.debug.printVMState(vm)
				end)
			end,
			stacks = function()
				for _, name in ipairs(stacksName) do
					local stack = vm[name]
					if (stack.pointer or #stack) > 0 then
						plume.debug.printStack(vm, stack, name)
					end
				end
			end,
			callstack = function()
				if vm.runtime.callstack and #vm.runtime.callstack > 0 then
					plume.debug.printCallstack(vm)
				end
			end,
		}

		local selected = {}
		if filter == nil then
			for _, name in ipairs(order) do
				selected[name] = true
			end
		elseif type(filter) == "string" then
			if categories[filter] then
				selected[filter] = true
			end
		elseif type(filter) == "table" then
			for _, name in ipairs(filter) do
				if categories[name] then
					selected[name] = true
				end
			end
		end

		local footer
		for _, name in ipairs(order) do
			if selected[name] then
				local f = categories[name]()
				if f then
					footer = f
				end
			end
		end
		if footer then
			print(footer)
		end
	end

	--- Compile a Plume source string and print its bytecode, one instruction
	--- per line. Returns the bytecode grid (see bytecodeGrid) on success.
	--- @param code string The Plume source code
	--- @param filename string|nil Source name used for error messages
	--- @return boolean success
	--- @return table|string grid on success, error message on failure
	function plume.debug.decomp(code, filename)
		filename = filename or "<input>"

		local runtime = plume.obj.runtime()
		local chunk   = plume.obj.macro(filename, runtime)

		local success, result = pcall(plume.compileFile, code, filename, chunk, runtime, true)
		if not success then
			return false, result
		end

		local grid = plume.debug.bytecodeGrid(runtime)
		for i, row in ipairs(grid) do
			local line = string.format("[%d] %s %d %d", i, row[2], row[3], row[4])
			if row[5] and row[5] ~= "" then
				line = line .. "  -- " .. row[5]
			end
			print(line)
		end
		return true, grid
	end

	--- Build a report of the most used opcode sequences, sorted by count.
	--- Requires plume.runStatFlag to have been enabled during the run.
	--- @return string The report, or a message if statistics were not gathered
	function plume.debug.getOpcodeUsageReport()
		if not plume.runStatFlag then
			return "Turn on plume.runStatFlag to gather statistics about opcode usages."
		end
		local opsNames = plume.debug.invTable(plume.ops)
		local stats = {}
		local total = 0
		for k, v in pairs(plume.stats.opseq) do
			local ops = {}
			local zero = false
			for i=1, plume.runStatDeep do
				ops[plume.runStatDeep-i+1] = k%128
				k = math.floor(k/128)
				if k==0 then
					zero = true
				end
			end

			if not zero then
				for i, vv in ipairs(ops) do
					ops[i] = opsNames[vv]
				end

				total = total + v

				table.insert(stats, {count=v, names=ops})
			end
		end

		table.sort(stats, function(x, y) return x.count>y.count end)
		local report = {}

		for _, stat in ipairs(stats) do
			local pp = 100*stat.count/total
			if pp>1 then
				table.insert(report, string.format("%-50s %4i (%i%%)", table.concat(stat.names, " "), stat.count, pp))
			end
		end

		return table.concat(report, "\n")
	end
end
