--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

plume.std.Random = plume.obj.luaMacro("Random", function (args)
	--!signature [number seed]
	local function _deriveSeed(oldseed, index)
		local newseed = ((oldseed + index * 1234567) * 1103515245 + 12345) % 2147483647
		if newseed == 0 then
			return 1
		else
			return newseed
		end
	end
	local state = _deriveSeed(args.table[1] or os.time(), 1)

	local function _random()
		state = ((state * 48271) % 2147483647)
		return (state / 2147483647)
	end
	local function _random_range(a, b)
		return math.floor(_random() * (b-a+1) + a)
	end

	local function shuffle(t)
		for i = #t.table, 1, -1 do
			local j = _random_range(1, i)

			t.table[i], t.table[j] = t.table[j], t.table[i]
		end
	end
	
	local random = plume.obj.quickTable{
		seed = plume.obj.luaMacro ("seed", function(args)
			--!signature [number newseed]
			state = _deriveSeed(newseed or os.time(), 1)
			return true
		end),
		choice = plume.obj.luaMacro ("choice", function(args)
			--!signature table t
			return true, t.table[_random_range(1, #t.table)]
		end),
		pchoice = plume.obj.luaMacro ("pchoice", function(args)
			--!signature table t
			local tw = 0
			for _, k in ipairs(t.keys) do
				local v = t.table[k]
				if type(v) == "number" then
					tw = tw + v
				end
			end
			local r = _random() * tw
			tw = 0
			for _, k in ipairs(t.keys) do
				local v = t.table[k]
				if type(v) == "number" then
					tw = tw + v
					if tw>=r then
						return true, k
					end
				end
			end
		end),
		shuffle = plume.obj.luaMacro ("shuffle", function(args)
			--!signature table t
			shuffle(t)
			return true
		end),
		sample = plume.obj.luaMacro ("sample", function(args)
			--!signature table t, number count
			if count > #t.table then
				return false, string.format("Cannot give a '%i'-size sample of a table with '%i' element%s.",
					count, #t.table, "s" and #t.table>1 or "")
			end
			t = plume.stdUtils.copy(t)
			shuffle(t)

			for i=#t.table, count+1, -1 do
				for j, key in ipairs(t.keys) do
					if key==i then
						t.keys[j] = nil
						break
					end
				end
				t.table[i] = nil
			end
			return true, t
		end)
	}
	random.meta = plume.obj.quickTable{
		call = plume.obj.luaMacro ("call", function(args)
			if #args.table == 0 then
				return true, _random()
			elseif #args.table == 1 then
				return true, _random_range(0, args.table[1])
			elseif #args.table == 2 then
				return true, _random_range(args.table[1], args.table[2])
			end
		end)
	}
	
	return true, random
end)