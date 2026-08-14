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

	local renderedDoc = string.format("%s %s%s\n    %s", mtype, mname, msignature, mdoc)

	local result = plume.obj.quickTable {
		type      = mtype,
		name      = mname,
		signature = msignature,
		doc       = mdoc
	}
	result:setMetaItem("tostring", plume.obj.luaMacro("tostring", function()
		return true, renderedDoc
	end))

	return result
end

plume.std.plume = plume.obj.quickTable {
	doc = plume.obj.luaMacro("doc", function (args)
		--!signature callable|table m
		return true, plume.makedoc(m)
	end)
}

plume.std.materialize = plume.obj.luaMacro("materialize", function(args, vm)
	--!signature any t
	if type(t) ~= "table" or t.type ~= "table" then
		return true, t
	end
	
	local result = plume.callForceFragment(vm, t)
	if vm.err then
		return false, vm.err
	end

	if type(result) == "table" and result.type == "table" then
		for _, key in ipairs(result.keys) do
			result.table[key] = plume.callForceFragment(vm, result.table[key])
			if vm.err then
				return false, vm.err
			end
		end
	end

	return true, result
end)

plume.std.plume.name = "plume"
plume.std.plume:setMetaItem('readonly', true)