--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function(plume)
	function plume.error.compoundWithDestruction(node)
		local message = "Cannot use compound operator and destructuration at the same time."
		plume.error.throwCompilationError(node, message)
	end

	function plume.error.useUnknownVariable(node, varName, visiblesVariables, isValidator)
		local visiblesVariableHint = plume.error.makeVisibleVariablesHint(node, varName, visiblesVariables, true)
		local validatorHint = ""
		local hardcodedHint = ""
		if isValidator then
			validatorHint = "\nOnly visibles variables can be used as validator."
		end
		if varName == "ipairs" then
			hardcodedHint = "\n(i) You don't need `ipairs` to iterate, just do `for item in iterable`"
		end

		local message = string.format(
			"Cannot use variable '%s', it isn't defined in the current scope.%s%s%s",
			varName, visiblesVariableHint, validatorHint, hardcodedHint
		)
		plume.error.throwCompilationError(node, message)
	end

	function plume.error.setUnknownVariable(node, varName, visiblesVariables)
		local visiblesVariableHint = plume.error.makeVisibleVariablesHint(node, varName, visiblesVariables, false)
		local message = string.format(
			"Cannot set variable '%s', it isn't defined in the current scope.%s",
			varName, visiblesVariableHint
		)
		plume.error.throwCompilationError(node, message)
	end

	function plume.error.setConstantVariable(node, varName, source, definitionNode)
		if source then
			source = string.format(" (imported from '%s')", source)
		else
			source = ""
		end
		local message = string.format("Cannot set variable '%s'%s, it is a constant.", varName, source)
		plume.error.addContext(node, definitionNode)
		plume.error.throwCompilationError(node, message)
	end

	function plume.error.letEmptyConstant(node)
		local message = string.format("Cannot define an empty constant variable.")
		plume.error.throwCompilationError(node, message)
	end

	function plume.error.letExistingVariable(node, varName, source, definitionNode)
		if source then
			source = string.format(" (imported from '%s')", source)
		else
			source = ""
		end
		local message = string.format(
			"Cannot define variable '%s', it already exists in the current scope%s.",
			varName, source
		)
		plume.error.addContext(node, definitionNode)
		plume.error.throwCompilationError(node, message)
	end

	function plume.error.useExistingVariable(node, varName, use)
		local message = string.format(
			"Cannot define variable '%s' from lib '%s', it already exists in the current file scope.",
			varName, use
		)
		plume.error.throwCompilationError(node, message)
	end

	function plume.error.cannotSetRef(node, varName, definitionNode, value)
		value = plume.error.getSourceCode(value)
		local message = string.format(
			"Cannot set variable '%s', it is a reference.\n Use `%s: %s` instead.",
			varName, varName, value
		)

		plume.error.addContext(node, definitionNode)
		plume.error.throwCompilationError(node, message)
	end

	function plume.error.variadicLetMustBeParam(node)
		local message = "Varadic declarations are reserved to `param` variables."
		plume.error.throwCompilationError(node, message)
	end

	function plume.error.variadicLetMustBeEmpty(node)
		local message = "Cannot set default value of a variadic param."
		plume.error.throwCompilationError(node, message)
	end

	function plume.error.cannotDeclareMultipleVariadicParam(node)
		local message = "Cannot declare multiple variadic params."
		plume.error.throwCompilationError(node, message)
	end

	function plume.error.variableDefiningItSelf(node, name, variableNode)
		local message = string.format("Cannot use the value of `%s` to define `%s` itself.", name, name)
		plume.error.addContext(node, variableNode)
		plume.error.throwCompilationError(node, message)
	end

	function plume.error.unknownContextVariable(node, name, plumetable, visiblesVariables)
		local plumeNames = {}
		for k, v in pairs(plumetable) do
			if (type(v) == "table" and v.type) == "context" then
				table.insert(plumeNames, k)
			end
		end

		local visiblesVariableHint = plume.error.makeVisibleVariablesHint(node, name, visiblesVariables, true)
		visiblesVariableHint = visiblesVariableHint:gsub("'(%w)", "'$%1")

		local plumeRelated = string.format("erhaps you mean '%s'?",
			table.concat(plume.error.suggestIdentifiers(name, plumeNames, 3), "', '"):gsub(', ([^,]-)$', ' or %1')
		)

		if #visiblesVariableHint == 0 then
			visiblesVariableHint = "\nP" .. plumeRelated
		else
			visiblesVariableHint = visiblesVariableHint .. "\nOr p" .. plumeRelated
		end
		
		
		local message = string.format("Unknown predefined contextual variable '%s'.%s",
			name, visiblesVariableHint
		)
		plume.error.throwCompilationError(node, message)
	end
end