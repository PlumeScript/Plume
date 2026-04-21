--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function(plume)
	------------------------
    -- Instruction format --
    ------------------------
    local bit = require("bit")
    plume.OP_BITS   = 7
    plume.ARG1_BITS = 5
    plume.ARG2_BITS = 20
    plume.ARG1_SHIFT = plume.ARG2_BITS
    plume.OP_SHIFT   = plume.ARG1_BITS + plume.ARG2_BITS
    plume.MASK_OP   = bit.lshift(1, plume.OP_BITS) - 1
    plume.MASK_ARG1 = bit.lshift(1, plume.ARG1_BITS) - 1
    plume.MASK_ARG2 = bit.lshift(1, plume.ARG2_BITS) - 1
    ------------------------
end