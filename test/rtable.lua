local rtable = require 'remote-table'

local database = {}

-- 测试独立的同步表
local rt1 = rtable.create()
rtable.onSet(rt1, function (key, value)
    database[key] = value
end)
rtable.onGet(rt1, function (key)
    return database[key]
end)

assert(rt1['aaaa'] == nil)
rt1['aaaa'] = 10
assert(database['aaaa'] == 10)
assert(rt1['aaaa'] == 10)
rt1['aaaa'] = 20
assert(database['aaaa'] == 20)
assert(rt1['aaaa'] == 20)
database['bbbb'] = 30
assert(rt1['bbbb'] == 30)
rt1['bbbb'] = 40
assert(database['bbbb'] == 40)
assert(rt1['bbbb'] == 40)

-- 测试共享的同步表
rtable.onTypeSet('mytype', function (key, value)
    database['t:'..key] = value
end)
rtable.onTypeGet('mytype', function (key)
    return database['t:'..key]
end)

local rt2 = rtable.create('mytype')
local rt3 = rtable.create('mytype')
assert(rt2['aaaa'] == nil)
assert(rt3['aaaa'] == nil)
rt2['aaaa'] = 10
assert(database['t:aaaa'] == 10)
assert(rt2['aaaa'] == 10)
assert(rt3['aaaa'] == 10)
rt3['aaaa'] = 20
assert(database['t:aaaa'] == 20)
assert(rt2['aaaa'] == 10) -- 不会更新本地缓存
assert(rt3['aaaa'] == 20)
database['t:bbbb'] = 30
assert(rt2['bbbb'] == 30)
assert(rt3['bbbb'] == 30)
rt2['bbbb'] = 40
assert(database['t:bbbb'] == 40)
assert(rt2['bbbb'] == 40)
assert(rt3['bbbb'] == 30) -- 不会更新本地缓存

local token = 0
local stack = {}
local function remoteSet(key, value)
    token = token + 1
    stack[#stack+1] = {
        method = 'set',
        token  = token,
        key    = key,
        value  = value,
    }
    return token
end

local function remoteGet(key)
    token = token + 1
    stack[#stack+1] = {
        method = 'get',
        token  = token,
        key    = key,
    }
    return token
end

local database = {}
coroutine.wrap(function ()
    -- 测试独立的异步表
    local rt1 = rtable.create()
    rtable.onAsyncSet(rt1, function (key, value)
        return remoteSet(key, value)
    end)
    rtable.onAsyncGet(rt1, function (key)
        return remoteGet(key)
    end)

    assert(rt1['aaaa'] == nil)
    rt1['aaaa'] = 10
    assert(database['aaaa'] == 10)
    assert(rt1['aaaa'] == 10)
    rt1['aaaa'] = 20
    assert(database['aaaa'] == 20)
    assert(rt1['aaaa'] == 20)
    database['bbbb'] = 30
    assert(rt1['bbbb'] == 30)
    rt1['bbbb'] = 40
    assert(database['bbbb'] == 40)
    assert(rt1['bbbb'] == 40)

    -- 测试共享的同步表
    rtable.onAsyncTypeSet('mytype', function (key, value)
        return remoteSet('t:' .. key, value)
    end)
    rtable.onAsyncTypeGet('mytype', function (key)
        return remoteGet('t:' .. key)
    end)

    local rt2 = rtable.create('mytype')
    local rt3 = rtable.create('mytype')
    assert(rt2['aaaa'] == nil)
    assert(rt3['aaaa'] == nil)
    rt2['aaaa'] = 10
    assert(database['t:aaaa'] == 10)
    assert(rt2['aaaa'] == 10)
    assert(rt3['aaaa'] == 10)
    rt3['aaaa'] = 20
    assert(database['t:aaaa'] == 20)
    assert(rt2['aaaa'] == 10) -- 不会更新本地缓存
    assert(rt3['aaaa'] == 20)
    database['t:bbbb'] = 30
    assert(rt2['bbbb'] == 30)
    assert(rt3['bbbb'] == 30)
    rt2['bbbb'] = 40
    assert(database['t:bbbb'] == 40)
    assert(rt2['bbbb'] == 40)
    assert(rt3['bbbb'] == 30) -- 不会更新本地缓存

end)()

while #stack > 0 do
    local request = stack[#stack]
    stack[#stack] = nil
    if request.method == 'set' then
        database[request.key] = request.value
        rtable.resume(request.token)
    end
    if request.method == 'get' then
        rtable.resume(request.token, database[request.key])
    end
end

assert(rtable.countHanging() == 0)

print('remote-table 测试完成')
