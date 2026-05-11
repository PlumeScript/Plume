--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

math.mod = math.fmod
math.pow = function (x, y)
	return x^y
end
math.atan2 = function (x, y)
	return math.atan(y/x)
end