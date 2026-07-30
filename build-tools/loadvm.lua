--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]



local lfs = require "lfs"
local path = "plume-data/engine/vm"
local Parser = require "parser"
local fpattern = 
	"\n%s*([^\n]-)" ..
	"\n\tfunction vm:([a-zA-Z_0-9]+)%(([^%)]*)%)" ..
	"(.-)" ..
	"\n\tend"


local function loadvmfile(file, functionsToInline, usedInlinedFunctions)
	local r = io.open(file)
		local code = r:read('*a')
	r:close()

	for header, name, args, body in code:gmatch(fpattern) do
		local directive = header:match('%-%-! (.*)')
		local inline = directive and directive:match('inline')

		local optns = {}
		if inline then
			local optn = directive:match('inline(.*)')
			
			for k in optn:gmatch('[^-]+') do
				optns[k] = true
			end
		end
				

		-- Duplication of some luaOptimizer logic
		body = body:gsub('%-%-! to%-remove%-begin.-%-%-! to%-remove%-end', '')
		body = body:gsub('[^\n]+%-%-! to%-remove', '')
		body = body:gsub('%-%-! to%-add ([^\n]+)', '%1')


		body = body:gsub('%-%-! save%-scalar', '_temp_save_scalar()')
		body = body:gsub('%-%-! update%-scalar', '_temp_update_scalar()')

		for command in body:gmatch('%-%-! ([^\n]*)') do
			if not command:match("^inline") and not command:match("^index%-to%-inline") then
				print("Error: unknown command '" .. command .. "'.")
			end
		end

		local fdef = "function (" .. args .. ")" .. body .. "\nend" 

		local parsed, err = Parser.parse(fdef, file, '5.2', true)
		if err then
			print("Cannot load " .. name)
			print("Code:")
			print('--------')
			print(fdef)
			print('--------')
			print('Error: ' .. err)
			os.exit(0)
		end
		local parsedFunction = parsed[1]
		---------------------------------------

		-- respect luaOptimizer convention
		functionsToInline[name] = {
			optn    = optns,
			body    = parsedFunction,
			params  = parsedFunction.args,
			inline  = inline
		}


		usedInlinedFunctions[name] = false
	end
end

local function loadvm()
	local functionsToInline    = {}
	local usedInlinedFunctions = {}
	for file in lfs.dir(path) do
		if not file:match('^%.+$') then
			loadvmfile(path .. "/" ..file, functionsToInline, usedInlinedFunctions)
		end
	end
	return functionsToInline, usedInlinedFunctions
end



return loadvm