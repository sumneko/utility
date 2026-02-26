local rec = require 'recursive'

local function f(i, t)
    if i <= 0 then
        return 0
    else
        local n = f(i-1, t)
        t.n = n
        return n + 1
    end
end

local t = {}
local clock = os.clock()
for _ = 1, 1000 do
    f(1000, t)
end
print(os.clock() - clock)
assert(t.n == 999)

f = rec.resolve(f, 10000000)

local t = {}
local clock = os.clock()
f(1000000, t)
print('递归1000000次耗时：', os.clock() - clock)
assert(t.n == 999999)
