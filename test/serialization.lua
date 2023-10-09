local seri = require 'serialization'
local util = require 'utility'

local function test(t, encodeHook, decodeHook)
    local r = seri.encode(t, encodeHook)
    local nt = seri.decode(r, decodeHook)
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
test({x = 1, y = 2, z = 3, 10000, -1})
test({
    x = {
        1, 2, 3
    },
    y = {
        4, 5, 6
    }
})
test({
    x = {
        x1 = {
            1, 2, 3
        },
        x2 = {
            1, 2, 3
        }
    },
    y = {
        y1 = {
            1, 2, 3
        },
        y2 = {
            1, 2, 3
        }
    }
})

local t = {}
t.self = t
test(t)

local largeTable = require 'test.input.mz'
local clock = os.clock()
test(largeTable)
print('序列化耗时：', clock)

test({
    x = {
        __class__ = 'C1'
    },
    y = {
        __class__ = 'C2'
    },
    z = {
        ok = true,
    },
    s1 = {
        __string__ = '123'
    },
    s2 = {
        __string__ = '321'
    }
}, function (v)
    if v.__class__ then
        return {
            class = v.__class__
        }
    end
    if v.__string__ then
        return v.__string__
    end
end, function (v)
    if type(v) == 'table' then
        return {
            __class__ = v.class
        }
    end
    if type(v) == 'string' then
        return {
            __string__ = v
        }
    end
end)

print('序列化测试完成')
