local gtable = require 'generation-table'
local util = require 'utility'

do
    local gt = gtable.create(3)
    gt:set('a', 1)
    gt:set('b', 2)
    gt:set('c', 3)

    assert(gt:get('a') == 1)
    assert(gt:get('b') == 2)
    assert(gt:get('c') == 3)

    gt:grow(function (deads)
        assert(deads == nil)
    end)

    gt:set('d', 4)

    assert(gt:get('a') == 1)
    assert(gt:get('b') == 2)
    assert(gt:get('c') == 3)
    assert(gt:get('d') == 4)

    gt:del('a')

    assert(gt:get('a') == nil)
    assert(gt:get('b') == 2)
    assert(gt:get('c') == 3)
    assert(gt:get('d') == 4)

    gt:grow(function (deads)
        assert(deads == nil)
    end)

    gt:set('b', 10)

    assert(gt:get('a') == nil)
    assert(gt:get('b') == 10)
    assert(gt:get('c') == 3)
    assert(gt:get('d') == 4)

    gt:grow(function (deads)
        assert(util.equal(deads, { c = 3 }))
    end)

    assert(gt:get('a') == nil)
    assert(gt:get('b') == 10)
    assert(gt:get('c') == nil)
    assert(gt:get('d') == 4)

    gt:grow(function (deads)
        assert(util.equal(deads, { d = 4 }))
    end)

    assert(gt:get('a') == nil)
    assert(gt:get('b') == 10)
    assert(gt:get('c') == nil)
    assert(gt:get('d') == nil)

    gt:grow(function (deads)
        assert(util.equal(deads, { b = 10 }))
    end)

    assert(gt:get('a') == nil)
    assert(gt:get('b') == nil)
    assert(gt:get('c') == nil)
    assert(gt:get('d') == nil)
end

print('generation-table 测试完成')
