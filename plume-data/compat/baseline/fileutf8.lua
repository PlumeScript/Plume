--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

local ffi = require("ffi")
futf8 = {}

if ffi.os == "Windows" then
	ffi.cdef[[
		int MultiByteToWideChar(unsigned int cp, uint32_t flags,
			const char* mb, int mblen, wchar_t* wc, int wclen);
		int WideCharToMultiByte(unsigned int cp, uint32_t flags,
			const wchar_t* wc, int wclen, char* mb, int mblen,
			const char* def, int* used);

		void* _wfopen(const wchar_t* path, const wchar_t* mode);
		size_t fread(void* ptr, size_t size, size_t nmemb, void* stream);
		size_t fwrite(const void* ptr, size_t size, size_t nmemb, void* stream);
		int fseek(void* stream, long offset, int whence);
		long ftell(void* stream);
		int fclose(void* stream);
	]]

	local function toWide(s)
		local len = ffi.C.MultiByteToWideChar(65001, 0, s, #s, nil, 0)
		local buf = ffi.new("wchar_t[?]", len + 1)
		ffi.C.MultiByteToWideChar(65001, 0, s, #s, buf, len)
		buf[len] = 0
		return buf
	end

	function futf8.read(path)
		local f = ffi.C._wfopen(toWide(path), toWide("rb"))
		if f == nil then return nil end
		ffi.C.fseek(f, 0, 2)
		local size = ffi.C.ftell(f)
		ffi.C.fseek(f, 0, 0)
		local buf = ffi.new("char[?]", size)
		local n = ffi.C.fread(buf, 1, size, f)
		ffi.C.fclose(f)
		local content = ffi.string(buf, n)
		local content = content:gsub("\r\n", "\n") -- emulate io.open(path):read('*a') behavior
		return content
	end

	function futf8.write(path, content)
		local f = ffi.C._wfopen(toWide(path), toWide("wb"))
	    if f == nil then return nil end
	    content = content:gsub("\n", "\r\n")-- emulate io.open(path):write(content) behavior
	    ffi.C.fwrite(content, 1, #content, f)
	    ffi.C.fclose(f)
	    return true
	end

	function futf8.exists(path)
		local f = ffi.C._wfopen(toWide(path), toWide("rb"))
		if f == nil then return false end
		ffi.C.fclose(f)
		return true
	end
else
	function futf8.read(path)
		local f = io.open(path, "rb")
		if not f then return nil end
		local content = f:read("*a")
		f:close()
		return content
	end

	function futf8.write(path, content)
		local f = io.open(path, "wb")
		if not f then return nil end
		f:write(content)
		f:close()
		return true
	end

	function futf8.exists(path)
		local f = io.open(path, "rb")
		if not f then return false end
		f:close()
		return true
	end
end
