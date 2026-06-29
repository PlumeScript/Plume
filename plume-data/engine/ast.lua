--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function (plume)
	plume.ast = {}
	function plume.ast.browse(node, f, mindeep, maxdeep, parents)
		if mindeep then
			mindeep = mindeep - 1
		end
		if maxdeep then
			maxdeep = maxdeep - 1
			if maxdeep < -1 then
				return
			end
		end

		parents = parents or {}

		if not mindeep or mindeep <= 0 then
			local value = f(node, parents)
			if value == "STOP" then
				return value
			end
		end

		table.insert(parents, node)
		for _, child in ipairs(node.children or {}) do
			local value = plume.ast.browse(child, f, mindeep, maxdeep, parents)
			if value == "STOP" then
				return value
			end
		end
		table.remove(parents)
	end

	function plume.ast.set(node, key, value, mindeep, maxdeep)
		plume.ast.browse(node, function(childnode) childnode[key] = value end, mindeep, maxdeep)
	end

	-- return the first child with given name
	function plume.ast.get(node, name, mindeep, maxdeep)
		mindeep = mindeep or 1
		maxdeep = maxdeep or 1
		local result
		plume.ast.browse(node, function(childnode)
			if childnode.name==name then
				result = childnode
				return "STOP"
			end
		end, mindeep, maxdeep)

		return result
	end

	function plume.ast.getAll(node, name, mindeep, maxdeep)
		mindeep = mindeep or 1
		maxdeep = maxdeep or 1
		local result = {}
		plume.ast.browse(node, function(childnode)
			if childnode.name==name then
				table.insert(result, childnode)
			end
		end, mindeep, maxdeep)

		return result
	end

	function plume.ast.markParent(node)
		for _, child in ipairs(node.children or {}) do
			plume.ast.markParent(child)
			child.parent = node
		end
	end

	local _primitiveTypes = {
		TABLE       = {"LIST_ITEM", "HASH_ITEM", "EXPAND", "EMPTY_REF"},
		TEXT        = {"TEXT", "RAW", "EVAL", "BLOCK", "NUMBER", "IDENTIFIER", "QUOTE"},
		VALUE       = {"ADD", "SUB", "MUL", "DIV", "NEG", "POW", "MOD", "EQ", "NEQ", "LT", "GT", "LTE", "GTE", "AND", "NOT", "OR", "FALSE", "TRUE"},
		VALUE_MACRO = {"ANONYMOUS_MACRO"},
		INHERIT     = {"FOR", "WHILE", "IF", "ELSEIF", "ELSE", "BODY"},
		EMPTY       = {"MACRO"}
	}

	local primitiveTypes = {}
	for typeName, nodeNames in pairs(_primitiveTypes) do
		for _, nodeName in ipairs(nodeNames) do
			primitiveTypes[nodeName] = typeName
		end
	end

	local typeHandlerTable = {}
	typeHandlerTable.DEFAULT = function(node, parentLastNode)
		local waitOneValue = node.parent and (node.parent.name == "ELSE" or node.parent.name == "ELSEIF") and node.parent.type == "VALUE"

		if node.parent and (
			   node.name == "FOR"
			or node.name == "WHILE"
			or node.name == "IF"
			or node.name == "ELSE"
			or node.name == "ELSEIF"
			or (node.name == "BODY" and (
				   node.parent.name == "FOR"
				or node.parent.name == "WHILE"
				or node.parent.name == "IF"
				or (node.parent.name == "ELSE" and #(node.children or {})>0)
				or (node.parent.name == "ELSEIF" and #(node.children or {})>0)
			)))	 then
			node.type = node.parent.type
		else
			node.type = "EMPTY"
		end

		local nulldelta = 0
		local lastNode = parentLastNode
		local branchType

		for i, child in ipairs(node.children or {}) do
			local childType = plume.ast.markType(child, lastNode)

			-- workaround for the case where child is an information,
			-- not a proper child
			local avoid = child.name == "IDENTIFIER" and (
					node.name ~= "EVAL"
					and node.name ~= "LIST_ITEM"
					and node.name ~= "BODY"
			) or child.name == "NULL" or child.name == "LINESTART"
			
			if avoid then
				nulldelta = nulldelta + 1
			else
				if (node.name == "LIST_ITEM" or node.name == "HASH_ITEM")
				and (childType == "VALUE_MACRO" or childType == "VALUE_TABLE") then
					node.type = "VALUE"
				elseif child.name == "BODY" and node.name == "WITH" then
					node.type = child.type
				elseif node.type == "EMPTY" then
					if childType == "TEXT"
					and (child.name ~= "FOR" and child.name ~= "WHILE") then
						node.type = "VALUE"
					else
						node.type = childType
					end
					lastNode = child
				elseif node.type == "VALUE"
				and (childType == "TEXT" or childType == "VALUE") then
					if waitOneValue then
						waitOneValue = false
					else
						node.type = "TEXT"
					end
				elseif node.type == "TEXT" and childType == "VALUE" then
					node.type = "TEXT"
				elseif node.type == "VALUE_TABLE" and childType == "VALUE_TABLE" then
					if branchType and branchType ~= "EMPTY" then
						if child.name == "INLINE_TABLE" then
							plume.error.inlineTableMuseBeAlone(child)
						elseif child.name == "WITH"  then
							plume.error.withTableMuseBeAlone(child)
						end
					else
						node.type = "VALUE_TABLE"
					end
				elseif childType ~= "EMPTY" and node.type ~= childType then
					if node.parent and (node.parent.name == "ELSE" or node.parent.name == "ELSEIF") and i==nulldelta+1 then
						plume.error.mixedBlockInsideIf(child, node.type, childType, node.parent.name)
					else
						if lastNode.name == "INLINE_TABLE" then
							plume.error.inlineTableMuseBeAlone(lastNode)
						elseif lastNode.name == "WITH"  then
							plume.error.withTableMuseBeAlone(child)
						else
							plume.error.mixedBlock(lastNode, node.type, childType, child)
						end
					end
				end
				branchType = node.type
			end
		end

		-- For / While cannot produce VALUE
		if node.name == "FOR" or node.name == "WHILE" then
			if node.type == "VALUE" then
				node.type = "TEXT"
			end
		end
	end

	-- It needs to be completely rewritten; it's completely impossible to maintain at this point.
	function plume.ast.markType(node, parentLastNode)
		(typeHandlerTable[node.name] or typeHandlerTable.DEFAULT) (node, parentLastNode)

		local primitiveType = primitiveTypes[node.name]
		if primitiveType == "INHERIT" then
			return node.type
		elseif primitiveType then
			return primitiveType
		elseif node.name == "INLINE_TABLE" 
			or (node.name == "WITH" and node.type == "TABLE") then
			return "VALUE_TABLE"
		elseif (node.name == "WITH" or node.name == "DO") and node.type == "EMPTY" then
			return "EMPTY"
		elseif node.name == "WITH"
			or node.name == "DO" then
			return "VALUE"
		else
			return "EMPTY"
		end
	end

	function plume.ast.labelMacro(ast)
		plume.ast.browse(ast, function(node)
			if node.name == "HASH_ITEM" and node.children[1].name == "IDENTIFIER"  then
				if node.children[2] then -- HAST_ITEM value should be empty
					local value = node.children[2]
					if value.name == "BODY"
					and #value.children == 1
					and (value.children[1].name == "MACRO" or value.children[1].name == "ANONYMOUS_MACRO") then
						value.children[1].label = node.children[1].content
					end
				end
			end
		end)
	end
end