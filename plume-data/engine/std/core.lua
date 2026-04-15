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
    require 'plume-data/engine/std/utils' (plume)

    plume.std = {}
    plume.stdUtils = {}
    require 'plume-data/engine/std/plume'  (plume)
    require 'plume-data/engine/std/lua'    (plume)
    require 'plume-data/engine/std/vm'     (plume)
    require 'plume-data/engine/std/table'  (plume)
    require 'plume-data/engine/std/math'   (plume)
    require 'plume-data/engine/std/string' (plume)
    require 'plume-data/engine/std/number' (plume)
    require 'plume-data/engine/std/random' (plume)
    require 'plume-data/engine/std/os'     (plume)

    for _, source in ipairs({plume.stdLua, plume.std.Table, plume.std.Math, plume.std.plume, plume.std.os}) do
        local Table
        if source == plume.stdLua then
            Table = plume.stdLua
        else
            Table = source.table
        end

        for name, f in pairs(Table) do
            if source ~= plume.stdLua then
                table.insert(source.keys, name)
            end
            if type(f) == "table" then
                if f.checkArgs then
                    f.checkArgs.signature = "$" .. name .. "(" .. f.checkArgs.signature .. ")"
                    for k, v in pairs(f.checkArgs.checkTypes or {}) do
                        if type(v) ~= "table" then
                            f.checkArgs.checkTypes[k] = {v}
                        end
                    end
                    if f.checkArgs.checkTypesAll and type(f.checkArgs.checkTypesAll) == "string" then
                        f.checkArgs.checkTypesAll = {f.checkArgs.checkTypesAll}
                    end
                end
                Table[name] = plume.obj.luaMacro(name, function(args, runtime, filestack, ip)
                    if f.checkArgs then
                        local success, message = plume.stdArgsCheck(name, args, f.checkArgs)
                        if not success then
                            return false, message
                        end
                    end

                    if Table == plume.stdLua then
                        return f.method(args, runtime, filestack, ip)
                    elseif Table == plume.std.plume.table then
                        return f.method(unpack(args.table))
                    elseif Table == plume.std.Math.table then
                        return f.method(unpack(args.table))
                    elseif Table == plume.std.os.table then
                        return f.method(unpack(args.table))
                    elseif Table == plume.std.Table.table then
                        table.insert(args.table, args)
                        return f.method(unpack(args.table))
                    end
                end)
            end
        end
    end

    for name, obj in pairs(plume.stdLua) do
        plume.std[name] = obj
    end
    for name, obj in pairs(plume.stdVM) do
        plume.std[name] = obj
    end

    for _, Table in ipairs({plume.std.Number, plume.std.String}) do
        for name, f in pairs(Table.table) do
            if f.checkArgs then
                f.checkArgs.signature = "$" .. name .. "(" .. f.checkArgs.signature .. ")"
                for k, v in pairs(f.checkArgs.checkTypes or {}) do
                    if type(v) ~= "table" then
                        f.checkArgs.checkTypes[k] = {v}
                    end
                end
                if f.checkArgs.checkTypesAll and type(f.checkArgs.checkTypesAll) == "string" then
                    f.checkArgs.checkTypesAll = {f.checkArgs.checkTypesAll}
                end
            end
            Table.table[name] = plume.obj.luaMacro(name, function(args)

                local shiftedArgs = plume.stdShiftArgs(Table, args)
                if f.checkArgs then
                    local success, message = plume.stdArgsCheck(name, shiftedArgs, f.checkArgs)
                    if not success then
                        return false, message
                    end
                end
                table.insert(shiftedArgs.table, args)
                return f.method(unpack(shiftedArgs.table))
            end)
        end
    end

    local function importLuaMacro(name, f)
        return plume.obj.luaMacro(name, function(args)
            local success, result = pcall(f, unpack(args.table))
            return success, result
        end)
    end

    local function importLuaTable(name, t)
        local result = plume.obj.table(0, 0)

        for k, v in pairs(t) do
            table.insert(result.keys, k)
            if type(v) == "table" then
                v = importLuaTable(k, v)
            elseif type(v) == "function" then
                v = importLuaMacro(k, v)
            end
            result.table[k] = v
        end

        return result
    end
    
    plume.std.lua = plume.obj.table(0, 0)

    for name in ("assert error"):gmatch("%S+") do
        plume.std.lua.table[name] = importLuaMacro(name, _G[name])
    end

    for name in ("string math os io"):gmatch("%S+") do
        plume.std.lua.table[name] = importLuaTable(name, _G[name])
    end

    plume.std.lua.table.require =  plume.obj.luaMacro("require", function(args, runtime, fileID)
        local firstFilename = runtime.files[1].name
        local lastFilename  = runtime.files[fileID].name

        local filename, searchPaths = plume.getFilenameFromPath(args.table[1], true, runtime, firstFilename, lastFilename)
        if filename then
            return true, dofile(filename)(plume) 
        else
            msg = "Error: cannot open '" .. args.table[1] .. "'.\nPaths tried:\n\t" .. table.concat(searchPaths, '\n\t')
            return false, msg
        end
    end)
end