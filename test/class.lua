local class = require 'class'

---@class A
local A = class.declare 'A'

function A:__init()
    self.x = 1
end

local a = class.new 'A' ()

assert(a.x == 1)

---@class B
local B = class.declare 'B'

function B:__init(x, y)
    self.x = x
    self.y = y
end

local b = class.new 'B' (1, 2)

assert(b.x == 1)
assert(b.y == 2)

---@class C: B
local C = class.declare('C', 'B')

function C:__init(x, y, z)
    class.super 'C' (x, y)
    self.z = z
end

local c = class.new 'C' (1, 2, 3)

assert(c.x == 1)
assert(c.y == 2)
assert(c.z == 3)

---@class D: B
local D = class.declare 'D'

class.extends('D', 'B', function (self, super, x, y)
    super(x, y)
end)

function D:__init(x, y, z)
    self.z = z
end

local d = class.new 'D' (1, 2, 3)

assert(d.x == 1)
assert(d.y == 2)
assert(d.z == 3)

---@class IA
local IA = class.declare 'IA'

IA.x = 1
IA.y = 2

local ia = class.new('IA', {
    x = 2,
})

assert(ia.x == 2)
assert(ia.y == 2)

---@class IB: IA
local IB = class.declare('IB')

IB.z = 3

class.extends('IB', 'IA')

local ib = class.new('IB', {
    z = 4,
})

assert(ib.x == 1)
assert(ib.y == 2)
assert(ib.z == 4)


print('功能测试通过')

---------------- 性能测试 ----------------
local function test(task, callback)
    local clock = os.clock()
    callback()
    print(task, os.clock() - clock)
end

local count = 1000000

test('只创建表', function ()
    for _ = 1, count do
        local t = {
            x = 1,
        }
    end
end)

test('创建表并设置元表', function ()
    local mt = {}
    for _ = 1, count do
        local t = setmetatable({
            x = 1,
        }, mt)
    end
end)

test('创建A', function ()
    for _ = 1, count do
        local t = class.new 'A' ()
    end
end)

test('创建C', function ()
    for _ = 1, count do
        local t = class.new 'C' (1, 2, 3)
    end
end)

test('创建D', function ()
    for _ = 1, count do
        local t = class.new 'D' (1, 2, 3)
    end
end)

test('创建IA', function ()
    for _ = 1, count do
        local t = class.new('IA', {
            x = 2,
        })
    end
end)

test('创建IB', function ()
    for _ = 1, count do
        local t = class.new('IB', {
            z = 4,
        })
    end
end)
