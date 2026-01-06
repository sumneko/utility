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
        { 'a', 0,  10 },
        { 'b', 3,  7  },
        { 'c', 5,  7  },
        { 'd', 8,  9  },
        { 'e', 15, 20 },
    }

    local result = util.mergeLayers(layers)

    assert(util.equal(result, {
        { 'a', 0,  3  },
        { 'b', 3,  5  },
        { 'c', 5,  7  },
        { 'a', 7,  8  },
        { 'd', 8,  9  },
        { 'a', 9,  10 },
        { 'e', 15, 20 },
    }))
end

print('ok')
