--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function(vm)
	--- @opcode
	--- Create a new accumulation frame
	--! inline
	function vm:BEGIN_ACC(arg1, arg2)
	    self:_STACK_PUSH(
	        self.mainStack.frames,
	        self.mainStack.pointer+1
	    )
	end

	--- Close the current frame
	--! inline
	function vm:_END_ACC()
		self:_STACK_POP(self.mainStack.frames)
	end

	--! inline
	function vm:_MAKE_FRAGMENT(start, count)
	    local fragment = self.plume.obj.fragment(count)
	    for i = 1, count do
	        fragment[i] = self:_STACK_GET(self.mainStack, start+i-1)
	    end
	    return fragment
	end

	--- @opcode
	--- Concatenate all values in the current frame into a single fragment.
	--- Pops every value down to the frame marker, concatenates them, and pushes the result.
	--- Small, flat sequences of strings/numbers are optimized via direct `table.concat`;
	--- larger or nested sequences produce a *fragment* (a lazy array of parts).
	--! inline
	function vm:CONCAT_TEXT(arg1, arg2)
	    local start = self:_STACK_GET(self.mainStack.frames)
	    local stop  = self:_STACK_POS(self.mainStack)
	    local count = stop - start + 1
	    local fragment

	    local CONCAT_COUNT_LIMIT  = 8
	    local CONCAT_LENGTH_LIMIT = 64

	    --! to-remove-begin
	    -- No optimisation in debug mode
	    CONCAT_COUNT_LIMIT = 0
	    --! to-remove-end

	    if count == 0 then
	        fragment = ""
	    elseif count == 1 then
	        fragment = self:_STACK_GET(self.mainStack, start)
	    elseif count <= CONCAT_COUNT_LIMIT then
	        local directConcat = true
	        local length = 0
	        for i = start, stop do
	            local item = self:_STACK_GET(self.mainStack, i)
	            if self:_GET_TYPE(item) == "fragment" then
	                directConcat = false
	                break
	            else
	                length = length + #item
	            end
	        end
	        directConcat = directConcat and length <= CONCAT_LENGTH_LIMIT
	        if directConcat then
	            fragment = table.concat(self.mainStack, "", start, stop)
	        else
	            fragment = self:_MAKE_FRAGMENT(start, count)
	        end
	    else
	        fragment = self:_MAKE_FRAGMENT(start, count)
	    end
		self:_STACK_MOVE(self.mainStack, start)
		self:_STACK_SET(self.mainStack, start, fragment)
		self:_END_ACC()
	end

	--! inline
	function vm:_FORCE_FRAGMENT_META(fragment)
		local meta = fragment:getMetaItem("fragment")
		local tmeta = self:_GET_TYPE(meta)

		if tmeta == "macro" or tmeta == "closure" then
			if not fragment.isRendering then -- detect infinite loop
				fragment.isRendering = true

				self:BEGIN_ACC(0, 0)
				self:_PUSH_SELF(fragment)
				self:_STACK_PUSH(self.mainStack, meta)
				self:_CONCAT_CALL_REC()

				local render = self:_STACK_POP(self.mainStack)
				fragment:setMetaItem("fragment", render)

				return render
			else
				self:_ERROR(self.plume.error.tryToUseFragmentInsideItSelf(fragment))
			end
		elseif tmeta ~= "nil" and tmeta ~= "empty" then
			return meta
		end
	end

	--- @opcode
	--- Recursively flatten a fragment on stack top into a single string.
	--- If the value is not a fragment, does nothing.
	--! inline
	function vm:FORCE_FRAGMENT(arg1, arg2)
	    while not self.err do
	    	local fragment = self:_STACK_GET(self.mainStack)
	    	local t = self:_GET_TYPE(fragment)
		    if t == "fragment" then
		        local result        = {}
		        local stackFragment = {fragment}
		        local stackIndex    = {}
		        local depth         = 0

		        while #stackFragment > 0 do
		            depth = #stackFragment
		            local top = table.remove(stackFragment)
		            local quickExit = false
		            for i=(stackIndex[depth] or 1), #top do
		                local item = top[i]
		                
		                while true do
			                local titem = self:_GET_TYPE(item)
			                if titem == "fragment" then
			                    stackIndex[depth] = i+1
			                    table.insert(stackFragment, top)
			                    table.insert(stackFragment, item)
			                    quickExit = true
			                    break
			                elseif titem == "table" then
			                	local value = self:_FORCE_FRAGMENT_META(item)
			                	if value then
			                		item = value
			                	else
			                		table.insert(result, item)
			                    	break
			                	end
			                elseif titem == "empty" then
			                	break
			                else
			                    table.insert(result, item)
			                    break
			                end
			            end
			            if quickExit then
			            	break
			            end
		            end
		            if not quickExit then
		                stackIndex[depth] = 1
		            end
		        end
				self:_STACK_POP(self.mainStack)
				self:_STACK_PUSH(self.mainStack, table.concat(result))
			elseif t == "table" then
				local value = self:_FORCE_FRAGMENT_META(fragment)
				if value then
					self:_STACK_POP(self.mainStack)
					self:_STACK_PUSH(self.mainStack, value)
				else
					break
				end
			else
				break
			end
		end
	end

	--- @opcode
	--- Make a table from elements of the current frame
	--- Unstack all element in current frame, remove the last frame.
	--- Make a new table
	--- First unstacked element must be a table, containing in order key, value, ismeta to insert in the new table
	--- All following elements are appended to the new table.
	--! inline
	function vm:CONCAT_TABLE()
		-- Treat all arguments as variadic by asking for 0 positional variables and 0 named variables
		local resultTable = self:_CONCAT_TABLE(0, nil, true)

		self:_STACK_POP_FRAME(self.mainStack) -- Clean stack from arguments
		self:_STACK_PUSH(self.mainStack, resultTable) -- Push the resulting table onto the stack

		return resultTable
	end

	---@param posParamCount integer The number of expected positional parameters (0 for none).
	---@param namedParamOffset table|nil A map of named parameters to their register offsets (nil for none).
	---@return table The variadic table object containing surplus/variadic arguments.
	--! inline
	function vm:_CONCAT_TABLE(posParamCount, namedParamOffset, variadic)
		local argsOffset   = 1

		local frameOffset  = self:_STACK_GET(self.mainStack.frames)
		local bufferOffset = frameOffset
		local mainStackTop = self:_STACK_POS(self.mainStack)

		local variadicTable
		-- Heuristic allocation: assume worst case (all items are part of the table)
		if variadic then
			local max = mainStackTop - bufferOffset + 1
			variadicTable = self.plume.obj.table(max, max / 2)
		end

		local tomanyPositionalCounter = 0
		local capturedCount = 0
		local unknownNamed

		while bufferOffset <= mainStackTop do
			local tag = self.tagStack[bufferOffset+1]
			local value = self:_STACK_GET(self.mainStack, bufferOffset)
			-- Positional Argument
			if tag == nil then
				if argsOffset <= posParamCount then
					-- Assign to local variable register
					self:_STACK_SET_FRAMED(self.variableStack, argsOffset-1, 0, value)
					capturedCount = capturedCount+1
				elseif variadicTable then
					-- Surplus → Insert into variadic table
					variadicTable:addItem(value)
				else
					tomanyPositionalCounter = tomanyPositionalCounter+1
				end
				argsOffset = argsOffset + 1

			-- Named Argument or Meta Key
			else
				bufferOffset = bufferOffset + 1
				local key = self:_STACK_GET(self.mainStack, bufferOffset)
				-- Check if this key corresponds to a declared named parameter
				local argOffset = namedParamOffset and (namedParamOffset)[key]
				if argOffset then
					if tag == "key" then
						-- Assign to local variable register
						self:_STACK_SET_FRAMED(self.variableStack, argOffset-1, 0, value)
					else
						self:_ERROR(self.plume.error.cannotUseMetaKey)
					end
				else
					-- Unknown key → Insert into variadic table
					if variadicTable then
						if tag == "key" then
							variadicTable:setItem(key, value)
						elseif tag == "metakey" then
							variadicTable:setMetaItem(key, value)
							self:_CHECK_META_FRAGMENT(variadicTable.meta, key)
						end
					elseif not unknownNamed then -- should capture all unknown?
						unknownNamed = key
					end
				end

				self.tagStack[bufferOffset] = nil -- Clean tagstack for the key
			end
			bufferOffset = bufferOffset + 1
		end

		return variadicTable, tomanyPositionalCounter, capturedCount, unknownNamed
	end

	--- @opcode
	--- Check if stack top can be concatened
	--- Get stack top. If neither empty, number or string, try
	--- to convert it, else throw an error.
	--! inline
	function vm:CHECK_IS_TEXT(arg1, arg2)
	    local value = self:_STACK_GET(self.mainStack)
	    local t     = self:_GET_TYPE(value)

	    if value == self.plume.obj.empty then
	        self:_STACK_SET(self.mainStack, self:_STACK_POS(self.mainStack), "")
	    elseif t == "number" then
	        local plumeTable =self.runtime.plume.table
	        local locale = plumeTable.locale:get()
	        local file = self:_GET_CURRENT_FILE()

	        if locale ~= self.plume.obj.empty and locale ~= "none" and not file.flagRawNumbers then
	            local success, result = self.plume.formatNumber(
	                value,
	                plumeTable.localeNumberFormat:get(),
	                locale,
	                plumeTable.localeThousandsSeparator:get(),
	                plumeTable.localeDecimalSeparator:get(),
	                plumeTable.localeThousandthsSeparator:get()
	            )

	            if success then
	                self:_STACK_SET(self.mainStack, self:_STACK_POS(self.mainStack), result)
	            else
	                self:_ERROR(result)
	            end
	        else
	            self:_STACK_SET(self.mainStack, self:_STACK_POS(self.mainStack), tostring(value))
	        end
	    elseif t ~= "string" and t ~= "fragment" then
	        local tostringMeta, fragmentValue
	        if t == "table" then
	        	tostringMeta = value:getMetaItem("tostring")
	        	if not tostringMeta then
		        	fragmentValue = self:_FORCE_FRAGMENT_META(value)
		        end
	        end

	        if tostringMeta then
	            self:_STACK_POP(self.mainStack)

	            self:BEGIN_ACC(0, 0)
	            self:_PUSH_SELF(value)
	            self:_STACK_PUSH(self.mainStack, tostringMeta)
	            self:_CONCAT_CALL_REC()

	            local stringValue     = self:_STACK_GET(self.mainStack)
	            local stringValueType = self:_GET_TYPE(stringValue)
	            if stringValueType ~= "string" and stringValueType ~= "empty" then
					self:_ADD_CALLSTACK_DEBUG_INFO(tostringMeta, tostringMeta.offset-1)
	            	self:_ERROR(self.plume.error.wrongTostringReturnType(stringValueType))
	            end

	        elseif fragmentValue then
	        	self:_STACK_POP(self.mainStack)
	        	self:_STACK_PUSH(self.mainStack, fragmentValue)
	        elseif t == "boolean" then
	            self:_STACK_SET(self.mainStack, self:_STACK_POS(self.mainStack), tostring(value))
	        else
	            self:_ERROR(self.plume.error.cannotConcatValue(t))
	        end
	    end
	end
end
