--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function(plume)
	plume.obj = {}
	plume.obj.empty = {type = "empty"}

	require 'plume-data/engine/objects/table'      (plume)
	require 'plume-data/engine/objects/fragment'   (plume)
	require 'plume-data/engine/objects/context'    (plume)
	require 'plume-data/engine/objects/macro'      (plume)
	require 'plume-data/engine/objects/runtime'    (plume)
	require 'plume-data/engine/objects/utils'      (plume)
	require 'plume-data/engine/objects/vm'         (plume)
end