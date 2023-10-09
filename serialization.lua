local type         = type
local pairs        = pairs
local mathType     = math.type
local stringPack   = string.pack
local stringUnpack = string.unpack
local stringSub    = string.sub

---@class Serialization
local M = {}

local Number  = 'N'
local Int8    = 'I'
local Int64   = 'J'
local String  = 'S'
local True    = 'T'
local False   = 'F'
local TableB  = 'B' -- 开始一张表的定义
local TableE  = 'E' -- 结束一张表的定义
local Ref     = 'R' -- 复用之前定义的字符串或表
local Custom  = 'C' -- 自定义数据

---@alias Serialization.SupportTypes
---| number
---| string
---| boolean
---| table

-- 将一个Lua值序列化为二进制数据
---@param data Serialization.SupportTypes | nil
---@param hook? fun(value: table): Serialization.SupportTypes | nil
---@return string
function M.encode(data, hook)
    local buf = {}
    local refid = 0
    local tableMap = {}

    local function encode(value, disableHook)
        local ref = tableMap[value]
        if ref then
            buf[#buf+1] = Ref.. stringPack('I4', ref)
            return
        end
        local tp = type(value)
        if tp == 'number' then
            if mathType(value) == 'integer' then
                if value >= 0 and value <= 255 then
                    buf[#buf+1] = Int8 .. stringPack('H', value)
                else
                    buf[#buf+1] = Int64 .. stringPack('j', value)
                end
            else
                buf[#buf+1] = Number .. stringPack('n', value)
            end
        elseif tp == 'string' then
            refid = refid + 1
            tableMap[value] = refid
            buf[#buf+1] = String .. stringPack('s4', value)
        elseif tp == 'boolean' then
            if value then
                buf[#buf+1] = True
            else
                buf[#buf+1] = False
            end
        elseif tp == 'table' then
            if hook and not disableHook then
                local newValue = hook(value)
                if newValue ~= nil then
                    buf[#buf+1] = Custom
                    encode(newValue, true)
                    return
                end
            end
            refid = refid + 1
            tableMap[value] = refid
            buf[#buf+1] = TableB
            for k, v in pairs(value) do
                encode(k)
                encode(v)
            end
            buf[#buf+1] = TableE
        end
    end

    encode(data)

    return table.concat(buf)
end

-- 反序列化二进制数据为Lua值
---@param str string
---@param hook? fun(value: Serialization.SupportTypes): Serialization.SupportTypes | nil
---@return Serialization.SupportTypes | nil
function M.decode(str, hook)
    if str == '' then
        return nil
    end
    local index = 1
    local tid = 0
    local tableMap = {}

    local function decode()
        local tp = stringSub(str, index, index)
        index = index + 1

        local value
        if tp == Number then
            value, index = stringUnpack('n', str, index)
            return value
        elseif tp == Int8 then
            value, index = stringUnpack('H', str, index)
            return value
        elseif tp == Int64 then
            value, index = stringUnpack('j', str, index)
            return value
        elseif tp == String then
            value, index = stringUnpack('s4', str, index)
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
        elseif tp == Ref then
            value, index = stringUnpack('I4', str, index)
            value = tableMap[value]
            return value
        elseif tp == Custom then
            ---@cast hook -?
            value = decode()
            ---@cast value -?
            value = hook(value)
            return value
        end
    end

    local value = decode()
    assert(index == #str + 1)
    return value
end

return M
