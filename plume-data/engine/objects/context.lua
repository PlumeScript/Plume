--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function(plume)
	
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
	
end