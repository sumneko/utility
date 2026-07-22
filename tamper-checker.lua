---@class TamperChecker
local M = {}
M.__index = M

---@class TamperChecker.Status
---@field hash integer # 表的哈希值，用于校验
---@field name string # 表的名称，子表用 `.` 来拼接

local clock = os.clock

local weakK = { __mode = "k" }

local MASK32 = 0xffffffff
local FNV_OFFSET = 2166136261
local FNV_PRIME = 16777619
local ID_MIX = 0x9e3779b1
local TYPE_TAG_STRING = 0x73
local TYPE_TAG_NUMBER = 0x6e
local TYPE_TAG_BOOLEAN = 0x62
local TYPE_TAG_NIL = 0x30
local TYPE_TAG_TABLE = 0x74
local TYPE_TAG_FUNCTION = 0x66
local TYPE_TAG_THREAD = 0x68
local TYPE_TAG_USERDATA = 0x75

local mathType = math.type
local strPack = string.pack
local strByte = string.byte

local identityHashes = setmetatable({}, weakK)
local nextIdentityId = 1

---@param n integer
---@return integer
local function u32(n)
    return n & MASK32
end

---@param x integer
---@param bits integer
---@return integer
local function rotl32(x, bits)
    return u32((x << bits) | (x >> (32 - bits)))
end

---@param str string
---@param seed? integer
---@return integer
local function hashString(str, seed)
    local h = seed or FNV_OFFSET
    for i = 1, #str do
        h = u32((h ~ strByte(str, i)) * FNV_PRIME)
    end
    return h
end

---@param v table|function|thread|userdata
---@param typeTag integer
---@return integer
local function hashIdentity(v, typeTag)
    local id = identityHashes[v]
    if not id then
        id = nextIdentityId
        nextIdentityId = nextIdentityId + 1
        identityHashes[v] = id
    end
    return u32((id * ID_MIX) ~ typeTag)
end

---@param v any
---@return integer
local function hashValue(v)
    local tp = type(v)
    if tp == 'string' then
        return hashString(v, FNV_OFFSET ~ TYPE_TAG_STRING)
    elseif tp == 'number' then
        local vType = mathType and mathType(v)
        if vType == 'integer' then
            return u32(v ~ (v >> 32))
        end
        if strPack then
            return hashString(strPack("<d", v), FNV_OFFSET ~ TYPE_TAG_NUMBER)
        end
        return hashString(tostring(v), FNV_OFFSET ~ TYPE_TAG_NUMBER)
    elseif tp == 'boolean' then
        return (v and 0x34567891 or 0x12345678) ~ TYPE_TAG_BOOLEAN
    elseif tp == 'nil' then
        return TYPE_TAG_NIL
    elseif tp == 'table' then
        return hashIdentity(v, TYPE_TAG_TABLE)
    elseif tp == 'function' then
        return hashIdentity(v, TYPE_TAG_FUNCTION)
    elseif tp == 'thread' then
        return hashIdentity(v, TYPE_TAG_THREAD)
    elseif tp == 'userdata' then
        return hashIdentity(v, TYPE_TAG_USERDATA)
    end

    return hashString(tostring(v), FNV_OFFSET)
end

---@param k any
---@param v any
---@return integer
local function hashPair(k, v)
    local kh = hashValue(k)
    local vh = hashValue(v)
    local mixed = u32(kh ~ rotl32(vh, 13))
    return u32((mixed * 0x9e3779b1) ~ (mixed >> 16))
end

---@param t table
---@return integer
local function makeHash(t)
    -- 使用交换律聚合，避免排序和大字符串拼接带来的分配与 O(nlogn)
    local xorAcc = 0
    local sumAcc = 0
    local count = 0

    for k, v in next, t do
        local pair = hashPair(k, v)
        xorAcc = u32(xorAcc ~ pair)
        sumAcc = u32(sumAcc + pair * 3 + 1)
        count = count + 1
    end

    local h = u32(xorAcc ~ rotl32(sumAcc, 7) ~ u32(count * 0x85ebca6b))
    h = u32((h ~ (h >> 16)) * 0x7feb352d)
    h = u32((h ~ (h >> 15)) * 0x846ca68b)
    return u32(h ~ (h >> 16))
end

---@package
---@param isWeakRef? boolean
function M:init(isWeakRef)
    ---@private
    ---@type table<table, TamperChecker.Status>
    self.tables = {}
    ---@private
    self.clock = clock
    if isWeakRef then
        setmetatable(self.tables, weakK)
    end
end

---将一张表加入检查
---@param t table
---@param name string # 表的名称
---@return boolean
function M:add(t, name)
    if self.tables[t] then
        return false
    end
    local status = {
        hash = makeHash(t),
        name = name,
    }
    self.tables[t] = status

    for k, v in pairs(t) do
        if type(v) == 'table' then
            self:add(v, name .. '.' .. tostring(k))
        end
    end

    return true
end

---@private
---@type table?
M.lastTable = nil

M.checkTimes = 0

---检查所有加入的表是否被篡改
---@param maxTime? number # 最大检查时间（秒）
---@return string[]?
---@return 'finished' | 'timeout'
function M:checkAll(maxTime)
    local startTime = self.clock()

    local currentTable = self.lastTable
    local tampered = nil
    while true do
        self.checkTimes = self.checkTimes + 1
        if maxTime and maxTime + startTime < self.clock() then
            self.lastTable = currentTable
            return tampered, 'timeout'
        end
        local status = self.tables[currentTable]
        if currentTable and status and makeHash(currentTable) ~= status.hash then
            tampered = tampered or {}
            tampered[#tampered+1] = status.name
        end
        currentTable = next(self.tables, currentTable)
        if currentTable == self.lastTable then
            break
        end
    end

    self.lastTable = currentTable
    return tampered, 'finished'
end

---立即检查指定表是否被篡改
---@param t table
---@param recursive? boolean # 是否递归检查子表
---@return boolean
function M:check(t, recursive)
    local status = self.tables[t]
    if not status then
        return false
    end

    if makeHash(t) ~= status.hash then
        return true
    end

    if recursive then
        local visited = {}

        local function lookInto(c)
            visited[c] = true

            for k, v in pairs(c) do
                if type(v) == 'table' and not visited[v] then
                    local cstatus = self.tables[v]
                    if not cstatus then
                        return true
                    end
                    if makeHash(v) ~= cstatus.hash then
                        return true
                    end
                    if lookInto(v) then
                        return true
                    end
                end
            end

            return false
        end

        return lookInto(t)
    end

    return false
end

---@param clockFunc fun():number # 返回当前时间（秒）的函数
function M:setClockFunc(clockFunc)
    self.clock = clockFunc
end

local API = {}

---@param isWeakRef? boolean # 是否是弱引用，如果是会使用弱表
---@return TamperChecker
function API.create(isWeakRef)
    local checker = setmetatable({}, M)
    checker:init(isWeakRef)
    return checker
end

---@param clockFunc fun():number # 返回当前时间（秒）的函数
function API.setClockFunc(clockFunc)
    clock = clockFunc
end

return API
