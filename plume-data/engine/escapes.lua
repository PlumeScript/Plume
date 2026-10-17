--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

-- Escape sequences usable in free text.
-- Single source of truth, shared by:
--  - the parser (engine/parser.lua), which builds its recognition rule from `plume.escapeList`
--  - the compiler (engine/compiler/handlers/literals.lua), which resolves a
--    SPECIAL_TEXT node to its value through `plume.escapes`
--
-- Note: `\0` resolves to empty text, not a NUL byte: it erases the character
-- that follows it, which is what allows keywords to be written as literal
-- text (\0let).
return function (plume)
	local escapeList = {
		{ "\\s", " " },
		{ "\\t", "\t" },
		{ "\\n", "\n" },
		{ "\\r", "\r" },
		{ "\\$", "$" },
		{ "\\(", "(" },
		{ "\\)", ")" },
		{ "\\:", ":" },
		{ "\\,", "," },
		{ "\\\\", "\\" },
		{ "\\/", "/" },
		{ "\\0", "" },
		{ "\\@", "@" },
	}

	local escapes = {}
	for _, entry in ipairs(escapeList) do
		escapes[entry[1]] = entry[2]
	end

	plume.escapeList = escapeList
	plume.escapes = escapes
end
