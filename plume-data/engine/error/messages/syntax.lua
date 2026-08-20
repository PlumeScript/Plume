--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
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

	function plume.error.cannotUseBreakInsideRaise(node)
		local message = "Cannot use break keyword inside a `raise` block."
		plume.error.throwCompilationError(node, message)
	end

	function plume.error.cannotUseContinueInsideRaise(node)
		local message = "Cannot use continue keyword inside a `raise` block."
		plume.error.throwCompilationError(node, message)
	end

	function plume.error.cannotUseBreakInsideLetset(node)
		local message = "Cannot use break keyword inside an affectation."
		plume.error.throwCompilationError(node, message)
	end

	function plume.error.cannotUseBreakInsideDo(node)
		local message = "Cannot use break keyword inside a `do` block."
		plume.error.throwCompilationError(node, message)
	end

	function plume.error.cannotUseContinueInsideDo(node)
		local message = "Cannot use continue keyword inside a `do` block."
		plume.error.throwCompilationError(node, message)
	end
	function plume.error.cannotUseContinueInsideLetset(node)
		local message = "Cannot use continue keyword inside an affectation."
		plume.error.throwCompilationError(node, message)
	end

	function plume.error.cannotUseLeaveInsideRaise(node)
		local message = "Cannot use leave keyword inside a `raise` block."
		plume.error.throwCompilationError(node, message)
	end

	function plume.error.cannotUseReturnInsideRaise(node)
		local message = "Cannot use return keyword inside a `raise` block."
		plume.error.throwCompilationError(node, message)
	end

	function plume.error.cannotUseReturnInsideLetset(node)
		local message = "Cannot use return keyword inside an affectation."
		plume.error.throwCompilationError(node, message)
	end

	function plume.error.cannotUseReturnInsideCall(node)
		local message = "Cannot use return keyword inside a call."
		plume.error.throwCompilationError(node, message)
	end

	function plume.error.useContextMustBeAtFileRoot(node)
		local message = "`use #context` must be at file root."
		plume.error.throwCompilationError(node, message)
	end

	function plume.error.useContextNotSupportPos(node)
		local message = "`use #context` doesn't support positional arguments."
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

	function plume.error.raiseMustBeTEXT(node, t)
		local message = string.format("Raise block must be 'TEXT', not '%s'", t)
		plume.error.throwCompilationError(node, message)
	end

	-- Build the "write as text" hint. A keyword whose first letter is a special
	-- escape (r/t/n/s) cannot be written as `\keyword` (e.g. `\r` is a carriage
	-- return); escape that first letter as a string instead: `$("r")aise`.
	local function emptyKeywordMessage(keyword, what)
		local message = string.format("The keyword `%s` must be followed by a %s.", keyword, what)
		local first = keyword:sub(1, 1)
		local hint
		if first:match("[rtns]") then
			hint = string.format("$(%q)%s", first, keyword:sub(2))
		else
			hint = "\\0" .. keyword
		end
		message = message .. string.format("\nIf you want to write the word '%s' as text, write '%s'.", keyword, hint)
		return message
	end

	function plume.error.emptyRaise(node)
		local message = emptyKeywordMessage("raise", "message")
		-- The error node's bpos points just after the keyword; shift back to highlight it.
		node.errorbpos = node.bpos - #("raise")
		node.errorepos = node.bpos - 1
		plume.error.throwSyntaxError(node, message)
	end

	function plume.error.emptyRun(node)
		local message = emptyKeywordMessage("run", "statement")
		-- The error node's bpos points just after the keyword; shift back to highlight it.
		node.errorbpos = node.bpos - #("run")
		node.errorepos = node.bpos - 1
		plume.error.throwSyntaxError(node, message)
	end

	function plume.error.emptyLet(node)
		local message = emptyKeywordMessage("let", "variable name")
		-- The error node's bpos points just after the keyword; shift back to highlight it.
		node.errorbpos = node.bpos - #("let")
		node.errorepos = node.bpos - 1
		plume.error.throwSyntaxError(node, message)
	end

	function plume.error.emptyUse(node)
		local message = emptyKeywordMessage("use", "library name")
		-- The error node's bpos points just after the keyword; shift back to highlight it.
		node.errorbpos = node.bpos - #("use")
		node.errorepos = node.bpos - 1
		plume.error.throwSyntaxError(node, message)
	end

	function plume.error.emptyWith(node)
		local message = emptyKeywordMessage("with", "table")
		-- The error node's bpos points just after the keyword; shift back to highlight it.
		node.errorbpos = node.bpos - #("with")
		node.errorepos = node.bpos - 1
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
		local message = "Cannot define variable 'self', it already exists in the current scope.\n"
						.. "'self' is an implicit variable used to store the call table."
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
		if expected == "VALUE_TABLE" then
			expected = "TABLE"
		end
		if expected == "VALUE_MACRO" then
			expected = "MACRO"
		end
		if found == "VALUE" then
			found = "TEXT"
		end
		if found == "VALUE_TABLE" then
			found = "TABLE"
		end
		if found == "VALUE_MACRO" then
			found = "MACRO"
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
		if expected == "VALUE_TABLE" then
			expected = "TABLE"
		end
		if expected == "VALUE_MACRO" then
			expected = "MACRO"
		end
		if found == "VALUE" then
			found = "TEXT"
		end
		if found == "VALUE_TABLE" then
			found = "TABLE"
		end
		if found == "VALUE_MACRO" then
			found = "MACRO"
		end
		local message = string.format(
			"Invalid '%s' content in a '%s' block.\n"
			.."The previous branches of this if statement were of type %s, but this %s body is of type %s.\n"
			.."All branches of an if statement must be of the same type.",
			found, expected, expected, parentName:lower(), found
		)
		plume.error.throwSyntaxError(node, message)
	end

	function plume.error.useDoesNotAcceptDynamicArgs(node, libName, paramName, paramValue, isImport)
		local message = "The arguments of 'use' are read at compile time and must therefore be plain text."
		if isImport then
			message = string.format(
				"%s\nTo import '%s' with dynamic parameters, use instead:\n"
				.. "    |let %s = $import(%s, %s: %s)\n"
				.. "    |...\n"
				.. "    |$lib.someMethod()",
				message, libName, libName, libName, paramName, paramValue
			)
		end
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

	function plume.error.nonEscapedEvalMark(node)
		local message = "`$` outside evaluation must be escaped."
		plume.error.throwSyntaxError(node, message)
	end

	function plume.error.leaveInValueBlock(node)
		local message = "Cannot use `leave` here.\n(i) `leave` is designed to stop accumulation,\nbut this macro returns a single value.\nYou should instead, use an `if` with an empty branch."
		plume.error.throwSyntaxError(node, message)
	end
end