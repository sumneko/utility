local type         = type
local pairs        = pairs
local mathType     = math.type
local stringPack   = string.pack
local stringUnpack = string.unpack

---@class Serialization
local M = {}

local Number  = 'N'
local Integer = 'I'
local String  = 'S'
local True    = 'T'
local False   = 'F'
local TableB  = 'B' -- 开始一张表的定义
local TableE  = 'E' -- 结束一张表的定义
local TableR  = 'R' -- 复用之前定义的表

-- 将一个Lua值序列化为二进制数据
---@param data nil | number | string | boolean | table
---@return string
function M.encode(data)
    local buf = {}
    local tid = 0
    local tableMap = {}

    local function encode(value)
        local tp = type(value)
        if tp == 'number' then
            if math.type(value) == 'integer' then
                buf[#buf+1] = Integer .. stringPack('j', value)
            else
                buf[#buf+1] = Number .. stringPack('n', value)
            end
        elseif tp == 'string' then
            buf[#buf+1] = String .. stringPack('s4', value)
        elseif tp == 'boolean' then
            if value then
                buf[#buf+1] = True
            else
                buf[#buf+1] = False
            end
        elseif tp == 'table' then
            local id = tableMap[value]
            if id then
                buf[#buf+1] = TableR.. stringPack('I4', id)
            else
                tid = tid + 1
                tableMap[value] = tid
                buf[#buf+1] = TableB
                for k, v in pairs(value) do
                    encode(k)
                    encode(v)
                end
                buf[#buf+1] = TableE
            end
        end
    end

    encode(data)

    return table.concat(buf)
end

-- 反序列化二进制数据为Lua值
---@param str string
---@return nil | number | string | boolean | table
function M.decode(str)
    if str == '' then
        return nil
    end
    local index = 1
    local tid = 0
    local tableMap = {}

    local function decode()
        local tp = string.sub(str, index, index)
        index = index + 1

        local value
        if tp == Number then
            value, index = string.unpack('n', str, index)
            return value
        elseif tp == Integer then
            value, index = string.unpack('j', str, index)
            return value
        elseif tp == String then
            value, index = string.unpack('s4', str, index)
            return value
        elseif tp == True then
            return true
        elseif tp == False then
            return false
        elseif tp == TableB then
            value = {}
            tid = tid + 1
            tableMap[tid] = value
            while true do
                local k = decode()
                if not k then
                    break
                end
                local v = decode()
                value[k] = v
            end
            return value
        elseif tp == TableR then
            value, index = string.unpack('I4', str, index)
            value = tableMap[value]
            return value
        end
    end

    local value = decode()
    assert(index == #str + 1)
    return value
end

return M
