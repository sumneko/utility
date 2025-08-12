---@class Attribute.API
local API = {}

---@class Attribute.System
---@field package compiled? boolean
---@field package defines table<string, Attribute.Define>
---@field package methods table<string, Attribute.Method>
---@field package links table<string, string[]>
---@field package require table<string, string[]>
---@field package touched table<Attribute.Instance, table<string, number>>
---@field package dirtyMark table<Attribute.Instance, true>
---@field package dirtyList Attribute.Instance[]
local System = {}
---@package
System.__index = System

System.defaultFormula = '{!} * (1 + 0.01 * {%})'
System.defaultBaseSymbol = '!'

---@package
---@return Attribute.System
function System:init()
    self.defines   = {}
    self.methods   = {}
    self.links     = {}
    self.require   = {}
    self.touched   = {}
    self.dirtyMark = {}
    self.dirtyList = {}
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

---@param customData? any
---@return Attribute.Instance
function System:instance(customData)
    self:compile()
    local instance = API.createInstance(self)

    return instance:init(self, customData)
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
        local requires = define:collectRequires()
        for k in pairs(requires) do
            if not linkMap[k] then
                linkMap[k] = {}
            end
            linkMap[k][name] = true
        end

        self.require[name] = { name }
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

        for _, link in ipairs(links) do
            table.insert(self.require[link], name)
        end
    end

    for _, define in pairs(self.defines) do
        define:compile()
    end
end

---@return table<Attribute.Instance, table<string, number>>? oldValues
function System:getTouched()
    local touched = self.touched
    if not next(touched) then
        return nil
    end
    self.touched = {}
    return touched
end

function System:updateEvent()
    local list = self.dirtyList
    local len = #list
    if len == 0 then
        return
    end

    self.dirtyList = {}
    self.dirtyMark = {}

    for i = 1, len do
        local instance = list[i]
        local events = instance.events
        ---@cast events -?
        for j = 1, #events do
            events[j](instance)
        end
    end
end

---@class Attribute.Define
---@field package formula string
---@field package baseSymbol string
---@field package simple? boolean # 是否是个简易属性
---@field package min? number | string
---@field package max? number | string
---@field package minKeepRate? boolean
---@field package maxKeepRate? boolean
---@field package needRecordTouch? boolean
---@field package compiled? boolean
local Define = {}
---@package
Define.__index = Define

---@package
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
---@param keepRate? boolean
---@return Attribute.Define
function Define:setMin(min, keepRate)
    if self.compiled then
        error('Cannot change min value after compilation.')
    end
    self.min = min
    self.minKeepRate = keepRate
    return self
end

---@param max number | string
---@param keepRate? boolean
---@return Attribute.Define
function Define:setMax(max, keepRate)
    if self.compiled then
        error('Cannot change max value after compilation.')
    end
    self.max = max
    self.maxKeepRate = keepRate
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

---@return Attribute.Define
function Define:recordTouch()
    self.needRecordTouch = true
    return self
end

---@class Attribute.Method
---@field package set fun(instance: Attribute.Instance, value: number)
---@field package add fun(instance: Attribute.Instance, value: number)
---@field package get fun(instance: Attribute.Instance): number
---@field package getMin fun(instance: Attribute.Instance): number
---@field package getMax fun(instance: Attribute.Instance): number
---@field package checkAttention fun(instance: Attribute.Instance)

---@param str string
---@param params table<string, any>
---@return string
local function format(str, params)
    return (str:gsub('{(.-)}', function (symbol)
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
    end))
end

---@param code string
---@return string
local function simplifyCode(code)
    ---@type string[]
    local lines = {}
    for line in code:gmatch('[^\n]+') do
        lines[#lines+1] = line
    end
    local usedLocals = {}
    for i = #lines, 1, -1 do
        local line = lines[i]
        local locDef, tails = line:match('^local%s+(.-)(=.*)$')
        if locDef then
            local locs = {}
            for name in locDef:gmatch('[%w_]+') do
                if usedLocals[name] then
                    locs[#locs+1] = name
                    usedLocals[name] = nil
                end
            end
            if #locs == 0 then
                table.remove(lines, i)
                goto continue
            end
            line = 'local ' .. table.concat(locs, ', ') .. ' ' .. tails
            lines[i] = line
            for name in tails:gmatch '[%w_]+' do
                usedLocals[name] = true
            end
        else
            for name in line:gmatch '[%w_]+' do
                usedLocals[name] = true
            end
        end
        ::continue::
    end
    return table.concat(lines, '\n')
end

local function loadCode(str, params)
    local code = simplifyCode(format(str, params))
    return assert(load(code, code, 't'))
end

---@package
---@param name string
---@return string
function Define:getAttrCode(name)
    local def = self.system.defines[name]
    if not def then
        error('Unknown attribute: ' .. name)
    end
    if def.simple then
        return format('cache[{key}]', { key = name })
    else
        return format('methods[{key}].get(instance)', { key = name })
    end
end

---@package
---@return string
function Define:compileSaveTouchCode()
    local links = self.system.links[self.name]

    local code = {}

    ---@param def Attribute.Define
    local function checkDef(def)
        if not def.needRecordTouch then
            return
        end
        code[#code+1] = format('if not record[{key}] then record[{key}] = {value:s} end', {
            key = def.name,
            value = self:getAttrCode(def.name)
        })
    end

    checkDef(self)

    if links then
        for _, link in ipairs(links) do
            local def = self.system.defines[link]
            checkDef(def)
        end
    end

    if #code == 0 then
        return ''
    end

    table.insert(code, 1, [[
local touched = instance.system.touched
local record = touched[instance]
if not record then
    record = {}
    touched[instance] = record
end
]])

    return table.concat(code, '\n')
end

---@package
---@return string
function Define:compileSaveRateCode()
    local links = self.system.links[self.name]
    if not links then
        return ''
    end

    local code = {}

    for i, link in ipairs(links) do
        local def = self.system.defines[link]
        if def.minKeepRate or def.maxKeepRate then
            if not def.simple then
                error('Complex attributes "' .. link .. '" cannot keep rates.')
            end
        end

        if def.minKeepRate then
            if type(def.min) ~= 'string' then
                error('Min value of "' .. link .. '" must be another attribute to keep rate.')
            end
            code[#code+1] = format([[
local rateMin{i} = (cache[{key}] or 0) / {other:s}
if rateMin{i} ~= rateMin{i} then
    rateMin{i} = 0
end
]], {
    i = i,
    key = link,
    other = self:getAttrCode(def.min --[[@as string]]),
})
        end
        if def.maxKeepRate then
            if type(def.max) ~= 'string' then
                error('Max value of "' .. link .. '" must be another attribute to keep rate.')
            end
            code[#code+1] = format([[
local rateMax{i} = (cache[{key}] or 0) / {other:s}
if rateMax{i} ~= rateMax{i} then
    rateMax{i} = 0
end
]], {
    i = i,
    key = link,
    other = self:getAttrCode(def.max --[[@as string]]),
})
        end
    end

    return table.concat(code, '\n')
end

---@package
---@return string
function Define:compileUpdateLinkCode()
    local links = self.system.links[self.name]
    if not links then
        return ''
    end

    local code = {}

    for _, link in ipairs(links) do
        local def = self.system.defines[link]
        if def.simple then
            if not def.minKeepRate and not def.maxKeepRate then
                code[#code+1] = format('local method = methods[{key}]', { key = link })
                code[#code+1] = format('method.set(instance, cache[{key}] or 0)', { key = link })
            end
        else
            code[#code+1] = format('cache[{key}] = nil', { key = link })
        end
    end

    for i, link in ipairs(links) do
        local def = self.system.defines[link]
        if def.minKeepRate then
            code[#code+1] = format('cache[{key}] = {other:s} * rateMin{i}', {
                key = link,
                i = i,
                other = self:getAttrCode(def.min --[[@as string]]),
            })
        end
        if def.maxKeepRate then
            code[#code+1] = format('cache[{key}] = {other:s} * rateMax{i}', {
                key = link,
                i = i,
                other = self:getAttrCode(def.max --[[@as string]]),
            })
        end
    end

    return table.concat(code, '\n')
end

---@package
---@return string
function Define:compileGetMinCode()
    local min = self.min
    if not min then
        return format('{min}', { min = -math.huge })
    end
    if type(min) == 'number' then
        return format('{min}', { min = min })
    end
    return self:getAttrCode(min)
end

---@package
---@return string
function Define:compileGetMaxCode()
    local max = self.max
    if not max then
        return format('{max}', { max = math.huge })
    end
    if type(max) == 'number' then
        return format('{max}', { max = max })
    end
    return self:getAttrCode(max)
end

---@package
---@return string
function Define:compileCheckMinCode()
    local min = self.min
    if not min then
        return ''
    end
    if type(min) == 'number' then
        return format([[
if value < {min} then
    value = {min}
end]], { min = min })
    end
    return format([[
local min = {min:s}
if value < min then
    value = min
end]], { min = self:getAttrCode(min) })
end

---@package
---@return string
function Define:compileCheckMaxCode()
    local max = self.max
    if not max then
        return ''
    end
    if type(max) == 'number' then
        return format([[
if value > {max} then
    value = {max}
end]], { max = max })
    end
    return format([[
local max = {max:s}
if value > max then
    value = max
end]], { max = self:getAttrCode(max) })
end

---@package
function Define:compileCheckAttention(name)
    return loadCode([[
local instance = ...
if not instance.attention[{name}] then
    return
end
local system = instance.system
if system.dirtyMark[instance] then
    return
end
system.dirtyMark[instance] = true
system.dirtyList[#system.dirtyList+1] = instance
]], { name = name })
end

---@package
function Define:compileSimple()
    local methods = self.system.methods
    local name = self.name
    local params = {
        name = name,
        saveTouch = self:compileSaveTouchCode(),
        saveRate = self:compileSaveRateCode(),
        getMin = self:compileGetMinCode(),
        getMax = self:compileGetMaxCode(),
        checkMin = self:compileCheckMinCode(),
        checkMax = self:compileCheckMaxCode(),
        updateLink = self:compileUpdateLinkCode(),
    }
    methods[name] = {
        set = loadCode([[
local instance, value = ...
local cache = instance.cache
local methods = instance.methods
{saveTouch:s}
{saveRate:s}
{checkMin:s}
{checkMax:s}
cache[{name}] = value
{updateLink:s}
]], params),
        add = loadCode([[
local instance, value = ...
local cache = instance.cache
local methods = instance.methods
if cache[{name}] then
    value = cache[{name}] + value
end
{saveTouch:s}
{saveRate:s}
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
        getMin = loadCode([[
local instance = ...
local methods = instance.methods
return {getMin:s}
]], params),
        getMax = loadCode([[
local instance = ...
local methods = instance.methods
return {getMax:s}
]], params),
        checkAttention = self:compileCheckAttention(name)
    }
end

---@package
function Define:compileComplex()
    local methods = self.system.methods
    local name = self.name

    local params = {
        name = name,
        saveTouch = self:compileSaveTouchCode(),
        saveRate = self:compileSaveRateCode(),
        updateLink = self:compileUpdateLinkCode(),
    }

    local code = self.formula:gsub('{(.-)}', function (symbol)
        if self.system.defines[symbol] then
            return self:getAttrCode(symbol)
        end
        local key = name .. symbol
        if not methods[key] then
            params.key = key
            methods[key] = {
                set = loadCode([[
local instance, value = ...
local cache = instance.cache
local methods = instance.methods
{saveTouch:s}
{saveRate:s}
cache[{key}] = value
cache[{name}] = nil
{updateLink:s}
]], params),
                add = loadCode([[
local instance, value = ...
local cache = instance.cache
local methods = instance.methods
{saveTouch:s}
{saveRate:s}
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
]], params),
                getMin = function ()
                    error('Cannot get min value of middle attribute: ' .. key)
                end,
                getMax = function ()
                    error('Cannot get max value of middle attribute: ' .. key)
                end,
                checkAttention = self:compileCheckAttention(name)
            }
        end
        return string.format('(cache[%q] or 0)', key)
    end)

    local params = {
        name = name,
        code = code,
        getMin = self:compileGetMinCode(),
        getMax = self:compileGetMaxCode(),
        checkMin = self:compileCheckMinCode(),
        checkMax = self:compileCheckMaxCode(),
    }
    local baseMethod = methods[name .. self.baseSymbol]
    methods[name] = {
        set = baseMethod and baseMethod.set or function ()
            error('Attribute "' .. name .. '" is readonly.')
        end,
        add = baseMethod and baseMethod.add or function ()
            error('Attribute "' .. name .. '" is readonly.')
        end,
        get = loadCode([[
local instance = ...
local cache = instance.cache
local methods = instance.methods
local value = cache[{name}]
if value then
    return value
end
value = {code:s}
{checkMin:s}
{checkMax:s}
cache[{name}] = value
return value
]], params),
        getMin = loadCode([[
local instance = ...
local methods = instance.methods
return {getMin:s}
]], params),
        getMax = loadCode([[
local instance = ...
local methods = instance.methods
return {getMax:s}
]], params),
        checkAttention = self:compileCheckAttention(name),
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
function Define:collectRequires()
    local requires = {}

    for name in self.formula:gmatch '{(.-)}' do
        if self.system.defines[name] then
            requires[name] = true
        end
    end
    if type(self.min) == 'string' then
        requires[self.min] = true
    end
    if type(self.max) == 'string' then
        requires[self.max] = true
    end

    return requires
end

---@alias Attribute.EventCallback fun(instance: Attribute.Instance, newValue: number, oldValue: number)

---@class Attribute.Instance
---@field package system Attribute.System
---@field package cache table<string, number>
---@field package methods table<string, Attribute.Method>
---@field package events? function[]
---@field package attention? table<string, integer>
local Instance = {}
---@package
Instance.__index = Instance

---@package
---@param system Attribute.System
---@param customData? any
---@return Attribute.Instance
function Instance:init(system, customData)
    self.system  = system
    self.cache   = {}
    self.methods = system.methods
    self.customData = customData
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
    if self.attention then
        method.checkAttention(self)
    end
end

---@param name string
---@param value number
function Instance:add(name, value)
    local method = self.methods[name]
    if not method then
        error('Unknown attribute: ' .. name)
    end
    method.add(self, value)
    if self.attention then
        method.checkAttention(self)
    end
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

---@param name string
---@return number
function Instance:getMin(name)
    local method = self.methods[name]
    if not method then
        error('Unknown attribute: ' .. name)
    end
    return method.getMin(self)
end

---@param name string
---@return number
function Instance:getMax(name)
    local method = self.methods[name]
    if not method then
        error('Unknown attribute: ' .. name)
    end
    return method.getMax(self)
end

---@param name string
---@param callback Attribute.EventCallback
---@return function
function Instance:event(name, callback)
    local events = self.events
    if not events then
        events = {}
        self.events = events
    end

    local oldValue = self:get(name)
    local proxy = function ()
        local newValue = self:get(name)
        if newValue == oldValue then
            return
        end
        callback(self, newValue, oldValue)
        oldValue = newValue
    end

    events[#events+1] = proxy
    local firstTry = #events

    local requires = self.system.require[name]
    local attention = self.attention
    if not attention then
        attention = {}
        self.attention = attention
    end

    for _, attr in ipairs(requires) do
        attention[attr] = (attention[attr] or 0) + 1
    end

    local disposed
    return function ()
        if disposed then
            return
        end
        disposed = true

        if events[firstTry] == proxy then
            events[firstTry] = events[#events]
            events[#events] = nil
        else
            for i = 1, #events do
                if events[i] == proxy then
                    events[i] = events[#events]
                    events[#events] = nil
                    break
                end
            end
        end

        if #events == 0 then
            self.events = nil
            self.attention = nil
        else
            for _, attr in ipairs(requires) do
                attention[attr] = attention[attr] - 1
                if attention[attr] <= 0 then
                    attention[attr] = nil
                end
            end
        end
    end
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
