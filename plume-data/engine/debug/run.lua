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

return function (plume)
	local nodeID = {}
	local nid = 0
	local function getNodeID(node)
		return node.name .. node.bpos .. "-" .. node.epos
	end

	local function renderCode(node)
		local result = {}
		for x in node.code:gmatch('.') do
			if x == "\n" then
				x = "<br>"
			elseif x == " " then
				x = "<span class='space'>&nbsp;</span>"
			elseif x == "\t" then
				x = "<span class='tab'>&nbsp;</span>"
			else
				x = string.format("<span>%s</span>", x)
			end
			table.insert(result, x)
		end
		return table.concat(result)
	end

	local function renderAST(node)
		local result = {}
		local nid = getNodeID(node)
		table.insert(result, string.format("<div class='ast-node' id='ast-node-%s' data-bpos=%i data-epos=%i>", nid, node.bpos, node.epos))
		table.insert(result, string.format("<div class='ast-node-infos'>%s (%s)</div>", node.name, node.type))
		
		if node.children and #node.children > 0 then
			table.insert(result, "<div class='ast-node-children'>")
			for _, child in ipairs(node.children) do
				table.insert(result, renderAST(child))
			end
			table.insert(result, "</div>")
		end

		table.insert(result, "</div>")
		return table.concat(result)
	end

	local function renderBytecode(bytecode, mapping)
		local function getNearestNode(i)
			for j=i, 1, -1 do
				if mapping[j] then
					return getNodeID(mapping[j])
				end
			end
			for j=i, #bytecode do
				if mapping[j] then
					return getNodeID(mapping[j])
				end
			end
			return 0
		end

		local bit   = require "bit"
		local names =  plume.debug.invTable(plume.ops)

		local result = {}

		for i, instr in ipairs(bytecode) do
			local op    = bit.band(bit.rshift(instr, plume.OP_SHIFT), plume.MASK_OP)
        	local arg1  = bit.band(bit.rshift(instr, plume.ARG1_SHIFT), plume.MASK_ARG1)
        	local arg2  = bit.band(instr, plume.MASK_ARG2)

			table.insert(result, string.format("<div class='instruction' data-node='ast-node-%s'>", getNearestNode(i)))
			table.insert(result, string.format("<div class='instruction-count'>%i</div>", i))
			table.insert(result, string.format("<div class='instruction-name'>%s</div>", names[op]))
			table.insert(result, string.format("<div class='instruction-arg'>%i</div>", arg1))
			table.insert(result, string.format("<div class='instruction-arg'>%i</div>", arg2))
			table.insert(result, "</div>")
		end
		return table.concat(result)
	end

	local function makeBody(data)
		nid = 0

		return string.format([[
			<div id="code-panel" class="panel">%s</div>
			<div id="ast-panel" class="panel">%s</div>
			<div id="bytecode-panel" class="panel">%s</div>
		]],
			renderCode(data.ast),
			renderAST(data.ast),
			renderBytecode(data.bytecode, data.mapping)
		)
	end

	local function saveHTML(dest, data)
		local src = "plume-data/engine/debug/run.html"
		local fsrc  = io.open(src)
		local fdest = io.open(dest, "w")
		fdest:write((fsrc:read("*a"):gsub('%%BODY%%', makeBody(data))))
		fsrc:close()
		fdest:close()
	end

	local function hook(vm)
	end

	plume.debug.run = function (input, output)
		local data = {}

		data.filename = input
		data.code = io.open(input):read('*a')

		local success, result

		data.ast      = plume.parse(data.code, data.filename)
		
		local runtime = plume.obj.runtime()
		local chunk   = plume.obj.macro(data.filename, runtime)

		success, result = pcall(plume.compileFile, data.code, data.filename, chunk, runtime)

		if success then
			data.bytecode = runtime.bytecode
			data.mapping  = runtime.mapping
			success, result, ip = plume.run(runtime, chunk, fileParams)
		else
			return false, result
		end

		saveHTML(output..".html", data)
	end
end