--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

-- On Windows, os.remove fails with EACCES on a read-only file (e.g. git's
-- .git/objects). LuaFileSystem exposes no attribute setter, so clear the
-- read-only flag via the native API before delegating to the original
-- os.remove. On POSIX a read-only file is deletable (permission lives on the
-- directory), so nothing is patched.
local ffi = require("ffi")
local bit = require("bit")

local originalRemove = os.remove

if ffi.os == "Windows" then
	ffi.cdef[[
		uint32_t GetFileAttributesW(const wchar_t* lpFileName);
		int SetFileAttributesW(const wchar_t* lpFileName, uint32_t dwFileAttributes);
		int MultiByteToWideChar(unsigned int cp, uint32_t flags,
			const char* mb, int mblen, wchar_t* wc, int wclen);
	]]

	local function toWide(s)
		local len = ffi.C.MultiByteToWideChar(65001, 0, s, #s, nil, 0)
		local buf = ffi.new("wchar_t[?]", len + 1)
		ffi.C.MultiByteToWideChar(65001, 0, s, #s, buf, len)
		buf[len] = 0
		return buf
	end

	local function clearReadOnly(path)
		local attrs = ffi.C.GetFileAttributesW(toWide(path))
		if attrs ~= 0xFFFFFFFF then
			-- clear FILE_ATTRIBUTE_READONLY (0x1), keep the other attributes
			ffi.C.SetFileAttributesW(toWide(path), bit.band(attrs, bit.bnot(0x1)))
		end
	end

	function os.remove(path)
		clearReadOnly(path)
		return originalRemove(path)
	end
end
