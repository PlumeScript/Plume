--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function (plume)
	plume.stdLua.Random = {
		checkArgs = { checkTypes = {"number"}, signature = "[number seed]", maxArgs=1},
        method = function(args)
            local random = plume.obj.table(0, 0)

            function _deriveSeed(seed, index)
				seed = ((seed + index * 1234567) * 1103515245 + 12345) % 2147483647
				if seed==0 then
					return 1
				else
					return seed
				end
			end
			local state = _deriveSeed(args.table[1] or os.time(), 1)

            function _random()
            	state = ((state * 48271) % 2147483647)
				return (state / 2147483647)
            end
            function _random_range(a, b)
				return math.floor(_random() * (b-a+1) + a)
            end
           	
            random.keys = {"seed", "choice", "pchoice", "shuffle", "sample"}

            random.table.seed = plume.obj.luaMacro ("seed", function(args)
            	state = _deriveSeed(args.table[1] or os.time(), 1)
            	return true
        	end)
            random.table.choice = plume.obj.luaMacro ("choice", function(args)
            	local t = args.table[1]
            	return true, t.table[_random_range(1, #t.table)]
        	end)
        	random.table.pchoice = plume.obj.luaMacro ("pchoice", function(args)
        		local t = args.table[1]
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
        	end)

        	local function shuffle(t)
        		for k=1, #t.table do
        			local i = _random_range(1, #t.table)
        			local j = _random_range(1, #t.table)

        			t.table[i], t.table[j] = t.table[j], t.table[i]
        		end
        	end
        	random.table.shuffle = plume.obj.luaMacro ("shuffle", function(args)
        		shuffle(args.table[1])
            	return true
        	end)
        	random.table.sample = plume.obj.luaMacro ("sample", function(args)
        		local t = args.table[1]
        		local count = args.table[2]
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

        	random.meta = plume.obj.table(0, 0)
        	random.meta.table.call = plume.obj.luaMacro ("call", function(args)
        		if #args.table == 0 then
	            	return true, _random()
	            elseif #args.table == 1 then
	            	return true, _random_range(0, args.table[1])
	            elseif #args.table == 2 then
	            	return true, _random_range(args.table[1], args.table[2])
	            end
        	end)
            
            return true, random
        end
    }
end