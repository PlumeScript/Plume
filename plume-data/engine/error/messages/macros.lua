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
	function plume.error.cannotAddPositionalAfterNamed(node, varName)
		local message = "Cannot add a positional parameter after a named one"
		plume.error.throwSyntaxError(node, message)
	end

	function plume.error.cannotAddPositionalAfterVariadic(node, varName)
		local message = "Cannot add a positional parameter after a variadic one"
		plume.error.throwSyntaxError(node, message)
	end

	function plume.error.cannotAddNamedAfterVariadic(node, varName)
		local message = "Cannot add a named parameter after a variadic one"
		plume.error.throwSyntaxError(node, message)
	end

	function plume.error.cannotUseSelfAsParam(node)
		local message = "Cannot use 'self' as macro parameter.\n'self' is an implicit variable used to store the call table."
		plume.error.throwCompilationError(node, message)
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

	function plume.error.wrongArgsCountStd(macroName, argCount, minArgsCount, maxArgsCount, signature)
		local signatureHint = ""
		if signature then
			signatureHint = string.format("\nUsage: %s", signature)
		end

		if minArgsCount == maxArgsCount then
			return string.format(
				"Wrong number of positional arguments for macro '%s', %s instead of %s.%s",
				macroName, argCount, minArgsCount, signatureHint
			)
		else
			return string.format(
				"Wrong number of positional arguments for macro '%s', %s instead of between %s and %s.%s",
				macroName, argCount, minArgsCount, maxArgsCount, signatureHint
			)
		end
	end

	function plume.error.wrongArgsCountMetaDefinition(macro, macroName, argCount, expectedArgsCount)
		local message = string.format(
			"Wrong number of positional parameters for meta-macro '%s', %s instead of %s.",
			macroName, argCount, expectedArgsCount
		)
		return message
	end

	function plume.error.metaMacroWithoutNamedParameter(name)
		return string.format("Meta-macro '%s' dont support named parameters.", name)
	end

	function plume.error.unknownParameter(parameterName, macro)
		local message = string.format("Unknown named parameter '%s' for macro '%s'.", parameterName, macro.name)
		local signature = plume.error.getMacroSignature(macro)
		if signature then
			message = string.format("%s\nUsage: %s", message, signature)
		end

		return message
	end

	function plume.error.unknownParameterStd(parameterName, macroName, signature)
		local message = string.format("Unknown named parameter '%s' for macro '%s'.", parameterName, macroName)

		if signature then
			message = string.format("%s\nUsage: %s", message, signature)
		end

		return message
	end

	function plume.error.WrongArgTypeStd(parameterName, macroName, usedType, expectedType, signature)
		local message = string.format("Wrong type '%s' for parameter '%s' of macro '%s'. Expected: '%s'.", usedType, parameterName, macroName, expectedType)

		if signature then
			message = string.format("%s\nUsage: %s", message, signature)
		end

		return message
	end
end