--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function(plume)

	function plume.obj.table(listSlots, hashSlots)
		local t
		t = {
			type = "table",
			table = table.new(listSlots, hashSlots),
			keys = table.new(hashSlots, 0),
			setItem = function(self, k, v)
				if not self.table[k] then
					table.insert(self.keys, k)
				end
				self.table[k] = v

			end,
			getMetaItem = function(self, k)
				if self.meta then
					return self.meta.table[k]
				end
			end,
			setMetaItem = function(self, k, v)
				if not self.meta then
					self.meta = plume.obj.table(0, 1)
				end
				self.meta:setItem(k, v)
			end,
			addItem = function(self, v)
				self:setItem(#self.table + 1, v)
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

end