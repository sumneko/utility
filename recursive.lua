local wrap        = coroutine.wrap
local cocreate    = coroutine.create
local status      = coroutine.status
local yield       = coroutine.yield
local pack        = table.pack
local unpack      = table.unpack
local isyieldable = coroutine.isyieldable

local Stacks = {}
local YieldMark = {}

local First = true
local Finish = setmetatable({}, { __close = function ()
    First = true
end })

local function createStack(func, ...)
    local s = {
        thd = wrap(func),
        arg = pack(...),
        st  = 0,
    }
    Stacks[#Stacks+1] = s
    return s
end

local function getResult(stack)
    local res = stack.res
    if not res then
        return
    end
    return unpack(res, 1, res.n)
end

local function getArg(stack)
    local arg = stack.arg
    if not arg then
        return
    end
    return unpack(arg, 1, arg.n)
end

local function callStack(stack, ...)
    local thd = stack.thd
    local res = pack(thd(...))
    if res[1] == YieldMark then
        stack.st = 1
    else
        stack.st = 2
        stack.res = res
    end
end

local function firstCall(max, func, ...)
    local lastStack = createStack(func, ...)
    for _ = 1, max do
        local len = #Stacks
        local stack = Stacks[len]
        if stack.st == 0 then
            callStack(stack, getArg(stack))
        elseif stack.st == 1 then
            callStack(stack, getResult(lastStack))
        else
            if len == 1 then
                return getResult(stack)
            end
            lastStack = stack
            Stacks[len] = nil
        end
    end
    error('stack overflow!')
end

local function subCall(func, ...)
    createStack(func, ...)
    return yield(YieldMark)
end

local m = {}

function m.resolve(func, max)
    return function (...)
        if First then
            First = false
            local finish <close> = Finish
            return firstCall(max or 10000, func, ...)
        else
            return subCall(func, ...)
        end
    end
end

return m
