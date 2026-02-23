-- --[[This file is part of Plume

-- Plume🪶 is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, version 3 of the License.

-- Plume🪶 is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details.

-- You should have received a copy of the GNU General Public License along with Plume🪶.
-- If not, see <https://www.gnu.org/licenses/>.
-- ]]

return function(plume)
	local function damerauLevenshtein(a, b)
	    local m, n = #a, #b
	    if m == 0 then return n end
	    if n == 0 then return m end
	      
	    local prev, curr = {}, {}
	    for j = 0, n do prev[j] = j end
	      
	    for i = 1, m do
	        curr[0] = i
	        for j = 1, n do
	            local cost = (a[i] == b[j]) and 0 or 1
	            curr[j] = math.min(
	                prev[j] + 1,
	                curr[j-1] + 1,    
	                prev[j-1] + cost
	            )
	            if i > 1 and j > 1 and a[i] == b[j-1] and a[i-1] == b[j] then
	                curr[j] = math.min(curr[j], (prev[j-2] or 0) + cost)
	            end
	        end
	        prev, curr = curr, prev
	    end
	    return prev[n]
	end

	local function toChars(str)
	    local t = {}
	    for i = 1, #str do t[i] = str:sub(i,i) end
	    return t
	end

	local function tokenizeSnake(str)
	    local tokens = {}
	    for token in str:gmatch("[^_]+") do
	        table.insert(tokens, token:lower())
	    end
	    return tokens
	end

	local function tokenizeCamel(str)
	    local tokens = {}
	    local current = {}
	      
	    for i = 1, #str do
	        local c = str:sub(i,i)
	        local isUpper = c:match("[A-Z]") ~= nil
	          
	        if isUpper and #current > 0 then
	            table.insert(tokens, table.concat(current):lower())
	            current = {}
	        end
	        table.insert(current, c)
	    end
	      
	    if #current > 0 then
	        table.insert(tokens, table.concat(current):lower())
	    end
	    return tokens
	end

	local function haveCommonSignificantToken(tokensA, tokensB, minLen)
	    minLen = minLen or 2
	    local significant = {}
	    for _, token in ipairs(tokensA) do
	        if #token >= minLen then
	            significant[token] = true
	        end
	    end
	    for _, token in ipairs(tokensB) do
	        if #token >= minLen and significant[token] then
	            return true
	        end
	    end
	    return false
	end

	local function semanticDistance(s, t)
		if #s <= 3 or #t <= 3 then
			return math.huge
		end

	    local dChar = damerauLevenshtein(toChars(s), toChars(t))
	    
	    local dSnake = math.huge
	    local snakeS, snakeT = tokenizeSnake(s), tokenizeSnake(t)
	    if #snakeS >= 2 and #snakeT >= 2 then
	        if haveCommonSignificantToken(snakeS, snakeT, 2) then
	            dSnake = damerauLevenshtein(snakeS, snakeT)
	        end
	    end
	    
	    local dCamel = math.huge
	    local camelS, camelT = tokenizeCamel(s), tokenizeCamel(t)
	    if #camelS >= 2 and #camelT >= 2 then
	        if haveCommonSignificantToken(camelS, camelT, 2) then
	            dCamel = damerauLevenshtein(camelS, camelT)
	        end
	    end
	    
	    return math.min(dChar, dSnake, dCamel)
	end

	function plume.error.suggestIdentifiers(input, candidates, threshold, maxResult)
	    local matches = {}
	      
	    for _, candidate in ipairs(candidates) do
	        local dist = semanticDistance(input, candidate)
	        if dist <= threshold then
	            table.insert(matches, {
	                text = candidate,
	                distance = dist,
	            })
	        end
	    end
	      
	    table.sort(matches, function(a, b)
	        if a.distance ~= b.distance then
	            return a.distance < b.distance
	        else
	            return a.text < b.text
	        end
	    end)
	      
	    local result = {}
	    for i, m in ipairs(matches) do
	    	result[i] = m.text
	    	if i >= maxResult then
	    		break
	    	end
	    end
	    return result
	end
end

