local rec = require 'recursive'

local t = {}
local function f(i)
    if i <= 1 then
        return i
    else
        -- 避免尾调用不入栈
        local n = f(i-1)
        t[#t+1] = n
        return i * 2
    end
end

f = rec.resolve(f, 100000)

local clock = os.clock()
f(10000)
print(os.clock() - clock)
assert(#t == 9999)
