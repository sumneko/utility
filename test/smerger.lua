local sm = require 'string-merger'

local result = sm.mergeDiff('aaabbbccc', {
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
