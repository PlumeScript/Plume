local TEST_COUNT = 1000
local MAX_DEEP = 3
local SEED = 651

local templates = {
[[if <bool>
	<body>
elseif <bool>
else
	<body>
end
]],
[[if <bool>
	<body>
else
	<body>
end
]],
[[if <bool>
	<body>
end
]],
[[macro <name:macro>(x)
	<body>
end
$<name>(x)
]],
[[for <name:loop> in seq(4)
	<body>
end
]],
[[let <name> = 0
while <name:loop> < 4
	set <name> += 1
	<body>
end
]],
[[let <name:ctx> = $Context()
with ($<name>: 5)
	<body>
end
]],
[[
do
	<body>
end]],
[[
let <name> = do
	<body>
end]],
[[
let <name> = 1
]],
[[
<body>
<body>]]
}


local uid = 0

local function genName()
	uid = uid + 1
	return "var" .. uid
end

local function merge(t1, t2)
	local result = {}
	for _, item in ipairs(t1) do
		table.insert(result, item)
	end
	for _, item in ipairs(t2) do
		table.insert(result, item)
	end
	return result
end

local function makeSnippet(deep, flags)
	flags = flags or {ctx={}, macro=true}
	if deep==0 then
		local l = {"a"}
		
		if #flags.ctx>0 then
			table.insert(l, "$"..flags.ctx[math.random(1, #flags.ctx)] .. "()")
		end
		if flags.loop then
			table.insert(l, "break")
			table.insert(l, "continue")
		end
		if flags.macro then
			table.insert(l, "leave")
		end
		return l[math.random(1, #l)]
	end
	
	local template = templates[math.random(1, #templates)]
	local newflags = {ctx={}}

	local name

	return template:gsub('<([^%s>:]*):?(%S-)>', function(m, flag)
		if m == "name" then
			name = name or genName()
			if flag == "ctx" then
				table.insert(newflags.ctx, name)
			elseif flag == "loop" then
				newflags.loop = true
			elseif flag == "macro" then
				newflags.macro = true
			end
			return name
		elseif m == "bool" then
			if math.random()>0.5 then
				return "true"
			else
				return "false"
			end
		elseif m == "body" then
			return makeSnippet(deep-1, {
				ctx   = merge(flags.ctx, newflags.ctx),
				loop  = (flags.loop or newflags.loop) and not newflags.macro,
				macro = (flags.macro or newflags.macro)
			}):gsub('\n', '\n\t')
		end

	end)
end

local ignoredErrors = {
	["SYNTAX ERROR: Cannot use `leave` in a value block. (i) `leave` is designed to stop accumulation, but this macro returns a single value. You should instead, use an `if` with an empty branch."] = true
}

local function runFuzzer(plume)
	local errors = {}
	local errorCount = 0
	for deep = 1, MAX_DEEP do
		for i = 1, TEST_COUNT do
			uid = 0
			local snippet = makeSnippet(deep)
			local success, result = plume.executeString(snippet, "test.plume")
			if not success then
				local error = result:match('^(.-)\ntest%.plume') or result
				if not ignoredErrors[error] then
					if not errors[error] then
						errorCount = errorCount + 1
					end
					if not errors[error] or #errors[error] > #snippet then
						errors[error] = snippet
					end
				end
			end
		end
		if errorCount > 0 then
			print(string.format('%s error(s) found at deep %s.', errorCount, deep))
			errorCount = 0
		end
	end

	for error, snippet in pairs(errors) do
		print("===============")
		print("--- Snippet ---")
		print(snippet)
		print("---  Error ---")
		print(error)
	end
end

package.path =  "../../?.lua;" .. package.path
local plume = require "plume-data/engine/init"
plume.runDevFlag = true
math.randomseed(SEED)
runFuzzer(plume)