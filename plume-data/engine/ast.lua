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
		TABLE       = {"LIST_ITEM", "HASH_ITEM", "EXPAND", "EMPTY_REF", "INLINE_TABLE"},
		TEXT        = {"TEXT", "SPECIAL_TEXT", "RAW", "EVAL", "BLOCK", "NUMBER", "IDENTIFIER", "QUOTE", "ADD", "SUB", "MUL", "DIV", "NEG", "POW", "MOD", "EQ", "NEQ", "LT", "GT", "LTE", "GTE", "AND", "NOT", "OR", "FALSE", "TRUE", "EMPTY", "CONCAT"},
		MACRO       = {"ANONYMOUS_MACRO"},
		RETURN      = {"RETURN"},
		INHERIT     = {"FOR", "WHILE", "IF", "ELSEIF", "ELSE", "BODY", "DO", "WITH"}
	}

	local _nodeCategory = {
		PROVIDER = {"FOR", "WHILE", "DO", "WITH"},
		BRANCH   = {"IF"}
	}

	local _cantBeUnic = {"FOR", "WHILE", "HASH_ITEM", "LIST_ITEM"}

	local primitiveTypes = {}
	for typeName, nodeNames in pairs(_primitiveTypes) do
		for _, nodeName in ipairs(nodeNames) do
			primitiveTypes[nodeName] = typeName
		end
	end
	local nodeCategory = {}
	for typeName, nodeNames in pairs(_nodeCategory) do
		for _, nodeName in ipairs(nodeNames) do
			nodeCategory[nodeName] = typeName
		end
	end
	local cantBeUnic = {}
	for _, nodeName in ipairs(_cantBeUnic) do
		cantBeUnic[nodeName] = true
	end

	local function checkType(a, b)
		if a == "EMPTY" or b == "EMPTY" then
			return true
		elseif a == b then
			return true
		else
			return false
		end
	end

	local function accTypeInference(node, canBeUnic)
		local detectedType = "EMPTY"
		local firstRelevantChild = node
		local isUnic = canBeUnic

		for _, child in ipairs(node.children or {}) do
			local childProvidedType, lastRelevantChild = plume.ast.markType(child)
			if childProvidedType ~= "EMPTY" then
				if childProvidedType ~= detectedType then
					if not checkType(detectedType, childProvidedType) then
						if child.name == "INLINE_TABLE" then
							plume.error.inlineTableMuseBeAlone(child)
						elseif firstRelevantChild.name == "INLINE_TABLE" then
							plume.error.inlineTableMuseBeAlone(firstRelevantChild)
						else
							plume.error.mixedBlock(
								firstRelevantChild,
								detectedType,
								childProvidedType,
								lastRelevantChild
							)
						end
					end
					if detectedType == "EMPTY"  then
						detectedType       = childProvidedType
						firstRelevantChild = lastRelevantChild
					end
				else
					isUnic = false
				end

				if cantBeUnic[child.name] then
					isUnic = false
				end
			end

			if child.name == "BREAK" then
				child.interruptPartialInformation = {isUnic=isUnic, detectedType=detectedType}
			end
		end

		if isUnic and detectedType ~= "EMPTY" then
			node.isUnic = true
		end

		return detectedType, firstRelevantChild
	end

	function plume.ast.markType(node)
		local detectedType = "EMPTY"
		local provideType  = "EMPTY"
		local firstRelevantChild 
		
		local category = nodeCategory[node.name] or "DEFAULT"

		if category == "DEFAULT" then
			detectedType, firstRelevantChild = accTypeInference(node, true)
		elseif category == "PROVIDER" then
			for _, elem in ipairs(node.children or {}) do
				if elem.name == "BODY" then
					detectedType, firstRelevantChild = accTypeInference(elem, not cantBeUnic[node.name])

					-- Not very clean: table concatenation should be done at
					-- the highest level, and text concatenation at the lowest
					if detectedType ~= "TABLE" then
						elem.type = detectedType
					else
						elem.type = "EMPTY"
					end
				else
					plume.ast.markType(elem)
				end
			end
		elseif category == "BRANCH" then
			for _, elem in ipairs(node.children or {}) do
				if elem.name == "BODY" or elem.name == "ELSEIF" or elem.name == "ELSE" then
					local branchDetectedType, branchRelevantChild = accTypeInference(elem, true)

					if branchDetectedType ~= "EMPTY" then
						if not checkType(branchDetectedType, detectedType) then
							plume.error.mixedBlockInsideIf(
								branchRelevantChild,
								detectedType,
								branchDetectedType,
								elem.name
							)
						end

						detectedType       = branchDetectedType
						firstRelevantChild = branchRelevantChild
					end
					elem.type = detectedType
				else
					plume.ast.markType(elem)
				end
			end
		end

		node.type = detectedType

		local primitiveType = primitiveTypes[node.name]

		if primitiveType == "INHERIT" then
			provideType = node.type
		elseif primitiveType then
			provideType = primitiveType
			firstRelevantChild = node
		end

		return provideType, firstRelevantChild
	end

	-- An IF can contain only a single value (and therefore does not concatenate it)
	-- AND be included in a block that does concatenate.
	-- We could add CHECK_IS_TEXT after each IF, but the error message would then point to the wrong line.
	-- Here, we force the IF and its children to no longer be “isUnic” if the parent is not.
	function plume.ast.fixIF_isUnic(node)
		for _, child in ipairs(node.children or {}) do
			if child.name == "IF" and not node.isUnic then
				local branchs = {}

				local elseifnodes = plume.ast.getAll(child, "ELSEIF")
				local elsenode    = plume.ast.get(child, "ELSE")

				table.insert(branchs, plume.ast.get(child, "BODY"))
				for _, elseifnode in ipairs(elseifnodes) do
					table.insert(branchs, plume.ast.get(elseifnode, "BODY"))
				end
				if elsenode then
					table.insert(branchs, plume.ast.get(elsenode, "BODY"))
				end

				for _, branch in ipairs(branchs) do
					branch.isUnic = false
				end
			end

			plume.ast.fixIF_isUnic(child)
		end
	end

	function plume.ast.labelMacro(ast)
		plume.ast.browse(ast, function(node)
			if node.name == "HASH_ITEM" and node.children[1].name == "NAME"  then
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