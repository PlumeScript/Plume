--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function (plume, context, nodeHandlerTable)
	--- Nothing special to notice: while is translated with 2 label,
	--- one before the check and one at the body end
	nodeHandlerTable.WHILE = function(node)
		local condition = plume.ast.get(node, "CONDITION")
		local body      = plume.ast.get(node, "BODY")
		local uid = context.getUID()

		context.registerLabel(node, "while_begin_"..uid)
		context.toggleConcatOff()
		context.childrenHandler(condition)
		context.toggleConcatPop()
		context.registerGoto(node, "while_end_"..uid, "JUMP_IF_NOT")

		-- Informations used by break/continue
		table.insert(context.loops, {
			begin_label    = "while_begin_"..uid,
			end_label      = "while_end_"..uid,
			contextToClose = 0,
			scopeToClose   = 0,
			insideMacro    = 0,
			insideRaise    = 0
		})

		local lets = context.countLocals(body)
		context.scope(function()
			context.childrenHandler(body)
		end, lets)(body)
			
		context.registerGoto(node, "while_begin_"..uid)
		context.registerLabel(node, "while_end_"..uid)

		table.remove(context.loops)
	end

	--- For create two scopes: one that lives the iterator,
	--- and another recreated at each iteration.
	nodeHandlerTable.FOR = function(node)
		local varlist = plume.ast.get(node, "VARLIST")
		local iterator   = plume.ast.get(node, "ITERATOR")
		local mainBody   = plume.ast.get(node, "BODY")
		local uid = context.getUID()
		
		context.toggleConcatOff() -- Prevent iterator to be converted to string
		context.childrenHandler(iterator) -- Evaluate the iterator expression
		context.toggleConcatPop()

		context.registerOP(node, plume.ops.GET_ITER) -- Get the iterator (meta method iter or default iterator)

		context.scope(function()
			context.registerOP(node, plume.ops.STORE_LOCAL, 0, 1) -- Save the iterator
			context.registerOP(node, plume.ops.STORE_LOCAL, 0, 2) -- Save the state
			context.registerOP(node, plume.ops.STORE_LOCAL, 0, 3) -- Save the flag

			context.registerLabel(node, "for_begin_"..uid)
			context.registerGoto(node, "for_end_"..uid, "FOR_ITER", 1) -- Call iterator to get next(s) value(s)

			context.scope(function()
				context.affectation(node, varlist, nil,-- Store returned value(s) into var(s)
					{
						isLet = true,
						isBodyStacked = true,
						isLoopVariable = true
					}
				)
				
				-- Informations used by break/continue
				table.insert(context.loops, {
					begin_label    = "for_loop_end_"..uid,
					end_label      = "for_end_"..uid,
					leave          = true,
					contextToClose = 0,
					scopeToClose   = 0,
					insideMacro    = 0,
					insideRaise    = 0
				})

				context.childrenHandler(mainBody)
				table.remove(context.loops)
				context.registerLabel(node, "for_loop_end_"..uid)
			end, #varlist.children)(mainBody)

			context.registerGoto (node, "for_begin_"..uid)
			context.registerLabel(node, "for_end_"..uid)
		end, 3)(mainBody)
	end

	-----------------------------------------------------------	
	--- BREAK/CONTINUE are just goto to the last loop end/begin
	-----------------------------------------------------------	
	nodeHandlerTable.CONTINUE = function(node)
		local loop = context.getLast 'loops'
		if not loop or loop.insideMacro>0 then
			plume.error.cannotUseContinueOutsideLoop(node)
		end
		if loop.insideRaise>0 then
			plume.error.cannotUseContinueInsideRaise(node)
		end

		context.safeClose(node, loop)
		context.registerGoto (node, loop.begin_label)
	end
	nodeHandlerTable.BREAK = function(node)
		local loop = context.getLast 'loops'
		if not loop or loop.insideMacro>0 then
			plume.error.cannotUseBreakOutsideLoop(node)
		end
		if loop.insideRaise>0 then
			plume.error.cannotUseBreakInsideRaise(node)
		end

		context.safeClose(node, loop, loop.leave)
		context.registerGoto (node, loop.end_label)
	end
end