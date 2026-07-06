--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function (plume, context, nodeHandlerTable)
	nodeHandlerTable.MACRO = function(node)
		local macroIdentifier = plume.ast.get(node, "NAME")
		local body            = plume.ast.get(node, "BODY")
		local paramList       = plume.ast.get(node, "PARAMLIST") or {children={}}
		local uid = context.getUID()

		local doc = context.collectComments(node)
		if doc == "" then
			context.macroWithoutDocWarning(node)
		end

		-- If the macro is named, save them in the local scope
		-- `macro wing()` is a sugar for `let wing = macro()`
		local macroName = macroIdentifier and macroIdentifier.content
		-- node.label is a debug informations for macro declared as table field
		local debugMacroName = macroName or node.label
		-- Case let x = macro
		if not debugMacroName then
			local parent = node.parent and node.parent.parent
			if parent and (parent.name == "SET" or parent.name == "LET") then
				local varlist    = plume.ast.get(parent, "VARLIST")
				local identifier = plume.ast.get(varlist, "NAME")
				debugMacroName = identifier and identifier.content
			end
		end
		if not debugMacroName then
			debugMacroName = "???"
		end

		-- Save name in the node
		node.debugMacroName = debugMacroName

		local macroObj     = plume.obj.macro(debugMacroName, context.chunk)
		local macroOffset  = context.registerConstant(macroObj)
		macroObj.uid = uid
		macroObj.upvalueMap = {}
		macroObj.node = node
		macroObj.body = body
		macroObj.doc  = doc
		macroObj.insideRaise = 0
		macroObj.insideLetset = 0
		macroObj.insideCall = 0
		macroObj.contextToClose = 0
		macroObj.blockToClose   = {}
		macroObj.scopeDeep = #context.scopes+1
		context.append("macros", macroObj)

		context.registerOP(macroIdentifier or node, plume.ops.LOAD_CONSTANT, 0, macroOffset)
		context.registerOP(macroIdentifier or node, plume.ops.CLOSURE)

		if macroName then
			local variable = context.registerVariable(node, macroName, {isMacro=true})
			if not variable then
				plume.error.letExistingVariable(node, macroName, context.getNameSource(macroName))
			end
			
			context.registerOP(macroIdentifier, plume.ops.STORE_LOCAL, 0, variable.offset)
		end


		-- Skip macro body
		context.registerGoto(node, "macro_declaration_end_" .. uid)

		-- Anchor point to find macro beginings
		context.registerLabel(node, "macro_begin_" .. uid, macroOffset)

		context.file(function ()
			context.enterScope(nil)

			--- Used to prevent break inside a macro inside a loop
			local lastLoop = context.getLast "loops"
			if lastLoop then
				lastLoop.insideMacro = lastLoop.insideMacro+1
			end

			-------------------------------------------------------------
			--- Count arguments, save variadic offset
			--- and evaluate default value when optionnal args are empty.
			-------------------------------------------------------------
			local passFlag

			for i, paramNode in ipairs(paramList.children) do
				local paramNameNode      = plume.ast.get(paramNode, "NAME", 1, 2)
										or plume.ast.get(paramNode, "IDENTIFIER", 1, 2) -- for variadics
										
				local paramValidatorNode = plume.ast.get(paramNode, "VALIDATOR")
				local variadic           = plume.ast.get(paramNode, "VARIADIC")
				local paramBody          = plume.ast.get(paramNode, "BODY")
				
				local paramName      = paramNameNode.content

				local param = context.registerVariable(paramNameNode, paramName, {isMacroParam=true})
				if not param then
					plume.error.cannotUseMultipleParamName(paramNode, paramName)
				end

				if paramName == "self" then
					plume.error.cannotUseSelfAsParam(paramNameNode)
				end
				if paramBody then
					if macroObj.variadicOffset then
						if paramNode.isFlag then
							plume.error.cannotAddNamedAfterVariadic(paramNode)
						else
							plume.error.cannotAddFlagAfterVariadic(paramNode)
						end
					end
					if passFlag and not paramNode.isFlag then
						plume.error.cannotAddNamedAfterFlag(paramNode)
					end
					passFlag = paramNode.isFlag

					context.registerOP(paramNode, plume.ops.LOAD_LOCAL, 0, i)
					context.registerGoto(paramNode, "macro_var_" .. i .. "_" .. uid, "JUMP_IF_NOT_EMPTY")
					context.accBlock()(paramBody)
					context.registerOP(paramNode, plume.ops.STORE_LOCAL, 0, i)
					context.registerLabel(paramNode, "macro_var_" .. i .. "_" .. uid)

					macroObj.namedParamCount = macroObj.namedParamCount+1
					macroObj.namedParamOffset[paramName] = param.offset
				elseif variadic then
					if macroObj.variadicOffset then
						plume.error.cannotUseMultipleVariadic(variadic)
					else
						macroObj.variadicOffset = param.offset
					end
				else
					if macroObj.namedParamCount > 0 then
						if passFlag then
							plume.error.cannotAddPositionalAfterFlag(paramNode)
						else
							plume.error.cannotAddPositionalAfterNamed(paramNode)
						end
					end
					if macroObj.variadicOffset then
						plume.error.cannotAddPositionalAfterVariadic(paramNode)
					end
					macroObj.positionalParamCount = macroObj.positionalParamCount+1
				end

				if paramValidatorNode then
					context.registerOP(paramNode, plume.ops.BEGIN_ACC, 0, 0)   -- Prepare call
					context.registerOP(paramNode, plume.ops.LOAD_LOCAL, 0, i)  -- load value
					context.nodeHandler(paramValidatorNode)                    -- Load validator
					context.registerOP(paramNode, plume.ops.CONCAT_CALL, 1, 0) -- call
					context.registerOP(paramNode, plume.ops.STORE_LOCAL, 0, i) -- save
				end
			end
			-- Always register self parameter.
			-- If the macro is called as a table field, `self`
			-- is a reference to this table.
			-- Else is empty
			if not context.getVariable("self", true) then
				local param = context.registerVariable(nil, "self", {isSelf=true})
				macroObj.namedParamCount = macroObj.namedParamCount+1
				macroObj.namedParamOffset.self = param.offset
			end

			context.accBlock()(body, "macro_body_end_" .. uid) -- Handle the macro body
			
			macroObj.localsCount = #context.getCurrentScope()

			context.leaveScope(nil)

			if lastLoop then
				lastLoop.insideMacro = lastLoop.insideMacro-1
			end
			
		end) ()
		context.registerOP(node, plume.ops.RETURN, 0, 0)

		context.registerLabel(node, "macro_declaration_end_" .. uid)
		context.remove("macros")
		-- Not used by the runtime
		macroObj.uid = nil
		macroObj.upvalueMap = nil
	end

	nodeHandlerTable.ANONYMOUS_MACRO = nodeHandlerTable.MACRO

	nodeHandlerTable.LEAVE = function(node)
		local macro = context.getLast "macros"

		if macro.body.isUnic then
			plume.error.leaveInValueBlock(node)
		end
		
		if macro.node.type == "TEXT" then
			context.registerOP(node, plume.ops.LOAD_CONSTANT, 0, context.registerConstant(""))
		end

		if macro.insideRaise>0 then
			plume.error.cannotUseLeaveInsideRaise(node)
		end
		if macro.insideLetset>0 then
			plume.error.cannotUseLeaveInsideLetset(node)
		end
		if macro.insideCall>0 then
			plume.error.cannotUseLeaveInsideCall(node)
		end

		macro.scopeToClose = #context.scopes - macro.scopeDeep
		context.safeClose(node, macro)

		local uid = macro and macro.uid
		if uid then
			context.registerGoto(node, "macro_body_end_" .. uid)
		else
			context.registerGoto(node, "macro_end")
		end
	end
end