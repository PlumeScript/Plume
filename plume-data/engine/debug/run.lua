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

	function escape(str)
		return str:gsub("&", "&amp;")
				  :gsub("<", "&lt;")
				  :gsub(">", "&gt;")
				  :gsub('"', "&quot;")
				  :gsub("'", "&#39;")
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

			table.insert(result, string.format("<div class='instruction' data-node='ast-node-%s' data-ip=%i>", getNearestNode(i), i))
			table.insert(result, string.format("<div class='instruction-count'>%i</div>", i))
			table.insert(result, string.format("<div class='instruction-name'>%s</div>", names[op]))
			table.insert(result, string.format("<div class='instruction-arg'>%i</div>", arg1))
			table.insert(result, string.format("<div class='instruction-arg'>%i</div>", arg2))
			table.insert(result, "</div>")
		end
		return table.concat(result)
	end

	local function renderExecution(log)
		local result = {}
		for i, vm in ipairs(log) do
			if not vm.onlyError then
				table.insert(result, string.format("<div class='vm-step' id='vm-step-%i' data-ip=%i>", i, vm.ip))
				table.insert(result, string.format([[<div class='vm-step-title'>
					Step %i on %i
					<span class='vm-step-select' data-target=1> << </span>
					<span class='vm-step-select' data-target=%i> < </span>
					<span class='vm-step-select' data-target=%i> > </span>
					<span class='vm-step-select' data-target=%i> >> </span>
				</div>]], i, #log, i-1, i+1, #log))

				table.insert(result, "<div class='stacks'>")
					table.insert(result, "<div class='stack-view'>")
						table.insert(result, "<div class='stack-title'>Main Stack</div>")
						table.insert(result, "<div class='stack-content'>")
						for i=1, vm.mainStack.pointer do
							for _, j in ipairs(vm.mainStack.frames) do
								if j==i and _>1  then
									table.insert(result, string.format("<div class='frame-separator'></div>"))
								end
							end
							table.insert(result, string.format("<div class='stack-element'>%s</div>", escape(plume.repr(vm.mainStack[i]))))
						end
						table.insert(result, "</div>")
					table.insert(result, "</div>")
					table.insert(result, "<div class='stack-view'>")
						table.insert(result, "<div class='stack-title'>Variable Stack</div>")
						table.insert(result, "<div class='stack-content'>")
						for i=1, vm.variableStack.pointer do
							for _, j in ipairs(vm.variableStack.frames) do
								if j==i and _>1 then
									table.insert(result, string.format("<div class='frame-separator'></div>"))
								end
							end
							table.insert(result, string.format("<div class='stack-element'>%s</div>", escape(plume.repr(vm.variableStack[i]))))
						end
						table.insert(result, "</div>")
					table.insert(result, "</div>")
				table.insert(result, "</div>")
			end

			if vm.error then
				table.insert(result, string.format("<div class='vm-error'>%s</div>", vm.error:gsub('\n', '<br>')))
			end

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
			<div id="execution-panel" class="panel">%s</div>
		]],
			renderCode(data.ast),
			renderAST(data.ast),
			renderBytecode(data.bytecode, data.mapping),
			renderExecution(data.log)
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

	function deepcopy(orig, seen)
		seen = seen or {}
		
		if type(orig) ~= "table" or seen[orig] then
			return orig
		end
		
		local copy = {}
		seen[orig] = copy
		
		for key, value in pairs(orig) do
			copy[key] = deepcopy(value, seen)
		end
		
		return copy
	end

	local function hook(log)
		return function(vm)
			table.insert(log, deepcopy(vm))
		end
	end

	plume.debug.run = function (input, output)
		local data = {}

		data.filename = input
		data.code = io.open(input):read('*a')

		local success, result

		success, result = pcall(plume.parse, data.code, data.filename)
		
		if success then
			data.ast = result
			local runtime = plume.obj.runtime()
			local chunk   = plume.obj.macro(data.filename, runtime)

			success, result = pcall(plume.compileFile, data.code, data.filename, chunk, runtime)

			if success then
				data.bytecode = runtime.bytecode
				data.mapping  = runtime.mapping
				data.log = {}
				plume.hook = hook(data.log)
				plume.runDevFlag = true
				success, result, ip = plume.run(runtime, chunk, fileParams)

				if not success then
					local last = data.log[#data.log]
					last.error = plume.error.makeRuntimeError(runtime, ip, result)
				end
			else
				data.ast = {code=data.code, bpos=1, epos=#data.code, name="", type=""}
				data.bytecode = {}
				data.log = {{error=result, onlyError=true}}
			end
		else
			data.ast = {code=data.code, bpos=1, epos=#data.code, name="", type=""}
			data.bytecode = {}
			data.log = {{error=result, onlyError=true}}
		end

		saveHTML(output..".html", data)
	end
end