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
			elseif child.name == "SPECIAL_TEXT" then
				table.insert(value, context.getSpecialText(child))
			else
				plume.error.useDoesNotAcceptDynamicArgs(child, name, paramName, node.code:sub(node.bpos, node.epos), isImport)
			end
		end, 2)
		return table.concat(value)
	end

	--- `use` directive execute a file that must return a table,
	--- and load all keys as constants into the current file scope
	local function useLib(node, pathNode, path, args)
		path = path:gsub('^%s*', ''):gsub('%s*$', '')

		local fileParams = {""} -- first slot always taken (why?)
		local fileParamsForCache = {}
		local posIndex = 1 -- 1 is for file path
		for _, param in ipairs(args) do
			local key   = param.name
			local value = param.value

			if key then
				if tonumber(key) then
					key = key + 1
				end
				fileParams[key] = value
				table.insert(fileParamsForCache, {key=key, value=value})
			end
		end

		-- Same path resolver as `import`
		local filename, searchPaths = plume.getFilenameFromPath(
			path,
			false,
			context.runtime,
			context.chunk.name,
			context.chunk.name
		)
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
		
		local cacheId = plume.getModuleCacheId(filename, fileParamsForCache)
        local result  = context.runtime.cache.results[cacheId]
        if not result then
			local success
			success, result = plume.executeFile(filename, context.runtime, fileParams)
			if not success then
				plume.error.cannotExecuteFile(pathNode, path, result)
			end
			context.runtime.cache.results[cacheId] = result
			-- clean stack
			local vm = context.runtime.vm
			vm:_STACK_POP(vm.mainStack)
		end

		local t = type(result) == "table" and result.type or type(result)
		if t ~= "table" then
			plume.error.fileMustReturnATable(pathNode, path, t)
		end

		for _, key in ipairs(result.keys) do
			if context.scopes[#context.scopes][key] then
				plume.error.useExistingVariable(pathNode, key, path)
			end
			if context.importedVariablesSource[key] then
				plume.warning.throwWarning(
					string.format(
						"'%s' declares a variable named '%s', shadowing that one imported from `%s`.",
						path,
						key,
						context.importedVariablesSource[key]
					),
					nil,
					pathNode, {381, 583}
				)
			end

			context.importedVariables[key] = result.table[key]
			context.importedVariablesSource[key] = path
		end

		table.remove(plume.currentUseProcessing)
		return result
	end

	local oldFlags = {
		Raven={"raven", "newEscape", "importCache", "return", "positionnalFileParam", "unknownParamError", "newLeave", "lineEval"}
	}
	local _oldFlags = {}
	
	context.directivesHandler = {
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
				context.directivesHandler.warning.method(node, args)
			end
		},

		context = {
			method = function(node, args)
				if node.parent.name ~= "FILE" then
					plume.error.useContextMustBeAtFileRoot(node)
				end

				context.contextVariableToClose = context.contextVariableToClose + 1
				context.registerOP(node, plume.ops.BEGIN_ACC)

				for name, value in pairs(args) do
					context.accBlock()(value)
					if type(name) == "table" then -- node
						context.childrenHandler(name)
					else -- key
						local var = context.runtime.plume.table[name]
						if not var then
							plume.error.wrongDirectiveArgs(node, "context", name)
						end
						context.registerOP(node, plume.ops.LOAD_CONSTANT, 0, context.registerConstant(var))
					end
					context.registerOP(node, plume.ops.TAG_KEY)
				end

				context.registerOP(node, plume.ops.CONCAT_TABLE)
				context.registerOP(node, plume.ops.PUSH_CONTEXT)
			end
		},

		rawNumbers = {
			method = function(node, args)
				for name, _ in pairs(args) do
					plume.error.wrongDirectiveArgs(node, "context", name)
				end
				context.chunk.flagRawNumbers = true
			end
		},

		future = {
			checkArgs = {
				all                  = {true}
			},
			method = function(node, args)
				for flag, _ in pairs(args) do
					if _oldFlags[flag] then
						plume.warning.throwWarning(
							string.format(
								"`%s` is a legacy flag and has had no effect since version `%s`.",
								flag, _oldFlags[flag]
							),
							"Consider removing it.", node, {988}
						)
					end
				end

				-- if args.NAME or args.EDITION or args.all then
				-- 	context.FLAG = true
				-- end
			end
		}
	}

	for edition, flags in pairs(oldFlags) do
		for _, flag in ipairs(flags) do
			_oldFlags[flag] = edition
			context.directivesHandler.future.checkArgs[flag] = {true}
		end
	end

	for _, handler in pairs(context.directivesHandler) do
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
	local function useDirective(node, directiveNameNode, directiveName, args)
		local handler = context.directivesHandler[directiveName]
		if not handler then
			plume.error.unknownDirective(directiveNameNode, directiveName)
		end
		
		local options = {}
		for _, option in ipairs(args) do
			local key   = option.name
			local value = option.value

			if tonumber(key) then
				key = value
				value = true
			end

			if handler.checkArgs then
				if not handler.checkArgs[key] then
					plume.error.wrongDirectiveArgs(option.nameSource or option.valueSource, directiveName, key, handler.checkArgs)
				elseif (handler.checkArgs[key] ~= "*" and not handler.checkArgs[key][value]) then
					plume.error.wrongDirectiveArgsValue(option.valueSource, directiveName, key, handler.checkArgs, value)
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

	local dynamicWhiteList = {context=true}

	nodeHandlerTable.USE = function(node)
		local libnameNode = plume.ast.get(node, "LIB_NAME")
		local libname     = libnameNode.content
		local posItemList = plume.ast.getAll(node, "LIST_ITEM")
		local nmdItemList = plume.ast.getAll(node, "HASH_ITEM")

		if not libname or #libname == 0 then
			plume.error.emptyUse(node)
		end

		local isDirective = false
		if libname:sub(1, 1) == "#" then
			isDirective = true
			libname = libname:sub(2, -1)
		end

		local whiteListed = isDirective and dynamicWhiteList[libname]

		local args = {}
		local function handleArg(name, value, nameSource)
			if type(name) ~= "string" and type(name) ~= "number" and not whiteListed then
				plume.error.useDoesNotAcceptDynamicArgs(name)
			end

			local rawvalue = value
			if not whiteListed then
				rawvalue = getRawValue(value, libname, name, not isDirective)
			end

			table.insert(args, {name=name, value=rawvalue, valueSource=value, nameSource=nameSource})
		end

		for i, posItem in ipairs(posItemList) do
			handleArg(i, posItem)
		end
		for i, nmdItem in ipairs(nmdItemList) do
			local nameNode = plume.ast.get(nmdItem, "NAME")
			local name  = nameNode and nameNode.content or plume.ast.get(nmdItem, "DYNAMIC_KEY")
			local value = plume.ast.get(nmdItem, "BODY")
			handleArg(name, value, nameNode)
		end

		if isDirective then
			useDirective(node, libnameNode, libname, args)
		else
			useLib(node, libnameNode, libname, args)
		end
	end
end