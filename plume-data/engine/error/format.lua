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
	local USE_COLOR = true

	local function focus(s)
		if USE_COLOR then
			return "\x1b[31m" .. s .. "\x1b[0m"
		else
			return s
		end
	end
	local function neutral(s)
		if USE_COLOR then
			return "\x1b[38;2;100;100;100m" .. s .. "\x1b[0m"
		else
			return s
		end
	end
	local function secondary(s)
		if USE_COLOR then
			return "\x1b[34m" .. s .. "\x1b[0m"
		else
			return s
		end
	end
	local function focusless(s)
		if USE_COLOR then
			return "\x1b[97;100m" .. s .. "\x1b[0m"
		else
			return s
		end
	end

	function plume.error.formatError(errorInfos)
		if not plume.warning.any and not errorInfos.message then
			return
		end

		local result = {}
		local maxLineNumberSize = 0

		---------------
		-- Constants --
		---------------
		local MAX_WIDTH = 80
		local BORDER_UR = "╮"
		local BORDER_UL = "╭"
		local BORDER_DR = "╯"
		local BORDER_DL = "╰"
		local BORDER_R = "┤"
		local BORDER_L = "├"

		local BORDER_H  = "─"
		local BORDER_V  = "│"

		local CODE_START  = "│"

		local HEADER_INDENT          = 1
		local SOURCE_FILENAME_INDENT = 2
		local SOURCE_CODE_INDENT     = 4

		local TRACEBACK_HEADER = "Traceback (most recent call first):"

		local MAX_WARNINGS_NODES = 3

		-----------
		-- Utils --
		-----------
		local function utf8len(s)
		    local len = 0
		    s = s:gsub('\x1b%[.-m', '')
		    for i = 1, #s do
		        local c = s:byte(i)
		        if c < 0x80 or c >= 0xC0 then len = len + 1 end
		    end
		    return len
		end

		local function makeLine(args)
			local content         = args[1]:gsub('\t', '  ')
			local indent          = args.indent or 0
			local lineIndentDelta = args.lineIndentDelta or 0
			local crop            = args.crop
			local center          = args.center
			local color           = args.color or function(x) return x end

			local leftover
			if content:match("\n") then
				local before = content:match('^[^\n]*')
				local after  = content:sub(#before+2, -1)
				makeLine{before, indent=indent, lineIndentDelta=lineIndentDelta, crop=crop}
				makeLine{after,  indent=indent+lineIndentDelta, crop=crop}
				return
			elseif utf8len(content) >= MAX_WIDTH-2 then 
				if crop then
					if crop == "start" then
						content = content:sub(1, 3)..'...'..content:sub(utf8len(content)-MAX_WIDTH+10, -1)
					else
						content = content:sub(1, MAX_WIDTH-7):gsub('%s*$', '')..'...'
					end
				else -- cut the last possible word
					local pos = 1
					for x in content:gmatch("%S+%s*") do
						if pos + utf8len(x:gsub('%s*$', '')) >= MAX_WIDTH-2 then
							break
						end
						pos = pos + #x
					end

					if pos == 1 then -- cannot find a cut point
						pos = MAX_WIDTH - 2
					end

					leftover = content:sub(pos, -1):gsub('^%s*', '')
					content = content:sub(1, pos-1):gsub('%s*$', '')
				end
			end

			local firstIndent, lastIndent

			if center then
				local space = MAX_WIDTH - utf8len(content)
				firstIndent = space/2
				lastIndent  = space/2

				if space%2==1 then
					lastIndent = lastIndent + 1
				end
			else
				firstIndent = indent
				lastIndent  = MAX_WIDTH - utf8len(content) - indent
			end

			table.insert(result,
				neutral(BORDER_V)
					.. (" "):rep(firstIndent)
						.. color(content)
					.. (" "):rep(lastIndent)
				.. neutral(BORDER_V)
			)

			if leftover then
				makeLine{leftover, indent=indent+lineIndentDelta, crop=crop}
			end
		end

		local function makeSourceLine(args)
			local content = args[1]
			local noline  = args[2]
			local dindent  = args.indent or 0
			local indent = maxLineNumberSize - #tostring(noline)
			makeLine{
				neutral(noline) .. (" "):rep(1+indent)
				.. neutral(CODE_START)
				.. content,
				indent=SOURCE_CODE_INDENT+dindent,
				crop=true
			}
		end
		local lastfilename
		local function makeSourceSnippet(infos, indent, important)
			indent = indent or 0

			if infos.filename ~= lastfilename then
				makeLine{"↳ " .. infos.filename, indent=SOURCE_FILENAME_INDENT+indent, crop="start", color=secondary}
				lastfilename = infos.filename
			else
				makeLine{"↳ (same file)", indent=SOURCE_FILENAME_INDENT+indent, color=secondary}
			end

			local lastNoLine
			for _, noLine in ipairs(infos.selectedNoLines) do
				-- if lastNoLine and lastNoLine < noLine - 1 then
				-- 	makeSourceLine{"...", "", indent=indent}
				-- end

				local line = infos.lines[noLine]
				local indicator
				if noLine == infos.sourceNoLine then
					indicator = (" "):rep(infos.sourceLinePosBegin-1) .. ("^"):rep(infos.sourceLen)
					if #indicator >= MAX_WIDTH*3/4 then
						delta     = #indicator - MAX_WIDTH*3/4
						indicator = indicator:sub(delta, -1)
						line      = "..."..line:sub(delta+3, -1)
					end

					if important then
						line = focus(line)
						indicator = focus(indicator)
					end
				end
				
				makeSourceLine{line, noLine, indent=indent}
				if indicator then
					makeSourceLine{indicator, "", indent=indent}
				end

				lastNoLine = noLine
			end
		end

		-----------------
		-- Preparation --
		-----------------
		
		local nodesInfos = {source=nil, traceback={}, warnings={count=0}, context={}}
		-- Get node infos
		if errorInfos.sourceNode then
			nodesInfos.source = plume.error.getNodeLinesContext(errorInfos.sourceNode, true, true)
		end
		for _, child in ipairs(errorInfos.sourceNode and errorInfos.sourceNode.errorContext or {}) do
			table.insert(nodesInfos.context, plume.error.getNodeLinesContext(child, false, false))
		end
		for _, infos in ipairs(errorInfos.errorCallstack or {}) do
			if infos.node then
				table.insert(nodesInfos.traceback,  plume.error.getNodeLinesContext(infos.node, false, true))
			else
				table.insert(nodesInfos.traceback, infos)
			end
		end
		for i, infos in ipairs(plume.warning.cache) do
			warningInfos = {message=infos.message, help=infos.help, issues=infos.issues}
			for j, node in ipairs(infos.nodes) do
				table.insert(warningInfos, plume.error.getNodeLinesContext(node, false, false))
				nodesInfos.warnings.count = nodesInfos.warnings.count + 1
			end
			table.insert(nodesInfos.warnings, warningInfos)
		end

		-- Get line number to align source code
		local allNode = {nodesInfos.source}
		for _, infos in ipairs(nodesInfos.traceback) do
			table.insert(allNode, infos)
		end
		for _, infos in ipairs(nodesInfos.context) do
			table.insert(allNode, infos)
		end
		for _, warningInfos in ipairs(nodesInfos.warnings) do
			for _, node in ipairs(warningInfos) do
				table.insert(allNode, node)
			end
		end

		local maxLineNumber = 1
		for _, node in ipairs(allNode) do
			for _, line in ipairs(node.selectedNoLines or {}) do
				maxLineNumber = math.max(maxLineNumber, line)
			end
		end

		maxLineNumberSize = #tostring(maxLineNumber)

		---------------
		-- Rendering --
		---------------

		-- Header
		if errorInfos.header then
			table.insert(result, neutral(BORDER_UL .. BORDER_H:rep(MAX_WIDTH) .. BORDER_UR))
			makeLine{errorInfos.header,  indent=HEADER_INDENT, color=focus}
			if errorInfos.message then
				makeLine{"→ "..errorInfos.message, indent=HEADER_INDENT, lineIndentDelta=2}
			end
			table.insert(result, neutral(BORDER_L.. BORDER_H:rep(MAX_WIDTH) .. BORDER_R))
		end

		-- Source File
		if nodesInfos.source then
			makeLine{""}
			makeSourceSnippet(nodesInfos.source, 0, true)
			makeLine{""}
		end

		-- Context
		if #nodesInfos.context > 0 then
			for i, infos in ipairs(nodesInfos.context) do
				if infos.sourceNoLine then
					makeSourceSnippet(infos)
					if i < #nodesInfos.context then
						makeLine{""}
					end
				end
			end
		end

		-- Traceback
		if #nodesInfos.traceback > 0 then
			table.insert(result, neutral(BORDER_L .. BORDER_H:rep(MAX_WIDTH) .. BORDER_R))
			makeLine{TRACEBACK_HEADER, indent=HEADER_INDENT}
			table.insert(result, neutral(BORDER_L .. BORDER_H:rep(MAX_WIDTH) .. BORDER_R))
			for i, infos in ipairs(nodesInfos.traceback) do
				if infos.sourceNoLine then
					makeSourceSnippet(infos)

					if i < #nodesInfos.traceback then
						makeLine{""}
					end
				elseif infos.repeatedBlockBegin then
					makeLine{string.format("! This block is repeated %s times:", infos.repeatedBlockBegin), indent=SOURCE_FILENAME_INDENT}
					makeLine{"↳...", indent=SOURCE_FILENAME_INDENT}
				elseif infos.repeated then
					makeLine{"↳...", indent=SOURCE_FILENAME_INDENT}
					makeLine{string.format("↳(previous block is repeated %s more times)", infos.repeated), indent=SOURCE_FILENAME_INDENT}
					makeLine{"↳...", indent=SOURCE_FILENAME_INDENT}
					if i < #nodesInfos.traceback then
						makeLine{""}
					end
				elseif infos.repeatedBlockEnd then
					
					makeLine{"↳...", indent=SOURCE_FILENAME_INDENT}
					
					if i < #nodesInfos.traceback then
						makeLine{("~"):rep(MAX_WIDTH-4), indent=SOURCE_FILENAME_INDENT}
						makeLine{""}
					end
				end
			end
		end
		
		if nodesInfos.warnings.count > 0 then
			if errorInfos.header then
				table.insert(result, neutral(BORDER_L.. BORDER_H:rep(MAX_WIDTH) .. BORDER_R))
			else
				table.insert(result, neutral(BORDER_UL .. BORDER_H:rep(MAX_WIDTH) .. BORDER_UR))
			end

			makeLine{string.format(focusless(" %s WARNING%s "), nodesInfos.warnings.count, nodesInfos.warnings.count>1 and "S" or ""),  indent=HEADER_INDENT}
			makeLine{"  Add `use #warning(mode: ignore[, issues: xxx yyy])` to ignore warnings. ",  indent=HEADER_INDENT, lineIndentDelta=2}
			table.insert(result, neutral(BORDER_L.. BORDER_H:rep(MAX_WIDTH) .. BORDER_R))

			for i, warningInfos in ipairs(nodesInfos.warnings) do
				makeLine{
					string.format("" .. focusless("→ WARNING %i ") .. neutral(" (%i occurrence%s, issue%s %s)"),
						i,
						#warningInfos,
						#warningInfos>1 and "s" or "",
						#warningInfos.issues>1 and "s" or "",
						table.concat(warningInfos.issues, ", ")
					),
					indent=HEADER_INDENT
				}
				makeLine{"! "..warningInfos.message,  indent=SOURCE_CODE_INDENT, lineIndentDelta=2}
				if warningInfos.help then
					makeLine{"(i) " .. warningInfos.help:gsub('^%s*', ''),  indent=SOURCE_CODE_INDENT, lineIndentDelta=4}
				end
				makeLine{""}
				for j, infos in ipairs(warningInfos) do
					makeSourceSnippet(infos, 2)

					makeLine{""}

					if j > MAX_WARNINGS_NODES then
						makeLine{string.format("↳... (%s more)", #warningInfos-j+1), indent=SOURCE_CODE_INDENT}
						makeLine{""}
						break
					end
				end

				if i<#plume.warning.cache then
					makeLine{""}
				end
			end
		end

		-- Border end
		table.insert(result, neutral(BORDER_DL.. BORDER_H:rep(MAX_WIDTH) .. BORDER_DR))

		return table.concat(result, "\n")
	end
end