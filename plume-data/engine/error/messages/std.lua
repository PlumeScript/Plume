--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function(plume)
	function plume.error.joinErrorHint()
		return "Wrong type 'table' for parameter '1' of macro 'join'.\nDid you write `Table.join($t)` instead of `Table.join(...t)`?"
	end
end