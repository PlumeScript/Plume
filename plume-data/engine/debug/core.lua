--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function (plume)
	plume.debug = {}

	require 'plume-data/engine/debug/utils' (plume)
	require 'plume-data/engine/debug/run'   (plume)
end