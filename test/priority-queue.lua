local api  = require 'priority-queue'
local util = require 'utility'

do
    local pq = api.create()

    pq:insert(1)
    pq:insert(2)
    pq:insert(3)
    pq:insert(4, 10)

    local result = {}
    for value, score in pq:pairs() do
        result[#result+1] = {value, score}
    end

    assert(util.equal(result, {
        {4, 10},
        {1, 0},
        {2, 0},
        {3, 0},
    }))

    pq:remove(4)
    pq:remove(2)

    local result = {}
    for value, score in pq:pairs() do
        result[#result+1] = {value, score}
    end

    assert(util.equal(result, {
        {1, 0},
        {3, 0},
    }))
end
