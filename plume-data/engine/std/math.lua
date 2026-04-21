--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
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