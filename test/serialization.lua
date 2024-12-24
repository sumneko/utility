local seri = require 'serialization'
local util = require 'utility'

local function test(t, encodeHook, decodeHook)
    local c = os.clock()
    local r = seri.encode(t, encodeHook)
    local nt = seri.decode(r, decodeHook)
    local p = os.clock() - c
    assert(util.equal(t, nt))
    return r, p
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
test({
    maximum = {
        x = 29.0652008056640625,
        y = 53.60010147094726562,
        z = 230,
    },
    minimum = {
        x = -29.00760078430175781,
        y = -53.45240020751953125,
        z = 1.41630995273590088,
    },
})

test({ 1, 2, nil, 3, 4, 5, 6, 7, 8 })
do
    local t = {1, 2, 3, 4, 5, 6, 7, 8}
    for i = 1, 5 do
        t[i] = nil
    end
    test(t)
end

local t = {}
for i = 1, 10000 do
    t[i] = i * 10
    t[i * 10000] = i * 100000000
end
test(t)

local t = {}
t.self = t
test(t)

local largeTable = require 'test.input.mz'
local bin, p = test(largeTable)
print('序列化+反序列化耗时：', p)
print('二进制大小：', #bin / 1024 / 1024, 'MB')

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
