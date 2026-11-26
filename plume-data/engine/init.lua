--[[
Plume🪶 b67 (Raven Edition)

Copyright © 2024-2026 Erwan Barbedor

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

]]

if _VERSION == "Lua 5.4" then
	require 'plume-data/compat/wasmoon/init'
else
	require 'plume-data/compat/baseline/init'
end

local plume = {}
plume.VERSION = "b67 (Raven Edition)"

require 'plume-data/engine/error/core'    (plume)
require 'plume-data/engine/warning'       (plume)
require 'plume-data/engine/utils'         (plume)
require 'plume-data/engine/ast'           (plume)
require 'plume-data/engine/escapes'       (plume)
require 'plume-data/engine/objects/core'  (plume)
require 'plume-data/engine/parser'        (plume)
require 'plume-data/engine/compiler/core' (plume)
require 'plume-data/generated/std'        (plume)
require 'plume-data/generated/stddoc'     (plume)
require 'plume-data/generated/engine'     (plume)
require 'plume-data/generated/engine-opt' (plume)
require 'plume-data/generated/vmloaders'  (plume)
require 'plume-data/engine/finalizer'     (plume)
require 'plume-data/engine/config'        (plume)

function plume.run(runtime, chunk, fileParams)
	if plume.runStatFlag then
		plume.runDevFlag = true
		plume.runStatDeep = plume.runStatDeep or 1
	end

	local run
	if plume.runDevFlag then
		run = plume._run_dev
	else
		run = plume._run
	end

	runtime.vm = runtime.vm or plume.obj.vm(runtime)
	local success, result, errip = runtime.vm:initFileParams(chunk, fileParams and plume.obj.quickTable(fileParams))
	if not success then
		return false, result, errip
	end

	local vm = runtime.vm
	vm:_STACK_PUSH(vm.fileStack, chunk.fileID)

	-- A direct run nested in an ongoing run (a `use`/`eval` inside an import
	-- or a macro call) is not launched by _RUN_START, so it owns no entry of
	-- its own on the recursiveStack and the callstack. Without its own
	-- entries, its END would pop the caller entry of the enclosing
	-- _RUN_START and its RETURN_FILE would pop the enclosing run's callinfo,
	-- desyncing the enclosing run (the nested `use` crash, issue #1304).
	-- Push the caller ip (vm.ip), exactly like _RUN_START and the `eval` std
	-- do, so its END restores it — including the sops-ip end-jump
	-- propagation when the run is a safe-run boundary (issue #1291) — and
	-- push a callinfo for RETURN_FILE to pop. A top-level direct run owns
	-- the VM exclusively: it pushes nothing, exactly like before.
	-- The enclosing run may itself be a top-level direct run, which never
	-- pushes on the recursiveStack — the reliable "a run is in progress"
	-- flag is vm.running, set for the whole run below (issue #1305).
	local nested = vm.running or vm:_STACK_POS(vm.recursiveStack) > 0
	local savedIp, savedJump
	if nested then
		vm:_STACK_PUSH(vm.recursiveStack, vm.ip)
		table.insert(vm.runtime.callstack, {
			runtime = runtime,
			macro   = chunk,
			ip      = chunk.offset,
			safe    = false,
			directRun = true
		})
		savedIp = vm.ip
		savedJump = vm.jump
	end

	-- A fresh run always starts with a clean jump: a pending end-jump is the
	-- termination signal of a previous run (a nested direct run whose END
	-- propagated it through a sops caller ip), and _VM_TICK would consume it
	-- on this run's first instruction, dispatching to the wrong opcode
	-- (see the nested `use` crash, issue #1304).
	vm.jump = 0

	local wasRunning = vm.running
	vm.running = true
	local runSuccess, runResult, runIp = plume.safeRun(run, vm, chunk.offset)
	vm.running = wasRunning

	if nested and not runSuccess then
		-- Defensive cleanup: on a hard VM crash, END and RETURN_FILE never
		-- ran, so pop the entries pushed above to leave the enclosing run
		-- as we found it. On success, END and RETURN_FILE already popped
		-- them, and _RUN_END restored the ip/jump the way the caller
		-- expects, so do nothing. (The mainStack is not restored: the run
		-- deliberately leaves its result there, consumed by the caller.)
		if vm.recursiveStack.pointer > 0
			and vm.recursiveStack[vm.recursiveStack.pointer] == savedIp then
			vm.recursiveStack.pointer = vm.recursiveStack.pointer - 1
		end
		local callstack = vm.runtime.callstack
		if callstack[#callstack] and callstack[#callstack].directRun then
			table.remove(callstack)
		end
		vm.ip = savedIp
		vm.jump = savedJump
	end

	return runSuccess, runResult, runIp
end

function plume.execute(code, filename, chunk, runtime, fileParams, isMain, args)
	local success, result, ip
	success, result = pcall(plume.compileFile, code, filename, chunk, runtime, isMain, args)
	
	if success then
		success, result, ip = plume.run(runtime, chunk, fileParams)
	else
		return false, result
	end

	if success then
		return true, result
	else
		result = plume.error.makeRuntimeError(runtime, ip, result)
		return false, result
	end
end

function plume.executeString(code, filename, runtime, fileParams, args, isMain)
	-- Should be associated with a runtime
	if args then
		plume.config = plume.config or {}
		plume.config.errorStyle = args.errorStyle
		plume.config.color = args.color
	end

	runtime = runtime or plume.obj.runtime()
	local chunk   = plume.obj.macro(filename, runtime)

	local success, result = plume.execute(code, filename, chunk, runtime, fileParams, isMain, args)
	if success and isMain then
		plume.error.showWarnings()
	end
	return success, result
end

function plume.executeFile(filename, runtime, fileParams, args, isMain)
	filename = plume.normalizePath(filename)

	if not futf8.exists(filename) then
		return false, "Error: the file '" .. filename .. "' don't exist or isn't readable."
	end

	local code = futf8.read(filename)

	return plume.executeString(code, filename, runtime, fileParams, args, isMain)
end

plume.hook = nil -- A function call at each step of the vm

return plume