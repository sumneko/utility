local pathTable = require 'path-table'

do
    local pt = pathTable.create()

    pt:set({1, 2, 3}, 'a')
    pt:set({1, 2, 4}, 'b')
    pt:set({1, 3, 4}, 'c')
    pt:set({1, 3, 5}, 'd')
    pt:set({1, 3, 6}, 'e')

    assert(pt:get({1, 2, 3}) == 'a')
    assert(pt:get({1, 2, 4}) == 'b')
    assert(pt:get({1, 3, 4}) == 'c')
    assert(pt:get({1, 3, 5}) == 'd')
    assert(pt:get({1, 3, 6}) == 'e')

    assert(pt:get({1}) == nil)
    assert(pt:get({1, 2}) == nil)
    assert(pt:get({1, 2, 5}) == nil)
    assert(pt:get({1, 2, 3, 4}) == nil)

    assert(pt:delete({1, 3, 4}) == true)
    assert(pt:get({1, 3, 4}) == nil)
    assert(pt:get({1, 3, 5}) == 'd')
    assert(pt:get({1, 3, 6}) == 'e')

    assert(pt:delete({1, 3, 5}) == true)
    assert(pt:get({1, 3, 5}) == nil)
    assert(pt:get({1, 3, 6}) == 'e')
end

do
    local pt = pathTable.create()

    collectgarbage()
    local m = collectgarbage 'count'
    local c = os.clock()
    for i = 1, 10000 do
        pt:set({1, 2, i}, i)
    end

    for i = 1, 10000 do
        assert(pt:get({1, 2, i}) == i)
    end

    for i = 1, 10000 do
        pt:set({1, 2, i, 3, 4}, i)
    end

    for i = 1, 10000 do
        assert(pt:get({1, 2, i, 3, 4}) == i)
    end
    print(os.clock() - c)
    print(collectgarbage 'count' - m, 'kb')
end

print('path-table 测试完成')
