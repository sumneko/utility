local rtable = require 'remote-table'

local database = {}
local rt = rtable.create()
rtable.onSet(rt, function (key, value)
    database[key] = value
end)
rtable.onGet(rt, function (key)
    return database[key]
end)

assert(rt['aaaa'] == nil)
rt['aaaa'] = 10
assert(database['aaaa'] == 10)
assert(rt['aaaa'] == 10)
rt['aaaa'] = 20
assert(database['aaaa'] == 20)
assert(rt['aaaa'] == 20)
database['bbbb'] = 30
assert(rt['bbbb'] == 30)
rt['bbbb'] = 40
assert(database['bbbb'] == 40)
assert(rt['bbbb'] == 40)

print('remote-table 测试完成')
