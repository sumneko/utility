---@diagnostic disable: undefined-field, inject-field
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

do
    ---@class FA
    local FA = class.declare 'FA'

    ---@class FB: FA
    local FB = class.declare 'FB'
    class.extends('FB', 'FA')

    ---@class FC: FB
    local FC = class.declare 'FC'
    class.extends('FC', 'FB')

    --发生了重载
    local FA = class.declare 'FA'

    ---@class FB: FA
    local FB = class.declare 'FB'
    class.extends('FB', 'FA')

    ---@class FC: FB
    local FC = class.declare 'FC'
    class.extends('FC', 'FB')

    class.new 'FC' ()
end

do
    class.declare 'GA1'
    class.declare 'GA2'

    class.declare 'GB1'
    class.extends('GB1', 'GA1')
    local gb1 = class.new 'GB1' ()
    assert(class.isInstanceOf(gb1, 'GA1') == true)
    assert(class.isInstanceOf(gb1, 'GB1') == true)
    assert(class.isInstanceOf(gb1, 'GA2') == false)

    class.declare 'GB2'
    class.extends('GB2', 'GA1')
    class.extends('GB2', 'GA2')
    local gb2 = class.new 'GB2' ()
    assert(class.isInstanceOf(gb2, 'GA1') == true)
    assert(class.isInstanceOf(gb2, 'GA2') == true)
    assert(class.isInstanceOf(gb2, 'GB1') == false)
    assert(class.isInstanceOf(gb2, 'GB2') == true)

    class.declare 'GC1'
    class.extends('GC1', 'GB1')
    local gc1 = class.new 'GC1' ()
    assert(class.isInstanceOf(gc1, 'GA1') == true)
    assert(class.isInstanceOf(gc1, 'GB1') == true)
    assert(class.isInstanceOf(gc1, 'GC1') == true)
    assert(class.isInstanceOf(gc1, 'GA2') == false)

    class.declare 'GC2'
    class.extends('GC2', 'GB2')
    local gc2 = class.new 'GC2' ()
    assert(class.isInstanceOf(gc2, 'GA1') == true)
    assert(class.isInstanceOf(gc2, 'GA2') == true)
    assert(class.isInstanceOf(gc2, 'GB2') == true)
    assert(class.isInstanceOf(gc2, 'GC2') == true)
    assert(class.isInstanceOf(gc2, 'GB1') == false)
end

print('功能测试通过')

---------------- 性能测试 ----------------
local function test(task, callback)
    collectgarbage()
    collectgarbage 'stop'
    local clock = os.clock()
    callback()
    print(task, ('%.3f'):format(os.clock() - clock))
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

test('访问默认属性', function ()
    ---@class G1
    local g1 = class.declare 'G1'

    g1.x = 1

    local t = class.new 'G1' ()
    assert(t.x == 1)
    for _ = 1, count do
        local x = t.x
    end
end)

test('访问getter', function ()
    ---@class G2: Class.Base
    local g2 = class.declare 'G2'

    function g2.__getter:x()
        return 1
    end

    local t = class.new 'G2' ()
    assert(t.x == 1)
    for _ = 1, count do
        local x = t.x
    end
end)

test('访问默认属性（有getter时）', function ()
    ---@class G3: Class.Base
    local g3 = class.declare 'G3'

    function g3.__getter:x()
        return 1
    end

    g3.y = 2

    local t = class.new 'G3' ()
    assert(t.y == 2)
    for _ = 1, count do
        local y = t.y
    end
end)

test('写入属性', function ()
    ---@class G1
    local g1 = class.declare 'G1'

    g1.x = 1

    local t = class.new 'G1' ()
    for _ = 1, count do
        t.x = 2
    end
    assert(t.x == 2)

    local t2 = class.new 'G1' ()
    assert(t2.x == 1)
end)

test('访问setter', function ()
    ---@class G2: Class.Base
    local g2 = class.declare 'G2'

    g2.y = 1

    function g2.__setter:x(value)
        self.y = value
    end

    local t = class.new 'G2' ()
    assert(t.y == 1)
    for _ = 1, count do
        t.x = 2
    end
    assert(t.y == 2)

    local t2 = class.new 'G2' ()
    assert(t2.y == 1)
end)

test('写入属性（有setter时）', function ()
    ---@class G3: Class.Base
    local g3 = class.declare 'G3'

    function g3.__setter:x(value)
        self.y = value
    end

    g3.y = 2

    local t = class.new 'G3' ()
    assert(t.y == 2)
    for _ = 1, count do
        t.y = 3
    end
    assert(t.y == 3)

    local t2 = class.new 'G3' ()
    assert(t2.y == 2)
end)

test('综合读写（有getter，无compress）', function ()
    ---@class H1: Class
    local h1 = class.declare 'H1'

    h1.__getter.x = function ()
        return 1
    end

    local t = class.new 'H1' ()
    for _ = 1, count do
        t.y = t.x + 1
        t.a = t.y + 1
        t.b = t.a + 1
    end

    assert(t.y == 2)
    assert(t.a == 3)
    assert(t.b == 4)
end)

test('综合读写（有getter，有compress）', function ()
    ---@class H2: Class
    local h2 = class.declare 'H2'
    class.compressKeys('H2', { 'x', 'y', 'a', 'b' })

    h2.__getter.x = function ()
        return 1
    end

    local t = class.new 'H2' ()
    for _ = 1, count do
        t.y = t.x + 1
        t.a = t.y + 1
        t.b = t.a + 1
    end

    assert(t.y == 2)
    assert(t.a == 3)
    assert(t.b == 4)
end)

test('compress内存比较', function ()
    local t1List = {}
    local t2List = {}
    collectgarbage()
    collectgarbage 'stop'

    local mem1 = collectgarbage 'count'
    for n = 1, 10000 do
        local t = class.new 'H1' ()
        t.x = 1
        t.y = 2
        t.a = 3
        t.b = 4
        t1List[n] = t
    end
    local usage1 = collectgarbage 'count' - mem1
    print('H1内存使用:', ('%.3f KB'):format(usage1))

    collectgarbage()
    local mem2 = collectgarbage 'count'
    for n = 1, 10000 do
        local t = class.new 'H2' ()
        t.x = 1
        t.y = 2
        t.a = 3
        t.b = 4
        t2List[n] = t
    end
    local usage2 = collectgarbage 'count' - mem2
    print('H2内存使用:', ('%.3f KB'):format(usage2))

    collectgarbage 'restart'
end)

test('预分配大小1', function ()
    ---@class TI1
    local TI1 = class.declare 'TI1'

    function TI1:__init()
        self.a = 1
        self.b = 2
        self.c = 3
        self.d = 4
        self.e = 5
        self.f = 6
        self.g = 7
        self.h = 8
        self.i = 9
        self.j = 10
    end

    for _ = 1, 1000000 do
        class.new 'TI1' ()
    end
end)

test('预分配大小2', function ()
    ---@class TI2
    local TI2 = class.declare 'TI2'

    class.presize(TI2, 10)

    function TI2:__init()
        self.a = 1
        self.b = 2
        self.c = 3
        self.d = 4
        self.e = 5
        self.f = 6
        self.g = 7
        self.h = 8
        self.i = 9
        self.j = 10
    end

    for _ = 1, 1000000 do
        class.new 'TI2' ()
    end
end)
