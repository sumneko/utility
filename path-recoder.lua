---@class PathRecoder
local M = {}
M.__index = M

---@package
function M:init()
    self.map = setmetatable({}, { __mode = 'k' })

    self.mt = { __index = function (parent, key)
        return self:make(key, parent)
    end }
end

---@class PathRecoder.Unit
---@field [any] PathRecoder.Unit

---@param key any
---@return PathRecoder.Unit
function M:root(key)
    return self:make(key)
end

---@package
---@param key? any
---@param parent PathRecoder.Unit?
---@return PathRecoder.Unit
function M:make(key, parent)
    local unit = setmetatable({}, self.mt)
    self.map[unit] = {
        key    = key,
        parent = parent,
        owner  = self,
    }
    return unit
end

---@param unit PathRecoder.Unit
---@return any[]
function M:keys(unit)
    local keys = {}
    local visited = {}
    while unit do
        if visited[unit] then
            break
        end
        visited[unit] = true
        local config = self.map[unit]
        if not config then
            break
        end
        keys[#keys+1] = config.key
        unit = config.parent
    end

    local result = {}
    for i = #keys, 1, -1 do
        result[#result+1] = keys[i]
    end
    return result
end

---@param unit PathRecoder.Unit
---@param unsupported? string
---@return string
function M:view(unit, unsupported)
    if type(unsupported) ~= 'string' then
        unsupported = '?'
    end

    local keys = self:keys(unit)

    local function formatKey(key)
        if type(key) == 'string' then
            if key:match('^[_%a\x80-\xFF][_%w\x80-\xFF]*$') then
                return key
            else
                return string.format('%q', key)
            end
        end
        if type(key) == 'number'
        or type(key) == 'boolean'
        or type(key) == 'nil' then
            return string.format('[%q]', key)
        end
        return unsupported
    end

    local buf = { formatKey(keys[1]) }
    for i = 2, #keys do
        local key = formatKey(keys[i])
        if key:sub(1, 1) == '[' then
            buf[#buf+1] = key
        else
            buf[#buf+1] = '.' .. key
        end
    end

    return table.concat(buf)
end

---@class PathRecoder.API
local API = {}

function API.create()
    local pr = setmetatable({}, M)
    pr:init()
    return pr
end

return API
