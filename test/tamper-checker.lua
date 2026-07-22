local tc = require 'tamper-checker'

do
    local instance = tc.create()

    local t = { x = 1, y = 2 }

    instance:add(t, 'test')

    assert(instance:check(t) == false)
    assert(instance:checkAll() == nil)

    t.x = 3

    assert(instance:check(t) == true)
    local tampered = instance:checkAll()
    assert(tampered ~= nil)
    assert(#tampered == 1)
    assert(tampered[1] == 'test')
end

do
    local instance = tc.create()

    local t = { x = 1, y = 2, z = { a = 1, b = 2 } }

    instance:add(t, 'test')

    assert(instance:check(t) == false)
    assert(instance:checkAll() == nil)

    t.z.a = 3

    assert(instance:check(t) == false)
    assert(instance:check(t.z) == true)
    assert(instance:check(t, true) == true)
    local tampered = instance:checkAll()
    assert(tampered ~= nil)
    assert(#tampered == 1)
    assert(tampered[1] == 'test.z')
end

do
    local time = 0
    local instance = tc.create()
    instance:setClockFunc(function ()
        time = time + 1
        return time
    end)

    local large = {}

    for i = 1, 10000 do
        large[i] = {}
        for j = 1, 3 do
            large[i][j] = j
        end
        for j = 4, 6 do
            large[i][j] = tostring(j)
        end
        for j = 7, 8 do
            large[i][j] = {}
        end
        for j = 9, 10 do
            large[i][j] = j + 0.123
        end
    end


    instance:add(large, 'test')

    large[9000].x = -1

    do
        local tampered, status = instance:checkAll()
        assert(status == 'finished')
        assert(tampered ~= nil)
        assert(#tampered == 1)
        assert(tampered[1] == 'test.9000')
    end

    do
        time = 0

        local tampered1, status1 = instance:checkAll(4000)
        assert(time == 4002)
        assert(status1 == 'timeout')

        local tampered2, status2 = instance:checkAll(4000)
        assert(time == 8004)
        assert(status2 == 'timeout')

        local tampered3, status3 = instance:checkAll(4000)
        assert(time == 12006)
        assert(status3 == 'timeout')

        local clock1 = os.clock()
        local tampered5, status5 = instance:checkAll()
        local clock2 = os.clock()
        assert(time == 12007)
        assert(status5 == 'finished')
        assert(tampered5 ~= nil)
        assert(#tampered5 == 1)
        assert(tampered5[1] == 'test.9000')

        print('tamper-checker 平均耗时', (clock2 - clock1) / #large * 1000 * 1000, '微秒')
    end
end
