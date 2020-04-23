local thread = require 'bee.thread'
thread.newchannel 'TEST'
local ch = thread.channel 'TEST'
local util = require 'utility'
local xml = require 'xml'
local type = type
local laod = load

local t = {}
for x = 1, 10000 do
    t[x] = t
end

local clock = os.clock()
for _ = 1, 100 do
    local dump = util.unpack(t)
    util.pack(dump)
end
print(os.clock() - clock)

local dump = util.unpack(t)
local clock = os.clock()
for _ = 1, 100 do
    ch:push(dump)
    ch:pop()
end
print(os.clock() - clock)

local xmltext = xml.encode {
    version = 1.0,
    heros = {
        hero = {
            {
                id = 'E02K',
                parent_id = '',
                ai = 0,
                name = {
                    zhCN = '军团指挥官',
                },
                primary = {
                    value = 'Str',
                },
                type = {
                    value = 'Control',
                },
                difficulty = {
                    value = 'Hard',
                },
                state = {
                    str = 26,
                    str_add = 2.6,
                    agi = 18,
                    agi_add = 1.7,
                    int = 20,
                    int_add = 2.2,
                    attack_range = 128,
                    is_shortrange = 1,
                    movespeed = 320,
                },
                icon = {
                    value = 'xxxx.blp',
                },
                keyword = {
                    value = '军团|指挥',
                },
                spells = {
                    spell = {
                        id = '',
                        hotkey = 'W',
                        name = {
                            zhCN = '<压倒性优势>',
                        },
                        icon = {
                            value = 'xxxx.blp',
                        },
                        attribute = {
                            zhCN = '作用范围xxxx',
                        },
                        description = {
                            zhCN = 'xxxxxxx',
                        },
                        levels = {
                            zhCN = 'xxxxxxxx',
                        }
                    }
                }
            }
        }
    }
}

print(xmltext)
