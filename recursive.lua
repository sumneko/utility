local wrap        = coroutine.wrap
local yield       = coroutine.yield
local pack        = table.pack
local unpack      = table.unpack
local isyieldable = coroutine.isyieldable

local Stacks = {}

local function createStack(func, ...)
    local s = {
        thd = wrap(func),
        arg = pack(...),
        res = nil,
    }
    Stacks[#Stacks+1] = s
    return s
end

local function getResult(stack)
    local res = stack.res
    return unpack(res, 1, res.n)
end

local function getArgs(stack)
    local arg = stack.arg
    return unpack(arg, 1, arg.n)
end

local function callStack(stack)
    local thd = stack.thd
    stack.res = pack(thd(getArgs(stack)))
end

local function firstCall(max, func, ...)
    local stack = createStack(func, ...)
    for _ = 1, max do
        local len = #Stacks
        if len <= 0 then
            return getResult(stack)
        end
        stack = Stacks[len]
        Stacks[len] = nil
        callStack(stack)
    end
    error('stack overflow!')
end

local function subCall(func, ...)
    createStack(func, ...)
    yield()
end

local m = {}
local mt = {}
mt.__index = mt

m.max = 100000

function m.resolve(func)
    return function (...)
        if isyieldable() then
            return subCall(func, ...)
        else
            return firstCall(m.max, func, ...)
        end
    end
end

return m
