--[[
Plume🪶 b59 (Owl Edition)

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
plume.VERSION = "b59 (Owl Edition)"

require 'plume-data/engine/debug/core'           (plume)
require 'plume-data/engine/error/core'           (plume)
require 'plume-data/engine/warning'              (plume)
require 'plume-data/engine/utils'                (plume)
require 'plume-data/engine/ast'                  (plume)
require 'plume-data/engine/objects'              (plume)

require 'plume-data/engine/parser'               (plume)
require 'plume-data/engine/compiler/core'        (plume)
require 'plume-data/engine/generated/std'        (plume)
require 'plume-data/engine/generated/stddoc'     (plume)
require 'plume-data/engine/generated/engine'     (plume)
require 'plume-data/engine/generated/engine-opt' (plume)
require 'plume-data/engine/finalizer'            (plume)
require 'plume-data/engine/config'               (plume)
require 'plume-data/engine/profiler'             (plume)

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

	return plume.safeRun(run, runtime, chunk, fileParams)
end

function plume.execute(code, filename, chunk, runtime, fileParams, isMain)
	local success, result, ip
	success, result = pcall(plume.compileFile, code, filename, chunk, runtime, isMain)
	
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
		plume.futureStringFlag = args.futureStringFlag
	end

	runtime = runtime or plume.obj.runtime()
	local chunk   = plume.obj.macro(filename, runtime)

	local success, result = plume.execute(code, filename, chunk, runtime, fileParams, isMain)
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