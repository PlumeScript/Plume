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
			plume.error.useUnknownVariable(node, varName, ref, context.getAllVisiblesVariables(), node.name == "VALIDATOR")
		end
		if var.source then
			var.source.used = true
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
	nodeHandlerTable.VALIDATOR = nodeHandlerTable.IDENTIFIER

	--- Analyzes a target node (variable or index) and prepares its internal structure
	--- @param node node The main statement node
	--- @param varNode node The specific node representing the target being assigned
	--- @param isLet boolean    If it's a declaration
	--- @param isConst boolean
	--- @param isParam boolean
	--- @param isFrom boolean If using object destructuring
	--- @param isContext boolean True if a bind to context
	--- @return table rvar The resolved variable object containing scope information and metadata
	local function resolveAssignmentTarget(node, varNode, isLet, isConst, isParam, isFrom, isContext, isLoopVariable)
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
				rvar, definitionVar = context.registerVariable(node, name, {isConst=isConst, isParam=isParam, isContext=isContext, isLoopVariable=isLoopVariable})
				if not rvar then
					if definitionVar.isSelf then
						plume.error.letExistingSelfVariable(node)
					else
						plume.error.letExistingVariable(node, name, source, definitionVar.node)
					end
				end
			else
				rvar, ref = context.getVariable(name)
				if not rvar then
					plume.error.setUnknownVariable(node, name, ref, context.getAllVisiblesVariables())
				elseif rvar.isConst or rvar.isStd then
					plume.error.setConstantVariable(node, name, source, rvar.node)
				elseif rvar.isContext then
					plume.error.setContextVariable(node, name, plume.ast.get(node, "BODY"))
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
				plume.error.cannotSetCall(node)
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
			plume.error.compoundWithDestruction(node)
		end

		-- Generate RHS code
		if not compound and not isBodyStacked then
			context.scope(context.accBlock())(body)
		end
			
		for i, var in ipairs(varlist) do
			local uid = context.getUID()

			if var.isRef then
				plume.error.cannotSetRef(node, var.key, var.source.node, body)
			end
			
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

			if not isLet and var.source then
				var.source.modified = true
			end

			-- Final storage of the value
			if var.getKey then
				var.getKey()
				context.registerOP(node, plume.ops.TABLE_SET, 0, 0)
			else
				if var.isRef then
					context.registerOP(node, plume.ops.LOAD_CONSTANT, 0, context.registerConstant(var.source.ref))
					context.registerOP(node, plume.ops.STORE_REF, var.frameOffset, 0)
				elseif var.isUpvalue then
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
	--- @param options table
	--- 	@field isLet boolean True if it's a declaration
	--- 	@field isConst boolean True if it's a constant 
	--- 	@field isParam boolean True if it's a parameter
	--- 	@field isFrom boolean True if using object destructuring
	--- 	@field compound table Compound operator node
	--- 	@field isBodyStacked boolean True if value is already on stack
	--- 	@field isContext boolean True if a bind to context
	--- 	@field isLoopVariable boolean True
	function context.affectation(node, nodevarlist, body, options)
		local varlist = {}

		if options.isContext then
			if options.isConst then
				plume.error.cannotMixContextConst(node)
			end
			if options.isParam then
				plume.error.cannotMixContextParamt(node)
			end
		end
		
		-- Phase 1: Preparation
		for _, varNode in ipairs(nodevarlist.children) do
			local parentNode = node
			if options.isLoopVariable or #nodevarlist.children>1 then
				parentNode = varNode
			end
			local rvar = resolveAssignmentTarget(parentNode, varNode, options.isLet, options.isConst, options.isParam, options.isFrom, options.isContext, options.isLoopVariable)
			table.insert(varlist, rvar)
		end

		-- Phase 2: Bytecode generation
		generateAssignmentBytecode(node, varlist, body,
			options.isLet,
			options.isParam,
			options.isFrom,
			options.compound,
			options.isBodyStacked,
			options.isContext
		)

		-- Validation check for empty constants
		if options.isConst and options.isLet and not options.isParam and not (body or options.isBodyStacked) then
			plume.error.letEmptyConstant(node)
		end
	end

	--- Helper to handle both LET and SET keywords
	--- @param node table The current AST node
	--- @param isLet boolean True if the operation is a declaration
	local function SETLET(node, isLet)
		local isConst     = plume.ast.get(node, "CONST")
		local isParam     = plume.ast.get(node, "PARAM")
		local isContext   = plume.ast.get(node, "CONTEXT")

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

		context.affectation(node, nodevarlist, body, {
			isLet=isLet,
			isConst=isConst,
			isParam=isParam,
			isFrom=isFrom,
			compound=compound,
			isContext=isContext
		})
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