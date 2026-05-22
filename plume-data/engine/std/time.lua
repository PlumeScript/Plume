--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

local createDate, createDuration

local function getType(x)
	return type(x) == "table" and x.table.type or type(x)
end

local function convert(t, v)
	local r
	if t == "number" or t == "string" and tonumber(v) then
		r = tonumber(v)
	elseif t == "Duration" then
		r = v.value
	elseif t == "Date" then
		r = v.table.timestamp
	else
		return false, string.format("Cannot do arithmetic on '%s' value.", t)
	end

	return true, r
end

local function sleep(s)
	local t = os.clock()
	while os.clock() - t <= s do end
end

local ddadd = plume.obj.luaMacro("add", function(args)
	local x = args.table[1]
	local y = args.table[2]

	local tx = getType(x)
	local ty = getType(y)

	local success, vx = convert(tx, x)
	if not success then
		return success, vx
	end
	local success, vy = convert(ty, y)
	if not success then
		return success, vy
	end

	local result = vx + vy

	if tx ~= "Date" and ty ~= "Date" then
		return createDuration(result)
	else
		return createDate({timestamp=result})
	end
end)

local ddsub = plume.obj.luaMacro("sub", function(args)
	local x = args.table[1]
	local y = args.table[2]

	local tx = getType(x)
	local ty = getType(y)

	local success, vx = convert(tx, x)
	if not success then
		return success, vx
	end
	local success, vy = convert(ty, y)
	if not success then
		return success, vy
	end

	local result = vx - vy

	if tx ~= "Date" and ty ~= "Date" then
		return createDuration(result)
	else
		return createDate({timestamp=result})
	end
end)

local ddmul = plume.obj.luaMacro("mul", function(args)
	local x = args.table[1]
	local y = args.table[2]

	local tx = getType(x)
	local ty = getType(y)

	if tx == "Date" or ty == "Date" then
		return false, "Cannot multiply a 'Date' value."
	end

	local success, vx = convert(tx, x)
	if not success then
		return success, vx
	end
	local success, vy = convert(ty, y)
	if not success then
		return success, vy
	end

	local result = vx * vy

	return createDuration(result)
end)

local dddiv = plume.obj.luaMacro("div", function(args)
	local x = args.table[1]
	local y = args.table[2]

	local tx = getType(x)
	local ty = getType(y)

	if tx == "Date" or ty == "Date" then
		return false, "Cannot divide a 'Date' value."
	end

	local success, vx = convert(tx, x)
	if not success then
		return success, vx
	end
	local success, vy = convert(ty, y)
	if not success then
		return success, vy
	end

	local result = vx / vy

	return createDuration(result)
end)


function createDate (args)
	local time = plume.obj.table(0, 0)
	
	time.keys = {
		"timestamp",
		"locale",
		"zone",
		"type"
	}

	function time:updateTimestamp(args)
		self.table.timestamp = os.time({
			year   = args.year or 1970,
			month  = args.month or 1,
			day    = args.day or 1
		})
		if self.table.timestamp then
			return true
		else
			return false, "Cannot make a Date frome these parameters."
		end
	end

	function time:getFromTimestamp()
		local timestamp   = self.table.timestamp
		return {
			year   = tonumber(os.date("%Y", timestamp)),
			month  = tonumber(os.date("%m", timestamp)),
			day    = tonumber(os.date("%d", timestamp)),
			hour   = tonumber(os.date("%H", timestamp)),
			minute = tonumber(os.date("%M", timestamp)),
			second = tonumber(os.date("%S", timestamp))
		}
	end

	time.table.type      = "Date"

	local success, result = true
	if args.timestamp and args.timestamp ~= 0 then
		time.table.timestamp = args.timestamp
	else
		success, result = time:updateTimestamp(args)
	end

	if not success then
		return success, result
	end

	time.meta = plume.obj.quickTable{
		tostring = plume.obj.luaMacro ("tostring", function(args)
			local self = args.table.self
			return true, os.date("%x", self.table.timestamp)
		end),
		setindex = plume.obj.luaMacro ("setindex", function(args)
			local self   = args.table.self
			local key    = args.table[1]
			local value  = args.table[2]
			local values = self:getFromTimestamp()

			if not values[key] then
				return true, value
			end

			values[key] = value
			time:updateTimestamp(values)

			return true
		end),
		getindex = plume.obj.luaMacro ("getindex", function(args)
			local self = args.table.self
			local key = args.table[1]
			local values = self:getFromTimestamp()

			if not values[key] then
				return false, string.format("Unregistered key '%s'", key)
			end
			return true, values[key]
		end),
		add = ddadd,
		sub = ddsub,
		mul = ddmul,
		div = dddiv,
		eq = plume.obj.luaMacro("eq", function(args)
			local x = args.table[1]
			local y = args.table[2]

			local tx = getType(x)
			local ty = getType(y)

			if tx ~= "Date" or ty ~= "Date" then
				return true, false
			end

			return true, x.table.timestamp == y.table.timestamp
		end),
		lt = plume.obj.luaMacro("lt", function(args)
			local x = args.table[1]
			local y = args.table[2]

			local tx = getType(x)
			local ty = getType(y)

			if tx ~= "Date" or ty ~= "Date" then
				return false, string.format("Cannot compare 'Date' and '%s'", (tx ~= "Date" and tx or ty))
			end

			return true, x.table.timestamp < y.table.timestamp
		end)
	}
	
	return true, time
end

function createDuration(s)
	local duration = plume.obj.table(0, 0)
	duration.value = s

	duration.keys = {"type"}

	duration.table.type = "Duration"

	duration.meta = plume.obj.table(0, 0)
	duration.meta.keys = {"tostring", "setindex", "getindex", "add", "sub", "mul", "div"}
	duration.meta.table.tostring = plume.obj.luaMacro ("tostring", function(args)
		local self = args.table.self
		return true, self.value
	end)
	duration.meta.table.setindex = plume.obj.luaMacro ("setindex", function(args)
		local self   = args.table.self
		local key    = args.table[1]
		
		return false, "Cannot edit 'duration' fields."
	end)
	duration.meta.table.getindex = plume.obj.luaMacro ("getindex", function(args)
		local self = args.table.self
		local key = args.table[1]
		
		if key == "day" then
			return true, self.value / 86400
		elseif key == "hour" then
			return true, self.value / 3600
		elseif key == "minute" then
			return true, self.value / 60
		elseif key == "second" then
			return true, self.value
		end

		if not values[key] then
			return false, string.format("Unregistered key '%s'", key)
		end
	end)

	duration.meta.table.add = ddadd
	duration.meta.table.sub = ddsub
	duration.meta.table.mul = ddmul
	duration.meta.table.div = dddiv

	duration.meta.table.eq = plume.obj.luaMacro("eq", function(args)
		local x = args.table[1]
		local y = args.table[2]

		local tx = getType(x)
		local ty = getType(y)

		if tx ~= "Duration" or ty ~= "Duration" then
			return true, false
		end

		return true, x.value == y.value
	end)

	duration.meta.table.lt = plume.obj.luaMacro("lt", function(args)
		local x = args.table[1]
		local y = args.table[2]

		local tx = getType(x)
		local ty = getType(y)

		if tx ~= "Duration" or ty ~= "Duration" then
			return false, string.format("Cannot compare 'Duration' and '%s'", (tx ~= "Duration" and tx or ty))
		end

		return true, x.value < y.value
	end)

	return true, duration
end

local function ignoreSuccess(x, y)
	return y
end

plume.std.Time = plume.obj.quickTable{
	date = plume.obj.luaMacro("date", function(args)
		--!signature number year: 0, number month: 0, number day: 0, number year: 0, number year: 0, number year: 0, string zone:, string locale:, number timestamp: 0
		return createDate(args)
	end),
	
	duration = plume.obj.luaMacro("duration", function(args)
		--!signature number seconds
		return createDuration(seconds)
	end),

	now = plume.obj.luaMacro("now", function(args)
		--!signature 
		return createDate({timestamp=os.time()})
	end),

	SECOND = ignoreSuccess(createDuration(1)),
	MINUTE = ignoreSuccess(createDuration(60)),
	DAY    = ignoreSuccess(createDuration(86400)),
	WEEK   = ignoreSuccess(createDuration(604800)),

	sleep =  plume.obj.luaMacro("sleep", function (args)
		--!signature number|Duration s
		if type(s) == "table" then
			s = s.value
		end

		sleep(s)
		return true
	end)
}
