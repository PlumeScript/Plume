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
				"year",
				"month",
				"day",
				"hour",
				"minute",
				"second",
				"timestamp",
				"locale",
				"zone",
				"type"
			}

			function time:updateTimestamp()
				self.table.timestamp = os.time({
					year   = self.table.year,
					month  = self.table.month,
					day    = self.table.day
				})
				if self.table.timestamp then
					self:updateFromTimestamp()
					return true
				else
					return false, "Cannot make a Date frome these parameters."
				end
			end

			function time:updateFromTimestamp()
				local timestamp   = self.table.timestamp
				self.table.year   = tonumber(os.date("%Y", timestamp))
				self.table.month  = tonumber(os.date("%m", timestamp))
				self.table.day    = tonumber(os.date("%d", timestamp))
				self.table.hour   = tonumber(os.date("%H", timestamp))
				self.table.minute = tonumber(os.date("%M", timestamp))
				self.table.second = tonumber(os.date("%S", timestamp))
				return true
			end

			time.table.type      = "Date"

			time.table.year      = args.year      or 1970
			time.table.month     = args.month     or 1
			time.table.day       = args.day       or 1
			time.table.hour      = args.hour      or 0
			time.table.minute    = args.minute    or 0
			time.table.second    = args.second    or 0
			time.table.timestamp = args.timestamp or 0

			local success, result = true
			if time.table.timestamp ~= 0 then
				success, result = time:updateFromTimestamp()
			elseif  time.table.year   ~= 1970 or
					time.table.month  ~= 1 or
					time.table.day    ~= 1 or
					time.table.hour   ~= 0 or
					time.table.minute ~= 0 or
					time.table.second ~= 0 then
				success, result = time:updateTimestamp()
			else
				time.table.timestamp = os.time()
				success, result = time:updateFromTimestamp()
			end

			if not success then
				return success, result
			end

			time.meta = plume.obj.table(0, 0)
			time.meta.keys = {"tostring"}
			time.meta.table.tostring = plume.obj.luaMacro ("tostring", function(args)
				local self = args.table.self
				return true, os.date("%x", self.table.timestamp)
			end)
			
			return true, time
		end
	}
end