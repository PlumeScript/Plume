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
	plume.std.os = plume.obj.table (0, 0)

	plume.std.os.table.getEnv = {
        checkArgs = {
            checkTypes = {"string"},
            signature = "string name",
            named={self=true},
            args=1,
        },
        method = function (x)
            return true, os.getenv(x)
        end
    }

    -- Very basic implementation
    plume.std.os.table.execute = {
        checkArgs = {
            checkTypes = {"string"},
            signature = "string commande",
            named={self=true},
            args=1,
        },
        method = function (x)
        	local success, result = pcall(function()
			    local h = io.popen(x)
				if not h then
					return nil
				end
				local r = h:read("*a")
				h:close()
				return r
			end)
            return success, result
        end
    }
end