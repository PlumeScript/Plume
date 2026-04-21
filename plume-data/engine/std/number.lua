--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function (plume)
	local Number = plume.obj.table (0, 0)

	-- Manipulations
	Number.table.floor = {
		checkArgs = {checkTypes={"number", digit="number"}, args=1, signature="number x, number digit: 0", named={self=true}},
		method = function (x, options)
			local digit = tonumber(options.table.digit or 0)
			return true, math.floor(x*10^digit)*10^-digit
		end
	}
	Number.table.ceil = {
		checkArgs = {checkTypes={"number", digit="number"}, args=1, signature="number x, number digit: 0", named={self=true}},
		method =function (x, options)
			local digit = tonumber(options.table.digit or 0)
			return true, math.ceil(x*10^digit)*10^-digit
		end
	}
	Number.table.round = {
		checkArgs = {checkTypes={"number", digit="number"}, args=1, signature="number x, number digit: 0", named={self=true}},
		method = function (x, options)
			local digit = tonumber(options.table.digit or 0)
			return true, math.floor(x*10^digit + 0.5)*10^-digit
		end
	}
	Number.table.abs = {
		checkArgs = {checkTypes={"number"}, args=1, signature="number x", named={self=true}},
		method = function (x)
			return true, math.abs(x)
		end
	}
	Number.table.clamp = {
		checkArgs = {checkTypes={"number", "number", "number"}, args=3, signature="number x, number min, number max", named={self=true}},
		method = function (x, min, max)
			return true, math.min(max, math.max(min, x))
		end
	}

	plume.formatNumber = function(x, format, locale, thousandsSeparator, decimalSeparator, thousandthsSeparator)
		if thousandsSeparator == plume.obj.empty then
			thousandsSeparator = nil
		end
		if thousandthsSeparator == plume.obj.empty then
			thousandthsSeparator = nil
		end
		if not format or format == plume.obj.empty then
			format = "%s"
		end

		local result = string.format(format, x)
		if locale then
			local integerPart, decimalPart
			if result:gmatch('%.') then
				integerPart = result:match('^[^%.]+')
				decimalPart = result:match('%.([^%.]+)')
			else
				integerPart = result
			end

			if locale == "en" or locale == "us" then
				thousandsSeparator = ","
				decimalSeparator  = "."
			elseif locale == "fr" then
				thousandsSeparator    = " "
				decimalSeparator     = ","
				thousandthsSeparator = " "
			elseif locale == "custom" then
				thousandsSeparator    = thousandsSeparator or nil
				decimalSeparator     = decimalSeparator or "."
				thousandthsSeparator = thousandthsSeparator or nil
			elseif locale then
				return false, "Unknown localization format '" .. locale .. "'."
			end

			if thousandsSeparator then
				thousandsSeparator = thousandsSeparator:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
				integerPart = integerPart:gsub("(.)(...)$", "%1"..thousandsSeparator.."%2")
				for i=1, #integerPart do
					integerPart = integerPart:gsub("([0-9])([0-9][0-9][0-9])"..thousandsSeparator, "%1"..thousandsSeparator.."%2"..thousandsSeparator)
				end
			end
			result = integerPart

			if decimalPart then
				if thousandthsSeparator then
					thousandthsSeparator = thousandthsSeparator:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
					decimalPart = decimalPart:gsub("^([0-9][0-9][0-9])([0-9])", "%1"..thousandthsSeparator.."%2")
					for i=1, #integerPart do
						decimalPart = decimalPart:gsub(thousandthsSeparator.."([0-9][0-9][0-9])([0-9])", "%1"..thousandthsSeparator.."%2"..thousandthsSeparator)
					end
				end

				result = result .. decimalSeparator .. decimalPart
			end
		end

		return true, result
	end

	Number.table.format = {
		checkArgs = {
			checkTypes={"number", "string", locale="string", thousandsSeparator="string", decimalSeparator="string", thousandthsSeparator="string"},
			args=2,
			signature="number x, string format, string locale:none, string thousandsSeparator:, string decimalSeparator:., string thousandthsSeparator:",
			named={self=true}
		},
		method = function (x, format, options)
			local localTag             = options.table["locale"]
			local thousandsSeparator   = options.table["thousandsSeparator"]
			local decimalSeparator     = options.table["decimalSeparator"]
			local thousandthsSeparator = options.table["thousandthsSeparator"]

			return plume.formatNumber(x, format, localTag, thousandsSeparator, decimalSeparator, thousandthsSeparator)
		end
	}

	Number.table.localize = {
		checkArgs = {
			checkTypes={"number", "string"},
			args=2,
			signature="number x, string locale",
			named={self=true}
		},
		method = function (x, localTag)
			return plume.formatNumber(x, "%s", localTag)
		end
	}

	-- Test
	Number.table.sign = {
		checkArgs = {
			checkTypes={"number"},
			args=1,
			signature="number x",
			named={self=true}
		},
		method = function (x)
			if x>0 then
				return true, 1
			elseif x<0 then
				return true, -1
			else
				return true, 0
			end
		end
	}

	Number.meta.table.call = plume.obj.luaMacro("Number", function(args)
		local x = args.table[1]
		if x == plume.obj.empty then
			return false, "Cannot convert empty into number"
		elseif type(x) == "number" then
			return true, x
		elseif tonumber(x) then
			return true, tonumber(x)
		else
		   return false, string.format("Cannot convert %s into number", type(x))
		end
	end)
		
	plume.std.Number = Number
end