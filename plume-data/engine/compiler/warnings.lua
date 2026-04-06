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

    function context.macroWithoutDocWarning(node)
    	plume.warning.throwWarning("Macro without documentation.", nil, node, {381, 454})
    end

    local function getCode(node)
    	return node.code:sub(node.bpos, node.epos)
    end

    function context.checkCallWarning(node)
    	local name  = plume.ast.get(node, "IDENTIFIER")
    	local call  = plume.ast.get(node, "CALL")
    	local bcall = plume.ast.get(node, "BLOCK_CALL")

    	if name and name.content == "Table" then
    		if call then
    			if #call.children >= 2 then
    				plume.warning.throwWarning(
    					"Using the macro `$Table` for create a new table, but a shorter alternative exists for any table with at least 2 elements.",
    					string.format("Consider writing `%s`.", getCode(call)),
    					node, {381, 607}
    				)
    			end
    		elseif bcall then
    			if not plume.ast.get(node, "LIST_ITEM") then
    				plume.warning.throwWarning(
    					"Using the macro `@Table` for create a new table block, but a shorter alternative exists.",
    					"Consider writing `do ... end` instead of `@Table ... end`.",
    					node, {381, 608}
    				)
    			end
    		end
    	end
    end

    -- Chekc for warnings emmited during parsing
    function context.checkForWarnings(node)
    	if node.warning then
            plume.warning.throwWarning(node.warning, node.warningHint, node, node.issues)
    	end
    end
end