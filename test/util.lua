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

print('ok')
