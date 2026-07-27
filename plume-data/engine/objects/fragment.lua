--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function(plume)

	function plume.obj.fragment(count)
		local fragment = table.new(count, 1)
		fragment.type = "fragment"
		return fragment
	end

end