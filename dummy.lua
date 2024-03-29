local DUMMY = {}
local mt = {}
setmetatable(DUMMY, mt)
mt.__add      = function (a, b)
    if a == DUMMY then a = 0 end
    if b == DUMMY then b = 0 end
    return a + b
end
mt.__sub      = function (a, b)
    if a == DUMMY then a = 0 end
    if b == DUMMY then b = 0 end
    return a - b
end
mt.__mul      = function (a, b)
    if a == DUMMY then a = 0 end
    if b == DUMMY then b = 0 end
    return a * b
end
mt.__div      = function (a, b)
    if a == DUMMY then a = 0 end
    if b == DUMMY then b = 0 end
    return a / b
end
mt.__mod      = function (a, b)
    if a == DUMMY then a = 0 end
    if b == DUMMY then b = 0 end
    return a % b
end
mt.__pow      = function (a, b)
    if a == DUMMY then a = 0 end
    if b == DUMMY then b = 0 end
    return a ^ b
end
mt.__unm      = function ()
    return 0
end
mt.__concat   = function (a, b)
    if a == DUMMY then a = '' end
    if b == DUMMY then b = '' end
    return a .. b
end
mt.__len      = function ()
    return 0
end
mt.__lt       = function (a, b)
    if a == DUMMY then a = 0 end
    if b == DUMMY then b = 0 end
    return a < b
end
mt.__le       = function (a, b)
    if a == DUMMY then a = 0 end
    if b == DUMMY then b = 0 end
    return a <= b
end
mt.__index    = function (self) return self end
mt.__newindex = function (self) end
mt.__call     = function (self) return self end
mt.__pairs    = function (self) end
mt.__ipairs   = function (self) end
if _VERSION == 'Lua 5.3' or _VERSION == 'Lua 5.4' then
    local env = { DUMMY = DUMMY }
    local function loadDummy(str)
        return load(str, str, 't', env)
    end
    mt.__idiv      = loadDummy[[
        local a, b = ...
        if a == DUMMY then a = 0 end
        if b == DUMMY then b = 0 end
        return a // b
    ]]
    mt.__band      = loadDummy[[
        local a, b = ...
        if a == DUMMY then a = 0 end
        if b == DUMMY then b = 0 end
        return a & b
    ]]
    mt.__bor       = loadDummy[[
        local a, b = ...
        if a == DUMMY then a = 0 end
        if b == DUMMY then b = 0 end
        return a | b
    ]]
    mt.__bxor      = loadDummy[[
        local a, b = ...
        if a == DUMMY then a = 0 end
        if b == DUMMY then b = 0 end
        return a ~ b
    ]]
    mt.__bnot      = loadDummy[[
        return ~ 0
    ]]
    mt.__shl       = loadDummy[[
        local a, b = ...
        if a == DUMMY then a = 0 end
        if b == DUMMY then b = 0 end
        return a << b
    ]]
    mt.__shr       = loadDummy[[
        local a, b = ...
        if a == DUMMY then a = 0 end
        if b == DUMMY then b = 0 end
        return a >> b
    ]]
end

return DUMMY
