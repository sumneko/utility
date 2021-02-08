local sm = require 'string-merger'

local result, info = sm.mergeDiff('aaabbbccc', {
    {
        start  = 1,
        finish = 0,
        text   = '123'
    },
    {
        start  = 1,
        finish = 4,
        text   = '987'
    },
    {
        start  = 6,
        finish = 6,
        text   = '456',
    }
})
assert(result == '123987b456ccc')

local function check(offset, start, finish)
    local resStart, resFinish = sm.getOffset(info, offset)
    assert(resStart  == start)
    assert(resFinish == finish)
end

local function checkBack(offset, start, finish)
    local resStart, resFinish = sm.getOffsetBack(info, offset)
    assert(resStart  == start)
    assert(resFinish == finish)
end

check(1, 4, 4)
check(2, 5, 5)
check(3, 6, 6)
check(4, 6, 6)
check(5, 7, 7)
check(6, 8, 10)
check(7, 11, 11)
check(8, 12, 12)
check(9, 13, 13)

checkBack(1, 0, 0)
checkBack(2, 0, 0)
checkBack(3, 0, 0)
checkBack(4, 1, 1)
checkBack(5, 2, 2)
checkBack(6, 3, 4)
checkBack(7, 5, 5)
checkBack(8, 6, 6)
checkBack(9, 6, 6)
checkBack(10, 6, 6)
checkBack(11, 7, 7)
checkBack(12, 8, 8)
checkBack(13, 9, 9)

result, info = sm.mergeDiff('aaa.bbbbb', {
    {
        start  = 5,
        finish = 9,
        text   = 'ccc'
    },
})

check(5, 5, 5)
check(6, 6, 6)
check(7, 7, 7)
check(8, 7, 7)
check(9, 7, 7)

checkBack(5, 5, 5)
checkBack(6, 6, 6)
checkBack(7, 7, 9)

result, info = sm.mergeDiff('aaa.bbb', {
    {
        start  = 5,
        finish = 7,
        text   = 'ccccc'
    },
})

check(5, 5, 5)
check(6, 6, 6)
check(7, 7, 9)

checkBack(5, 5, 5)
checkBack(6, 6, 6)
checkBack(7, 7, 7)
checkBack(8, 7, 7)
checkBack(9, 7, 7)

local function test1()
    local text = [[
--##
local t: boolean
local num: number

print(t)
]]

    local diffs = {}
    diffs[#diffs+1] = {
        start  = 1,
        finish = 4,
        text   = '',
    }

    for localPos, colonPos, typeName, finish in text:gmatch '()local%s+[%w_]+()%s*%:%s*([%w_]+)()' do
        diffs[#diffs+1] = {
            start  = localPos,
            finish = localPos - 1,
            text   = ('---@type %s\n'):format(typeName),
        }
        diffs[#diffs+1] = {
            start  = colonPos,
            finish = finish - 1,
            text   = '',
        }
    end

    local result, info = sm.mergeDiff(text, diffs)

    assert(result == [[

---@type boolean
local t
---@type number
local num

print(t)
]])

    assert(sm.getOffset(info, 48) == 60)
    assert(sm.getOffsetBack(info, 60) == 48)
end
test1()
