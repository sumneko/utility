local ap = require 'active-pool'
local util = require 'utility'

do
    local p = ap.create {
        {1, 60},
        {3, 30},
        {6, 10},
        {10, 5},
        {1000, 1},
    }

    for i = 1, 100 do
        p:push(i, i)
    end

    assert(#p:toArray() == 100)

    p:update(100)

    assert(util.equal(p:toArray(), { 95, 96, 97, 98, 99, 100  }))

    p:update(128)
    assert(util.equal(p:toArray(), { 98, 99, 100 }))

    p:update(129)
    assert(util.equal(p:toArray(), { 99, 100 }))

    p:update(130)
    assert(util.equal(p:toArray(), { 100 }))

    p:update(160)
    assert(util.equal(p:toArray(), { 100 }))

    p:update(161)
    assert(util.equal(p:toArray(), {}))
end

do
    local p = ap.create {
        {3, 5},
    }

    p:push('a', 1)
    p:push('b', 2)
    p:push('c', 3)

    assert(util.equal(p:toArray(), { 'a', 'b', 'c' }))

    p:push('a', 4)
    p:update(4)

    assert(util.equal(p:toArray(), { 'b', 'c', 'a' }))

    p:push('b', 5)
    p:update(5)

    assert(util.equal(p:toArray(), { 'c', 'a', 'b' }))

    p:push('c', 6)
    p:update(6)

    assert(util.equal(p:toArray(), { 'a', 'b', 'c' }))
end
