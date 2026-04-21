--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function (plume)
	local function createDate (args)
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

		time.meta = plume.obj.table(0, 0)
		time.meta.keys = {"tostring", "setindex", "getindex"}
		time.meta.table.tostring = plume.obj.luaMacro ("tostring", function(args)
			local self = args.table.self
			return true, os.date("%x", self.table.timestamp)
		end)
		time.meta.table.setindex = plume.obj.luaMacro ("setindex", function(args)
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
		end)
		time.meta.table.getindex = plume.obj.luaMacro ("getindex", function(args)
			local self = args.table.self
			local key = args.table[1]
			local values = self:getFromTimestamp()

			if not values[key] then
				return false, string.format("Unregistered key '%s'", key)
			end
			return true, values[key]
		end)
		
		return true, time
	end

	local function createDuration(s)
		local duration = plume.obj.table(0, 0)
		duration.value = s

		duration.keys = {"type"}

		duration.table.type = "Duration"

		duration.meta = plume.obj.table(0, 0)
		duration.meta.keys = {"tostring", "setindex", "getindex"}
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

		return true, duration
	end

	plume.std.Time = plume.obj.table (0, 0)
	plume.std.Time.table.date = {
		checkArgs = {
			named = {
				self      = true,
				year      = true,
				month     = true,
				day       = true,
				hour      = true,
				minute    = true,
				second    = true,
				locale    = true,
				zone      = true,
				timestamp = true
			},
			checkTypes = {
				year      = "number",
				month     = "number",
				day       = "number",
				hour      = "number",
				minute    = "number",
				second    = "number",
				locale    = "string",
				zone      = "string",
				timestamp = "number"
			},
			signature = "number year: 0, number month: 0, number day: 0, number year: 0, number year: 0, number year: 0, string zone:, string locale:, number timestamp: 0",
			maxArgs=0
		},
		method = createDate
	}

	plume.std.Time.table.duration = {
		checkArgs = {
			signature="",
			args=1,
			named = {self=true},
			checkTypes={"number"}
		},
		method = function(args)
			return createDuration(args[1])
		end
	}

	plume.std.Time.table.now = {
		checkArgs = {
			signature="",
			maxArgs=0
		},
		method = function(args)
			return createDate({timestamp=os.time()})
		end
	}

	local _
	_, plume.std.Time.table.SECOND = createDuration(1)
	_, plume.std.Time.table.MINUTE = createDuration(60)
	_, plume.std.Time.table.DAY    = createDuration(86400)
	_, plume.std.Time.table.WEEK   = createDuration(604800)
end