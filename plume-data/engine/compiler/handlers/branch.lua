--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function (plume, context, nodeHandlerTable)
	--- Nothing special to notice: if-elseif-else are translated into
	--- a sequence of jumps.
	--- A jump before the branch bodies if the condition is not verified
	--- A jump after the bodies to go to the end
	nodeHandlerTable.IF = function(node)
		local condition = plume.ast.get(node, "CONDITION")
		local body      = plume.ast.get(node, "BODY")
		local _elseif   = plume.ast.getAll(node, "ELSEIF")
		local _else     = plume.ast.get(node, "ELSE")
		local uid = context.getUID()

		--------------------------------------------
		-- Special case: if inside a VALUE block,
		-- create an ELSE branch to emit LOAD_EMPTY
		local specialValueMode = (
			node.parent.type == "VALUE"
			and node.type ~= "EMPTY"
		)

		local _else_body
		if specialValueMode then
			if not _else then
				_else_body = {type="EMPTY"}
			end
		end
		--------------------------------------------

		local branchs = {body, condition}
		for _, child in ipairs(_elseif) do
			local condition = plume.ast.get(child, "CONDITION")
			local body      = plume.ast.get(child, "BODY")

			table.insert(branchs, body)
			table.insert(branchs, condition)
		end

		if _else then
			local body = plume.ast.get(_else, "BODY")
			table.insert(branchs, body)
		elseif _else_body then
			table.insert(branchs, _else_body)
		end

		local finalBranch = #branchs+1
		for i=1, #branchs, 2 do
			local body = branchs[i]
			local condition = branchs[i+1]
			context.registerLabel(node, "branch_"..i.."_"..uid)
			if condition then
				context.toggleConcatOff()
				context.childrenHandler(condition)
				context.toggleConcatPop()
				context.registerGoto(node, "branch_"..(i+2).."_"..uid, "JUMP_IF_NOT")
			end
			if body.type == "TEXT" then
				context.scope(context.accBlock())(body)
			else
				context.scope()(body)
			end
			if specialValueMode and body.type == "EMPTY" then
				if not context.checkIfCanConcat() then
					context.registerOP(node, plume.ops.LOAD_EMPTY)
				end
			end

			context.registerGoto(node, "branch_"..finalBranch.."_"..uid)
		end

		context.registerLabel(node, "branch_"..finalBranch.."_"..uid)
	end
end