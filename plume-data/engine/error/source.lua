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
	function plume.error.getNodeLines(node)
		local code      = node.code
		local bpos      = node.errorbpos or node.bpos
		local epos      = node.errorepos or node.epos
		local sourceLen = epos - bpos + 1

		local currentPos = 1
		local lines = {}
		local noLine = 1
		local sourceNoLine
		local sourceLinePosBegin
		for line in (node.code.."\n"):gmatch('[^\n]*\n') do
			if not sourceNoLine and currentPos + #line > bpos then
				sourceNoLine = noLine
				sourceLinePosBegin = bpos - currentPos + 1
				sourceLen = math.min(sourceLen, #line - sourceLinePosBegin)
			end

			lines[noLine] = line:sub(1, -2) -- remove `\n`
			currentPos = currentPos + #line
			noLine = noLine + 1
		end

		return {
			filename           = node.filename,
			lines              = lines,
			sourceNoLine       = sourceNoLine,
			sourceLinePosBegin = sourceLinePosBegin,
			sourceLen          = sourceLen
		}
	end

	function plume.error.getNodeLinesContext(node, fullContext, macroContext)
		local selectedNoLines = {}
		local selectedNoLinesCheck = {}
		local function addLine(n)
			if not selectedNoLinesCheck[n] then
				table.insert(selectedNoLines, n)
				selectedNoLinesCheck[n] = #selectedNoLines
			end
		end
		local function removeLine(n)
			if selectedNoLinesCheck[n] then
				table.remove(selectedNoLines, selectedNoLinesCheck[n])
				selectedNoLinesCheck[n] = nil
			end
		end

		local linesInfos = plume.error.getNodeLines(node)
		
		addLine(linesInfos.sourceNoLine)
		if fullContext then
			local prevNoLine = linesInfos.sourceNoLine-1
			while prevNoLine > 0 and linesInfos.lines[prevNoLine]:match('^%s*$') do
				prevNoLine = prevNoLine - 1
			end
			if prevNoLine > 0 then
				addLine(prevNoLine)
			end
			local nextNoLine = linesInfos.sourceNoLine+1
			while nextNoLine <= #linesInfos.lines and linesInfos.lines[nextNoLine]:match('^%s*$') do
				nextNoLine = nextNoLine + 1
			end
			if nextNoLine <= #linesInfos.lines then
				addLine(nextNoLine)
			end
		end

		if macroContext then
			local parentMacro = plume.error.findNodeParentMacro (node)
			if parentMacro then
				local parentMacroInfos = plume.error.getNodeLines(parentMacro)
				addLine(parentMacroInfos.sourceNoLine)
			end
		end

		for _, child in ipairs(node.errorContext or {}) do
			local childInfos = plume.error.getNodeLines(child)
			if childInfos.filename == node.filename then
				removeLine(childInfos.sourceNoLine)
			end
		end

		table.sort(selectedNoLines)
		local lines = {}
		local indentSize = 1/0
		local sourceLinePosBegin = linesInfos.sourceLinePosBegin
		for _, noLine in ipairs(selectedNoLines) do
			indentSize = math.min(indentSize, #linesInfos.lines[noLine]:match('^%s*'))
		end
		for _, noLine in ipairs(selectedNoLines) do
			lines[noLine] = linesInfos.lines[noLine]:gsub('\t', ' '):sub(indentSize+1, -1)
			if noLine == linesInfos.sourceNoLine then
				sourceLinePosBegin = sourceLinePosBegin - indentSize
			end
		end

		return {
			filename           = linesInfos.filename,
			sourceNoLine       = linesInfos.sourceNoLine,
			sourceLinePosBegin = sourceLinePosBegin,
			sourceLen          = linesInfos.sourceLen,
			selectedNoLines    = selectedNoLines,
			lines              = lines,
		}
	end
end