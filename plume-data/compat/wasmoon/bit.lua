--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

bit = {
	band = function (a, b)
		return a & b
	end,
	lshift = function (a, n)
		return a << n
	end,
	rshift = function (a, n)
		return a >> n
	end,
	bor = function (a, b, c)
		return a | b | c
	end
}