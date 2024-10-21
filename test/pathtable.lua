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

do
    local pt = pathTable.create(true, true)

    local weak   = {'<WEAK>'}

    local gc = false

    pt:set({1, weak, 3}, setmetatable({}, { __gc = function ()
        gc = true
    end}))
    pt:set({1, 2, 3}, weak)

    assert(pt:has({1, weak, 3}) == true)
    assert(pt:get({1, 2, 3}) == weak)

    weak = nil

    collectgarbage()

    assert(gc == true)
    assert(pt:has({1, 2, 3}) == false)

    ---@diagnostic disable-next-line: invisible
    assert(rawget(pt.root.childDirs, 1) == nil)
    ---@diagnostic disable-next-line: invisible
    assert(rawget(pt.root.childDirs, 3) == nil)
end

do
    local pt = pathTable.create(true, true)

    local o1 = {'o1'}
    local o2 = {'o2'}
    local pk = {x = o1, y = o2}

    pt:set({o1, o2}, pk)

    o1 = nil
    o2 = nil

    collectgarbage()

    ---@diagnostic disable-next-line: invisible
    assert(next(pt.root.childDirs) ~= nil)

    pk = nil

    collectgarbage()

    ---@diagnostic disable-next-line: invisible
    assert(next(pt.root.childDirs) == nil)
end

do
    local pt = pathTable.create(false, true)

    local ref = {}
    for i = 1, 10000 do
        local o = {i}
        if i > 9000 then
            ref[i] = o
        end
        pt:set({ 'key1', i, 'key2' }, o)
    end

    collectgarbage()

    ---@diagnostic disable-next-line: invisible
    --assert(rawget(pt.root.childDirs['key1'].childDirs, 1) == nil)
end

print('path-table 测试完成')
