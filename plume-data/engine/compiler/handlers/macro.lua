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
		local endLabel = "macro_body_end_" .. uid

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
		macroObj.accDeep = context.accBlockDeep
		macroObj.accBlockDeep = context.accBlockDeep + 1
		macroObj.endLabel = endLabel
		macroObj.signatureRef = paramList
		context.append("macros", macroObj)
		context.append("accBlock", macroObj)

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
			local lasRef = context.getLast "ref"
			if lasRef then
				lasRef.insideMacro = lasRef.insideMacro+1
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
							
							plume.error.cannotAddFlagAfterVariadic(paramNode)
						else
							plume.error.cannotAddNamedAfterVariadic(paramNode)
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
			if not context.getVariable(node, "self", true) then
				local param = context.registerVariable(nil, "self", {isSelf=true})
				macroObj.namedParamCount = macroObj.namedParamCount+1
				macroObj.namedParamOffset.self = param.offset
			end

			context.accBlock()(body, endLabel) -- Handle the macro body
			
			macroObj.localsCount = #context.getCurrentScope()

			context.leaveScope(nil)

			if lastLoop then
				lastLoop.insideMacro = lastLoop.insideMacro-1
			end
			local lasRef = context.getLast "ref"
			if lasRef then
				lasRef.insideMacro = lasRef.insideMacro-1
			end
			
		end) ()
		context.registerOP(node, plume.ops.RETURN, 0, 0)

		context.registerLabel(node, "macro_declaration_end_" .. uid)
		context.remove("accBlock")
		context.remove("macros")
		-- Not used by the runtime
		macroObj.uid = nil
		macroObj.upvalueMap = nil
	end

	nodeHandlerTable.ANONYMOUS_MACRO = nodeHandlerTable.MACRO

	nodeHandlerTable.LEAVE = function(node)
		local parent = context.getLast "accBlock"
		local macro  = context.getLast "macros"

		if parent.body and parent.body.isUnic then
			plume.error.leaveInValueBlock(node)
		end
		if macro.insideRaise>0 then
			plume.error.cannotUseLeaveInsideRaise(node)
		end
		
		-- Messy: `do` doesn't provide node field, but handle itself this case...
		if parent.node and parent.node.type == "TEXT" then
			context.registerOP(node, plume.ops.LOAD_CONSTANT, 0, context.registerConstant(""))
		end

		parent.scopeToClose = #context.scopes - parent.scopeDeep
		context.safeClose(node, parent)

		local uid = parent and parent.uid
		context.registerGoto(node, parent.endLabel)
	end

	nodeHandlerTable.RETURN = function(node)
		local parent = context.getLast "macros"

		if parent.insideRaise>0 then
			plume.error.cannotUseReturnInsideRaise(node)
		end
		if parent.insideLetset>0 then
			plume.error.cannotUseReturnInsideLetset(node)
		end
		if parent.insideCall>0 then
			plume.error.cannotUseReturnInsideCall(node)
		end

		-- Evaluate the returned value (or nothing) on the stack
		context.accBlock(function(node)
			context.childrenHandler(node)
		end)(node)

		parent.scopeToClose = #context.scopes - parent.scopeDeep
		context.safeClose(node, parent)

		context.registerGoto(node, parent.endLabel)
	end
end