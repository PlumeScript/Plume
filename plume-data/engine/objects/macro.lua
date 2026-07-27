--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function(plume)

	function plume.obj.luaMacro(name, f, refs)
		return {
			type = "luaMacro",
			callable = f,
			refs = refs or {},
			name = name
		}
	end

	function plume.obj.macro(name, parent)
		local t = {
			type = "macro",
			name = name,
			positionalParamCount = 0,
			namedParamCount = 0,
			namedParamOffset = {},
			parent = parent,
			isFile = parent.type == "runtime",
			doc = "",
			upvalues = {}
		}

		if t.isFile then
			table.insert(parent.files, t)
			parent.files[name] = t
			t.fileID = #parent.files
		end

		return t
	end

	function plume.copyMacrosInfos(src, dest)
		dest.positionalParamCount = src.positionalParamCount
		dest.namedParamCount = src.namedParamCount
		dest.namedParamOffset = src.namedParamOffset
		dest.offset = src.offset
	end

end