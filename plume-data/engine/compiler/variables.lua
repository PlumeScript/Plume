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
	--- @param isStatic bool
	--- @return string|nil
	function context.getNameSource(name, isStatic)
		local scope
		if isStatic then
			scope = context.static
		else
			scope = context.getCurrentScope()
		end

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
	--- @return table upvalueInfo Metadata for the upvalue
	function context.registerUpvalue(name, variableOffset, scopeDepth, currentScopeIndex, relativeScopeOffset)
		-- First macro inside the scope will capture upvalue
		local macro = context.macros[#context.macros - scopeDepth + 1]

		if not macro.upvalueMap[name] then
			table.insert(macro.upvalues, {
				offset = #macro.upvalues+1,
				localOffset = variableOffset, -- local offset to capture the variable
				scopeOffset = relativeScopeOffset-1, -- in which scope get the variable
				isUpvalue = true
			})

			macro.upvalueMap[name] = macro.upvalues[#macro.upvalues]
			plume.debug.print(macro.upvalues[#macro.upvalues])
			local scopeUp = context.scopesUp[currentScopeIndex]
			local found
			for _, offset in ipairs(scopeUp) do
				if offset == variableOffset then
					found = true
					break
				end
			end
			if not found then
				table.insert(scopeUp, variableOffset)
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

		return macro.upvalueMap[name]
	end

	--- Open upvalue at scope start,
	--- close it at scope end
	--- @param upvalues table
	function context.manageUpvalues(upvalues)
		for _, offset in ipairs(upvalues) do
			context.registerOP(paramNode, plume.ops.OPEN_UPVALUE, 0, offset, "scope_begin_" .. upvalues.uid)
		end
		for _, offset in ipairs(upvalues) do
			context.registerOP(paramNode, plume.ops.CLOSE_UPVALUE, 0, offset)
		end
	end
	
	--- Get informations about a variable by it's name.
	--- Return nil if the variable hasn't be registered
	--- @param name string The name of the variable
	--- @param strict bool Shouldn't check in outer scopes
	--- @return table|nil {frameOffset?, offset, isConst, isStatic}
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
					return context.registerUpvalue(name, variable.offset, scopeDepth, i, relativeScopeOffset-i+1)
				else
					result = {
						frameOffset = #context.scopes-i,
						offset   = variable.offset,
						isConst  = variable.isConst,
						isRef    = variable.isRef,
						ref      = variable.ref
					}
				end

				if variable.isRef then
					result.frameOffset = context.accBlockDeep - variable.blockOffset
				end

				return result
			end
		end
		if context.static[name] then
			local variable = context.static[name]
			return {
				offset   = variable.offset,
				isConst  = variable.isConst,
				isStatic = variable.isStatic
			}
		end
	end

	--- Add a constant (raw strings or number found in the sourcecode) to the constant table.
	--- @param value any The value to register.
	--- @return number Offset of the constant, used by the opcode LOAD_CONSTANT
	function context.registerConstant(value)
		local key = tostring(value) -- for numeric keys
		if not context.constants[key] then
			table.insert(context.constants, value)
			context.constants[key] = #context.constants
		end
		return context.constants[key]
	end

	--- Register a variable by its name in the local or static scope.
	--- @param name string The name of the variable.
	--- @param isStatic boolean Store in the static scope.
	--- @param isConst boolean Flag to prevent future edits.
	--- @param isParam boolean True if it should be initialized by the calling script.
	--- @param staticValue any Initial value for static vars (compilation time, default to empty).
	--- @param source string|nil The path to the file if imported via `use`.
	--- @param isRef boolean True if it is a reference to a table field
	--- @param ref string If isRef, name of the key ref
	--- @return table|nil Returns the variable metadata {offset, isStatic, isConst, isRef, source}, or nil on name collision.
	function context.registerVariable(name, isStatic, isConst, isParam, staticValue, source, isRef, ref)
		local scope
		if isStatic then
			scope = context.static
			table.insert(context.chunk.static, staticValue or plume.obj.empty)
		else
			scope = context.getCurrentScope()
		end

		-- To avoid conflicts between static variables
		-- and non-static variables declared at the root
		if isStatic then
			if #context.scopes > 0 and context.scopes[1][name] then
				return nil
			end
		elseif #context.scopes == 1 then
			if context.static[name] then
				return nil
			end
		end 
		if scope[name] then
			return nil
		end
		
		-- Why count var by inserting empty table?
		-- Certainly legacy code that should be examinated
		table.insert(scope, {scope[name]}) 

		scope[name] = {
			offset = #scope, -- Used by opcodes GET_LOCAL / SET_LOCAL to use the correct frame
			isStatic = isStatic,
			isConst = isConst,
			isRef = isRef,
			source = source,
			ref = ref
		}

		if isRef then
			scope[name].blockOffset = context.accBlockDeep
		end

		if isParam then
			-- Files parameters are always named.
			context.chunk.namedParamCount = context.chunk.namedParamCount+1
			context.chunk.namedParamOffset[name] = #scope
		end

		return scope[name]
	end

end