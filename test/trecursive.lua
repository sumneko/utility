local rec = require 'recursive'

local t
local function f(i)
    if i <= 0 then
        return 0
    else
        local n = f(i-1)
        t[#t+1] = n
        return n + 1
    end
end

t = {}
local clock = os.clock()
for _ = 1, 100 do
    f(1000)
end
print(os.clock() - clock)
assert(#t == 100000)

f = rec.resolve(f, 1000000)

t = {}
local clock = os.clock()
f(100000)
print(os.clock() - clock)
assert(#t == 100000)
