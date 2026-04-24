--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function (plume, context, nodeHandlerTable)
	local function getRawValue(node, name, paramName, isImport)
		local value = {}
		plume.ast.browse(node, function(child)
			if child.name == "TEXT" then
				table.insert(value, child.content)
			else
				plume.error.useDoesNotAcceptDynamicArgs(child, name, paramName, node.code:sub(node.bpos, node.epos), isImport)
			end
		end, 2)
		return table.concat(value)
	end

	--- `use` directive execute a file that must return a table,
	--- and load all keys as constants into the current file scope
	nodeHandlerTable.USE_LIB = function(node)
		local pathNode = plume.ast.get(node, "NAME")
		local path = pathNode.content:gsub('^%s*', ''):gsub('%s*$', '')

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

		-- Prevent cyclical import
		table.insert(plume.currentUseProcessing, filename)

		for i=1, #plume.currentUseProcessing-1 do
			if plume.currentUseProcessing[i] == filename then
				plume.error.cycleWithUse(pathNode, plume.currentUseProcessing)
			end
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

        table.remove(plume.currentUseProcessing)
        return result
	end

	local directivesHandler
	directivesHandler = {
		warning = {
			checkArgs = {
				mode   = {"normal", "ignore", "strict"},
				scope  = {"local", "global"},
				issues = "*"
			},
			method = function (node, args)
				local mode  = args.mode  or "normal"
				local scope = args.scope or "local"
				local filters = {}
	
				if args.issues then
					for issue in args.issues:gmatch('[0-9]+') do
						table.insert(filters, issue)
					end
				end

				if scope ~= "global" then
					scope = node.filename
				end

				if #filters == 0 then
					plume.warning.mode.default[scope] = mode
				else
					for _, x in ipairs(filters) do
						plume.warning.mode[x] = plume.warning.mode[x] or {}
						plume.warning.mode[x][scope] = mode
					end
				end
			end
		},

		devWarnings = {
			checkArgs = {
				mode  = {"normal", "ignore", "strict"},
				scope = {"local", "global"}
			},
			method = function(node, args)
				args.issues = "381"
				args.mode = args.mode or "normal"
				directivesHandler.warning.method(node, args)
			end
		},

		context = {
			method = function(node, args)
				for name, value in pairs(args) do
					context.contextVariableToClose = context.contextVariableToClose + 1
					context.registerOP(node, plume.ops.LOAD_CONSTANT, 0, context.registerConstant(name))
					context.registerOP(node, plume.ops.LOAD_CONSTANT, 0, context.registerConstant(tonumber(value) or value))
					context.registerOP(node, plume.ops.PUSH_CONTEXT)
				end
			end
		}
	}

	for _, handler in pairs(directivesHandler) do
		if handler.checkArgs then
			for name, values in pairs(handler.checkArgs) do
				if type(values) == "table" then
					for _, value in ipairs(values) do
						handler.checkArgs[name][value] = true
					end
				end
			end
		end
	end

	--- `use #name(...optns)`
	nodeHandlerTable.USE_DIRECTIVE = function(node)
		local directiveNameNode = plume.ast.get(node, "NAME")
		local directiveName = directiveNameNode.content
		local handler = directivesHandler[directiveName]
		if not handler then
			plume.error.unknownDirective(directiveNameNode, directiveName)
		end
		
		local options = {}
		for _, option in ipairs(plume.ast.getAll(node, "USE_OPTION")) do
			local keyNode = plume.ast.get(option, "KEY")
			local valueNode = plume.ast.get(option, "VALUE")
			local key = keyNode and keyNode.content

			local value = getRawValue(valueNode)

			if handler.checkArgs then
				if not handler.checkArgs[key] then
					plume.error.wrongDirectiveArgs(node, directiveName, key, handler.checkArgs)
				elseif (handler.checkArgs[key] ~= "*" and not handler.checkArgs[key][value]) then
					plume.error.wrongDirectiveArgsValue(node, directiveName, key, handler.checkArgs, value)
				end
			end

			
			if key then
				options[key] = value
			else
				table.insert(option, value)
			end
		end
		
		handler.method(node, options)
	end
end