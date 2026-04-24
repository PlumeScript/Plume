--[[
Plume🪶 b46 (Sparrow Edition)

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

local plume = {}
plume._VERSION = "b45 (Sparrow Edition)"

require 'plume-data/engine/debug/core'    (plume)
require 'plume-data/engine/error/core'    (plume)
require 'plume-data/engine/warning'       (plume)
require 'plume-data/engine/utils'         (plume)
require 'plume-data/engine/objects'       (plume)
require 'plume-data/engine/std/core'      (plume)
require 'plume-data/engine/parser'        (plume)
require 'plume-data/engine/compiler/core' (plume)
require 'plume-data/engine/engine'        (plume)
require 'plume-data/engine/engine-opt'    (plume)
require 'plume-data/engine/finalizer'     (plume)
require 'plume-data/engine/config'        (plume)
require 'plume-data/engine/profiler'      (plume)

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

function plume.execute(code, filename, chunk, runtime, fileParams)
	local success, result, ip
	success, result = pcall(plume.compileFile, code, filename, chunk, runtime)

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

function plume.executeString(code, filename, runtime, fileParams, args)
	-- Should be associated with a runtime
	if args then
		plume.config = plume.config or {}
		plume.config.errorStyle = args.errorStyle
		plume.config.color = args.color
	end

	local runtime = runtime or plume.obj.runtime()
	local chunk   = plume.obj.macro(filename, runtime)

	local success, result = plume.execute(code, filename, chunk, runtime, fileParams)
	if success then
		plume.error.showWarnings()
	end
	return success, result
end

function plume.executeFile(filename, runtime, fileParams, args)
	filename = plume.normalizePath(filename)

	local f = io.open(filename)
		if not f then
			return false, "Error: the file '" .. filename .. "' don't exist or isn't readable."
		end

		local code = f:read("*a")
	f:close()

	return plume.executeString(code, filename, runtime, fileParams, args)
end

plume.hook = nil -- A function call at each step of the vm

return plume