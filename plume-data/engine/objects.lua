--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function(plume)
	plume.obj = {}
	plume.obj.empty = {type = "empty"}

	--- lua fonction take 1 parameter: the plume table of all given arguments
	function plume.obj.luaMacro (name, f)
		return {
			type = "luaMacro",
			callable = f,
			name = name -- optionnal
		}
	end

	function plume.obj.table (listSlots, hashSlots)
		local t
		t = {
			type = "table", --type
			table = table.new(listSlots, hashSlots),
			keys = table.new(hashSlots, 0),
			setItem = function (self, k, v)
				if not self.table[k] then
					table.insert(self.keys, k)
				end
				self.table[k] = v
				
			end,
			getMetaItem = function (self, k)
				if self.meta then
					return self.meta.table[k]
				end
			end,
			setMetaItem = function (self, k, v)
				if not self.meta then
					self.meta = plume.obj.table(0, 1)
				end
				self.meta:setItem(k, v)
			end,
			addItem = function (self, v)
				self:setItem(#self.table+1, v)
			end
		}
		return t
	end

	function plume.obj.quickTable(source)
		local t = plume.obj.table(#source, 0)

		for _, v in ipairs(source) do
			if type(v) == "table" and not v.type then
				v = plume.obj.quickTable(v)
			end

			t:addItem(v)
		end

		for k, v in pairs(source) do
			if not tonumber(k) then
				if type(v) == "table" and not v.type then
					v = plume.obj.quickTable(v)
				end
				t:setItem(k, v)
			end
		end

		return t
	end

	function plume.obj.macro(name, parent)
		local t = {
			type   = "macro",
			name   = name,
			positionalParamCount = 0,
			namedParamCount      = 0,
			namedParamOffset     = {},
			parent               = parent,
			isFile               = parent.type == "runtime",
			doc                  = "",
			upvalues             = {} -- Variables that should be captured
			-- offset = offset -- Offset is set by the linker
		}

		if t.isFile then
			table.insert(parent.files, t)
			parent.files[name] = t
			t.fileID = #parent.files
		end
		
		return t
	end

	function plume.copyMacrosInfos(src, dest)
		dest.positionalParamCount = src.positionalParamCount
		dest.namedParamCount = src.namedParamCount
		dest.namedParamOffset = src.namedParamOffset
		dest.offset = src.offset
	end

	local function makePlumeTable()
		local result = plume.obj.table(0, 2)

		local pathTable = plume.obj.table(0, 0)
		for path in (os.getenv("PLUME_PATH") or ""):gmatch('[^;]+') do
			pathTable:addItem(path)
		end
		result:setItem("path", pathTable)
		for _, key in ipairs(plume.std.plume.keys) do
			result:setItem(key, plume.std.plume.table[key])
		end

		result:setItem("locale", plume.obj.context(plume.obj.empty))
		result:setItem("localeNumberFormat", plume.obj.context(plume.obj.empty))
		result:setItem("localeThousandsSeparator",  plume.obj.context(plume.obj.empty))
		result:setItem("localeDecimalSeparator",  plume.obj.context(plume.obj.empty))
		result:setItem("localeThousandthsSeparator",  plume.obj.context(plume.obj.empty))
		return result
	end

	function plume.obj.runtime()
		-----------------------------------------
		--- Not very clean
		--- In theory, there is only one runtime per execution,
		---- so this should not pose a problem in the short term.
		plume.lastErrorInfos = nil
		plume.warning.cache = {}
		plume.warning.any = false
		plume.warning.mode = {
			default={global="normal"},
			["381"]={global="ignore"} -- helper warnings
		}
		plume.currentUseProcessing = {}
		-----------------------------------------

		return {
			type = "runtime",
			instructions         = {},
			insert               = {},
			linkedInstructions   = {},
			bytecode             = {},
			constants            = {},
			mapping              = {},
			callstack            = {},
			files                = {},
			cache                = {chunks={}, results={}},
			contextCount         = 0, -- used to generate a unique UID for each compilation
			plume                = makePlumeTable()
		}
	end

	function plume.obj.context(default)
		return {
			values = {default},
			push = function(self, value)
				table.insert(self.values, value)
			end,
			pop = function(self)
				table.remove(self.values)
			end,
			get = function(self)
				return self.values[#self.values] or plume.obj.empty
			end,
			type = "context"
		}
	end

	local function toint(x)
		local n = tonumber(x)
		return n and n == math.floor(n) and n
	end

	local function isShortTable(t)
		local l = 0
		for k, v in pairs(t.table) do
			if type(k) == "table" or type(v) == "table" then
				return false
			end
			if type(k) ~= "number" then
				l = l + #tostring(k)
			end
			l = l + #tostring(v)
		end

		return l<80
	end

	local function reprTable(t, acc, pretty, indent)
		acc[t] = true

		local result = {}
		local ordered = true
		local lastIndex = 0
		indent = indent or 0

		local itemsCount = 0
		local valueCount = 0

		pretty = pretty and not isShortTable(t)
		for _, key in ipairs(t.keys) do
			local value = plume.repr(t.table[key], acc, pretty, indent+1)
			local index = toint(key)
			if index then
				itemsCount = itemsCount + 1
				if ordered then
					if index < lastIndex or index > lastIndex+2 then
						ordered = false
					else
						for _=1, index-lastIndex-1 do
							table.insert(result,  "empty")
						end
						lastIndex = index
					end
				end

				if ordered then
					if pretty then
						value = "- " .. value
					end
					table.insert(result, value)
				else
					
					table.insert(result, string.format("%s: %s", key, value))
				end
			else
				valueCount = valueCount + 1
				local rkey = plume.repr(key, acc)
				table.insert(result, string.format("%s: %s", rkey, value))
			end
		end
		
		if pretty then
			return string.format("do\n%s%s\n%send",
				("  "):rep(indent+1),
				table.concat(result, "\n"..("  "):rep(indent+1)),
				("  "):rep(indent)
			)
		else
			local prefix = "$Table"
			local inline = itemsCount>1 or valueCount>0
			if inline then
				prefix = ""
			end
			return string.format("%s(%s)", prefix, table.concat(result, ", "))
		end
	end

	local function reprObj(obj, pretty, indent)
		indent = indent or 0
		if type(obj) == "string" and pretty and #obj > 80 then
			local result = {"do"}
			for i=1, #obj/80+1 do
				local line = obj:sub((i-1)*80+1, i*80)
				line = line:gsub('^ ', '\\s'):gsub(' $', '\\s')
				table.insert(result, line)
			end
			return table.concat(result, "\n"..("  "):rep(indent+1)) .. "\n"..("  "):rep(indent) .. "end"
		else
			return tostring(obj)
		end
	end

	function plume.repr(obj, acc, pretty, indent)
		acc = acc or {}
		if type(obj) ~= "table" then
			return reprObj(obj, pretty, indent)
		end

		local t = obj.type or "???"
		if t == "empty" then
			return "empty"
		elseif t == "luaMacro" or t == "stdMacro" or t == "macro" then
			return t .. "<" .. obj.name .. ">"
		elseif t == "closure" then
			return "macro<" .. (obj.macro.name or "???") .. ">"
		elseif t == "table" then
			if acc[obj] then
				return "$Table(...)"
			else
				return reprTable(obj, acc, pretty, indent)
			end
		elseif t == "context" then
			local values = {}
			for _, value in ipairs(obj.values) do
				table.insert(values, plume.repr(value))
			end
			return string.format("Context<%s>", table.concat(values, ", "))
		else
			return t.."Obj<"..(t.name or "???")..">"
		end
	end

end