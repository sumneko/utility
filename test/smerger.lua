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

assert(sm.getOffset(info, 1) == 4)
assert(sm.getOffset(info, 2) == 5)
assert(sm.getOffset(info, 3) == 6)
assert(sm.getOffset(info, 4) == 6)
assert(sm.getOffset(info, 5) == 7)
assert(sm.getOffset(info, 6) == 8)
assert(sm.getOffset(info, 7) == 11)
assert(sm.getOffset(info, 8) == 12)
assert(sm.getOffset(info, 9) == 13)

assert(sm.getOffsetBack(info, 1) == 0)
assert(sm.getOffsetBack(info, 2) == 0)
assert(sm.getOffsetBack(info, 3) == 0)
assert(sm.getOffsetBack(info, 4) == 1)
assert(sm.getOffsetBack(info, 5) == 2)
assert(sm.getOffsetBack(info, 6) == 3)
assert(sm.getOffsetBack(info, 7) == 5)
assert(sm.getOffsetBack(info, 8) == 6)
assert(sm.getOffsetBack(info, 9) == 6)
assert(sm.getOffsetBack(info, 10) == 6)
assert(sm.getOffsetBack(info, 11) == 7)
assert(sm.getOffsetBack(info, 12) == 8)
assert(sm.getOffsetBack(info, 13) == 9)

result, info = sm.mergeDiff('aaa.bbbbb', {
    {
        start  = 5,
        finish = 9,
        text   = 'ccc'
    },
})
assert(sm.getOffset(info, 5) == 5)
assert(sm.getOffset(info, 6) == 6)
assert(sm.getOffset(info, 7) == 7)
assert(sm.getOffset(info, 8) == 7)
assert(sm.getOffset(info, 9) == 7)


assert(sm.getOffsetBack(info, 5) == 5)
assert(sm.getOffsetBack(info, 6) == 6)
assert(sm.getOffsetBack(info, 7) == 7)

result, info = sm.mergeDiff('aaa.bbb', {
    {
        start  = 5,
        finish = 7,
        text   = 'ccccc'
    },
})
assert(sm.getOffset(info, 5) == 5)
assert(sm.getOffset(info, 6) == 6)
assert(sm.getOffset(info, 7) == 7)


assert(sm.getOffsetBack(info, 5) == 5)
assert(sm.getOffsetBack(info, 6) == 6)
assert(sm.getOffsetBack(info, 7) == 7)
assert(sm.getOffsetBack(info, 8) == 7)
assert(sm.getOffsetBack(info, 9) == 7)

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
