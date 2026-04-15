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
	local Math = plume.obj.table (0, 10)
    
    Math.table.sin = {
        checkArgs = {
            checkTypes = {"number"},
            signature = "number x",
            named={self=true},
            args=1,
        },
        method = function  (x)
            return true, math.sin(x)
        end
    }
    Math.table.cos = {
        checkArgs = {
            checkTypes = {"number"},
            signature = "number x",
            named={self=true},
            args=1,
        },
        method = function  (x)
            return true, math.cos(x)
        end
    }
    Math.table.tan = {
        checkArgs = {
            checkTypes = {"number"},
            signature = "number x",
            named={self=true},
            args=1,
        },
        method = function  (x)
            return true, math.tan(x)
        end
    }
    Math.table.asin = {
        checkArgs = {
            checkTypes = {"number"},
            signature = "number x",
            named={self=true},
            args=1,
        },
        method = function  (x)
            return true, math.asin(x)
        end
    }
    Math.table.acos = {
        checkArgs = {
            checkTypes = {"number"},
            signature = "number x",
            named={self=true},
            args=1,
        },
        method = function  (x)
            return true, math.acos(x)
        end
    }
    Math.table.atan = {
        checkArgs = {
            checkTypes = {"number"},
            signature = "number x",
            named={self=true},
            args=1,
        },
        method = function  (x)
            return true, math.atan(x)
        end
    }
    Math.table.atan2 = {
        checkArgs = {
            checkTypes = {"number", "number"},
            signature = "number x, number x",
            named={self=true},
            args=2,
        },
        method = function  (x, y)
            return true, math.atan2(x, y)
        end
    }
    Math.table.sinh = {
        checkArgs = {
            checkTypes = {"number"},
            signature = "number x",
            named={self=true},
            args=1,
        },
        method = function  (x)
            return true, math.sinh(x)
        end
    }
    Math.table.cosh = {
        checkArgs = {
            checkTypes = {"number"},
            signature = "number x",
            named={self=true},
            args=1,
        },
        method = function  (x)
            return true, math.cosh(x)
        end
    }
    Math.table.tanh = {
        checkArgs = {
            checkTypes = {"number"},
            signature = "number x",
            named={self=true},
            args=1,
        },
        method = function  (x)
            return true, math.tanh(x)
        end
    }

    Math.table.log = {
        checkArgs = {
            checkTypes = {"number"},
            signature = "number x",
            named={self=true},
            args=1,
        },
        method = function  (x)
            return true, math.log(x)
        end
    }
    Math.table.log10 = {
        checkArgs = {
            checkTypes = {"number"},
            signature = "number x",
            named={self=true},
            args=1,
        },
        method = function  (x)
            return true, math.log10(x)
        end
    }

    Math.table.pi   = math.pi
    Math.table.e    = math.exp(1)
    Math.table.huge = math.huge

    plume.std.Math = Math
end