--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

-- Wasmoon's `require` bridge returns two values: the module AND its name.
-- Standard Lua require returns one. Multi-value expansion of the last field
-- of a table constructor (e.g. `plume.vmLoaders`) then leaks the name
-- string into the table. Normalize to a single return value.
local realRequire = require

function require(name)
	return (realRequire(name))
end
