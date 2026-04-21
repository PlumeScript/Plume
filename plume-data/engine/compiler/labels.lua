--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function (plume, context)
	--- Insert a label. Serves as the basis for plume.finalize to calculate
	--- the offset of goto statements. Does not appear in the final bytecode.
	--- @param node node Emiting node
	--- @param name string Unique name of this label
	--- @param link number Will set `runtime.constants[link].offset`
	----				   to the final position of this label
	function context.registerLabel(node, name, link)
		local current = context.runtime.instructions
		table.insert(current, {label=name, mapsto=node, link=link})
	end

	--- Insert a goto. Will be resolved as a JUMP opcode, to the offset
	--- determined by the label with the same name.
	--- @param node node Emiting node
	--- @param name string Unique name of this label
	--- @param jump string|nil Jump method to use. Default to JUMP.
	--- Can be: JUMP_IF JUMP_IF_NOT JUMP_IF_NOT_EMPTY JUMP JUMP_IF_PEEK JUMP_IF_NOT_PEEK
	function context.registerGoto(node, name, jump)
		local current = context.runtime.instructions
		table.insert(current, {_goto=name, jump=jump or "JUMP", mapsto=node})
	end
end