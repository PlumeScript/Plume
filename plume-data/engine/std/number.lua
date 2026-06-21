--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

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
	if locale and locale ~= plume.obj.empty then
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
			for _=1, #integerPart do
				integerPart = integerPart:gsub(
					"([0-9])([0-9][0-9][0-9])"..thousandsSeparator,
					"%1"..thousandsSeparator.."%2"..thousandsSeparator
				)
			end
		end
		result = integerPart

		if decimalPart then
			if thousandthsSeparator then
				thousandthsSeparator = thousandthsSeparator:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
				decimalPart = decimalPart:gsub("^([0-9][0-9][0-9])([0-9])", "%1"..thousandthsSeparator.."%2")
				for _=1, #integerPart do
					decimalPart = decimalPart:gsub(
						thousandthsSeparator.."([0-9][0-9][0-9])([0-9])",
						"%1"..thousandthsSeparator.."%2"..thousandthsSeparator
					)
				end
			end

			result = result .. decimalSeparator .. decimalPart
		end
	end

	return true, result
end

plume.std.Number = plume.obj.quickTable{
	-- Manipulations
	floor = plume.obj.luaMacro("floor", function (args)
		--!override-self-plume.std.Number
		--!signature number x, number digit:0
		return true, math.floor(x*10^digit)*10^-digit
	end),
	ceil = plume.obj.luaMacro("ceil", function (args)
		--!override-self-plume.std.Number
		--!signature number x, number digit:0
		return true, math.ceil(x*10^digit)*10^-digit
	end),
	round = plume.obj.luaMacro("round", function (args)
		--!override-self-plume.std.Number
		--!signature number x, number digit:0
		return true, math.floor(x*10^digit + 0.5)*10^-digit
	end),
	abs = plume.obj.luaMacro("abs", function (args)
		--!override-self-plume.std.Number
		--!signature number x
		return true, math.abs(x)
	end),
	clamp = plume.obj.luaMacro("clamp", function (args)
		--!override-self-plume.std.Number
		--!signature number x, number min, number max
		return true, math.min(max, math.max(min, x))
	end),
	format = plume.obj.luaMacro("format", function (args)
		--!override-self-plume.std.Number
		--!signature number x, string format, (string locale:), (string thousandsSeparator:), (string decimalSeparator:), (string thousandthsSeparator:)
		return plume.formatNumber(
			x, format, locale, thousandsSeparator, decimalSeparator, thousandthsSeparator
		)
	end),
	localize = plume.obj.luaMacro("format", function (args, runtime)
		--!override-self-plume.std.Number
		--!signature number x, [string locale]
		if not locale then
			locale = runtime.plume.table.locale:get()
		end
		return plume.formatNumber(x, "%s", locale)
	end),

	-- Test
	sign = plume.obj.luaMacro("sign", function (args)
		--!override-self-plume.std.Number
		--!signature number x
		if x>0 then
			return true, 1
		elseif x<0 then
			return true, -1
		else
			return true, 0
		end
	end)
}

plume.std.Number.meta = plume.obj.quickTable {
	call = plume.obj.luaMacro("Number", function(args)
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
}