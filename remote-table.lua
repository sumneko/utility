---@class remotetable
local mt = {}
mt.__name  = 'remote-table'

local InterfaceMap   = setmetatable({}, { __mode = 'k' })
local TypeMap        = {}
local WaitingMap     = {}
local enableMergeGet = true

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
    if interface.type then
        local typeInterface = TypeMap[interface.type]
        return typeInterface[name]
    else
        return interface[name]
    end
end

local function promiseSet(callback)
    return function (key, value)
        local token = callback(key, value)
        if not token then
            error('异步接口没有返回 token!')
        end
        if not coroutine.isyieldable() then
            error('当前不可让出！')
        end
        WaitingMap[token] = {
            thread = coroutine.running(),
        }
        return coroutine.yield()
    end
end

local function mergedGet(interface, key)
    if not enableMergeGet then
        return false
    end
    if not interface.mergeThreads then
        interface.mergeThreads = {}
    end
    if not interface.mergeThreads[key] then
        interface.mergeThreads[key] = {}
        return false
    end
    interface.mergeThreads[key][#interface.mergeThreads[key]+1] = coroutine.running()
    return true
end

local function promiseGet(callback, interface)
    return function (key)
        if not coroutine.isyieldable() then
            error('当前不可让出！')
        end
        if mergedGet(interface, key) then
            return coroutine.yield()
        end
        local token = callback(key)
        if not token then
            error('异步接口没有返回 token!')
        end
        WaitingMap[token] = {
            thread    = coroutine.running(),
            key       = key,
            interface = interface,
        }
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
    local ext = InterfaceMap[self].ext
    local value = method(key, ext)
    if cache[key] ~= nil then
        return cache[key]
    end
    cache[key] = value
    return value
end

function mt:__newindex(key, value)
    local cache  = InterfaceMap[self].cache
    local method = getMethod(self, 'onSet')
    if not method then
        error('没有设置远程写接口!')
    end
    local ext = InterfaceMap[self].ext
    method(key, value, ext)
    cache[key] = value
end

local m = {}

---创建一个远程表，读写数据时会调用远程的读写接口
---如果没有设置 `tp` 参数，那么你需要给这个表单独设置读写接口
---如果设置了 `tp` 参数，那么他会使用该类的读写接口
---@param  tp? any # 使用同一个 tp 的表会使用同样的接口。
---@param  ext? any # 额外参数，在调用类型接口时传入，方便类型接口区分是哪个对象
---@return remotetable
function m.create(tp, ext)
    local rt = setmetatable({}, mt)
    InterfaceMap[rt] = {
        type  = tp,
        ext   = ext,
        cache = {},
        onSet = nil,
        onGet = nil,
    }
    return rt
end

---设置远程的读接口
---@param rt       remotetable
---@param callback fun(key: any, ext: any): any
function m.onGet(rt, callback)
    local interface = InterfaceMap[rt]
    if not interface then
        error('第1个参数不是remotetable!')
    end
    if type(callback) ~= 'function' then
        error('第2个参数不是function!')
    end
    if interface.type then
        error('不能给共享类型的remotetable设置单独的方法')
    end
    interface.onGet = callback
end

---设置远程的写接口
---@param rt       remotetable
---@param callback fun(key: any, value: any, ext: any): any
function m.onSet(rt, callback)
    local interface = InterfaceMap[rt]
    if not interface then
        error('第1个参数不是remotetable!')
    end
    if type(callback) ~= 'function' then
        error('第2个参数不是function!')
    end
    if interface.type then
        error('不能给共享类型的remotetable设置单独的方法')
    end
    interface.onSet = callback
end

---设置远程的异步读接口
---
---回调函数必须返回一个token，
---之后通过 m.resume 方法来延续
---@param rt       remotetable
---@param callback fun(key: any, ext: any): any
function m.onAsyncGet(rt, callback)
    local interface = InterfaceMap[rt]
    if not interface then
        error('第1个参数不是remotetable!')
    end
    if type(callback) ~= 'function' then
        error('第2个参数不是function!')
    end
    if interface.type then
        error('不能给共享类型的remotetable设置单独的方法')
    end
    interface.onGet = promiseGet(callback, interface)
end

---设置远程的异步写接口
---
---回调函数必须返回一个token，
---之后通过 m.resume 方法来延续
---@param rt       remotetable
---@param callback fun(key: any, value: any, ext: any): any
function m.onAsyncSet(rt, callback)
    local interface = InterfaceMap[rt]
    if not interface then
        error('第1个参数不是remotetable!')
    end
    if type(callback) ~= 'function' then
        error('第2个参数不是function!')
    end
    if interface.type then
        error('不能给共享类型的remotetable设置单独的方法')
    end
    interface.onSet = promiseSet(callback)
end

---设置类的远程读接口
---@param tp       any
---@param callback fun(key: any, ext: any): any
function m.onTypeGet(tp, callback)
    local typeInterface = getTypeMap(tp)
    if type(callback) ~= 'function' then
        error('第2个参数不是function!')
    end
    typeInterface.onGet = callback
end

---设置类的远程写接口
---@param tp       any
---@param callback fun(key: any, value: any, ext: any): any
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
---@param callback fun(key: any, ext: any): any
function m.onAsyncTypeGet(tp, callback)
    local typeInterface = getTypeMap(tp)
    if type(callback) ~= 'function' then
        error('第2个参数不是function!')
    end
    typeInterface.onGet = promiseGet(callback, typeInterface)
end

---设置类的远程写接口
---
---回调函数必须返回一个token，
---之后通过 m.resume 方法来延续
---@param tp       any
---@param callback fun(key: any, value: any, ext: any): any
function m.onAsyncTypeSet(tp, callback)
    local interface = getTypeMap(tp)
    if type(callback) ~= 'function' then
        error('第2个参数不是function!')
    end
    interface.onSet = promiseSet(callback)
end

---延续之前让出的远程读写
---即使读写失败了也要调用一次这个函数
---@param token  any
---@param value? any
function m.resume(token, value)
    local waiting = WaitingMap[token]
    if not waiting then
        error(('无法根据 token 找到让出的线程：%s'):format(token))
    end
    WaitingMap[token] = nil
    local thread = waiting.thread
    local interface = waiting.interface
    local mergedThreads
    if interface then
        local key = waiting.key
        mergedThreads = interface.mergeThreads and interface.mergeThreads[key]
        if mergedThreads then
            interface.mergeThreads[key] = nil
        end
    end
    coroutine.resume(thread, value)
    if not mergedThreads then
        return
    end
    for _, mergedThread in ipairs(mergedThreads) do
        coroutine.resume(mergedThread, value)
    end
end

---允许合并获取请求，默认是开启的
---@param enable boolean
function m.mergeGet(enable)
    enableMergeGet = enable
end

---清点挂起的请求
function m.countHanging()
    local c = 0
    for _ in pairs(WaitingMap) do
        c = c + 1
    end
    return c
end

return m
