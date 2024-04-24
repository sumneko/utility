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
    ---@diagnostic disable-next-line: deprecated
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

---@class E: Class.Base
local E = class.declare 'E'

function E.__getter:x()
    return 1
end

local e = class.new 'E' ()

assert(e.x == 1)

---@class F: E
local F = class.declare('F', 'E')

function F.__getter:y()
    return 2
end

local f = class.new 'F' ()

assert(f.x == 1)
assert(f.y == 2)
assert(f.__super == class.get 'E')

do

    ---@class G: Class.Base
    local G = class.declare 'G'

    function G.__getter:x()
        return 1
    end

    function G.__getter:echoz()
        return self.z
    end

    ---@class H: G
    local H = class.declare 'H'

    class.extends('H', 'G')

    function H.__getter:y()
        return 2
    end

    local h = class.new 'H' ()

    assert(h.x == 1)
    assert(h.y == 2)
    h.z = 3
    assert(h.echoz == 3)
end

---@class K: Class.Base
---@field x number
local K = class.declare 'K'

function K.__setter:x(v)
    self.y = v
end

local k = class.new 'K' ()

k.x = 123
assert(k.y == 123)

---@class L: K
local L = class.declare('L', 'K')

function L.__setter:y(v)
    self.z = v
    return v + 1
end

local l = class.new 'L' ()

l.x = 123
assert(l.y == 124)
assert(l.z == 123)

---@class I
local I = class.declare 'I'

I.x = 1

local i = class.new 'I' ()

assert(i.x == 1)

---@class J: I
local J = class.declare('J', 'I')

J.x = 2

local j = class.new 'J' ()

assert(j.x == 2)



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

--阻止循环引用
do
    ---@class AA
    local AA = class.declare 'AA'

    class.extends('AA', 'AA')

    local suc, err = pcall(function ()
        class.new 'AA' ()
    end)
    assert(suc == false)
    assert(err and err:find 'circular')
end

do
    ---@class AB
    local AB = class.declare 'AB'
    ---@class AC
    local AC = class.declare 'AC'

    class.extends('AB', 'AC')
    class.extends('AC', 'AB')

    local suc, err = pcall(function ()
        class.new 'AB' ()
    end)
    assert(suc == false)
    assert(err and err:find 'circular')
end

-- extends 中 super 只能生效一次
do
    ---@class CA
    local CA = class.declare 'CA'

    CA.x = 0

    function CA:__init()
        self.x = self.x + 1
    end

    ---@class CB
    local CB = class.declare 'CB'

    ---@class CB: CA
    class.extends('CB', 'CA', function (self, super)
        assert(self.x == 0)
        super()
        assert(self.x == 1)
        super()
        assert(self.x == 1)
    end)
end

-- 调用 super 返回父类
do
    ---@class DA
    local DA = class.declare 'DA'

    DA.x = 0

    function DA:__init()
        self.x = self.x + 1
    end

    ---@class DB
    local DB = class.declare 'DB'

    ---@class DB: DA
    class.extends('DB', 'DA', function (self, super)
        assert(self.x == 0)
        assert(super() == class.get 'DA')
        assert(self.x == 1)
        assert(super() == class.get 'DA')
        assert(self.x == 1)
    end)
end

do
    --测试对重载的支持
    ---@class EA
    local EA = class.declare 'EA'

    EA.x = 1

    ---@class EB: EA
    local EB = class.declare 'EB'
    class.extends('EB', 'EA')

    local eb1 = class.new 'EB' ()

    assert(eb1.x == 1)

    -- 进行了重载
    ---@class EA
    local EA = class.declare 'EA'

    EA.x = 2

    ---@class EB: EA
    local EB = class.declare 'EB'
    class.extends('EB', 'EA')

    assert(eb1.x == 2)

    local eb2 = class.new 'EB' ()

    assert(eb2.x == 2)
end

print('功能测试通过')

---------------- 性能测试 ----------------
local function test(task, callback)
    collectgarbage()
    collectgarbage 'stop'
    local clock = os.clock()
    callback()
    print(task, os.clock() - clock)
    collectgarbage 'restart'
end

local count = 1000000

test('只创建表', function ()
    for _ = 1, count do
        local t = {
            x = 1,
            y = 2,
            z = 3,
        }
    end
end)

test('创建表并设置元表', function ()
    local mt = {}
    for _ = 1, count do
        local t = setmetatable({
            x = 1,
            y = 2,
            z = 3,
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
            x = 1,
            y = 2,
            z = 3,
        })
    end
end)

test('创建IB', function ()
    for _ = 1, count do
        local t = class.new('IB', {
            x = 1,
            y = 2,
            z = 3,
        })
    end
end)
