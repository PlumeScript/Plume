--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

plume.std.Math = plume.obj.quickTable{
    sin = plume.obj.luaMacro("sin", function (args)
        --!signature number x
        return true, math.sin(x)
    end),
    cos = plume.obj.luaMacro("cos", function (args)
        --!signature number x
        return true, math.cos(x)
    end),
    tan = plume.obj.luaMacro("tan", function (args)
        --!signature number x
        return true, math.tan(x)
    end),
    asin =  plume.obj.luaMacro("asin", function (args)
        --!signature number x
        return true, math.asin(x)
    end),
    acos =  plume.obj.luaMacro("acos", function (args)
        --!signature number x
        return true, math.acos(x)
    end),
    atan =  plume.obj.luaMacro("atan", function (args)
        --!signature number x
        return true, math.atan(x)
    end),
    atan2 =  plume.obj.luaMacro("atan2", function (args)
        --!signature number x, number y
        return true, math.atan2(x, y)
    end),
    sinh =  plume.obj.luaMacro("sinh", function (args)
        --!signature number x
        return true, math.sinh(x)
    end),
    cosh =  plume.obj.luaMacro("cosh", function (args)
        --!signature number x
        return true, math.cosh(x)
    end),
    tanh =  plume.obj.luaMacro("tanh", function (args)
        --!signature number x
        return true, math.tanh(x)
    end),
    log =  plume.obj.luaMacro("log", function (args)
        --!signature number x
        return true, math.log(x)
    end),
    log10 =  plume.obj.luaMacro("log10", function (args)
        --!signature number x
        return true, math.log10(x)
    end),
    pi   = math.pi,
    e    = math.exp(1),
    huge = math.huge
}