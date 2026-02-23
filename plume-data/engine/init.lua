--[[
Plume🪶 1.0.beta.8
Copyright (C) 2024-2026 Erwan Barbedor

Check https://github.com/PlumeScript/Plume
for documentation, tutorials, or to report issues.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3 of the License.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <https://www.gnu.org/licenses/>.
]]

local plume = {}

require 'plume-data/engine/debug_tools' (plume)
require 'plume-data/engine/error'         (plume)
require 'plume-data/engine/errorMessages' (plume)
require 'plume-data/engine/warning'       (plume)
require 'plume-data/engine/utils'         (plume)
require 'plume-data/engine/objects'       (plume)
require 'plume-data/engine/std'           (plume)
require 'plume-data/engine/parser'        (plume)
require 'plume-data/engine/compiler/core' (plume)
require 'plume-data/engine/engine'        (plume)
require 'plume-data/engine/engine-opt'    (plume)
require 'plume-data/engine/finalizer'     (plume)
require 'plume-data/engine/pec'           (plume)
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
	plume.lastErrorInfos = nil
	plume.warning.cache = {}
	plume.warning.mode = {default="normal"}

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

function plume.executeFile(filename, runtime, fileParams)
	local runtime = runtime or plume.obj.runtime()
	local chunk   = plume.obj.macro(filename, runtime)

	local f = io.open(filename)
		if not f then
			error("The file '" .. filename .. "' don't exist or isn't readable.")
		end

		local code = f:read("*a")
	f:close()

	local success, result = plume.execute(code, filename, chunk, runtime, fileParams)
	if success then
		plume.error.showWarnings()
	end
	return success, result
end

plume.hook = nil -- A function call at each step of the vm

return plume