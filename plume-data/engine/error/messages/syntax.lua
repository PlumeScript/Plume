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
	function plume.error.cannotUseBreakOutsideLoop(node)
		local message = "Cannot use break keyword outside a loop."
		plume.error.throwCompilationError(node, message)
	end

	function plume.error.cannotUseContinueOutsideLoop(node)
		local message = "Cannot use continue keyword outside a loop."
		plume.error.throwCompilationError(node, message)
	end

	function plume.error.missingIterator(node)
		local message = "Missing for iterator."
		node.errlpos = 3 
		node.errorepos = node.bpos + 3 -- target empty space after "in"
		plume.error.throwSyntaxError(node, message)
	end

	function plume.error.missingIteratorVariable(node)
		local message = "Missing for variable."
		node.errorepos = node.epos - 2 -- remove captured "in"
		plume.error.throwSyntaxError(node, message)
	end

	function plume.error.missingCondition(node)
		local message = "Missing condition."
		node.errlpos = 3
		plume.error.throwSyntaxError(node, message)
	end

	function plume.error.missingEnd(node)
		local message = "Missing end."
		plume.error.throwSyntaxError(node, message)
	end

	function plume.error.missingValue(node)
		local message = "Missing value"
		plume.error.throwSyntaxError(node, message)
	end

	function plume.error.emptyExpr(node)
		local message = "Evaluation cannot be empty."
		node.errorbpos = node.bpos-1
		plume.error.throwSyntaxError(node, message)
	end

	function plume.error.evalAlone(node)
		local message = "'$' must be followed by a variable name or an expression in parentheses.\nIf you want to write the '$' character, write '\\$'."
		node.errorbpos = node.bpos-1
		plume.error.throwSyntaxError(node, message)
	end

	function plume.error.missingClosingBracket(node)
		local message = "Missing ')' to close evaluation."
		node.errlpos = 1
		plume.error.throwSyntaxError(node, message)
	end

	function plume.error.missingClosingBracketArgList(node)
		local message = "Missing ')' to close arguments list."
		node.errlpos = 1
		plume.error.throwSyntaxError(node, message)
	end

	function plume.error.missingLoopIdentifier(node)
		local message = "Missing loop identifier."
		plume.error.throwSyntaxError(node, message)
	end

	function plume.error.missingParam(node)
		local message = "Missing parameter name."
		if node.bpos == node.epos+1 then
			node.errorbpos = node.bpos-1
		end
		plume.error.throwSyntaxError(node, message)
	end

	function plume.error.emptySet(node)
		local message = "Using set without giving it a value."
		plume.error.throwSyntaxError(node, message)
	end

	function plume.error.letCompound(node)
		local message = "Using let with a compound assignment."
		plume.error.throwSyntaxError(node, message)
	end

	function plume.error.malformedCode(node)
		local message = "Malformed code."
		plume.error.throwSyntaxError(node, message)
	end

	function plume.error.cannotUseDefaultValueWithoutFrom(node)
		local message = "Cannot use a default value outside of a from statement."
		plume.error.throwCompilationError(node, message)
	end

	function plume.error.cannotSetCall(node)
		local message = "Cannot set the result of a call."
		plume.error.throwCompilationError(node, message)
	end

	function plume.error.letExistingSelfVariable(node)
		local message = "Cannot define variable 'self', it already exists in the current scope.\n'self' is an implicit variable used to store the call table."
		plume.error.throwCompilationError(node, message)
	end

	function plume.error.cannotUseParamAndConst(node)
		local message = "Cannot use 'const' and 'param' together (parameter variables are by default constant)."
		plume.error.throwCompilationError(node, message)
	end

	function plume.error.wrongIdentifier(node, name)
		local message = string.format("Cannot use '%s' as an identifier.", name)
		plume.error.throwSyntaxError(node, message)
	end

	function plume.error.mixedBlock(node, expected, found, lastNode)
		if expected == "VALUE" then
			expected = "TEXT"
		end
		local message = string.format("Invalid '%s' content in a '%s' block.", found, expected)
		
		node.errorLabel = string.format("Reading this line, Plume assumes the block type is '%s'.", expected)

		lastNode.errorSkipFilename = true
		lastNode.errorLabel = string.format("But you try to add a '%s' element.", found)

		plume.error.addContext(node, lastNode)

		plume.error.throwSyntaxError(node, message)
	end

	function plume.error.mixedBlockInsideIf(node, expected, found, parentName)
		if expected == "VALUE" then
			expected = "TEXT"
		end
		local message = string.format("Invalid '%s' content in a '%s' block.\nThe previous branches of this if statement were of type %s, but this %s body is of type %s.\nAll branches of an if statement must be of the same type.", found, expected, expected, parentName:lower(), found)
		plume.error.throwSyntaxError(node, message)
	end

	function plume.error.useDoesNotAcceptDynamicArgs(node, libName, paramName, paramValue, isImport)
		local message = "The arguments of 'use' are read at compile time and must therefore be plain text."
		if isImport then
			message = string.format(
				"%s\nTo import '%s' with dynamic parameters, use instead:\n    |let %s = $import(%s, %s: %s)\n    |...\n    |$lib.someMethod()",
				message, libName, libName, libName, paramName, paramValue
			)
		end
		plume.error.throwSyntaxError(node, message)
	end
	function plume.error.useDoesNotAcceptPositionalArgs(node)
		local message = "'use' does not accept positional arguments."
		plume.error.throwSyntaxError(node, message)
	end

	function plume.error.unknownEscapeSequence(node, s)
		local message = string.format("Unknown escape sequence '\\%s'.", s)
		plume.error.throwSyntaxError(node, message)
	end

	function plume.error.inlineTableMuseBeAlone(node)
		local message = "Inline tables must be the only elements in their block."
		plume.error.throwSyntaxError(node, message)
	end

	function plume.error.withTableMuseBeAlone(node)
		local message = "`with` statement that returns a table must be the only elements in their block."
		plume.error.throwSyntaxError(node, message)
	end

	function plume.error.cannotUseRef(node)
		local message = "Cannot use `ref` inside inline table or inline macro call."
		plume.error.throwSyntaxError(node, message)
	end
end