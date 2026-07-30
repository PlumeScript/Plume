--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

local Parser = require "parser"
local ast = require "parser.lua.ast"
local plume = require"plume-data/engine/init"
local loadvm = require"build-tools/loadvm"
local function printTable(t)
	print(tolua(t))
end


local recAnchor = {
	"add", "sub", "mul", "div", "mod", "concat", "pow",
	"eq", "ne", "lt", "le", "gt", "ge",
	"and", "or", "not", "index", "return"
}
for _, k in ipairs(recAnchor) do
	recAnchor[k] = true
end

local _ret = 0
local function geturet()
	_ret = _ret + 1
	return "_ret".._ret
end
local _labend = 0
local function getulabend()
	_labend = _labend + 1
	return "_inline_end".._labend
end


local function findAnchor(node)
	local insertPoint, assignPoint
	if node.parent then
		if node.parent.type == "assign" then
			assignPoint = node.parent
			if node.parent.parent and node.parent.parent.type == "local" then
				insertPoint = node.parent.parent
			else
				insertPoint = node.parent
			end
		elseif node.parent.type == "if" then
			if node == node.parent.cond then
				insertPoint = node.parent
			else
				insertPoint = node
			end
		-- missing case where min or max should be replaced
		elseif node.parent.type == "foreq" then
			insertPoint = node
		-- Break lazy if-else strategy
		elseif node.parent.type == "elseif" then
			if node == node.parent.cond then
				insertPoint = node.parent.parent
			else
				insertPoint = node
			end
		elseif recAnchor[node.parent.type] then
			return findAnchor(node.parent)
		elseif node.parent.type == "block" or node.parent.type == "function" then
			insertPoint = node
		elseif node.parent.type == "call" then
			insertPoint = findAnchor(node.parent)
		end
	end
	return insertPoint, assignPoint
end

local functionsToInline, usedInlinedFunctions = loadvm()
local indexToInline = {}
local scalars

local _temp_save_scalar_code, _temp_update_scalar_code
local _temp_save_scalar, _temp_update_scalar

local function copyvm()
	scalars = {{"ip", "ip"},{"jump", "jump"}}
	local vars = {
		{"bytecode", "runtime.bytecode"},
		{"constants", "runtime.constants"},
		{"runtimeCallstack", "runtime.callstack"},
		{"runtimeFiles", "runtime.files"},
		{"runtimeCache", "runtime.cache"},
		{"runtimePlume", "runtime.plume"},

		{"fileParams", "fileParams"},

		{"run", "plume._run"},
	}
	local rec = {flag=true}
	local fakevm = plume.obj.vm({})
	local fakekeys = {}
	for k, v in pairs(fakevm) do
		table.insert(fakekeys, {k, v})
	end

	local function sort()
		table.sort(fakekeys, function (x, y) return x[1]<y[1] end) -- deterministic engine-opt
	end

	sort()
	while #fakekeys>0 do
		local infos = table.remove(fakekeys)
		local k = infos[1]
		local v = infos[2]
		local alias = infos[3] or k
		if type(v) ~= "function" then
			table.insert(vars, {k, alias})
			if type(v)=="table"  then
				if v.frames then
					table.insert(vars, {k.."Frames", k..".frames"})
					table.insert(vars, {k.."FramesPointer", k..".frames.pointer"})
					table.insert(scalars, {k.."FramesPointer", k..".frames.pointer"})
				end
				if v.pointer then
					table.insert(vars, {k.."Pointer", k..".pointer"})
					table.insert(scalars, {k.."Pointer", k..".pointer"})
				end
			end
			if rec[k] then
				for kk, vv in pairs(v) do
					table.insert(fakekeys, {kk, vv, k.."."..kk})
				end
				sort()
			end
		end
	end

	local result = {"local vmstate = vm"} -- bypass agressive inlining

	for _, var in ipairs(vars) do
		table.insert(result, string.format("local %s = vmstate.%s", var[1], var[2]))
	end

	-- plume.obj
	table.insert(result, string.format("local plumeObjTable = vmstate.plume.obj.table"))
	table.insert(result, string.format("local plumeObjMacro = vmstate.plume.obj.macro"))
	table.insert(result, string.format("local plumeObjFragment = vmstate.plume.obj.fragment"))
	table.insert(result, string.format("local plumeObjEmpty = vmstate.plume.obj.empty"))

	table.insert(result, string.format("local plumeObjEmpty = vmstate.plume.obj.empty"))

	-- plume.sops
	for index, infos in ipairs(plume.sops_config) do
		table.insert(result, string.format(string.format("local sops_%s = %i", infos.name, plume.sops[infos.name])))
	end

	local save = {}
	for _, scalar in ipairs(scalars) do
		table.insert(save, string.format('vmstate.%s = %s', scalar[2], scalar[1]))
		
	end
	_temp_save_scalar_code = table.concat(save, "\n")
	_temp_save_scalar = Parser.parse(_temp_save_scalar_code, file, '5.2', true)

	local update = {}
	for _, scalar in ipairs(scalars) do
		table.insert(update, string.format('%s = vmstate.%s', scalar[1], scalar[2]))
	end
	_temp_update_scalar_code = table.concat(update, "\n")
	_temp_update_scalar = Parser.parse(_temp_update_scalar_code, file, '5.2', true)

	table.insert(result, (functionsToInline['_ERROR'].body:toLua():gsub('function', 'local function _ERROR')))

	return table.concat(result, "\n")
end

local function applyCommands(code)
	for value, rpl in code:gmatch('%-%-! index%-to%-inline ([^%s]+) ?([^\n]*)') do
		local expr, key = value:match('(.-)%.(.*)')
		rpl = rpl~=""and rpl or expr..key:sub(1, 1):upper()..key:sub(2, -1)
		table.insert(indexToInline, {expr=expr, key=key, rpl=rpl})
	end

	code = code:gsub('%-%-! to%-remove%-begin.-%-%-! to%-remove%-end', '')
	code = code:gsub('[^\n]+%-%-! to%-remove', '')
	code = code:gsub('%-%-! to%-add ([^\n]+)', '%1')

	code = code:gsub('%-%-! copyvm', copyvm())
	code = code:gsub('%-%-! save%-scalar', _temp_save_scalar_code)
	code = code:gsub('%-%-! update%-scalar', _temp_update_scalar_code)

	for command in code:gmatch('%-%-! ([^\n]*)') do
		if not command:match("^inline") and not command:match("^index%-to%-inline") then
			print("Error: unknown command '" .. command .. "'.")
		end
	end

	return code
end

local function loadCode(path, isFile)
	local code
	if isFile then
		local f = io.open(path)
			code = f:read("a")
		f:close()
	else
		code = path
	end

	code = applyCommands(code)
	local result, msg = Parser.parse(code, isFile and path, '5.2', true)

	if not result then
		if #path > 100 then
			path = path:sub(1, 1000)
		end
		print("Cannot load " .. path .. ".")
		error(msg)
	end

	return result
end

local function inlineFunctions(node)
	if node.type == "call" then
		local fname = node.func.key
		if fname and type(fname) == "table" then
			fname = fname.value
		end
		
		local toinline = node.func.expr and (node.func.expr.name == "self" or node.func.expr.name == "vm")
			

		if toinline and fname then
			local f = functionsToInline[fname]
			if f and f.inline then
				local firstArg = node.args[1]
				if firstArg and firstArg.name=="self" then
					table.remove(node.args, 1)
				end

				usedInlinedFunctions[fname] = true
				local body = f.body:copy()
				
				local args = node.args
				local params = f.params
				for i, param in ipairs(params) do
					

					local arg = node.args[i] or ast._nil()
					body:traverse(function(node)
						if node.type == "var" and node.name == param.name then
							return arg:copy()
						end
						return node
					end)
				end

				local labend = getulabend()
				local rets = {}
				if not f.optn.keepret then
					body:traverse(function(node)
						if node.type == "return" then
							for i=1, #node.exprs do
								if #rets<i then
									table.insert(rets, ast._var(geturet()))
								end
							end
							return ast._block(
								ast._assign(rets, node.exprs),
								ast._goto(labend)
							)
						end
						return node
					end)
				end

				local init
				if #rets>0 then
					init = ast._local(rets)
				end

				body:traverse(nil, inlineFunctions)

				local parent = ast._do
				if f.optn['nodo'] then
					parent = ast._block
				end
				
				local result = parent(unpack(body))
				if init then
					result = ast._block(init, result)
				end
				if #rets>0 then
					result = ast._block(result, ast._label(labend))
				end
				local insertPoint, assignPoint = findAnchor(node)
				if insertPoint and insertPoint ~= node then
					if insertPoint.insertBefore then
						insertPoint.insertBefore = ast._block(insertPoint.insertBefore, result)
					else
						insertPoint.insertBefore = result
					end

					if #rets>1 then
						assignPoint.exprs = rets
						return
					elseif #rets == 1 then
						return rets[1]
					else
						return ast._nil()
					end
				else
					if node.insertBefore then
	                    result = ast._block(node.insertBefore, result)
	                end
					return result
				end
			elseif fname == "_ERROR" then
				node.func.name = "_ERROR"
				return node
			end
		elseif node.func.name == "_temp_save_scalar" then
			return _temp_save_scalar
		elseif node.func.name == "_temp_update_scalar" then
			return _temp_update_scalar
		end

	end
	return node
end

local inlined = {}
local function inlineIndex (node)
	if node.type == "index" then
		if node.expr.type == "var" and node.key.type == "string" then
			for _, inlineInfos in ipairs(indexToInline) do
				if node.expr.name == inlineInfos.expr then
					if node.key.value == inlineInfos.key or inlineInfos.key == "*" then
						local rpl

						if inlineInfos.key == "*" then
							local value = node.key.value
							if inlineInfos.rpl:sub(1, 1) ~= "*" then
								value = value:sub(1, 1):upper() .. value:sub(2, -1)
							end
							rpl = inlineInfos.rpl:gsub('%*', value)
							
						else
							rpl = inlineInfos.rpl
						end
						if not inlined[rpl] then
							inlined[rpl] = true
							-- must be an assign
							node.parent.tolocal = true
						end
						return ast._var(rpl)
					end
				end
			end
		end
	end
	return node
end

local function tolocal(node)
	if node.type == "assign" and node.parent.type ~= "local" and node.tolocal then
		node.tolocal = nil
		return ast._local({node})
	end
	return node
end

local function applyInsertBefore (node)
	if node.insertBefore then
		local before = node.insertBefore
		node.insertBefore = nil
		local result = ast._block(before, node)
		result:traverse(applyInsertBefore)
		return result
	end
	return node
end

local function applyInsertExprs (node)
	if node.insertExprs then
		local exprs = node.insertExprs
		node.insertExprs = nil
		node.exprs = exprs
	end
	return node
end


local optimizer
optimizer = {
	loadCode = loadCode,
	applyCommands = applyCommands,
	applyInsertBefore=applyInsertBefore,
	applyInsertExprs=applyInsertExprs,
	inlineFunctions = inlineFunctions,
	inlineIndex = inlineIndex,
	tolocal = tolocal,
	inlineRequire = function (node)
		if node.type == "call" and node.func.name == "require" then
			local path = node.args[1].value .. ".lua"
			return ast._do(loadCode(path, true))
		end
		return node
	end,

	checkUselessFunctions = function()
		for k, v in pairs(usedInlinedFunctions) do
			if not v and functionsToInline[k].inline then
				print(string.format("Warning: function %s not used", k))
			end
		end
	end,

	renameRun = function (node)
		if node.type == "function" and node.name then
			if node.name.key and node.name.key.value == "_run_dev" then
				node.name.key.value = "_run"
			end
		end
		return node
	end,

	optimize = function (tree)
		tree:traverse(optimizer.renameRun)
		tree:traverse(optimizer.inlineFunctions)
		tree:traverse(optimizer.applyInsertBefore)
		tree:traverse(optimizer.applyInsertExprs)
		tree:traverse(optimizer.inlineIndex)
		tree:traverse(optimizer.inlineIndex)
		tree:traverse(optimizer.inlineIndex)
		-- tree:traverse(optimizer.tolocal) -- broken: generate `local t[1] =` and at least one another error

		optimizer.checkUselessFunctions()

		return tree
	end
}

return optimizer