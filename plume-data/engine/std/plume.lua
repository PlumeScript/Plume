--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

-- plume.std.plume isn't loaded like other std table,
-- but copied at runtime creation

function plume.makedoc(m)
	m = m.macro or m

	local mtype = m.type
	local mname = (m.debugMacroName or m.name or "???")

	local signatureRef = m.signatureRef
	local msignature = ""
	if signatureRef and signatureRef.bpos then
		msignature = signatureRef.code:sub(signatureRef.bpos, signatureRef.epos)
	end

	local mdoc  = (m.doc or ""):gsub('\n', '\n    ')

	return string.format("%s %s%s\n    %s", mtype, mname, msignature, mdoc)
end

plume.std.plume = plume.obj.quickTable {
	doc = plume.obj.luaMacro("doc", function (args)
		--!signature callable|table m
		return true, plume.makedoc(m)
	end)
}
plume.std.plume.name = "plume"
plume.std.plume:setMetaItem('readonly', true)