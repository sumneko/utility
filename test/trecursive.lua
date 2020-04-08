local rec = require 'recursive'

local function f(i)
    if i >= 10000 then
        return i
    else
        -- 避免尾调用不入栈
        local n = f(i+1)
        return n
    end
end

f = rec.resolve(f)

local clock = os.clock()
print(f(0))
print(os.clock() - clock)
