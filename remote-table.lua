---@class remotetable
local mt = {}
mt.__name  = 'remote-table'

local InterfaceMap = setmetatable({}, { __mode = 'k' })
local TypeMap      = {}
local WaitingMap   = {}

local function getTypeMap(tp)
    if not TypeMap[tp] then
        TypeMap[tp] = {
            onSet = nil,
            onGet = nil,
        }
    end
    return TypeMap[tp]
end

local function getMethod(rt, name)
    local interface = InterfaceMap[rt]
    if interface[name] then
        return interface[name]
    end
    local typeInterface = TypeMap[interface.type]
    if not typeInterface then
        return nil
    end
    return typeInterface[name]
end

local function promise(callback)
    return function (...)
        local token = callback(...)
        if not token then
            error('异步接口没有返回 token!')
        end
        if not coroutine.isyieldable() then
            error('当前不可让出！')
        end
        WaitingMap[token] = coroutine.running()
        return coroutine.yield()
    end
end

function mt:__index(key)
    local cache  = InterfaceMap[self].cache
    if cache[key] ~= nil then
        return cache[key]
    end
    local method = getMethod(self, 'onGet')
    if not method then
        error('没有设置远程读接口!')
    end
    local value = method(key)
    cache[key] = value
    return value
end

function mt:__newindex(key, value)
    local cache  = InterfaceMap[self].cache
    local method = getMethod(self, 'onSet')
    if not method then
        error('没有设置远程写接口!')
    end
    method(key, value)
    cache[key] = value
end

local m = {}

---创建一个远程表，读写数据时会调用远程的读写接口
---如果没有设置 `tp` 参数，那么你需要给这个表单独设置读写接口
---如果设置了 `tp` 参数，那么他会使用该类的读写接口
---@param  tp? any # 使用同一个 tp 的表会使用同样的接口。
---@return remotetable
function m.create(tp)
    local rt = setmetatable({}, mt)
    InterfaceMap[rt] = {
        type  = tp,
        cache = {},
        onSet = nil,
        onGet = nil,
    }
    return rt
end

---设置远程的读接口
---@param rt       remotetable
---@param callback fun(key: any): any
function m.onGet(rt, callback)
    local interface = InterfaceMap[rt]
    if not interface then
        error('第1个参数不是remotetable!')
    end
    if type(callback) ~= 'function' then
        error('第2个参数不是function!')
    end
    interface.onGet = callback
end

---设置远程的写接口
---@param rt       remotetable
---@param callback fun(key: any, value: any)
function m.onSet(rt, callback)
    local interface = InterfaceMap[rt]
    if not interface then
        error('第1个参数不是remotetable!')
    end
    if type(callback) ~= 'function' then
        error('第2个参数不是function!')
    end
    interface.onSet = callback
end

---设置远程的异步读接口
---
---回调函数必须返回一个token，
---之后通过 m.resume 方法来延续
---@param rt       remotetable
---@param callback fun(key: any): any
function m.onAsyncGet(rt, callback)
    local interface = InterfaceMap[rt]
    if not interface then
        error('第1个参数不是remotetable!')
    end
    if type(callback) ~= 'function' then
        error('第2个参数不是function!')
    end
    interface.onGet = promise(callback)
end

---设置远程的异步写接口
---
---回调函数必须返回一个token，
---之后通过 m.resume 方法来延续
---@param rt       remotetable
---@param callback fun(key: any, value: any): any
function m.onAsyncSet(rt, callback)
    local interface = InterfaceMap[rt]
    if not interface then
        error('第1个参数不是remotetable!')
    end
    if type(callback) ~= 'function' then
        error('第2个参数不是function!')
    end
    interface.onSet = promise(callback)
end

---设置类的远程读接口
---@param tp       any
---@param callback fun(key: any): any
function m.onTypeGet(tp, callback)
    local typeInterface = getTypeMap(tp)
    if type(callback) ~= 'function' then
        error('第2个参数不是function!')
    end
    typeInterface.onGet = callback
end

---设置类的远程写接口
---@param tp       any
---@param callback fun(key: any, value: any)
function m.onTypeSet(tp, callback)
    local interface = getTypeMap(tp)
    if type(callback) ~= 'function' then
        error('第2个参数不是function!')
    end
    interface.onSet = callback
end

---设置类的远程读接口
---
---回调函数必须返回一个token，
---之后通过 m.resume 方法来延续
---@param tp       any
---@param callback fun(key: any): any
function m.onAsyncTypeGet(tp, callback)
    local typeInterface = getTypeMap(tp)
    if type(callback) ~= 'function' then
        error('第2个参数不是function!')
    end
    typeInterface.onGet = promise(callback)
end

---设置类的远程写接口
---
---回调函数必须返回一个token，
---之后通过 m.resume 方法来延续
---@param tp       any
---@param callback fun(key: any, value: any): any
function m.onAsyncTypeSet(tp, callback)
    local interface = getTypeMap(tp)
    if type(callback) ~= 'function' then
        error('第2个参数不是function!')
    end
    interface.onSet = promise(callback)
end

---延续之前让出的远程读写
---即使读写失败了也要调用一次这个函数
---@param token  any
---@param value? any
function m.resume(token, value)
    local thread = WaitingMap[token]
    if not thread then
        error(('无法根据 token 找到让出的线程：%s'):format(token))
    end
    WaitingMap[token] = nil
    coroutine.resume(thread, value)
end

return m
