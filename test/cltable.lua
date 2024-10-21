local cltable = require 'caseless-table'

do
    local ct = cltable.create()

    ct['a'] = 1
    ct['B'] = 2

    assert(ct['a'] == 1)
    assert(ct['A'] == 1)
    assert(ct['b'] == 2)
    assert(ct['B'] == 2)
end

do
    local ct = cltable.create()

    ct['a'] = 1
    ct['A'] = 2

    assert(ct['a'] == 2)
    assert(ct['A'] == 2)
end

do
    local ct = cltable.create()

    ct['a'] = 1
    ct['A'] = nil

    assert(ct['a'] == nil)
    assert(ct['A'] == nil)
end

do
    local ct = cltable.create()

    ct['a'] = 1
    ct['B'] = 2
    ct['c'] = 3
    ct['A'] = 4
    ct['b'] = 5
    ct['C'] = nil

    local kv = {}
    for k, v in pairs(ct) do
        kv[#kv+1] = {k, v}
    end

    table.sort(kv, function (a, b)
        return a[1] < b[1]
    end)

    assert(#kv == 2)
    assert(kv[1][1] == 'B')
    assert(kv[1][2] == 5)
    assert(kv[2][1] == 'a')
    assert(kv[2][2] == 4)
end

print('caseless-table 测试完成')
