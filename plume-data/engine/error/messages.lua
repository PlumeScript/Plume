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
	local function throwCompilationError(node, message)
		message = plume.error.makeCompilationError(node, message)
		error(message, -1)
	end

	local function throwSyntaxError(node, message)
		message = plume.error.makeSyntaxError(node, message)
		error(message, -1)
	end

	function plume.error.strictWarningError (node, message)
		message = plume.error.makeStrictWarningError(node, message)
		error(message, -1)
	end

	function plume.error.cannotAddPositionalAfterNamed(node, varName)
		local message = "Cannot add a positional parameter after a named one"
		throwCompilationError(node, message)
	end

	function plume.error.cannotAddPositionalAfterVariadic(node, varName)
		local message = "Cannot add a positional parameter after a variadic one"
		throwCompilationError(node, message)
	end

	function plume.error.cannotAddNamedAfterVariadic(node, varName)
		local message = "Cannot add a named parameter after a variadic one"
		throwCompilationError(node, message)
	end

	function plume.error.cannotUseSelfAsParam(node)
		local message = "Cannot use 'self' as macro parameter.\n'self' is an implicit variable used to store the call table."
		throwCompilationError(node, message)
	end

	function plume.error.unknownDirective(node, name)
		local message = string.format("Cannot use directive '%s': it doesn't exist.", name)
		throwCompilationError(node, message)
	end

	function plume.error.compoundWithDestructionError(node)
		local message = "Cannot use compound operator and destructuration at the same time."
		throwCompilationError(node, message)
	end

	function plume.error.useUnknownVariableError(node, varName, ref, visiblesVariables)
		local refHint = ""
		if ref then
			refHint = string.format("\n'ref%s' exists in parent scope, but a ref cannot be captured by macros.", varName)
			plume.error.addContext(node, ref)
		end
		local message = string.format("Cannot use variable '%s', it isn't defined in the current scope.%s", varName, refHint)
		throwCompilationError(node, message)
	end

	function plume.error.setUnknownVariableError(node, varName, ref, visiblesVariables)
		local refHint = ""
		if ref then
			refHint = string.format("\n'ref %s' exists in parent scope, but a ref cannot be captured by macros.", varName)
			plume.error.addContext(node, ref)
		end
		local message = string.format("Cannot set variable '%s', it isn't defined in the current scope.%s", varName, refHint)
		throwCompilationError(node, message)
	end

	function plume.error.setConstantVariableError(node, varName, source, definitionNode)
		if source then
			source = string.format(" (imported from '%s')", source)
		else
			source = ""
		end
		local message = string.format("Cannot set variable '%s'%s, it is a constant.", varName, source)
		plume.error.addContext(node, definitionNode)
		throwCompilationError(node, message)
	end

	function plume.error.cannotMixContextConstError(node)
		local message = "Variable cannot be both const and context"
		throwCompilationError(node, message)
	end

	function plume.error.cannotMixContextParamError(node)
		local message = "Variable cannot be both param and context"
		throwCompilationError(node, message)
	end

	function plume.error.setContextVariableError(node, varName)
		local message = string.format("Cannot set variable '%s', it is a context variable. Use `with %s: value` instead.", varName, varName)
		throwCompilationError(node, message)
	end

	function plume.error.letEmptyConstantError(node)
		local message = string.format("Cannot define an empty constant variable.")
		throwCompilationError(node, message)
	end

	function plume.error.letExistingVariableError(node, varName, source, definitionNode)
		if source then
			source = string.format(" (imported from '%s')", source)
		else
			source = ""
		end
		local message = string.format("Cannot define variable '%s', it already exists in the current scope%s.", varName, source)
		plume.error.addContext(node, definitionNode)
		throwCompilationError(node, message)
	end
	function plume.error.letExistingSelfVariableError(node)
		local message = "Cannot define variable 'self', it already exists in the current scope.\n'self' is an implicit variable used to store the call table."
		throwCompilationError(node, message)
	end

	function plume.error.cannotUseParamAndConst(node)
		local message = "Cannot use 'const' and 'param' together (parameter variables are by default constant)."
		throwCompilationError(node, message)
	end

	function plume.error.useExistingVariableError(node, varName, use)
		local message = string.format("Cannot define variable '%s' from lib '%s', it already exists in the current file scope.", varName, use)
		throwCompilationError(node, message)
	end

	function plume.error.cannotUseDefaultValueWithoutFrom(node)
		local message = "Cannot use a default value outside of a from statement."
		throwCompilationError(node, message)
	end

	function plume.error.cannotSetCallError(node)
		local message = "Cannot set the result of a call."
		throwCompilationError(node, message)
	end

	function plume.error.cannotUseBreakOutsideLoop(node)
		local message = "Cannot use break keyword outside a loop."
		throwCompilationError(node, message)
	end

	function plume.error.cannotUseContinueOutsideLoop(node)
		local message = "Cannot use continue keyword outside a loop."
		throwCompilationError(node, message)
	end

	function plume.error.missingIteratorError(node)
		local message = "Missing iterator."
		throwSyntaxError(node, message)
	end

	function plume.error.missingConditionError(node)
		local message = "Missing condition."
		throwSyntaxError(node, message)
	end

	function plume.error.missingEndError(node)
		local message = "Missing end."
		throwSyntaxError(node, message)
	end

	function plume.error.emptyExprError(node)
		local message = "Evaluation cannot be empty."
		throwSyntaxError(node, message)
	end

	function plume.error.missingClosingBracketError(node)
		local message = "Missing ')' to close evaluation."
		throwSyntaxError(node, message)
	end

	function plume.error.missingLoopIdentifierError(node)
		local message = "Missing loop identifier."
		throwSyntaxError(node, message)
	end

	function plume.error.missingParamListError(node)
		local message = "Missing parameters list."
		throwSyntaxError(node, message)
	end

	function plume.error.missingParamError(node)
		local message = "Missing parameter name."
		if node.bpos == node.epos+1 then
			node.errorbpos = node.bpos-1
		end
		throwSyntaxError(node, message)
	end

	function plume.error.emptySetError(node)
		local message = "Using set without giving it a value."
		throwSyntaxError(node, message)
	end

	function plume.error.letCompoundError(node)
		local message = "Using let with a compound assignment."
		throwSyntaxError(node, message)
	end

	function plume.error.malformedCodeError(node)
		local message = "Malformed code."
		throwSyntaxError(node, message)
	end

	function plume.error.wrongIdentifierError(node, name)
		local message = string.format("Cannot use '%s' as an identifier.", name)
		throwSyntaxError(node, message)
	end

	function plume.error.mixedBlockError(node, expected, found)
		local message = string.format("Mixed block: the expected type of the block is %s, but it contains an element %s.", expected, found)
		throwSyntaxError(node, message)
	end

	function plume.error.mixedBlockErrorInsideIf(node, expected, found, parentName)
		local message = string.format("Mixed block: The previous branches of this if statement were of type %s, but this %s body is of type %s.\nAll branches of an if statement must be of the same type.", expected, parentName:lower(), found)
		throwSyntaxError(node, message)
	end

	function plume.error.compilationCannotOpenFile(node, path, searchPaths)
		local message = string.format("Cannot open '%s'.\nPaths tried:\n\t%s", path, table.concat(searchPaths, '\n\t'))
		throwCompilationError(node, message)
	end

	function plume.error.cannotExecuteFile(node, path, error)
		local message = string.format("Error when executing '%s':\n%s", path, error)
		throwCompilationError(node, message)
	end

	function plume.error.fileMustReturnATable(node, path, t)
		local message = string.format("To be used, '%s' must return a table. Currently, it returns a %s.", path, t)
		throwCompilationError(node, message)
	end

	-- Runtime
	function plume.error.cannotConcatValue(t)
		return string.format("Cannot concat a '%s' value.", t)
	end

	function plume.error.cannotCallValue(t)
		return string.format("Cannot call a '%s' value.", t)
	end

	function plume.error.cannotIterateValue(t)
		return string.format("Cannot iterate over a non-table '%s' value.", t)
	end

	function plume.error.cannotIndexValue(t)
		return string.format("Cannot index a non-table '%s' value.", t)
	end

	function plume.error.cannotExpandValue(t)
		return string.format("Cannot expand a non-table '%s' value.", t)
	end

	function plume.error.wrongArgsCount(macro, argCount, expectedArgsCount)
		local message = string.format(
			"Wrong number of positional arguments for macro '%s', %s instead of %s.",
			macro.name, argCount, expectedArgsCount
		)
		local signature = plume.error.getMacroSignature(macro)
		if signature then
			message = string.format("%s\nUsage: %s", message, signature)
		end

		return message
	end

	function plume.error.wrongArgsCountStd(macroName, argCount, minArgsCount, maxArgsCount)
		if minArgsCount == maxArgsCount then
			return string.format(
				"Wrong number of positional arguments for macro '%s', %s instead of %s.\nSignature: %s",
				macro.name, argCount, minArgsCount, macro
			)
		else
			return string.format(
				"Wrong number of positional arguments for macro '%s', %s instead of between %s and %s.",
				macroName, argCount, minArgsCount, maxArgsCount
			)
		end
	end

	function plume.error.stackOverflow()
		return "Stack overflow"
	end

	function plume.error.cannotUseEmptyAsKey()
		return "Cannot use empty as key."
	end

	function plume.error.invalidKey(key)
		if tonumber(key) then
			return string.format("Invalid index '%s'.",  key)
		else
			return string.format("Invalid key '%s'.",  key)
		end
	end

	function plume.error.unregisteredKey(key)
		return string.format("Unregistered key '%s'.",  key)
	end

	function plume.error.unknownParameter(parameterName, macro)
		local message = string.format("Unknown named parameter '%s' for macro '%s'.", parameterName, macro.name)
		local signature = plume.error.getMacroSignature(macro)
		if signature then
			message = string.format("%s\nUsage: %s", message, signature)
		end

		return message
	end

	function plume.error.hasNoLen(tt)
		return string.format("Type '%s' has no len.", tt)
	end

	function plume.error.cannotUseMetaKey()
		return "Cannot use a meta key for a macro named argument."
	end

	function plume.error.cannotOpenFile(path, searchPaths)
		return string.format("Error: cannot open '%s'.\nPaths tried:\n\t%s", path, table.concat(searchPaths, '\n\t'))
	end
end