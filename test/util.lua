local util = require 'utility'

-- sortByScore
local o1 = {10, 10}
local o2 = {5, 10}
local o3 = {5, 10}
local o4 = {5, 5}
local o5 = {1, 1}
local t = {o1, o2, o3, o4, o5}
util.sortByScore(t, {
    function (o)
        return -o[1]
    end,
    function (o)
        return -o[2]
    end,
})
assert(t[1] == o5)
assert(t[2] == o4)
assert(t[3] == o2 or t[3] == o3)
assert(t[5] == o1)

assert(4  == util.utf8Len('最萌小汐'))
assert(10 == util.utf8Len('AAA最萌小汐AAA'))
assert(10 == util.utf8Len(('\xff'):rep(10)))
assert(10 == util.utf8Len('\xff\xff\xff最萌小汐\xff\xff\xff'))

-- sortTop
do
    local t = {}
    for i = 1, 100000 do
        t[#t+1] = i
    end
    util.sortK(t, 500)
    for i = 1, 500 do
        assert(t[i] == i)
    end

    local t = {}
    for i = 100000, 1, -1 do
        t[#t+1] = i
    end
    util.sortK(t, 500)
    for i = 1, 500 do
        assert(t[i] == i)
    end

    local t = {}
    for i = 1, 100000 do
        t[#t+1] = i
    end
    util.randomSortTable(t)
    util.sortK(t, 500)
    for i = 1, 500 do
        assert(t[i] == i)
    end

    util.randomSortTable(t)
    local c1 = os.clock()
    table.sort(t)
    local c2 = os.clock()
    print('table.sort time:', c2 - c1)

    util.randomSortTable(t)
    local c1 = os.clock()
    util.sortK(t, 500)
    local c2 = os.clock()
    print('util.sortK time:', c2 - c1)
end

do
    local layers = {
        { 0,  10, 'a' },
        { 3,  7,  'b' },
        { 5,  7,  'c' },
        { 8,  9,  'd' },
        { 15, 20, 'e' },
    }

    local result = util.mergeLayers(layers)

    assert(util.equal(result, {
        { 0,  3,  'a' },
        { 3,  5,  'b' },
        { 5,  7,  'c' },
        { 7,  8,  'a' },
        { 8,  9,  'd' },
        { 9,  10, 'a' },
        { 15, 20, 'e' },
    }))
end

do
    local ranges = {{1, 10}, {20, 30}}
    local merged, filled = util.fillRanges(ranges, 5, 40)
    assert(util.equal(merged, {{1, 40}}))
    assert(util.equal(filled, {{11, 19}, {31, 40}}))
end

do
    local ranges = {{1, 10}, {20, 30}, {40, 50}}
    local merged, filled = util.fillRanges(ranges, 2, 3)
    assert(util.equal(merged, {{1, 10}, {20, 30}, {40, 50}}))
    assert(util.equal(filled, {}))
end

do
    local ranges = {{1, 10}, {20, 30}, {40, 50}}
    local merged, filled = util.fillRanges(ranges, 25, 55)
    assert(util.equal(merged, {{1, 10}, {20, 55}}))
    assert(util.equal(filled, {{31, 39}, {51, 55}}))
end

do
    local ranges = {{1, 10}, {20, 30}, {40, 50}}
    local merged, filled = util.fillRanges(ranges, 11, 19)
    assert(util.equal(merged, {{1, 30}, {40, 50}}))
    assert(util.equal(filled, {{11, 19}}))
end

-- 刁钻测试：空范围列表
do
    local ranges = {}
    local merged, filled = util.fillRanges(ranges, 10, 20)
    assert(util.equal(merged, {{10, 20}}))
    assert(util.equal(filled, {{10, 20}}))
end

-- 刁钻测试：填充范围完全在已有范围之前
do
    local ranges = {{20, 30}, {40, 50}}
    local merged, filled = util.fillRanges(ranges, 1, 10)
    assert(util.equal(merged, {{1, 10}, {20, 30}, {40, 50}}))
    assert(util.equal(filled, {{1, 10}}))
end

-- 刁钻测试：填充范围完全在已有范围之后
do
    local ranges = {{1, 10}, {20, 30}}
    local merged, filled = util.fillRanges(ranges, 40, 50)
    assert(util.equal(merged, {{1, 10}, {20, 30}, {40, 50}}))
    assert(util.equal(filled, {{40, 50}}))
end

-- 刁钻测试：填充范围与已有范围完全重合
do
    local ranges = {{1, 10}, {20, 30}}
    local merged, filled = util.fillRanges(ranges, 5, 8)
    assert(util.equal(merged, {{1, 10}, {20, 30}}))
    assert(util.equal(filled, {}))
end

-- 刁钻测试：填充范围刚好紧邻已有范围（差1）
do
    local ranges = {{1, 10}, {30, 40}}
    local merged, filled = util.fillRanges(ranges, 11, 29)
    assert(util.equal(merged, {{1, 40}}))
    assert(util.equal(filled, {{11, 29}}))
end

-- 刁钻测试：填充单点范围（start == finish）
do
    local ranges = {{1, 10}, {20, 30}}
    local merged, filled = util.fillRanges(ranges, 15, 15)
    assert(util.equal(merged, {{1, 10}, {15, 15}, {20, 30}}))
    assert(util.equal(filled, {{15, 15}}))
end

-- 刁钻测试：填充单点恰好填补空缺
do
    local ranges = {{1, 10}, {12, 20}}
    local merged, filled = util.fillRanges(ranges, 11, 11)
    assert(util.equal(merged, {{1, 20}}))
    assert(util.equal(filled, {{11, 11}}))
end

-- 刁钻测试：填充范围横跨所有已有范围
do
    local ranges = {{5, 10}, {20, 25}, {35, 40}}
    local merged, filled = util.fillRanges(ranges, 1, 50)
    assert(util.equal(merged, {{1, 50}}))
    assert(util.equal(filled, {{1, 4}, {11, 19}, {26, 34}, {41, 50}}))
end

-- 刁钻测试：填充范围恰好连接两个范围（start-1 和 finish+1）
do
    local ranges = {{1, 9}, {21, 30}}
    local merged, filled = util.fillRanges(ranges, 10, 20)
    assert(util.equal(merged, {{1, 30}}))
    assert(util.equal(filled, {{10, 20}}))
end

-- 刁钻测试：已有范围重叠（虽然输入可能不应该这样，但测试鲁棒性）
do
    local ranges = {{1, 15}, {10, 20}, {18, 25}}
    local merged, filled = util.fillRanges(ranges, 30, 35)
    assert(util.equal(merged, {{1, 25}, {30, 35}}))
    assert(util.equal(filled, {{30, 35}}))
end

-- 刁钻测试：填充范围部分覆盖多个已有范围
do
    local ranges = {{1, 5}, {10, 15}, {20, 25}, {30, 35}}
    local merged, filled = util.fillRanges(ranges, 3, 22)
    assert(util.equal(merged, {{1, 25}, {30, 35}}))
    assert(util.equal(filled, {{6, 9}, {16, 19}}))
end

-- 刁钻测试：负数范围
do
    local ranges = {{-10, -5}, {5, 10}}
    local merged, filled = util.fillRanges(ranges, -4, 4)
    assert(util.equal(merged, {{-10, 10}}))
    assert(util.equal(filled, {{-4, 4}}))
end

-- 刁钻测试：填充范围恰好在两个范围的中间但不相邻
do
    local ranges = {{1, 10}, {30, 40}}
    local merged, filled = util.fillRanges(ranges, 15, 20)
    assert(util.equal(merged, {{1, 10}, {15, 20}, {30, 40}}))
    assert(util.equal(filled, {{15, 20}}))
end

-- 刁钻测试：填充范围刚好差2（不会合并）
do
    local ranges = {{1, 10}, {30, 40}}
    local merged, filled = util.fillRanges(ranges, 12, 28)
    assert(util.equal(merged, {{1, 10}, {12, 28}, {30, 40}}))
    assert(util.equal(filled, {{12, 28}}))
end

-- 刁钻测试：大量范围的连续合并
do
    local ranges = {{1, 5}, {15, 20}, {30, 35}, {45, 50}, {60, 65}}
    local merged, filled = util.fillRanges(ranges, 1, 65)
    assert(util.equal(merged, {{1, 65}}))
    assert(util.equal(filled, {{6, 14}, {21, 29}, {36, 44}, {51, 59}}))
end

-- 刁钻测试：填充范围恰好覆盖一个已有范围的起点
do
    local ranges = {{10, 20}, {30, 40}}
    local merged, filled = util.fillRanges(ranges, 10, 15)
    assert(util.equal(merged, {{10, 20}, {30, 40}}))
    assert(util.equal(filled, {}))
end

-- 刁钻测试：填充范围恰好覆盖一个已有范围的终点
do
    local ranges = {{10, 20}, {30, 40}}
    local merged, filled = util.fillRanges(ranges, 15, 20)
    assert(util.equal(merged, {{10, 20}, {30, 40}}))
    assert(util.equal(filled, {}))
end

do
    local t = {5, 4, 3, 2, 1}
    local pt = setmetatable({}, {
        __len = function ()
            return #t
        end,
        __index = t,
        __newindex = t,
    })

    table.sort(pt)

    assert(util.equal(t, { 1, 2, 3, 4, 5 }))
end

print('ok')
