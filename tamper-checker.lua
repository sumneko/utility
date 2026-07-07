---@class TamperChecker
local M = {}
M.__index = M

---@class TamperChecker.Status
---@field hash integer # 表的哈希值，用于校验
---@field name string # 表的名称，子表用 `.` 来拼接

local clock = os.clock

local weakK = { __mode = "k" }

---@param str string
---@return integer
local function hash(str)
    local h = 0xcbf29ce484222325
    local bytes = { string.byte(str, 1, -1) }
    for i = 1, #bytes do
        h = (h ~ bytes[i]) * 0x100000001b3
    end
    return h
end

---@param v any
---@return string
local function valueHash(v)
    local tp = type(v)
    if tp == 'string' then
        return 'string:' .. hash(v)
    elseif tp == 'boolean'
    or tp == 'number'
    or tp == 'nil' then
        return ('%q'):format(v)
    else
        return ('%s:%p'):format(tp, v)
    end
end

---@param t table
---@return integer
local function makeHash(t)
    local buf = {}
    for k, v in pairs(t) do
        buf[#buf + 1] = valueHash(k) .. '=' .. valueHash(v)
    end
    table.sort(buf)
    local concated = table.concat(buf, ",")
    return hash(concated)
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
