--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function (plume)
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
		method = function(args)
			local time = plume.obj.table(0, 0)
			
			time.keys = {
				"timestamp",
				"locale",
				"zone",
				"type"
			}

			function time:updateTimestamp(args)
				self.table.timestamp = os.time({
					year   = args.year,
					month  = args.month,
					day    = args.day
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
			if args.timestamp ~= 0 then
				time.table.timestamp = args.timestamp
			elseif  args.year   ~= 0 or
					args.month  ~= 0 or
					args.day    ~= 0 or
					args.hour   ~= 0 or
					args.minute ~= 0 or
					args.second ~= 0 then
				success, result = time:updateTimestamp(args)
			else
				time.table.timestamp = os.time()
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
	}
end