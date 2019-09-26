local thread = require 'bee.thread'
thread.newchannel 'TEST'
local ch = thread.channel 'TEST'
local util = require 'utility'
local type = type
local laod = load

local t = {}
for x = 1, 10000 do
    t[x] = t
end

local clock = os.clock()
for _ = 1, 100 do
    local dump = util.unpack(t)
    util.pack(dump)
end
print(os.clock() - clock)

local dump = util.unpack(t)
local clock = os.clock()
for _ = 1, 100 do
    ch:push(dump)
    ch:pop()
end
print(os.clock() - clock)
