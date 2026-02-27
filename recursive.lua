local wrap        = coroutine.wrap
local yield       = coroutine.yield
local pack        = table.pack
local unpack      = table.unpack

local Stacks = {}
local YieldMark = {}

local First = true

-- 当前协程内已使用的递归深度（每个协程独享，通过调度循环维护）
local CurrentDepth = 0
-- 每个协程允许的最大递归深度，超过后才切换协程
local SliceSize = 256

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
            -- 新协程开始，重置深度计数
            CurrentDepth = 0
            callStack(stack, getArg(stack))
        elseif stack.st == 1 then
            -- 恢复被挂起的协程，重置深度计数
            CurrentDepth = 0
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
    CurrentDepth = CurrentDepth + 1
    if CurrentDepth < SliceSize then
        -- 深度未满，在当前协程内直接递归
        -- 调用完成后恢复深度，保证兄弟调用也能正确计数
        local res = pack(func(...))
        CurrentDepth = CurrentDepth - 1
        return unpack(res, 1, res.n)
    end
    -- 深度已满，切换到新协程
    createStack(func, ...)
    return yield(YieldMark)
end

local m = {}

function m.resolve(func, max, sliceSize)
    SliceSize = sliceSize or 256
    return function (...)
        if First then
            First = false
            local res = pack(xpcall(firstCall, debug.traceback, max or 10000, func, ...))
            First = true
            if res[1] == true then
                return unpack(res, 2, res.n)
            else
                error(res[2])
            end
        else
            return subCall(func, ...)
        end
    end
end

return m
