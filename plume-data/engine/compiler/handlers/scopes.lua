--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function (plume, context, nodeHandlerTable)
	nodeHandlerTable.FILE = context.file(function(node)
		local doc = context.collectFileComments(node)
		local lets = context.countLocals(node)
		local fileUID = context.getUID()
		local endLabel = "macro_end"..fileUID

		context.enterScope(lets, true)
			local fileInfos = {
				isFile         = true,
				node           = node,
				body           = node,
				scopeDeep      = 1,
				contextToClose = 0,
				blockToClose   = {},
				insideRaise    = 0,
				insideLetset   = 0,
				insideCall     = 0,
				endLabel       = endLabel,
				accBlockDeep   = 1
			}
			context.append("macros",fileInfos)
				context.append("accBlock",fileInfos)
					context.accBlock(nil, {
						{"name", node.filename},
						{"doc", doc}
					})(node, endLabel)
				context.remove("accBlock")
			context.remove("macros")
		context.leaveScope()

		if context.isMain then
			context.registerOP(node, plume.ops.FORCE_FRAGMENT)
		end
	end)

	nodeHandlerTable.RUN = function(node)
		context.accBlock(function(node)
			context.childrenHandler(node)
		end)(node)
		context.registerOP(node, plume.ops.STORE_VOID)
	end

	nodeHandlerTable.DO = function(node)
		local loop = context.getLast "loops"
		
		if loop then
			loop.insideDo = loop.insideDo + 1
		end

		local uid = context.getUID()
		local label = "do_end_" .. uid
		context.append("accBlock", {uid=uid, endLabel=label, scopeDeep = #context.scopes+1})

		local body = plume.ast.get(node, "BODY")
		context.scope(function()
			if body.type == "TABLE" or body.isUnic then
				context.childrenHandler(body)
			else
				context.accBlock()(body, nil, label)
			end
		end)(body)

		context.remove("accBlock")

		if loop then
			loop.insideDo = loop.insideDo - 1
		end

		if context.checkIfCanConcat() and node.type ~= "EMPTY" then
			context.registerOP(node, plume.ops.CHECK_IS_TEXT)
		end
	end

	nodeHandlerTable.WITH = function(node)
		if node.parent and node.parent.type == "TEXT" and node.type == "TABLE" then
			plume.error.withTableMuseBeAlone(node)
		end

		local body   = plume.ast.get(node, "BODY")
		local params = plume.ast.get(node, "PARAMLIST")

		context.accBlock()(params)

		context.registerOP(node, plume.ops.PUSH_CONTEXT)

		local macro = context.getLast "macros"
		local loop  = context.getLast "loops"
		if macro then
			macro.contextToClose = macro.contextToClose + 1
		end
		if loop and loop.contextToClose then
			loop.contextToClose  = loop.contextToClose + 1
		end

		if body.type == "TABLE" or body.isUnic then
			context.childrenHandler(body)
		else
			context.accBlock()(body)
		end

		if macro then
			macro.contextToClose = macro.contextToClose - 1
		end
		if loop and loop.contextToClose then
			loop.contextToClose  = loop.contextToClose - 1
		end
		
		context.registerOP(node, plume.ops.POP_CONTEXT)

		if context.checkIfCanConcat() and node.type ~= "EMPTY" then
			context.registerOP(node, plume.ops.CHECK_IS_TEXT)
		end
	end

	nodeHandlerTable.RAISE = function(node)
		local macro = context.getLast "macros"
		local loop  = context.getLast "loops"

		if loop then
			loop.insideRaise = loop.insideRaise+1
		end
		if macro then
			macro.insideRaise = macro.insideRaise+1
		end

		context.accBlock(function(node)
			context.childrenHandler(node)
		end)(node)
		if loop then
			loop.insideRaise = loop.insideRaise-1
		end
		if macro then
			macro.insideRaise = macro.insideRaise-1
		end
		
		context.safeClose(node, macro)
		context.safeClose(node, loop, loop and loop.leave)
		
		context.registerOP(node, plume.ops.FORCE_FRAGMENT)
		context.registerOP(node, plume.ops.CHECK_IS_TEXT)
		context.registerOP(node, plume.ops.RAISE)
	end
end