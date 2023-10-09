local seri = require 'serialization'
local util = require 'utility'

local function test(t)
    local r = seri.encode(t)
    local nt = seri.decode(r)
    assert(util.equal(t, nt))
end

test(nil)
test(123)
test(1.23)
test('xxxyy')
test(true)
test(false)
test({1, 2, 3})
test({x = 1, y = 2, z = 3})

local t = {}
t.self = t
test(t)
