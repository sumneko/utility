local proxy = require 'proxy'

local MODE_K = { __mode = 'k' }
local MODE_V = { __mode = 'v' }

---@class SharedTable
local M = {}
M.__index = M

---@param default? table
---@return SharedTable
function M:init(default)
    self.value = default or {}
    ---@type { [table]: integer }
    self.bindMap = setmetatable({}, MODE_K)
    self.bindId = 0

    self.trap = proxy.new(self.value, {
        recursive = true,
        updateRaw = true,
        anySetter = function (parent, raw, key, value)
            local tp = type(value)
            if  tp ~= 'nil'
            and tp ~= 'boolean'
            and tp ~= 'number'
            and tp ~= 'string'
            and tp ~= 'table' then
                local path = proxy.getPath(parent)
                path[#path+1] = key
                local pathStr = table.concat(path, '.')
                error('不支持的值类型：' .. tp .. '，路径是：' .. pathStr)
                return
            end
            if not self.touched then
                self.touched = {}
            end
            if not self.touched[raw] then
                self.touched[raw] = {}
            end
            self.touched[raw][key] = true
            return value
        end
    })

    local queue = { self.value }

    while true do
        local current = queue[#queue]
        if not current then
            break
        end
        queue[#queue] = nil

        self.bindId = self.bindId + 1
        self.bindMap[current] = self.bindId

        for _, v in pairs(current) do
            if type(v) == 'table' then
                queue[#queue+1] = v
            end
        end
    end

    return self
end

---@alias SharedTable.DumpShape { value: table, bind: { [integer]: table } }

---@return SharedTable.DumpShape
function M:dump()
    local bind = {}
    for tbl, id in pairs(self.bindMap) do
        bind[id] = tbl
    end
    return {
        value = self.value,
        bind  = bind,
    }
end

---@return boolean
function M:isTouched()
    return self.touched ~= nil
end

---@alias SharedTable.ChangesShape {
--- set?: { [integer]: table<any, any> },
--- del?: { [integer]: any[] },
--- newBind?: { [table]: integer },
---}

---@return SharedTable.ChangesShape?
function M:exportChanges()
    local touched = self.touched
    if touched == nil then
        return nil
    end
    self.touched = nil

    local set, del
    local newBind

    local function getId(t)
        if type(t) ~= 'table' then
            return nil
        end
        local id = self.bindMap[t]
        if id then
            return id
        end
        id = self.bindId + 1
        self.bindId = id
        self.bindMap[t] = id
        if not newBind then
            newBind = {}
        end
        newBind[t] = id
        if not set then
            set = {}
        end
        local kv = {}
        set[id] = kv
        for k, v in pairs(t) do
            kv[k] = v
            getId(v)
        end
        return id
    end

    local function updateResult(raw, key)
        local value = raw[key]
        local id = self.bindMap[raw]
        if not id then
            -- raw 本身是新插入但还没注册的子表，注册时已包含全部当前 kv
            getId(raw)
            return
        end

        if value == nil then
            if not del then
                del = {}
            end
            if not del[id] then
                del[id] = {}
            end
            del[id][#del[id]+1] = key
            return
        end

        getId(value)

        if not set then
            set = {}
        end
        if not set[id] then
            set[id] = {}
        end
        set[id][key] = value
    end

    for raw, keys in pairs(touched) do
        for key in pairs(keys) do
            updateResult(raw, key)
        end
    end

    return {
        set = set,
        del = del,
        newBind = newBind,
    }
end

---@class SharedTable.API
local API = {}

---@private
---@type table<table, table<integer, table>>
API.tableToBind = setmetatable({}, MODE_K)

---@param default? table
---@return SharedTable
function API.create(default)
    local st = setmetatable({}, M)
    st:init(default)
    return st
end

---@param dump SharedTable.DumpShape
function API.load(dump)
    API.tableToBind[dump.value] = setmetatable(dump.bind, MODE_V)
    return dump.value
end

---@param t table
---@param changes SharedTable.ChangesShape
function API.importChanges(t, changes)
    local bind = API.tableToBind[t]
    if not bind then
        error('table is not a shared table')
        return
    end

    if changes.newBind then
        for tbl, id in pairs(changes.newBind) do
            bind[id] = tbl
        end
    end

    if changes.set then
        for id, kv in pairs(changes.set) do
            local tbl = bind[id]
            if not tbl then
                error('invalid bind id: ' .. id)
                return
            end
            for k, v in pairs(kv) do
                tbl[k] = v
            end
        end
    end

    if changes.del then
        for id, keys in pairs(changes.del) do
            local tbl = bind[id]
            if not tbl then
                error('invalid bind id: ' .. id)
                return
            end
            for _, k in ipairs(keys) do
                tbl[k] = nil
            end
        end
    end
end

return API
