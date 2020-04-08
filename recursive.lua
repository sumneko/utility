local m = {}
local mt = {}
mt.__index = mt

m.max = 100000
m._stacks = {}
m._mark = {}

function m._createStack(func, ...)
    local s = {
        thd = coroutine.wrap(func),
        arg = table.pack(...),
        res = nil,
    }
    m._stacks[#m._stacks+1] = s
    return s
end

function m._getResult(stack)
    local res = stack.res
    return table.unpack(res, 1, res.n)
end

function m._getArgs(stack)
    local arg = stack.arg
    return table.unpack(arg, 1, arg.n)
end

function m._callStack(stack)
    local thd = stack.thd
    stack.res = table.pack(thd(m._getArgs(stack)))
end

function m._firstCall(func, ...)
    local stack = m._createStack(func, ...)
    for _ = 1, m.max do
        local len = #m._stacks
        if len <= 0 then
            return m._getResult(stack)
        end
        stack = m._stacks[len]
        m._stacks[len] = nil
        m._callStack(stack)
    end
    error('stack overflow!')
end

function m._subCall(func, ...)
    m._createStack(func, ...)
    coroutine.yield()
end

function m.resolve(func)
    return function (...)
        if coroutine.isyieldable() then
            return m._subCall(func, ...)
        else
            return m._firstCall(func, ...)
        end
    end
end

return m
