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

    local pt = proxy.new(t, {
        recursive = true,
        anyGetter = function (self, raw, key, config, custom)
            if type(raw[key]) == 'table' then
                return proxy.new(raw[key], config)
            end
            return string.format('%s:%s', type(raw[key]), raw[key])
        end
    })

    assert(pt[1] == pt)
    assert(pt[2].x == 'number:1')
    assert(pt[2].y == 'number:2')
    assert(pt[2].z == 'number:3')
    assert(pt[3].a == pt)
    assert(pt[3].b == pt)
    assert(pt[3].c == pt)
end

print('proxy测试通过')
