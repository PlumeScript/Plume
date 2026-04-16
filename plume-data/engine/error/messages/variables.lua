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

	function plume.error.setContextVariable(node, varName)
		local message = string.format("Cannot set variable '%s', it is a context variable. Use `with %s: value` instead.", varName, varName)
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
end