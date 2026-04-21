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

	function plume.error.useUnknownVariable(node, varName, ref, visiblesVariables, isValidator)
		local refHint = ""
		-- if ref then -- now, ref can be captured by closures
		-- 	refHint = string.format("\n'ref%s' exists in parent scope, but a ref cannot be captured by macros.", varName)
		-- 	plume.error.addContext(node, ref)
		-- end
		local visiblesVariableHint = plume.error.makeVisibleVariablesHint(node, varName, visiblesVariables, true)
		local validatorHint = ""
		if isValidator then
			validatorHint = "\nOnly visibles variables can be used as validator."
		end

		local message = string.format("Cannot use variable '%s', it isn't defined in the current scope.%s%s%s", varName, refHint, visiblesVariableHint, validatorHint)
		plume.error.throwCompilationError(node, message)
	end

	function plume.error.setUnknownVariable(node, varName, ref, visiblesVariables)
		local refHint = ""
		-- if ref then -- now, ref can be captured by closures
		-- 	refHint = string.format("\n'ref %s' exists in parent scope, but a ref cannot be captured by macros.", varName)
		-- 	plume.error.addContext(node, ref)
		-- end
		local visiblesVariableHint = plume.error.makeVisibleVariablesHint(node, varName, visiblesVariables, false)
		local message = string.format("Cannot set variable '%s', it isn't defined in the current scope.%s%s", varName, refHint, visiblesVariableHint)
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

	function plume.error.cannotMixContextConst(node)
		local message = "Variable cannot be both const and context"
		plume.error.throwCompilationError(node, message)
	end

	function plume.error.cannotMixContextParam(node)
		local message = "Variable cannot be both param and context"
		plume.error.throwCompilationError(node, message)
	end

	function plume.error.setContextVariable(node, varName, value)
		value = plume.error.getSourceCode(value)
		local message = string.format("Cannot set variable '%s', it is a context variable. Use `with %s: %s` instead.", varName, varName, value)
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
		local message = string.format("Cannot define variable '%s', it already exists in the current scope%s.", varName, source)
		plume.error.addContext(node, definitionNode)
		plume.error.throwCompilationError(node, message)
	end

	function plume.error.useExistingVariable(node, varName, use)
		local message = string.format("Cannot define variable '%s' from lib '%s', it already exists in the current file scope.", varName, use)
		plume.error.throwCompilationError(node, message)
	end

	function plume.error.cannotSetRef(node, varName, definitionNode, value)
		value = plume.error.getSourceCode(value)
		local message = string.format("Cannot set variable '%s', it is a reference.\n Use `%s: %s` instead.", varName, varName, value)

		plume.error.addContext(node, definitionNode)
		plume.error.throwCompilationError(node, message)
	end
end