local hex = require 'hex'
local w3rparser = hex.define {
    'version:L',
    'count:L',
    'region:Region[count]',
    Region = {
        'left:f',
        'bottom:f',
        'right:f',
        'top:f',
        'name:z',
        'index:I4',
        ':c4',
        ':z',
        ':c3',
        ':B',
    },
}

local rects = {
    version = 5,
    count = 3,
    region = {
        {
            name   = 'R1',
            left   = -5000,
            bottom = -5000,
            right  = 5000,
            top    = 5000,
            index  = 1,
        },
        {
            name   = 'R2',
            left   = -15000,
            bottom = -15000,
            right  = 15000,
            top    = 15000,
            index  = 2,
        },
        {
            name   = 'R3',
            left   = -25000,
            bottom = -25000,
            right  = 25000,
            top    = 25000,
            index  = 3,
        },
    }
}

local buf = w3rparser:encode(rects)
local new = w3rparser:decode(buf)
print(new)
