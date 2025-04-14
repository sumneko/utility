local proxy = require 'proxy'

do
    local t = {}
    t[1] = t
    t[2] = {
        x = 1,
        y = 2,
        z = 3,
    }
    t[3] = {
        a = t,
        b = t,
        c = t,
    }

    local lastAction
    local pt = proxy.new(t, {
        updateRaw = true,
        recursive = true,
        anySetter = function (self, raw, key, value, config, custom)
            lastAction = string.format('set[%s] = %s', key, value)
            return value
        end,
        anyGetter = function (self, raw, key, config, custom)
            lastAction = string.format('get[%s] = %s', key, raw[key])
            return raw[key]
        end
    })

    local function test(exp, expected)
        assert(lastAction == expected, string.format('expect %s, but %s', expected, lastAction))
    end

    test(assert(pt[1] == pt), 'get[1] = ' .. tostring(t))
    test(assert(pt[2].x == 1), 'get[x] = 1')
    test(assert(pt[2].y == 2), 'get[y] = 2')
    test(assert(pt[2].z == 3), 'get[z] = 3')
    test(assert(pt[3].a == pt), 'get[a] = ' .. tostring(t))
    test(assert(pt[3].b == pt), 'get[b] = ' .. tostring(t))
    test(assert(pt[3].c == pt), 'get[c] = ' .. tostring(t))

    local new = {}
    pt[4] = new
    assert(lastAction == 'set[4] = ' .. tostring(new))
    assert(t[4] == new)
    pt[4].x = 10
    assert(lastAction == 'set[x] = 10')
    test(assert(pt[4].x == 10), 'get[x] = 10')
end

do
    local t = {
        x = {
            a = {
                l = 1,
                m = 2,
                n = 3,
            },
            b = {
                l = 1,
                m = 2,
                n = 3,
            },
            c = {
                l = 1,
                m = 2,
                n = 3,
            },
        },
        y = {
            a = {
                l = 1,
                m = 2,
                n = 3,
            },
            b = {
                l = 1,
                m = 2,
                n = 3,
            },
            c = {
                l = 1,
                m = 2,
                n = 3,
            },
        },
        z = {
            a = {
                l = 1,
                m = 2,
                n = 3,
            },
            b = {
                l = 1,
                m = 2,
                n = 3,
            },
            c = {
                l = 1,
                m = 2,
                n = 3,
            },
        },
    }

    local lastTouch
    local pt = proxy.new(t, {
        updateRaw = true,
        recursive = true,
        anySetter = function (self, raw, key, value, config, custom)
            local path = proxy.getPath(self)
            path[#path+1] = key
            lastTouch = table.concat(path, '.')
            return value
        end,
    })

    pt.x.a.l = 10
    assert(t.x.a.l == 10)
    assert(lastTouch == 'x.a.l')
    pt.z.c.n = 20
    assert(t.z.c.n == 20)
    assert(lastTouch == 'z.c.n')
    pt.y.b = {
        xx = {
            nn = 30,
        }
    }
    assert(t.y.b.xx.nn == 30)
    assert(lastTouch == 'y.b')
    pt.y.b.xx.nn = 40
    assert(t.y.b.xx.nn == 40)
    assert(lastTouch == 'y.b.xx.nn')
end

print('proxy测试通过')
