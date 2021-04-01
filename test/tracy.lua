local util = require 'utility'

local m = {}

m._origin = {}

local function getGlobal(name)
    local g = _G
    for n in name:gmatch '[^%.]+' do
        g = g[n]
    end
    return g
end

local function setGlobal(name, v)
    local g = _G
    local l = {}
    for n in name:gmatch '[^%.]+' do
        l[#l+1] = n
    end
    for i = 1, #l - 1 do
        g = g[l[i]]
    end
    g[l[#l]] = v
end

function m.start(list)
    require 'luatracy'

    util.enableCloseFunction()

    for _, name in ipairs(list) do
        m._origin[name] = getGlobal(name)
        setGlobal(name, function (...)
            tracy.ZoneBeginN(name)
            local a, b, c, d, e, f = m._origin[name](...)
            tracy.ZoneEnd()
            return a, b, c, d, e, f
        end)
    end
end

function m.stop()
    for name, f in pairs(m._origin) do
        setGlobal(name, f)
    end
end

return m
