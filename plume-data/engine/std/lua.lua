--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function (plume)
    
    plume.stdLua = {
        print = {
            method = function(args, chunk)
                local result = {}
                for _, x in ipairs(args.table) do
                    table.insert(result, plume.repr(x, nil, args.table.pretty))
                end
                print(table.unpack(result))
                return true
            end
        },

        help = {
            checkArgs = { checkTypes = {"macro"}, signature = "macro m", args = 1},
            method = function(args)
                print("macro " .. (args.table[1].debugMacroName or args.table[1].name) .. "\n    " .. args.table[1].doc:gsub('\n', '\n    ') or "")
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
            checkArgs = {args=1, signature="any obj", named={pretty=true}},
            method = function(args)
                local obj = args.table[1]
                return true, plume.repr(obj, nil, args.table.pretty)
            end
        },

        min = {
            checkArgs = {minArgs=1, signature="...numbers", checkTypesAll="number"},
            method = function(args)
                return true, math.min(unpack(args.table))
            end
        },
        max = {
            checkArgs = {minArgs=1, signature="...numbers", checkTypesAll="number"},
            method = function(args)
                return true, math.max(unpack(args.table))
            end
        }
    }

    plume.stdLua.List = plume.obj.table(0, 0)
    plume.stdLua.List.meta = plume.obj.table(0, 0)
    plume.stdLua.List.meta.keys = {"call", "validate"}
    plume.stdLua.List.meta.table.call = plume.obj.luaMacro ("call", function(args)
        local result = plume.obj.table(0, 0)
        local t = args.table[1]
        for k, v in ipairs(t.table) do
            table.insert(result.keys, k)
            table.insert(result.table, v)
        end
        return true, result
    end)
    plume.stdLua.List.meta.table.validate = plume.obj.luaMacro ("validate", function(args)
        local t = args.table[1]
        for _, k in ipairs(t.keys) do
            if not tonumber(k) then
                return false, string.format("Received extra named argument '%s', but extra arguments must be positional.", k)
            end
        end

        return true, args
    end)

    plume.stdLua.Map = plume.obj.table(0, 0)
    plume.stdLua.Map.meta = plume.obj.table(0, 0)
    plume.stdLua.Map.meta.keys = {"call", "validate"}
    plume.stdLua.Map.meta.table.call = plume.obj.luaMacro ("call", function(args)
        local result = plume.obj.table(0, 0)
        local t = args.table[1]
        for _, k in ipairs(t.keys) do
            if not tonumber(k) then
                table.insert(result.keys, k)
                result.table[k] = t.table[k]
            end
        end
        return true, result
    end)
    plume.stdLua.Map.meta.table.validate = plume.obj.luaMacro ("validate", function(args)
        local t = args.table[1]
        for _, k in ipairs(t.keys) do
            if tonumber(k) then
                return false, "Received an extra positional argument, but extra arguments must be named."
            end
        end

        return true, args
    end)
end