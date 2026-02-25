--[[This file is part of Plume

Plume🪶 is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3 of the License.

Plume🪶 is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with Plume🪶.
If not, see <https://www.gnu.org/licenses/>.
]]

return function (plume)
	local _table = plume.obj.table (0, 2)
    _table.table.keys = {"append", "remove", "removeKey", "hasKey", "find", "findAll", "count", "entry", "join"}
    _table.table.remove = plume.obj.luaMacro("remove", plume.temp.remove)
    _table.table.append = plume.obj.luaMacro("append", plume.temp.append)
    _table.table.join   = plume.obj.luaMacro("join", plume.temp.join)
    _table.table.removeKey = plume.obj.luaMacro("removeKey", function (args)
        local t = args.table[1]
        local key = args.table[2]

        key = tonumber(key) or key
        local index = 0
        for k, v in ipairs(t.keys) do
            if v == key then
                index = k
                break
            end
        end

        t.table[key] = nil
        table.remove(t.keys, index)
        return true
    end)
    _table.table.hasKey = plume.obj.luaMacro("hasKey", function (args)
        local t = args.table[1]
        local key = args.table[2]

        key = tonumber(key) or key
        for k, v in ipairs(t.keys) do
            if v == key then
                return true, true
            end
        end

        return true, false
    end)
    _table.table.find = plume.obj.luaMacro("find", function (args)
        local t = args.table[1]
        local x = args.table[2]

        for k, v in ipairs(t.keys) do
            if t.table[v] == x then
                return true, v
            end
        end
        return true, nil
    end)
    _table.table.finds = plume.obj.luaMacro("findAll", function (args)
        local t = args.table[1]
        local x = args.table[2]

        local result = plume.obj.table(0, 0)
        for k, v in ipairs(t.keys) do
            if t.table[v] == x then
                table.insert(result.table, v)
                table.insert(result.keys, #result.table)
            end
        end

        return true, result
    end)
    _table.table.count = plume.obj.luaMacro("count", function (args)
        local t = args.table[1]
        local named = args.table.named

        if named then
            local count = 0
            for k, v in ipairs(t.keys) do
                if not tonumber(v) then
                    count = count + 1
                end
            end
            return true, count
        else
            return true, #t.keys
        end
    end)
    _table.table.entry = plume.obj.luaMacro("entry", function (args)
        local t = args.table[1]
        local index = tonumber(args.table[2])

        local key = t.keys[index]
        local result = plume.obj.table(2, 0)
        result.table[1] = key
        result.table[2] = t.table[key]
        result.keys = {1, 2}
        return true, result
    end)

    plume.std.table = _table
end