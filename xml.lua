local type = type
local concat = table.concat
local stringRep = string.rep
local tableSort = table.sort

local m = {}

--- 排序后遍历
---@param t table
local function sortPairs(t)
    local keys = {}
    for k in pairs(t) do
        keys[#keys+1] = k
    end
    tableSort(keys)
    local i = 0
    return function ()
        i = i + 1
        local k = keys[i]
        return k, t[k]
    end
end

local TAB = setmetatable({}, { __index = function (self, n)
    self[n] = stringRep('    ', n)
    return self[n]
end})

local function encodeProp(name, t, tab)
    local props = {}
    local attrs = {name}
    tab = tab or 0
    for k, v in sortPairs(t) do
        if type(v) == 'table' then
            if #v == 0 then
                props[#props+1] = encodeProp(k, v, tab + 1)
            else
                for i = 1, #v do
                    props[#props+1] = encodeProp(k, v[i], tab + 1)
                end
            end
        else
            attrs[#attrs+1] = ('%s=%q'):format(k, tostring(v))
        end
    end
    if #props == 0 then
        return TAB[tab] .. '<' .. concat(attrs, ' ') .. ' />'
    else
        local lines = {}
        lines[1] = TAB[tab] .. '<' .. concat(attrs, ' ') .. '>'
        for i = 1, #props do
            lines[i+1] = props[i]
        end
        lines[#lines+1] = TAB[tab] .. '</' .. name .. '>'
        return concat(lines, '\r\n')
    end
end

function m.encode(t)
    local result = {}
    result[1] = '<?xml version="1.0" encoding="UTF-8"?>'
    result[2] = encodeProp('root', t)
    result[3] = ''
    return concat(result, '\r\n')
end

return m
