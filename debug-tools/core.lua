--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function (plume)
	plume.debug = {}

	require 'debug-tools/utils' (plume)
	require 'debug-tools/run'   (plume)
end