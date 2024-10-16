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

do
    local pt = pathTable.create(true, false)

    local strong = {'<STRONG>'}
    local weak   = {'<WEAK>'}

    local gc = false

    pt:set({1, strong, 2}, true)
    pt:set({2, weak, 1}, setmetatable({}, { __gc = function ()
        gc = true
    end}))

    assert(pt:has({1, strong, 2}) == true)
    assert(pt:has({2, weak, 1}) == true)

    weak = nil

    collectgarbage()

    assert(pt:has({1, strong, 2}) == true)
    assert(gc == true)
end

do
    local pt = pathTable.create(false, true)

    local strong = {'<STRONG>'}
    local weak   = {'<WEAK>'}

    pt:set({1, 2, 3}, strong)
    pt:set({3, 2, 1}, weak)

    assert(pt:has({1, 2, 3}) == true)
    assert(pt:has({3, 2, 1}) == true)

    weak = nil

    collectgarbage()

    assert(pt:has({1, 2, 3}) == true)
    assert(pt:has({3, 2, 1}) == false)

    ---@diagnostic disable-next-line: invisible
    assert(rawget(pt.root.childDirs, 3) == nil)
end

print('path-table 测试完成')
