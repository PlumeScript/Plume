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

    -----------------------
    -- WILL BE MOVED IN 1.0
    -----------------------
    plume.temp = {}
    function plume.temp.append (args)
        local t = args.table[1]
        local value = args.table[2]
        table.insert(t.table, value)
        table.insert(t.keys, #t.table)
        return true
    end
    function plume.temp.remove (args)
        local t = args.table[1]
        local index = args.table[2]

        t.keys[#t.table] = nil

        return true, table.remove(t.table, index)
    end
    function plume.temp.join (args)
        local sep = args.table.sep
        if sep == plume.obj.empty then
            sep = ""
        end
        return pcall(table.concat, args.table, sep)
    end
    -----------------------

    plume.std = {}
    require 'plume-data/engine/std/lua' (plume)
    ---------------------------------
    -- WILL BE REMOVED IN 1.0 (#175, #230, #403)
    ---------------------------------
    plume.stdLua.remove = {
        method=plume.warning.deprecatedFunctionRuntime("1.0", "`remove` standard macro", "Instead of `remove`, use `able.remove`", {175, 230}, plume.temp.remove)
    }
    plume.stdLua.append = {
        method=plume.warning.deprecatedFunctionRuntime("1.0", "`append` standard macro", "Instead of `append`, use `table.append`", {175, 230}, plume.temp.append)
    }
    plume.stdLua.join = {
        method=plume.warning.deprecatedFunctionRuntime("1.0", "`join` standard macro", "Instead of `join`, use `table.join`", {230, 430}, plume.temp.join)
    }
    ---------------------------------
    for name, f in pairs(plume.stdLua) do
        if f.checkArgs then
            f.checkArgs.signature = "$" .. name .. "(" .. f.checkArgs.signature .. ")"
            plume.std[name] = plume.obj.luaMacro(name, function(args, runtime, filestack, ip)
                
                if f.checkArgs then
                    local success, message = plume.stdArgsCheck(name, args, f.checkArgs)
                    if not success then
                        return false, message
                    end
                end

                return f.method(args, runtime, filestack, ip)
            end)
        else
             plume.std[name] = plume.obj.luaMacro(name, f.method)
        end
    end
    require 'plume-data/engine/std/vm' (plume)
    for name, obj in pairs(plume.stdVM) do
        plume.std[name] = obj
    end

    require 'plume-data/engine/std/table' (plume)
    require 'plume-data/engine/std/string' (plume)
    require 'plume-data/engine/std/number' (plume)

    for name, f in pairs(plume.std.Number.table) do
        if f.checkArgs then
            f.checkArgs.signature = "$" .. name .. "(" .. f.checkArgs.signature .. ")"
        end
        plume.std.Number.table[name] = plume.obj.luaMacro(name, function(args)
            local shiftedArgs = plume.stdShiftArgs(plume.std.Number, args)
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

    ---------------------------------
    -- WILL BE REMOVED IN 1.0 (#230, #414)
    ---------------------------------
    plume.std.tostring = {} -- hardcoded
    ---------------------------------

    local function importLuaMacro(name, f)
        return plume.obj.luaMacro(name, function(args)
            return pcall(f, unpack(args.table))
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