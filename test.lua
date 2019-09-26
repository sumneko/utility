local util = require 'utility'
local type = type
local laod = load

local t = {}
for x = 1, 10000 do
    t[x] = t
end
local clock = os.clock()
for _ = 1, 100 do
    local new = util.unpack(t)
    local old = util.pack(new)
end
print(os.clock() - clock)
