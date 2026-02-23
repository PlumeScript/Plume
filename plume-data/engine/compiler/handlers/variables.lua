--[[This file is part of Plume

Plume🪶 is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3 of the License.

Plume🪶 is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with Plume🪶.
If not, see <https://www.gnu.org/licenses/>.
]]

return function (plume, context, nodeHandlerTable)

	--- Check if variable exists, and load it from appropriate scope
	--- @param node table The current AST node
	nodeHandlerTable.IDENTIFIER = function(node)
		local varName = node.content
		local var, ref = context.getVariable(varName)
		if not var then
			plume.error.useUnknownVariableError(node, varName, ref)
		end
		if var.isRef then
			context.registerOP(node, plume.ops.LOAD_CONSTANT, 0, context.registerConstant(var.ref))
			context.registerOP(node, plume.ops.LOAD_REF, var.frameOffset, 0)
		elseif var.isUpvalue then
			context.registerOP(node, plume.ops.LOAD_UPVALUE, 0, var.offset)
		elseif var.isStd then
			context.registerOP(node, plume.ops.LOAD_CONSTANT, 0, var.offset)
		elseif var.isContext then
			context.registerOP(node, plume.ops.LOAD_CONSTANT, 0, context.registerConstant(varName))
			context.registerOP(node, plume.ops.LOAD_CONTEXT)
		else
			context.registerOP(node, plume.ops.LOAD_LOCAL, var.frameOffset, var.offset)
		end
	end

	--- Analyzes a target node (variable or index) and prepares its internal structure
	--- @param node node The main statement node
	--- @param varNode node The specific node representing the target being assigned
	--- @param isLet boolean    If it's a declaration
	--- @param isConst boolean
	--- @param isParam boolean
	--- @param isFrom boolean If using object destructuring
	--- @param isContext boolean True if a bind to context
	--- @return table rvar The resolved variable object containing scope information and metadata
	local function resolveAssignmentTarget(node, varNode, isLet, isConst, isParam, isFrom, isContext)
		local rvar, isRef
		
		----------------------------------------------------------
		--- Case 1: Variable assignment
		--- `let name [= value]`
		--- `set name = value`
		--- `let key [as name] [:defaultValue] from `
		----------------------------------------------------------
		if varNode.name == "IDENTIFIER" or varNode.name == "ALIAS" or varNode.name == "DEFAULT" or varNode.name == "ALIAS_DEFAULT" then
			local key, name, default
			
			-- Extracting names and keys based on node type
			if varNode.name == "IDENTIFIER" then
				key = varNode.content
				name = varNode.content
			elseif varNode.name == "DEFAULT" then
				key = varNode.children[1].content
				name = key
				default = varNode.children[2]
			elseif varNode.name == "ALIAS" then
				key = varNode.children[1].content
				name = varNode.children[2].content
			elseif varNode.name == "ALIAS_DEFAULT" then
				key = varNode.children[1].content
				name = varNode.children[2].content
				default = varNode.children[3]
			else -- guards against typo
				error("Internal error: unknown type '" .. (varNode.name or "") .. "' inside affectation.")
			end

			if default and not isFrom then
				plume.error.cannotUseDefaultValueWithoutFrom(varNode)
			end

			local source = context.getNameSource(name)

			-- Handle declaration (LET) or affectation (SET)
			if isLet then
				rvar, definitionVar = context.registerVariable(node, name, isConst, isParam, nil, nil, nil, isContext)
				if not rvar then
					if definitionVar.isSelf then
						plume.error.letExistingSelfVariableError(node)
					else
						plume.error.letExistingVariableError(node, name, source, definitionVar.node)
					end
				end
			else
				rvar, ref = context.getVariable(name)
				if not rvar then
					plume.error.setUnknownVariableError(node, name, ref)
				elseif rvar.isConst or rvar.isStd then
					plume.error.setConstantVariableError(node, name, source, rvar.node)
				elseif rvar.isContext then
					plume.error.setContextVariableError(node, name)
				end
			end
			rvar.key = key
			rvar.default = default

		----------------------------------------------------------
		--- Case 2: Array/Object index assignment (SETINDEX) 
		--- `set wing.nib = value`
		--- `set wing[1] = value`
		---------------------------------------------------------- 
		elseif varNode.name == "SETINDEX" then
			-- The last index should be detected by the parser, and not modified here.
			local last = varNode.children[#varNode.children]
			if last.name == "INDEX" or last.name == "DIRECT_INDEX" then
				varNode.children[#varNode.children] = nil
				varNode.name = "EVAL"

				rvar = {}
				rvar.ref = varNode.children
				
				--- Function to generate bytecode for retrieving the key and the table
				rvar.getKey = function()
					if last.name == "DIRECT_INDEX" then
						local key = context.registerConstant(last.children[1].content)
						context.registerOP(node, plume.ops.LOAD_CONSTANT, 0, key)
					else
						context.childrenHandler(last) -- key
					end
					context.toggleConcatOff() -- prevent value from being checked against text type
					context.nodeHandler(varNode) -- table
					context.toggleConcatPop()
				end
			else
				plume.error.cannotSetCallError(node)
			end
		end

		rvar.ref = varNode
		return rvar
	end

	--- Generates bytecode for assignment, destructuring, and storage
	--- @param node node The current AST node
	--- @param varlist table List of resolved variables to process
	--- @param body table The expression/value being assigned (RHS)
	--- @param isLet boolean If it's a declaration
	--- @param isParam boolean
	--- @param isFrom boolean If using object destructuring
	--- @param compound table Node representing compound operators like +=
	--- @param isBodyStacked boolean True if the value is already on the stack
	--- @param isContext boolean True if a bind to context
	local function generateAssignmentBytecode(node, varlist, body, isLet, isParam, isFrom, compound, isBodyStacked, isContext)
		if not (body or isBodyStacked) then
			return
		end

		local dest = #varlist > 1

		if dest and compound then
			plume.error.compoundWithDestructionError(node)
		end

		-- Generate RHS code
		if not compound and not isBodyStacked then
			context.scope(context.accBlock())(body)
		end
			
		for i, var in ipairs(varlist) do
			local uid = context.getUID()
			
			-- Handle optional parameters (skip storage if value is provided/peeked)
			if isParam then
				context.registerOP(node, plume.ops.LOAD_LOCAL, 0, var.offset)
				context.registerGoto(node, "param_end_"..uid, "JUMP_IF_PEEK")
				context.registerOP(nil, plume.ops.STORE_VOID)
			end

			-- Handle compound assignment (+=, -=, etc.)
			if compound then
				if var.getKey then
					var.getKey()
					context.registerOP(node, plume.ops.TABLE_INDEX)
				else
					context.nodeHandler(var.ref)
				end
				context.scope(context.accBlock())(body)
				context.registerOP(var.ref, plume.ops["OP_" .. compound.children[1].name])
			end

			-- Handle object destructuring (FROM)
			if isFrom then
				if i < #varlist then
					context.registerOP(nil, plume.ops.DUPLICATE)
				end
				context.registerOP(var.ref, plume.ops.LOAD_CONSTANT, 0, context.registerConstant(var.key))
				context.registerOP(nil, plume.ops.SWITCH)
				if var.default then
					context.registerOP(nil, plume.ops.TABLE_INDEX, 1, 0) -- 1 → safemode
					local defUid = context.getUID()
					context.registerGoto(node, "default_end_"..defUid, "JUMP_IF_PEEK")
					context.registerOP(nil, plume.ops.STORE_VOID)
					context.scope(context.accBlock())(var.default)
					context.registerLabel(node, "default_end_"..defUid)
				else
					context.registerOP(nil, plume.ops.TABLE_INDEX, 0, 0)
				end

			-- Handle array destructuring (Multiple assignment)
			elseif dest then
				if i < #varlist then
					context.registerOP(nil, plume.ops.DUPLICATE, 0, 0)
				end
				context.registerOP(nil, plume.ops.LOAD_CONSTANT, 0, context.registerConstant(i))
				context.registerOP(nil, plume.ops.SWITCH, 0, 0)
				context.registerOP(nil, plume.ops.TABLE_INDEX)
			end

			-- Final storage of the value
			if var.getKey then
				var.getKey()
				context.registerOP(node, plume.ops.TABLE_SET, 0, 0)
			else
				if var.isUpvalue then
					context.registerOP(node, plume.ops.STORE_UPVALUE, 0, var.offset)
				elseif not isLet and var.frameOffset > 0 then
					context.registerOP(var.ref, plume.ops.STORE_LOCAL, var.frameOffset, var.offset)
				else
					context.registerOP(var.ref, plume.ops.STORE_LOCAL, 0, var.offset)
				end
			end

			-- End of parameter handling block
			if isParam then
				context.registerGoto(node, "param_end_skip_store"..uid)
				context.registerLabel(node, "param_end_"..uid)
				context.registerOP(nil, plume.ops.STORE_VOID)
				context.registerOP(nil, plume.ops.STORE_VOID)
				context.registerLabel(node, "param_end_skip_store"..uid)
			end
		end
	end

	--- Orchestrates the assignment process from resolving targets to generating bytecode
	--- @param node table The current AST node
	--- @param nodevarlist table The list of variable nodes from the AST
	--- @param body table The RHS expression node
	--- @param isLet boolean True if it's a declaration
	--- @param isConst boolean True if it's a constant 
	--- @param isParam boolean True if it's a parameter
	--- @param isFrom boolean True if using object destructuring
	--- @param compound table Compound operator node
	--- @param isBodyStacked boolean True if value is already on stack
	--- @param isContext boolean True if a bind to context
	function context.affectation(node, nodevarlist, body, isLet, isConst, isParam, isFrom, compound, isBodyStacked, isContext)
		local varlist = {}

		if isContext then
			if isConst then
				plume.error.cannotMixContextConstError(node)
			end
			if isParam then
				plume.error.cannotMixContextParamtError(node)
			end
		end
		
		-- Phase 1: Preparation
		for _, varNode in ipairs(nodevarlist.children) do
			local rvar = resolveAssignmentTarget(node, varNode, isLet, isConst, isParam, isFrom, isContext)
			table.insert(varlist, rvar)
		end

		-- Phase 2: Bytecode generation
		generateAssignmentBytecode(node, varlist, body, isLet, isParam, isFrom, compound, isBodyStacked, isContext)

		-- Validation check for empty constants
		if isConst and isLet and not isParam and not (body or isBodyStacked) then
			plume.error.letEmptyConstantError(node)
		end
	end

	--- Helper to handle both LET and SET keywords
	--- @param node table The current AST node
	--- @param isLet boolean True if the operation is a declaration
	local function SETLET(node, isLet)
		local isConst     = plume.ast.get(node, "CONST")
		local isParam     = plume.ast.get(node, "PARAM")
		local isContext   = plume.ast.get(node, "CONTEXT")

		---------------------------------------
		-- WILL BE REMOVED IN 1.0 (#230, #332)
		---------------------------------------
		if plume.ast.get(node, "STATIC") then
			plume.warning.deprecatedCompilationTime(node, "1.0", "Keyword `static`", "Instead of `let static x`, put `let x` at the file root.", {230, 332})
		end
		---------------------------------------

		if isParam then
			if isConst then
				plume.error.cannotUseParamAndConst(node)
			end
			isConst = true 
		end

		local isFrom    = plume.ast.get(node, "FROM")
		local compound = plume.ast.get(node, "COMPOUND")

		local nodevarlist = plume.ast.get(node, "VARLIST")
		local body        = plume.ast.get(node, "BODY")

		context.affectation(node, nodevarlist, body, isLet, isConst, isParam, isFrom, compound, nil, isContext)
	end

	--- Entry point for declarations (LET)
	nodeHandlerTable.LET = function(node)
		SETLET(node, true)
	end

	--- Entry point for assignments (SET)
	nodeHandlerTable.SET = function(node)
		SETLET(node, false)
	end
end