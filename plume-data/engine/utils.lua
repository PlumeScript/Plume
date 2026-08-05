--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function (plume)
	-- OPP
	plume.ops_names = [[
		LOAD_CONSTANT LOAD_TRUE LOAD_FALSE LOAD_EMPTY
		LOAD_LOCAL LOAD_REF LOAD_UPVALUE
		STORE_LOCAL STORE_VOID STORE_UPVALUE STORE_REF

		OPEN_UPVALUE CLOSE_UPVALUE OPEN_REF_UPVALUE CLOSE_REF_UPVALUE CLOSURE

		TABLE_NEW
		TABLE_SET TABLE_INDEX TABLE_REGISTER_SELF
		TABLE_SET_META
		TABLE_SET_ACC
		TABLE_EXPAND
		TABLE_INDEX_CHECK_IS_NIL
		TABLE_CUSTOM_FIELD

		CALL_INDEX_REGISTER_SELF

		TAG_META_KEY TAG_KEY
		
		ENTER_SCOPE LEAVE_SCOPE
		BEGIN_ACC CONCAT_TABLE CONCAT_TEXT CONCAT_CALL CHECK_IS_TEXT FORCE_FRAGMENT

		JUMP_IF JUMP_IF_NOT JUMP_IF_NOT_EMPTY JUMP_FOR JUMP
		JUMP_IF_PEEK JUMP_IF_NOT_PEEK

		GET_ITER FOR_ITER

		OP_ADD OP_MUL OP_SUB OP_DIV OP_NEG OP_MOD OP_POW OP_CONCAT
		OP_LT OP_EQ
		OP_AND OP_NOT OP_OR
		
		DUPLICATE SWITCH

		RETURN RETURN_FILE FILE_INIT_PARAMS

		PUSH_CONTEXT POP_CONTEXT LOAD_CONTEXT CREATE_CONTEXT
	
		RAISE

		END
]]
	local function makeNames(names)
		local t = {}
		plume.ops_count = 1
		for name in names:gmatch("%S+") do
			t[name] = plume.ops_count
			plume.ops_count = plume.ops_count + 1
		end
		return t
	end

	local function makeSNames(all_infos)
		local t = {}
		for index, infos in ipairs(all_infos) do
			t[infos.name] = index
		end
		return t
	end

	plume.ops = makeNames(plume.ops_names)
	plume.sops_config = {
		{name="CONCAT_CALL", plume.ops.CONCAT_CALL, 0, 0},
		{name="CONCAT_CALL_SAFE", plume.ops.CONCAT_CALL, 0, 1}
	}
	plume.sops = makeSNames(plume.sops_config)

	plume.validMetaNames = {}
	for name in ([[
		add addr addl mul mull mulr
		div divr divl sub subr subl mod modr modl
		pow powl powr
		eq lt minus
		call getindex setindex
		iter next tostring validate
		readonly fragment
	]]):gmatch("%S+") do
		plume.validMetaNames[name] = true
	end

	

	function plume.checkIdentifier(node, identifier)
		for kw in ('if elseif else while for do macro let set const param use raw run ref with raise'):gmatch('%S+') do
			if identifier == kw then
				plume.error.wrongIdentifier(node, identifier)
			end
		end
	end

	local function formatDir(s)
		local result = s:gsub('\\', '/')
		if result ~= "" and not result:match('/$') then
			result = result .. "/"
		end
		return result
	end
	local function formatDirFromFilename(s)
		local result = formatDir(s:gsub('/[^/]+$', ''))
		if result ~= "" and not result:match('/$') then
			result = result .. "/"
		end
		return result
	end

	local function normalizePathParts(path)
		-- path uses forward slashes
		local leadingSlash = path:match("^/")
		local parts = {}
		for part in string.gmatch(path, "[^/]+") do
			if part == ".." then
				if #parts > 0 and parts[#parts] ~= "" then
					table.remove(parts)
				end
			elseif part ~= "." then
				table.insert(parts, part)
			end
		end

		local normalized = table.concat(parts, "/")

		if parts[1] and string.match(parts[1], "^[A-Za-z]:$") then
			local drive = table.remove(parts, 1)
			normalized = drive .. "/" .. table.concat(parts, "/")
		elseif leadingSlash then
			normalized = "/" .. normalized
		end

		while string.match(normalized, "//+") do
			normalized = string.gsub(normalized, "//+", "/")
		end

		return normalized:gsub("/$", "")
	end

	function plume.normalizePath(path)
		path = path:gsub("\\", "/")

		if path:match("^/") or path:match("^[A-Za-z]:/") then
			return normalizePathParts(path)
		end

		local cwd = (plume.debugForcedRoot or lfs.currentdir()):gsub("\\", "/")
		if cwd == "" then
			return normalizePathParts(path)
		end
		return normalizePathParts(cwd .. "/" .. path)
	end

	local pathTemplates = {
		"%base%%path%.%ext%",
		"%base%%path%/init.%ext%",
	}
	
	function plume.getFilenameFromPath(path, lua, runtime, firstFilename, lastFilename)
		path = path:gsub('\\', '/')
		
		local root
		if path:match('^%.+/') or path == "." then
			root = formatDirFromFilename(lastFilename)
		else
			root = formatDirFromFilename(firstFilename)
		end

		local exts
		if lua then
			exts = {"lua"}
		else
			exts = {"plume", "🪶"}
		end

		local basedirs = {}
		local env = runtime.plume.table.path
		if type(env) == "table" and env.type == "table" then
			if env then
				for _, dir in ipairs(env.table) do
					if type(dir) == "string" then
						dir = formatDir(dir)
						table.insert(basedirs, dir)
					end
				end
			end
		end
		table.insert(basedirs, root)
		table.insert(basedirs, "")

		local searchPaths = {}
		local logSearchPaths = {}
		for _, base in ipairs(basedirs) do
			for i, ext in ipairs(exts) do
				for _, template in ipairs(pathTemplates) do
					template = template:gsub('%%base%%', base)
					template = template:gsub('%%path%%', path)
					template = template:gsub('%%ext%%', ext)

					template = plume.normalizePath(template)

					table.insert(searchPaths, template)
					if i==1 then
						table.insert(logSearchPaths, template)
					end
				end
			end
		end

		for _, search in ipairs(searchPaths) do
			if futf8.exists(search) then
				return search
			end
		end
		
		return nil, logSearchPaths
	end

	function plume.getModuleCacheId(filename, fileparam)
		local result = {plume.normalizePath(filename)}
		local mutableWarning
		for _, paramInfos in ipairs(fileparam) do
			table.insert(result,
				(tostring(paramInfos.key):gsub('%?', '??'):gsub(':', '::'))
				.. ':'
				.. tostring(paramInfos.value):gsub('%?', '??'):gsub(':', '::')
			)

			if type(paramInfos.value) == "table" and not mutableWarning then
				if paramInfos.value.type == "table" then
					mutableWarning = paramInfos.key
				end
			end
		end
		return table.concat(result, "?"), mutableWarning
	end
end