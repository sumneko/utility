---@class Attribute.API
local API = {}

---@class Attribute.System
---@field package compiled? boolean
---@field package defines table<string, Attribute.Define>
---@field package methods table<string, Attribute.Method>
local System = {}
---@package
System.__index = System

System.defaultFormula = '{!} * (1 + 0.01 * {%})'
System.defaultBaseSymbol = '!'

---@package
---@return Attribute.System
function System:init()
    self.defines = {}
    self.methods = {}
    self.links   = {}
    return self
end

---@param name string
---@param simple? boolean # 是否是个简易属性
---@param min? number | string
---@param max? number | string
---@return Attribute.Define
function System:define(name, simple, min, max)
    if self.compiled then
        error('Cannot define new attributes after compilation.')
    end
    local define = API.createDefine(self, name)
    self.defines[name] = define
    if simple then
        define:setSimple(simple)
    end
    if min then
        define:setMin(min)
    end
    if max then
        define:setMax(max)
    end
    define:setFormula(self.defaultFormula)
    define:setBaseSymbol(self.defaultBaseSymbol)
    return define
end

---@return Attribute.Instance
function System:instance()
    self:compile()
    return API.createInstance(self)
end

function System:compile()
    if self.compiled then
        return
    end
    ---@type boolean?
    self.compiled = true

    ---@type table<string, table<string, true>>
    local linkMap = {}
    for name, define in pairs(self.defines) do
        local links = define:collectLinks()
        for k in pairs(links) do
            if not linkMap[k] then
                linkMap[k] = {}
            end
            linkMap[k][name] = true
        end
    end

    local function lookIntoLink(name, visited)
        if visited[name] then
            return visited
        end
        visited[name] = true
        local targets = linkMap[name]
        if not targets then
            return visited
        end
        for target in pairs(targets) do
            lookIntoLink(target, visited)
        end
        return visited
    end

    for name in pairs(linkMap) do
        local result = lookIntoLink(name, {})
        result[name] = nil
        local links = {}
        for k in pairs(result) do
            links[#links+1] = k
        end
        table.sort(links)
        self.links[name] = links
    end

    for _, define in pairs(self.defines) do
        define:compile()
    end
end

---@class Attribute.Define
---@field package formula string
---@field package baseSymbol string
---@field package simple? boolean # 是否是个简易属性
---@field package min? number | string
---@field package max? number | string
---@field package compiled? boolean
local Define = {}
---@package
Define.__index = Define

---@param system Attribute.System
---@param name string
function Define:init(system, name)
    self.system = system
    self.name = name
    return self
end

---@param simple boolean
---@return Attribute.Define
function Define:setSimple(simple)
    if self.compiled then
        error('Cannot change simple status after compilation.')
    end
    self.simple = simple
    return self
end

---@param min number | string
---@return Attribute.Define
function Define:setMin(min)
    if self.compiled then
        error('Cannot change min value after compilation.')
    end
    self.min = min
    return self
end

---@param max number | string
---@return Attribute.Define
function Define:setMax(max)
    if self.compiled then
        error('Cannot change max value after compilation.')
    end
    self.max = max
    return self
end

---@param formula string
---@return Attribute.Define
function Define:setFormula(formula)
    if self.compiled then
        error('Cannot change formula after compilation.')
    end
    self.formula = formula
    return self
end

---@param baseSymbol string
---@return Attribute.Define
function Define:setBaseSymbol(baseSymbol)
    if self.compiled then
        error('Cannot change base symbol after compilation.')
    end
    self.baseSymbol = baseSymbol
    return self
end

---@class Attribute.Method
---@field package set fun(instance: Attribute.Instance, value: number)
---@field package add fun(instance: Attribute.Instance, value: number)
---@field package get fun(instance: Attribute.Instance): number

local function format(str, params)
    return str:gsub('{(.-)}', function (symbol)
        local left, right = symbol:match('^(.-):(.-)$')
        local fmt = '%q'
        if left and right then
            symbol = left
            if right and right ~= '' then
                fmt = '%' .. right
            end
        end
        local key = params[symbol]
        if not key then
            error('Unknown symbol: ' .. symbol)
        end
        return string.format(fmt, key)
    end)
end

local function loadCode(str, params)
    local code = format(str, params)
    return assert(load(code, code, 't'))
end

---@package
function Define:compileUpdateLinkCode()
    local links = self.system.links[self.name]
    if not links then
        return ''
    end

    local code = {}
    local needMethods

    for _, link in ipairs(links) do
        local def = self.system.defines[link]
        if def.simple then
            needMethods = true
            code[#code+1] = format('local method = methods[{key}]', { key = link })
            code[#code+1] = format('method.set(instance, cache[{key}] or 0)', { key = link })
        else
            code[#code+1] = format('cache[{key}] = nil', { key = link })
        end
    end

    if needMethods then
        table.insert(code, 1, 'local methods = instance.methods')
    end

    return table.concat(code, '\n')
end

---@package
function Define:compileSimple()
    local methods = self.system.methods
    local name = self.name
    local params = {
        name = name,
        checkMin = '',
        checkMax = '',
        updateLink = self:compileUpdateLinkCode(),
    }
    if self.min then
        if type(self.min) == 'number' then
            params.checkMin = format([[
if value < {min} then
    value = {min}
end]], { min = self.min })
        elseif type(self.min) == 'string' then
            params.checkMin = format([[
local min = instance:get({min})
if value < min then
    value = min
end]], { min = self.min })
        else
            error('Invalid min value type: ' .. type(self.min))
        end
    end
    if self.max then
        if type(self.max) == 'number' then
            params.checkMax = format([[if value > {max} then
value = {max}
end]], { max = self.max })
        elseif type(self.max) == 'string' then
            params.checkMax = format([[
local max = instance:get({max})
if value > max then
    value = max
end]], { max = self.max })
        else
            error('Invalid max value type: ' .. type(self.max))
        end
    end
    methods[name] = {
        set = loadCode([[
local instance, value = ...
local cache = instance.cache
{checkMin:s}
{checkMax:s}
cache[{name}] = value
{updateLink:s}
]], params),
        add = loadCode([[
local instance, value = ...
local cache = instance.cache
if cache[{name}] then
    value = cache[{name}] + value
end
{checkMin:s}
{checkMax:s}
cache[{name}] = value
{updateLink:s}
]], params),
        get = loadCode([[
local instance = ...
local cache = instance.cache
return cache[{name}] or 0
]], params),
    }
end

---@package
function Define:compileComplex()
    local methods = self.system.methods
    local name = self.name

    local params = {
        name = name,
        updateLink = self:compileUpdateLinkCode(),
    }

    local code = self.formula:gsub('{(.-)}', function (symbol)
        local key = name .. symbol
        if not methods[key] then
            params.key = key
            methods[key] = {
                set = loadCode([[
local instance, value = ...
local cache = instance.cache
cache[{key}] = value
cache[{name}] = nil
{updateLink:s}
]], params),
                add = loadCode([[
local instance, value = ...
local cache = instance.cache
local dirty = instance.dirty
if cache[{key}] then
    cache[{key}] = cache[{key}] + value
else
    cache[{key}] = value
end
cache[{name}] = nil
{updateLink:s}
]], params),
                get = loadCode([[
local instance = ...
local cache = instance.cache
return cache[{key}] or 0
]], params)
            }
        end
        return string.format('(cache[%q] or 0)', key)
    end)

    local params = {
        name = name,
        code = code,
        checkMin = '',
        checkMax = '',
    }
    if self.min then
        if type(self.min) == 'number' then
            params.checkMin = format([[
if result < {min} then
    result = {min}
end]], { min = self.min })
        elseif type(self.min) == 'string' then
            params.checkMin = format([[
local min = instance:get({min})
if result < min then
    result = min
end]], { min = self.min })
        else
            error('Invalid min value type: ' .. type(self.min))
        end
    end
    if self.max then
        if type(self.max) == 'number' then
            params.checkMax = format([[if result > {max} then
    result = {max}
end]], { max = self.max })
        elseif type(self.max) == 'string' then
            params.checkMax = format([[
local max = instance:get({max})
if result > max then
    result = max
end]], { max = self.max })
        else
            error('Invalid max value type: ' .. type(self.max))
        end
    end
    methods[name] = {
        set = methods[name .. self.baseSymbol].set,
        add = methods[name .. self.baseSymbol].add,
        get = loadCode([[
local instance = ...
local cache = instance.cache
local result = cache[{name}]
if result then
    return result
end
result = {code:s}
{checkMin:s}
{checkMax:s}
cache[{name}] = result
return result
]], params)
    }
end

---@package
function Define:compile()
    if self.compiled then
        return
    end
    self.compiled = true

    if self.simple then
        self:compileSimple()
    else
        self:compileComplex()
    end
end

---@package
---@return table<string, true>
function Define:collectLinks()
    local links = {}

    if type(self.min) == 'string' then
        links[self.min] = true
    end
    if type(self.max) == 'string' then
        links[self.max] = true
    end

    return links
end

---@class Attribute.Instance
---@field package system Attribute.System
---@field package cache table<string, number>
---@field package dirty table<string, boolean>
---@field package methods table<string, Attribute.Method>
local Instance = {}
---@package
Instance.__index = Instance

---@package
---@param system Attribute.System
---@return Attribute.Instance
function Instance:init(system)
    self.system  = system
    self.cache   = {}
    self.methods = system.methods
    return self
end

---@param name string
---@param value number
function Instance:set(name, value)
    local method = self.methods[name]
    if not method then
        error('Unknown attribute: ' .. name)
    end
    method.set(self, value)
end

---@param name string
---@param value number
function Instance:add(name, value)
    local method = self.methods[name]
    if not method then
        error('Unknown attribute: ' .. name)
    end
    method.add(self, value)
end

---@param name string
---@return number
function Instance:get(name)
    local method = self.methods[name]
    if not method then
        error('Unknown attribute: ' .. name)
    end
    return method.get(self)
end

---@return Attribute.System
function API.create()
    return setmetatable({}, System):init()
end

---@package
---@param system Attribute.System
---@param name string
function API.createDefine(system, name)
    return setmetatable({}, Define):init(system, name)
end

---@package
---@param system Attribute.System
---@return Attribute.Instance
function API.createInstance(system)
    return setmetatable({}, Instance):init(system)
end

return API
