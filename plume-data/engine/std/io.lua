--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function (plume)
	plume.stdio = {}
	function plume.stdio.write(path, content)
		local file = io.open(path, "w")
			if not file then
				return false, "Cannot write file '" .. path .. "'."
			end
			file:write(content)
		file:close()
		return true
	end

	function plume.stdio.read(path)
		local file = io.open(path)
			if not file then
				return false, "Cannot read file '" .. path .. "'."
			end
			local content = file:read("*a")
		file:close()
		return true, content
	end
end