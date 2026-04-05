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

return function (plume, context)
	--- Return the source filename, if exists and differents from processing one, of an imported variable. 
	--- Used when name conflict between file variables and variables imported via `use`.
	--- @param name string Name of the variable
	--- @return string|nil
	function context.getNameSource(name)
		local scope = context.getCurrentScope()

		if scope[name] then
			return scope[name].source
		end
	end

	--- Registers a variable from an outer scope as an upvalue for closure capture.
	--- 
	--- When a macro references a variable defined in an enclosing scope, this function
	--- establishes the upvalue chain across nested macro boundaries. It creates:
	--- 1. A primary upvalue entry in the outermost macro (the one defining the variable),
	---    capturing the local variable at its stack offset
	--- 2. Proxy upvalue entries in all intermediate nested macros, linking them to the
	---    parent's upvalue slot rather than the original variable
	---
	--- This ensures proper closure semantics where inner macros maintain references to
	--- outer variables even when the outer scope has exited.
	---
	--- @param name string The identifier of the variable to capture
	--- @param variableOffset number Stack offset of the variable within its defining scope
	--- @param scopeDepth number Number of macro boundaries between current position and the variable's defining scope (≥1)
	--- @param currentScopeIndex number Index in context.scopes where the variable is defined
	--- @param relativeScopeOffset number Frame offset between current scope and variable's scope (used to locate the correct scope frame)
	--- @param ref string
	--- @return table upvalueInfo Metadata for the upvalue
	function context.registerUpvalue(name, variableOffset, scopeDepth, currentScopeIndex, relativeScopeOffset, ref)
		-- First macro inside the scope will capture upvalue
		local macro = context.macros[#context.macros - scopeDepth + 1]

		if not macro.upvalueMap[name] then
			if ref then
				table.insert(macro.upvalues, {
					offset = #macro.upvalues+1,
					key = ref,
					scopeOffset = relativeScopeOffset-1,
					isUpvalue = true,
					isRefUpvalue = true
				})
			else
				table.insert(macro.upvalues, {
					offset = #macro.upvalues+1,
					localOffset = variableOffset, -- local offset to capture the variable
					scopeOffset = relativeScopeOffset-1, -- in which scope get the variable
					isUpvalue = true
				})
				
			end

			macro.upvalueMap[name] = macro.upvalues[#macro.upvalues]

			local scopeUp = context.scopesUp[currentScopeIndex]
			local found
			for _, infos in ipairs(scopeUp) do
				if infos.offset == (ref or variableOffset) then
					found = true
					break
				end
			end

			if not found then
				if ref then
					table.insert(scopeUp, {offset=ref, isRef=true})
				else
					table.insert(scopeUp, {offset=variableOffset})
				end
			end
			
		end

		-- All nested macro will load upvalue from previous first macro
		for i=scopeDepth-1, 1, -1 do
			local childMacro = context.macros[#context.macros - i + 1]
			if not childMacro.upvalueMap[name] then
				table.insert(childMacro.upvalues, {
					offset = #childMacro.upvalues+1,
					parentOffset = #macro.upvalues,
					isUpvalue = true
				})
				childMacro.upvalueMap[name] = childMacro.upvalues[#childMacro.upvalues]
			end
		end

		macro = context.macros[#context.macros] or macro -- return from the deepest macro

		return macro.upvalueMap[name]
	end

	--- Open upvalue at scope start,
	--- close it at scope end
	--- @param upvalues table
	function context.manageUpvalues(upvalues)
		for _, infos in ipairs(upvalues) do
			if infos.isRef then
				context.registerOP(paramNode, plume.ops.LOAD_CONSTANT, 0, context.registerConstant(infos.offset), "scope_begin_" .. upvalues.uid)
				context.registerOP(paramNode, plume.ops.OPEN_REF_UPVALUE, 0, 0, "scope_begin_" .. upvalues.uid)
			else
				context.registerOP(paramNode, plume.ops.OPEN_UPVALUE, 0, infos.offset, "scope_begin_" .. upvalues.uid)
			end
		end
		for _, infos in ipairs(upvalues) do
			if infos.isRef then
				context.registerOP(paramNode, plume.ops.LOAD_CONSTANT, 0, context.registerConstant(infos.offset))
				context.registerOP(paramNode, plume.ops.CLOSE_REF_UPVALUE, 0, 0)
			else
				context.registerOP(paramNode, plume.ops.CLOSE_UPVALUE, 0, infos.offset)
			end
		end
	end
	
	--- Get informations about a variable by it's name.
	--- Return nil if the variable hasn't be registered
	--- @param name string The name of the variable
	--- @param strict bool Shouldn't check in outer scopes
	--- @return table|nil {frameOffset?, offset, isConst}
	function context.getVariable(name, strict)
		local scopeDepth = 0
		local relativeScopeOffset
		for i=#context.scopes, 1, -1 do

			if i == context.roots[#context.roots - scopeDepth]-1 then
				scopeDepth = scopeDepth + 1
				relativeScopeOffset = i
			end

			if strict and scopeDepth > 0 then
				break
			end
			
			local current = context.scopes[i]
			if current[name] then
				local variable = current[name]
				local result
				
				if scopeDepth > 0 then
					if variable.isRef then
						return context.registerUpvalue(name, nil, scopeDepth, i, relativeScopeOffset-i+1, variable.ref)
					elseif variable.isContext then
						return {isContext = true}
					else
						return context.registerUpvalue(name, variable.offset, scopeDepth, i, relativeScopeOffset-i+1)
					end
				else
					result = {
						frameOffset = #context.scopes-i,
						offset      = variable.offset,
						isConst     = variable.isConst,
						isContext   = variable.isContext,
						isRef       = variable.isRef,
						ref         = variable.ref,
						node        = variable.node,
						source      = variable
					}
				end

				if variable.isRef then
					result.frameOffset = context.accBlockDeep - variable.blockOffset
				end

				return result
			end
		end

		-- Cannot found variable ; check if it is a std/imported one
		local value = (name == "plume" and context.runtime.plume) or plume.std[name] or context.importedVariables[name]
		if value then
			return {
				isStd = true,
				offset = context.registerConstant(value)
			}
		end
	end

	--- Add a constant (raw strings or number found in the sourcecode) to the constant table.
	--- @param value any The value to register.
	--- @return number Offset of the constant, used by the opcode LOAD_CONSTANT
	function context.registerConstant(value)
		local key
		if tonumber(value) then
			key = tostring(value)
		else
			key = value
		end
		if not context.constants[key] then
			table.insert(context.constants, value)
			context.constants[key] = #context.constants
		end
		return context.constants[key]
	end

	--- Register a variable by its name in the local scope
	--- @param node node Emitting node
	--- @param name string The name of the variable.
	--- @param options table
	--- 	@field isConst boolean Flag to prevent future edits.
	--- 	@field isParam boolean True if it should be initialized by the calling script.
	--- 	@field source string|nil The path to the file if imported via `use`.
	--- 	@field isRef boolean True if it is a reference to a table field
	--- 	@field ref string If isRef, name of the key ref
	--- 	@field isContext boolean
	--- 	@field isSelf boolean
	---		@field isLoopVariable boolean
	---		@field isMacro boolean
	---		@field isMacroParam boolean
	--- @return table|nil Returns the variable metadata {offset, isConst, isRef, source}, or nil on name collision.
	function context.registerVariable(node, name, options)
		-- , isConst, isParam, source, isRef, ref, isContext, isSelf
		local scope
		scope = context.getCurrentScope()

		options = options or {}

		if scope[name] and (name ~= "_" or not options.isLoopVariable) then
			return nil, scope[name]
		end
		
		-- Why count var by inserting empty table?
		-- Certainly legacy code that should be examinated
		table.insert(scope, {scope[name]}) 

		scope[name] = {
			offset    = #scope, -- Used by opcodes GET_LOCAL / SET_LOCAL to use the correct frame
			isConst   = options.isConst,
			isRef     = options.isRef,
			source    = options.source,
			isContext = options.isContext,
			isSelf    = options.isSelf,
			node      = node,
			ref       = options.ref,
			-- Used by warning 381
			isLoopVariable = options.isLoopVariable,
			isMacro        = options.isMacro,
			isMacroParam   = options.isMacroParam
		}

		if options.isRef then
			scope[name].blockOffset = context.accBlockDeep
		end

		if options.isParam then
			-- Files parameters are always named.
			context.chunk.namedParamCount = context.chunk.namedParamCount+1
			context.chunk.namedParamOffset[name] = #scope
		end

		return scope[name]
	end

	function context.getAllVisiblesVariables()
		local result = {}
		local passMacroScope = false
    	for i=#context.scopes, 1, -1 do
    		if i == context.roots[#context.roots]-1 then
				passMacroScope = true
			end
			local current = context.scopes[i]
			for k, v in pairs(current) do
				if not tonumber(k) and not result[k] and (not passMacroScope or not v.isRef) then
					result[k] = v
				end
			end
		end

		for k in pairs(plume.std) do
			if not result[k] then
				result[k] = {}
			end
		end

		if not result.plume then
			result.plume = {}
		end

		for k in pairs(context.importedVariables) do
			if not result[k] then
				result[k] = {}
			end
		end

		return result
    end

    function context.emiVariablesUsageWarning(varList)

    	for name, var in pairs(varList) do
    		if not tonumber(name) and var.node then
	    		if not var.used then
    				if var.isLoopVariable then
    					if name ~= "_" then
	    					plume.warning.throwWarning(
		    					"Never used loop variables.",
		    					"Consider removing them or rename them '_'.",
		    					var.node, {381, 473}
		    				)
		    			end
		    		elseif var.isMacro then
		    			plume.warning.throwWarning(
	    					"Never used macros.",
	    					"Consider removing them.",
	    					var.node, {381, 473}
	    				)
	    			elseif var.isMacroParam then
		    			plume.warning.throwWarning(
	    					"Never used macros parameters.",
	    					"Consider removing them.",
	    					var.node, {381, 473}
	    				)
    				elseif var.isRef then
    					plume.warning.throwWarning(
	    					"Never used reference.",
	    					"Consider removing `ref`.",
	    					var.node, {381, 473}
	    				)
    				else
	    				plume.warning.throwWarning(
	    					"Never used variables.",
	    					"Consider removing them.",
	    					var.node, {381, 473}
	    				)
	    			end
    			elseif not var.isConst and not var.modified and not var.isLoopVariable and not var.isMacro and not var.isMacroParam then
    				plume.warning.throwWarning(
    					"Non-constant variables that are never modified.",
    					"Consider making them constants.",
    					var.node, {381, 382}
    				)
    			end
    			
    		end
    	end
    end
end