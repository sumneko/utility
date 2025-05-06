---@class GenerationTable
local M = {}
M.__index = M

---@package
---@param count integer # 分成多少代，一般2~3代差不多了
function M:init(count)
    self.count = count
    ---@private
    ---@type table[]
    self.list = {{}}
    ---@private
    self.index = 0
end

---@param k any
---@param v any
function M:set(k, v)
    local index = self.index % self.count + 1
    local current = self.list[index]
    self:del(k)
    current[k] = v
end

---@param k any
function M:del(k)
    for _, t in ipairs(self.list) do
        t[k] = nil
    end
end

---@param k any
---@return any
function M:get(k)
    for _, t in ipairs(self.list) do
        local v = t[k]
        if v ~= nil then
            return v
        end
    end
end

---@param grave fun(deads?: table)
function M:grow(grave)
    self.index = self.index + 1
    local index = self.index % self.count + 1
    local current = self.list[index]
    grave(current)
    self.list[index] = {}
end

---@class GenerationTable.API
local API = {}

---@param count integer # 分成多少代，一般2~3代差不多了
function API.create(count)
    local t = setmetatable({}, M)
    t:init(count)
    return t
end

return API
