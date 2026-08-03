--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

-- These adjustments should only have a minor impact on performance, since luajit would have done it itself.
-- But it makes the code look nicer.

local ast = require "parser.lua.ast"
local optimizer = require"luaOptimizer"
local beautifier = require "luaBeautifier"

local function isEmpty(node)
	for _, child in ipairs(node) do
		if child.type ~= "block" or not isEmpty(child) then
			return false
		end
	end
	return true
end

local function hasLocals(node)
	for _, child in ipairs(node) do
		if child.type== "local" then
			return true
		end
	end
	return false
end

local function removeUselessDo(node)
	if node.type == "do" then
		if isEmpty(node) then
			return ast._block()
		elseif not hasLocals(node) then
			return ast._block(unpack(node)):traverse(removeUselessDo)
		end
	end
	return node
end


local function constantFolding(node)
	if node.type == "or" then
		if node[1].type == "nil" or node[1].type == "false" then
			return node[2]
		end
		if node[2].type == "nil" or node[2].type == "false" then
			return node[1]
		end
		if node[1].type == "number" then
			return node[1]
		end
	elseif node.type == "and" then
		if node[1].type == "nil" or node[1].type == "false" then
			return node[1]
		end
		if node[2].type == "nil" or node[2].type == "false" then
			return node[2]
		end
		if node[1].type == "true" then
			return node[2]
		end
	elseif node.type == "eq" then
		if node[1].type == "number" and node[2].type == "number" then
			if node[1].value == node[2].value then
				return ast._true()
			else
				return ast._false()
			end
		elseif node[1].type == "string" and node[2].type == "string" then
			if node[1].value == node[2].value then
				return ast._true()
			else
				return ast._false()
			end
		end
	elseif node.type == "add" then
		if node[1].type == "number" and node[1].value == "0" then
			return node[2]
		end
		if node[2].type == "number" and node[2].value == "0" then
			return node[1]
		end
	elseif node.type == "sub" then
		if node[2].type == "number" and node[2].value == "0" then
			return node[1]
		end
	elseif node.type == "not" then
		if node[1].type == "true" then
			return ast._false()
		elseif node[1].type == "false" or node[1].type == "nil" then
			return ast._true()
		end
	elseif node.type == "concat" then
		if node[1].type == "string" and node[2].type == "string" then
			return ast._string(node[1].value .. node[2].value)
		end
	elseif node.type == "par" and node.expr.type == "number" then
		return node.expr
	end
	return node
end


local function removeUselessIf(node)
	if node.type == "if" then
		if node.cond.type == "false" or node.cond.type == "nil" then
			if node.elseifs and #node.elseifs > 0 then
				local first = table.remove(node.elseifs, 1)
				return ast._if(first.cond, unpack(first), unpack(node.elseifs), node.elsestmt):traverse(removeUselessIf)
			elseif node.elsestmt then
				return ast._block(unpack(node.elsestmt))
			else
				return ast._block()
			end
		elseif node.cond.type == "true" then
			return ast._block(unpack(node))
		end
	end
	return node
end

local function findPosInList(l, node)
	for i, child in ipairs(l) do
		if child == node then
			return i
		end
	end
end

local function getNodePos(node)
	local parent = node.parent
	
	if not parent then
		return
	end

	if parent.type == "if" then
		local nxt = findPosInList(parent, node)
		if nxt then
			return parent, nxt
		end
		for _, _elseif in ipairs(parent.elseifs) do
			local nxt = findPosInList(_elseif, node)
			if nxt then
				return _elseif, nxt
			end
		end
		return parent.elsestmt, findPosInList(parent.elsestmt or {}, node)
	else
		return parent, findPosInList(parent, node)
	end
end

local function getNextNode(node)
	local parent, index = getNodePos(node)
	if index then
		return parent[index+1]
	end
end

local function removeUselessLocalSplitA(node)
	if node.type == "local" then
		if node.exprs[1].type == "var" then
			local nxt = getNextNode(node)

			if nxt then
				if nxt.type == "block" and nxt[1] then
					nxt = nxt[1]
				end

				if nxt.type == "assign" then
					if nxt.vars[1].name == node.exprs[1].name then
						nxt.wrapLocal = true
						return ast._block()
					end
				end
			end
		end
	end
	return node
end

local function removeUselessLocalSplitB(node)
	if node.wrapLocal then
		node.wrapLocal = nil
		return ast._local({node})
	end
	return node
end

local function removeUselessGoto(tree)
	local count = {}
	local marked = {}

	tree:traverse(function(basenode)
		local nodes = {basenode}

		if basenode.elseifs then
			nodes = {unpack(nodes), unpack(basenode.elseifs)}
		end

		table.insert(nodes, basenode.elsestmt)
		for _, node in ipairs(nodes) do
			if node then
				for pos, child in ipairs(node) do
					if child.type == "goto" then
						if not marked[child] then -- Dirty patch: traverse should'nt touch a node twice
							marked[child] = true
							if count[child.name] then
								count[child.name] = count[child.name] + 1 
							else
								count[child.name] = 1 
							end
						end

						local nxt = node[pos+1]
						local parent = node.parent
						if not nxt and node.type == "do" and parent then
							local index
							for i, child in ipairs(node.parent) do
								if child == node then
									index = i
									break
								end
							end

							if not index and parent.type == "if" then
								for _, _elseif in ipairs(parent.elseifs or {}) do
									for i, child in ipairs(_elseif) do
										if child == node then
											index = i
											parent = _elseif
											break
										end
									end
								end
								for i, child in ipairs(parent.elsestmt or {}) do
									if child == node then
										index = i
										parent = parent.elsestmt
										break
									end
								end
							end

							if index then
								nxt = parent[index+1]
							end
						end

						local adj = nxt and nxt.type == "label" and nxt.name == child.name
						if adj then
							child.adj = true
							nxt.adj = true
						end
					end
				end
			end
		end
		return basenode
	end)
	
	tree:traverse(function(node)
		if node.type == "label" or node.type == "goto" then
			if count[node.name] then

				if node.adj and (count[node.name] == 1 or node.type == "goto") or count[node.name] == 0 then
					if node.type == "goto" and not node.adj then
						count[node.name] = count[node.name] - 1
					end
					return ast._block()
				end
			end
		end
		return node
	end)
	return node
end


return {
	removeUselessDo = removeUselessDo,
	removeUselessGoto = removeUselessGoto,
	removeUselessIf = removeUselessIf,
	removeUselessLocalSplitA = removeUselessLocalSplitA,
	removeUselessLocalSplitB = removeUselessLocalSplitB,

	clean = function(tree)
		tree = optimizer.loadCode(beautifier(tree), false)
		for i=1, 5 do
			tree:traverse(constantFolding)
		end
		tree:traverse(removeUselessIf)
		tree:traverse(removeUselessDo)
		tree:traverse(removeUselessLocalSplitA)
		tree:traverse(removeUselessLocalSplitB)
		tree = optimizer.loadCode(beautifier(tree), false)
		removeUselessGoto(tree)
		return tree
	end
}