---@class PathTable
local M = {}
M.__index = M

local dirMT = {}

---@param weakMode string
---@return PathTable.Dir
local function createDir(weakMode)
    return setmetatable({}, dirMT[weakMode])
end

local wk  = { __mode = 'k' }
local wv  = { __mode = 'v' }
local wkv = { __mode = 'kv' }

local dirChildMT = {}
dirChildMT[''] = { __index = function (t, k)
    local dir = createDir ''
    t[k] = dir
    return dir
end }
dirChildMT['k'] = {
    __mode = 'k',
    __index = function (t, k)
        local dir = createDir 'k'
        t[k] = dir
        return dir
    end
}
dirChildMT['v'] = {
    __mode = 'v',
    __index = function (t, k)
        local dir = createDir 'v'
        t[k] = dir
        return dir
    end
}
dirChildMT['kv'] = {
    __mode = 'kv',
    __index = function (t, k)
        local dir = createDir 'kv'
        t[k] = dir
        return dir
    end
}

dirMT[''] = { __index = function (t, k)
    if k == 'childDirs' then
        local child = setmetatable({}, dirChildMT[''])
        t[k] = child
        return child
    end
    if k == 'values' then
        local values = {}
        t[k] = values
        return values
    end
    error('Invalid key ' .. tostring(k))
end }
dirMT['k'] = { __index = function (t, k)
    if k == 'childDirs' then
        local child = setmetatable({}, dirChildMT['k'])
        t[k] = child
        return child
    end
    if k == 'values' then
        local values = setmetatable({}, wk)
        t[k] = values
        return values
    end
    error('Invalid key ' .. tostring(k))
end }
dirMT['v'] = { __index = function (t, k)
    if k == 'childDirs' then
        local child = setmetatable({}, dirChildMT['v'])
        t[k] = child
        return child
    end
    if k == 'values' then
        local values = setmetatable({}, wv)
        t[k] = values
        return values
    end
    error('Invalid key ' .. tostring(k))
end }
dirMT['kv'] = { __index = function (t, k)
    if k == 'childDirs' then
        local child = setmetatable({}, dirChildMT['kv'])
        t[k] = child
        return child
    end
    if k == 'values' then
        local values = setmetatable({}, wkv)
        t[k] = values
        return values
    end
    error('Invalid key ' .. tostring(k))
end }

---@class PathTable.Dir
---@field childDirs table<any, PathTable.Dir>
---@field values table<any, any>
---@field fields any[] | false

M.weakMode = ''

---@private
---@param t PathTable.Dir
---@param path any[]
---@param index integer
---@param value any
function M:_set(t, path, index, value)
    local key = path[index]
    local isLastKey = index == #path
    if isLastKey then
        t.values[key] = value
        return
    end

    -- fallback to childs part
    self:_set(t.childDirs[key], path, index + 1, value)
end

---@private
---@param t PathTable.Dir
---@param path any[]
---@param index integer
---@return any
function M:_get(t, path, index)
    local key = path[index]
    local isLastKey = index == #path
    if isLastKey then
        local values = rawget(t, 'values')
        return values and values[key] or nil
    end

    -- try childs part
    local childDirs = rawget(t, 'childDirs')
    if childDirs then
        return self:_get(childDirs[key], path, index + 1)
    end

    return nil
end

---@private
---@param t PathTable.Dir
---@param path any[]
---@param index integer
---@return boolean
function M:_delete(t, path, index)
    local key = path[index]
    local isLastKey = index == #path
    if isLastKey then
        local values = rawget(t, 'values')
        if values then
            values[key] = nil
        end
        return true
    end

    -- try childs part
    local childDirs = rawget(t, 'childDirs')
    if childDirs then
        if self:_delete(childDirs[key], path, index + 1) then
            return true
        end
    end

    return false
end

function M:clear()
    ---@private
    self.root = createDir(self.weakMode)
end

---@param path any[]
---@param value any
---@return PathTable
function M:set(path, value)
    if #path == 0 then
        error('path is empty')
    end
    if value == nil then
        error('value is nil')
    end
    self:_set(self.root, path, 1, value)
    return self
end

---@param path any[]
---@return any
function M:get(path)
    if #path == 0 then
        error('path is empty')
    end
    return self:_get(self.root, path, 1)
end

---@param path any[]
---@return boolean
function M:has(path)
    return self:get(path) ~= nil
end

---@param path any[]
---@return boolean
function M:delete(path)
    if #path == 0 then
        error('path is empty')
    end
    return self:_delete(self.root, path, 1)
end

---@class PathTable.API
local API = {}

---@param weakKey? boolean
---@param weakValue? boolean
---@return PathTable
function API.create(weakKey, weakValue)
    local weakMode = ''
    if weakKey then
        weakMode = weakMode .. 'k'
    end
    if weakValue then
        weakMode = weakMode .. 'v'
    end
    local pt = setmetatable({
        weakMode = weakMode,
    }, M)
    pt:clear()
    return pt
end

return API
