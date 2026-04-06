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
	local Table = plume.obj.table (0, 10)
    Table.keys = {"append", "remove", "removeKey", "hasKey", "find", "findAll", "count", "entry", "join", "deepcopy"}
    Table.table.remove = {
        checkArgs = {
            checkTypes = {"table"},
            signature = "table t[, string|number index]",
            named={self=true},
            minArgs=1,
            maxArgs=2
        },
        method = function  (t, index)
            --`Table` automatically passes all of the macro's arguments as its second argument
            index = (type(index) == "number" and index) or #t.table

            for key, value in ipairs(t.keys) do
                if value == index then
                    table.remove(t.keys, key)
                end
            end

            return true, table.remove(t.table, index)
        end
    }
    Table.table.append = {
        checkArgs = {
            checkTypes = {"table"},
            signature = "table t, any x",
            named={self=true},
            -- args=2
        },
        method = function  (t, value)
            table.insert(t.table, value)
            table.insert(t.keys, #t.table)
            return true
        end
    }
    Table.table.join   = {
        method = function  (...)
            local args = {...}

            local options = table.remove(args)
            local sep = options.table.sep
            if sep == plume.obj.empty then
                sep = ""
            end

            if args and #args == 1 and type(args[1]) == "table" and args[1].type == "table" then
                return false, plume.error.joinErrorHint()
            end

            for i, value in ipairs(args) do
                if type(value) ~= "number" and type(value) ~= "string" then
                    return false, plume.error.wrongArgTypeStd(i, "join", type(value), "string", "$table.join(string ...items)")
                end
            end

            return pcall(table.concat, args, sep)
        end
    }
    Table.table.removeKey = {
        checkArgs = {
            checkTypes = {"table"},
            signature = "Table t, any key",
            named={self=true},
            args=2
        },
        method = function (t, key)
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
        end
    }
    Table.table.hasKey = {
        checkArgs = {
            checkTypes = {"table"},
            signature = "table t, any key",
            named={self=true},
            args=2
        },
        method = function (t, key)
            key = tonumber(key) or key
            for k, v in ipairs(t.keys) do
                if v == key then
                    return true, true
                end
            end

            return true, false
        end
    }
    Table.table.find = {
        checkArgs = {
            checkTypes = {"table"},
            signature = "table t, any x",
            named={self=true},
            args=2
        },
        method = function (t, x)
            for k, v in ipairs(t.keys) do
                if t.table[v] == x then
                    return true, v
                end
            end
            return true, nil
        end
    }
    Table.table.findAll = {
        checkArgs = {
            checkTypes = {"table"},
            signature = "table t, any x",
            named={self=true},
            args=2
        },
        method = function (t, x)
            local result = plume.obj.table(0, 0)
            for k, v in ipairs(t.keys) do
                if t.table[v] == x then
                    table.insert(result.table, v)
                    table.insert(result.keys, #result.table)
                end
            end

            return true, result
        end
    }
    Table.table.count = {
        checkArgs = {
            checkTypes = {"table"},
            signature = "table t, ?named",
            named={self=true, named=true},
            args=1
        },
        method = function (t, options)
            local named = options.table.named

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
        end
    }
    Table.table.entry = {
        checkArgs = {
            checkTypes = {"table"},
            signature = "table t, any index",
            named={self=true},
            args=2
        },
        method = function (t, index)
            local key = t.keys[index]
            local result = plume.obj.table(2, 0)
            result.table[1] = key
            result.table[2] = t.table[key]
            result.keys = {1, 2}
            
            return true, result
        end
    }
    Table.table.sort = {
        checkArgs = {
            checkTypes = {"table"},
            signature = "table t",
            named={self=true},
            args=1
        },
        method = function (t)
            table.sort(t.table)
            return true
        end
    }

    local function copy(t, deep, nt)
        local nt = nt or plume.obj.table(#t.table, #t.keys)

        for _, key in ipairs(t.keys) do
            local rawvalue = t.table[key]
            local value
            if deep and type(rawvalue) == "table" and rawvalue.type == "table" then
                if deep[rawvalue] then
                    value = deep[rawvalue]
                else
                    deep[rawvalue] = plume.obj.table(0, 0)
                    value = copy(rawvalue, deep, deep[rawvalue])
                end
            else
                value = rawvalue
            end

            table.insert(nt.keys, key)
            nt.table[key] = value
        end

        return nt
    end

    Table.table.copy = {
        checkArgs = {
            checkTypes = {"table"},
            signature = "table t",
            named={self=true},
            args=1
        },
        method = function (t)
            return true, copy(t)
        end
    }

    Table.table.deepcopy = {
        checkArgs = {
            checkTypes = {"table"},
            signature = "table t",
            named={self=true},
            args=1
        },
        method = function (t)
            return true, copy(t, {})
        end
    }

    plume.std.Table = Table
end