---@class remotetable
local mt = {}
mt.__name  = 'remote-table'

local InterfaceMap = setmetatable({}, { __mode = 'k' })
local TypeMap = {}

local function getTypeMap(tp)
    if not TypeMap[tp] then
        TypeMap[tp] = {}
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

function mt:__index(key)
    local method = getMethod(self, 'onGet')
    if not method then
        error('没有设置远程读接口!')
    end
    local value = method(key)
    rawset(self, key, value)
    return value
end

function mt:__newindex(key, value)
    local method = getMethod(self, 'onSet')
    if not method then
        error('没有设置远程写接口!')
    end
    method(key, value)
    rawset(self, key, value)
end

local m = {}

---创建一个远程表，读写数据时会调用远程的读写接口
---@param  tp? any # 使用同一个type的表会使用同样的接口。
---@return remotetable
function m.create(tp)
    local rt = setmetatable({}, mt)
    InterfaceMap[rt] = {
        type = tp,
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

return m
