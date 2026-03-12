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
    
    plume.stdLua = {
        print = {
            method = function(args, chunk)
                local result = {}
                for _, x in ipairs(args.table) do
                    table.insert(result, plume.repr(x))
                end
                print(table.unpack(result))
                return true
            end
        },
        
        --------------------------------------  
        -- WILL BE REMOVED IN 1.0 (#230, #414)  
        --------------------------------------  
        tonumber = {
            method = plume.warning.deprecatedFunctionRuntime("Sparrow", "`tonumber` standard macro", "Use `Number` instead", {230, 414},function(args, chunk)
                    local x = args.table[1]
                    if x == plume.obj.empty then
                        return false, "Cannot convert empty into number"
                    elseif type(x) == "number" then
                        return true, x
                    else
                       return false, string.format("Cannot convert %s into number", type(x))
                    end
                    return true, table.concat(result)
                end
            )
        },
        --------------------------------------  

        -- path
        setPlumePath = {
            checkArgs = {checkTypes={"string"}, args=1, signature="string path"},
            method = function(args, runtime)
                runtime.env.plume_path = args.table[1]
                return true
            end
        },

        addToPlumePath = {
            checkArgs = {checkTypes={"string"}, args=1, signature="string path"},
            method = function(args, runtime)
                runtime.env.plume_path = (runtime.env.plume_path or "") .. ";" .. args.table[1]
                return true
            end
        },

        -- io
        write = {
            checkArgs = {checkTypes={"string"}, minArgs=1, maxArgs=math.huge, signature="string path, ...content"},
            method = function(args)
            local filename = args.table[1]
            local content = table.concat(args.table, 2,  #args.table)
            local file = io.open(filename, "w")
                if not file then
                    return false, "Cannot write file '" .. filename .. "'."
                end
                file:write(content)
            file:close()
            return true
        end },

        read = {
            checkArgs = {checkTypes={"string"}, args=1, signature="string path"},
            method = function(args)
            local filename = args.table[1]
            local file = io.open(filename)
                if not file then
                    return false, "Cannot read file '" .. filename .. "'."
                end
                local content = file:read("*a")
            file:close()
            return true, content
        end },

        rawset = {
            checkArgs = {checkTypes={"table", "string"}, args=3, signature="table t, string key, any value"},
            method = function(args)
                local obj   = args.table[1]
                local key   = args.table[2]
                local value = args.table[3]

                if not obj.table[key] then
                    table.insert(obj.keys, key)
                end
                obj.table[key] = value
                return true
            end
        },

        repr = {
            checkArgs = {args=1, signature="any obj"},
            method = function(args)
                local obj = args.table[1]
                return true, plume.repr(obj)
            end
        }
    }
end