--[[This file is part of Plume

Plume🪶 is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3 of the License.

Plume🪶 is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with Plume🪶.
If not, see <https://www.gnu.org/licenses/>.
]]

return function (plume, context, nodeHandlerTable)
	local function getRawValue(node, name, paramName, isImport)
		local value = node.code:sub(node.bpos, node.epos)
		plume.ast.browse(node, function(child)
			if child.name ~= "TEXT" then
				plume.error.useDoesNotAcceptDynamicArgs(child, name, paramName, value, isImport)
			end
		end, 2)
		return value
	end

	--- `use` directive execute a file that must return a table,
	--- and load all keys as constants into the current file scope
	nodeHandlerTable.USE_LIB = function(node)
		local pathNode = plume.ast.get(node, "NAME")
		local path = pathNode.content

		local fileParams = {}
		for _, param in ipairs(plume.ast.getAll(node, "USE_OPTION")) do
			local keyNode = plume.ast.get(param, "KEY")
			local valueNode = plume.ast.get(param, "VALUE")
			local key = keyNode and keyNode.content
			local value = getRawValue(valueNode, path, key, true)

			if key then
				fileParams[key] = value
			end
		end

		-- Same path resolver as `import`
		local filename, searchPaths = plume.getFilenameFromPath(path, false, context.runtime, context.chunk.name, context.chunk.name )
		if not filename then
            plume.error.compilationCannotOpenFile(pathNode, path, searchPaths)
		end

		local success, result = plume.executeFile(filename, context.runtime, fileParams)
        if not success then
            plume.error.cannotExecuteFile(pathNode, path, result)
        end

        local t = type(result) == "table" and result.type or type(result)
        if t ~= "table" then
        	plume.error.fileMustReturnATable(pathNode, path, t)
        end

        for _, key in ipairs(result.keys) do
			if context.scopes[#context.scopes][key] then
				plume.error.useExistingVariable(pathNode, key, path)
			end
			context.importedVariables[key] = result.table[key]
        end

        return result
	end

	local directivesHandler = {
		warning = function (args)
			local mode = args.mode or "normal"
			local filters = {}

			if args.issues then
				for issue in args.issues:gmatch('[0-9]+') do
					table.insert(filters, issue)
				end
			end

			if #filters == 0 then
				plume.warning.mode.default = mode
			else
				for _, x in ipairs(filters) do
					plume.warning.mode[x] = mode
				end
			end
		end,

		context = function(args)
			for name, value in pairs(args) do
				context.contextVariableToClose = context.contextVariableToClose + 1
				context.registerOP(node, plume.ops.LOAD_CONSTANT, 0, context.registerConstant(name))
				context.registerOP(node, plume.ops.LOAD_CONSTANT, 0, context.registerConstant(value))
				context.registerOP(node, plume.ops.PUSH_CONTEXT)
			end
		end
	}

	--- `use #name-optn-optn`
	nodeHandlerTable.USE_DIRECTIVE = function(node)
		local directiveNameNode = plume.ast.get(node, "NAME")
		local directiveName = directiveNameNode.content
		local options = {}
		for _, option in ipairs(plume.ast.getAll(node, "USE_OPTION")) do
			local keyNode = plume.ast.get(option, "KEY")
			local valueNode = plume.ast.get(option, "VALUE")
			local key = keyNode and keyNode.content
			local value = getRawValue(valueNode)

			if key then
				options[key] = value
			else
				table.insert(option, value)
			end
		end
		
		local handler = directivesHandler[directiveName]
		if not handler then
			plume.error.unknownDirective(directiveNameNode, directiveName)
		end
		handler(options)
	end
end