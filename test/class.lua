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

    local err
    class.setErrorHandler(function (msg)
        err = msg
    end)
    class.new 'AA' ()
    class.setErrorHandler(error)
    assert(err and err:find 'circular')
end

do
    ---@class AB
    local AB = class.declare 'AB'
    ---@class AC
    local AC = class.declare 'AC'

    class.extends('AB', 'AC')
    class.extends('AC', 'AB')

    local err
    class.setErrorHandler(function (msg)
        err = msg
    end)
    class.new 'AB' ()
    class.setErrorHandler(error)
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

-- 多次定义同一个类要合并字段
do
    local M1 = class.declare 'MERGE'

    M1.x = 1

    local M2 = class.declare 'MERGE'

    M2.y = 2

    local m = class.new 'MERGE' ()

    assert(m.x == 1)
    assert(m.y == 2)
end

-- 直接在类上访问扩展字段
do
    local M1 = class.declare 'VISIT_EXTENDS_CHILD'

    M1.x = 1

    local M2 = class.declare 'VISIT_EXTENDS_CHILD_PARENT'

    M2.y = 2

    class.extends('VISIT_EXTENDS_CHILD', 'VISIT_EXTENDS_CHILD_PARENT')

    assert(M1.y == 2)
end

do
    local result = {}
    local DEL_A = class.declare 'DEL_A'

    function DEL_A:__del()
        result[#result+1] = 'A'
    end

    local DEL_B = class.declare('DEL_B', 'DEL_A')

    function DEL_B:__del()
        result[#result+1] = 'B'
    end

    local DEL_C = class.declare('DEL_C', 'DEL_B')

    function DEL_C:__del()
        result[#result+1] = 'C'
    end

    local del = class.new 'DEL_C' ()

    class.delete(del)

    assert(result[1] == 'C')
    assert(result[2] == 'B')
    assert(result[3] == 'A')
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
    class.declare 'EA'

    EA.x = 2

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

-- __init 调用顺序：父类先，子类后（与析构相反）
do
    local result = {}

    local INIT_A = class.declare 'INIT_A'
    function INIT_A:__init()
        result[#result+1] = 'A'
    end

    local INIT_B = class.declare('INIT_B', 'INIT_A')
    function INIT_B:__init()
        result[#result+1] = 'B'
    end

    local INIT_C = class.declare('INIT_C', 'INIT_B')
    function INIT_C:__init()
        result[#result+1] = 'C'
    end

    class.new 'INIT_C' ()

    assert(result[1] == 'A')
    assert(result[2] == 'B')
    assert(result[3] == 'C')
end

-- 菱形继承
--      Animal
--      /    \
--    Cat    Dog
--      \    /
--      CatDog
do
    local initOrder = {}
    local delOrder = {}

    ---@class Animal
    local Animal = class.declare 'Animal'
    function Animal:__init()
        initOrder[#initOrder+1] = 'Animal'
        self.species = (self.species or '') .. 'Animal;'
    end
    function Animal:__del()
        delOrder[#delOrder+1] = 'Animal'
    end
    function Animal:breathe()
        return 'breathe'
    end

    ---@class Cat: Animal
    local Cat = class.declare('Cat', 'Animal')
    function Cat:__init()
        initOrder[#initOrder+1] = 'Cat'
        self.species = self.species .. 'Cat;'
    end
    function Cat:__del()
        delOrder[#delOrder+1] = 'Cat'
    end
    function Cat:meow()
        return 'meow'
    end

    ---@class Dog: Animal
    local Dog = class.declare('Dog', 'Animal')
    function Dog:__init()
        initOrder[#initOrder+1] = 'Dog'
        self.species = self.species .. 'Dog;'
    end
    function Dog:__del()
        delOrder[#delOrder+1] = 'Dog'
    end
    function Dog:bark()
        return 'bark'
    end

    ---@class CatDog: Cat, Dog
    local CatDog = class.declare 'CatDog'
    class.extends('CatDog', 'Cat')
    class.extends('CatDog', 'Dog')
    function CatDog:__init()
        initOrder[#initOrder+1] = 'CatDog'
        self.species = self.species .. 'CatDog;'
    end
    function CatDog:__del()
        delOrder[#delOrder+1] = 'CatDog'
    end

    local cd = class.new 'CatDog' ()

    -- isInstanceOf：四种类型都满足
    assert(class.isInstanceOf(cd, 'CatDog') == true)
    assert(class.isInstanceOf(cd, 'Cat') == true)
    assert(class.isInstanceOf(cd, 'Dog') == true)
    assert(class.isInstanceOf(cd, 'Animal') == true)

    -- 继承父类的方法
    assert(cd:breathe() == 'breathe')
    assert(cd:meow() == 'meow')
    assert(cd:bark() == 'bark')

    -- species 字段累积反映同一调用顺序
    assert(cd.species == 'Animal;Cat;Dog;CatDog;')

    -- __init 顺序：菱形继承下 Animal 只被调用一次
    -- Cat 链：Animal -> Cat；Dog 链：Animal 已 visited 跳过 -> Dog；自身：CatDog
    assert(initOrder[1] == 'Animal')
    assert(initOrder[2] == 'Cat')
    assert(initOrder[3] == 'Dog')
    assert(initOrder[4] == 'CatDog')
    assert(#initOrder == 4)

    -- __del 顺序：按 __init 顺序的逆序
    -- __init 顺序：Animal -> Cat -> Dog -> CatDog
    -- 所以 __del 顺序：CatDog -> Dog -> Cat -> Animal
    class.delete(cd)
    assert(delOrder[1] == 'CatDog')
    assert(delOrder[2] == 'Dog')
    assert(delOrder[3] == 'Cat')
    assert(delOrder[4] == 'Animal')
    assert(#delOrder == 4)
end

-- 菱形继承下，通过 super 显式重复初始化已被另一条链初始化的父类应当报错
do
    class.declare 'DiaA'
    class.declare 'DiaB'
    class.extends('DiaB', 'DiaA')  -- B -> A，不显式 super，自动调
    class.declare 'DiaC'
    class.extends('DiaC', 'DiaA', function (self, super)
        super()  -- C -> A，显式 super
    end)
    class.declare 'DiaD'
    class.extends('DiaD', 'DiaB')  -- 先走 B 链：A, B（A 被初始化）
    class.extends('DiaD', 'DiaC')  -- 再走 C 链：C 的钩子调 super() 试图初始化已 visited 的 A

    local errored = false
    class.setErrorHandler(function (msg)
        errored = true
    end)
    class.new 'DiaD' ()
    assert(errored, '菱形继承下显式 super 重复初始化父类应当报错')
    class.setErrorHandler(error)
end

-- alias：为已有构造函数注册别名，class.new 返回一个工厂闭包
do
    local function makePoint(x, y)
        return { x = x, y = y }
    end
    class.alias('Point', makePoint)

    -- class.new 'Point' 返回一个工厂函数
    local factory = class.new 'Point'
    assert(type(factory) == 'function')

    local p = factory(3, 4)
    assert(p.x == 3)
    assert(p.y == 4)
    -- alias 创建的实例会被打上 __class__ 标记
    assert(p.__class__ == 'Point')
    assert(class.type(p) == 'Point')

    -- 普通 declare 类不受 alias 影响
    class.declare 'NotAlias'
    local na = class.new 'NotAlias' ()
    assert(class.type(na) == 'NotAlias')

    -- 名称既不在 _classes 也不在 _alias 中：触发错误
    local err
    class.setErrorHandler(function (msg)
        err = msg
    end)
    local r = class.new 'NoSuchClass'
    class.setErrorHandler(error)
    assert(err and err:find 'NoSuchClass')
    assert(r == nil)
end

--flush 清理 getter 写回的缓存
 do
    ---@class J1: Class.Base
    local J1 = class.declare 'J1'

    local calls = 0
    function J1.__getter:x()
        calls = calls + 1
        return calls, true
    end

    local t = class.new 'J1' ()
    assert(t.x == 1)
    assert(t.x == 1) -- 命中缓存
    assert(calls == 1)

    class.flush(t)
    assert(t.x == 2) -- 缓存被清理后重新计算
    assert(calls == 2)
end

--flush 不影响纯访问器
do
    ---@class J3: Class.Base
    local J3 = class.declare 'J3'

    local calls = 0
    function J3.__getter:x()
        calls = calls + 1
        return calls
    end

    local t = class.new 'J3' ()
    assert(t.x == 1)
    assert(t.x == 2) -- 每次重新计算
    class.flush(t)
    assert(t.x == 3)
    assert(calls == 3)
end

--flush 清理 getter 字段上的值（外部赋值也可清，preset 除外）
do
    ---@class J4: Class.Base
    local J4 = class.declare 'J4'

    function J4.__getter:x()
        return 100
    end

    local t = class.new 'J4' ()
    t.x = 5 -- 外部显式赋值
    assert(t.x == 5)
    class.flush(t)
    assert(t.x == 100) -- 被清理后重新走 getter
end

--flush 清理压缩字段的缓存
do
    ---@class J5: Class.Base
    local J5 = class.declare 'J5'
    class.compressKeys('J5', { 'x' })

    local calls = 0
    function J5.__getter:x()
        calls = calls + 1
        return calls, true
    end

    local t = class.new 'J5' ()
    assert(t.x == 1)
    assert(t.x == 1)
    class.flush(t)
    assert(t.x == 2)
end

--class.preset 固定值（永久）与 getter 缓存（可清）的生命周期分离
do
    ---@class J6: Class.Base
    local J6 = class.declare 'J6'

    local n = 0
    function J6.__getter:x()
        n = n + 1
        return n, true
    end

    local a = class.new 'J6' ()
    local b = class.new 'J6' ()
    class.preset(a, 'x', 100) -- 固定值：永久
    assert(a.x == 100)
    assert(b.x == 1) -- getter 缓存，可清

    class.flush(a)
    assert(a.x == 100) -- preset 不被清

    class.flush(b)
    assert(b.x == 2) -- getter 缓存被清，重新计算
end

--flush 遍历所有 getter 字段（大量键）
do
    ---@class J7: Class.Base
    local J7 = class.declare 'J7'

    local n = 0
    for i = 1, 70 do
        J7.__getter['k' .. i] = function ()
            n = n + 1
            return n, true
        end
    end

    local t = class.new 'J7' ()
    for i = 1, 70 do
        assert(t['k' .. i] == i)
    end
    assert(n == 70)

    -- 首次访问后全部命中缓存
    for i = 1, 70 do
        assert(t['k' .. i] == i)
    end
    assert(n == 70)

    class.flush(t)
    for i = 1, 70 do
        assert(t['k' .. i] == 70 + i) -- 全部重新计算
    end
end

--flush 缓存未命中（getter 缓存后手动赋 nil）
do
    ---@class J8: Class.Base
    local J8 = class.declare 'J8'

    local n = 0
    function J8.__getter:x()
        n = n + 1
        return n, true
    end

    local t = class.new 'J8' ()
    assert(t.x == 1) -- 首次计算并缓存
    assert(t.x == 1) -- 命中缓存
    assert(n == 1)

    t.x = nil -- 手动清空字段 → 缓存未命中
    assert(t.x == 2) -- getter 重新计算并再次缓存
    assert(n == 2)

    class.flush(t) -- 标记仍在，flush 正常清理
    assert(t.x == 3) -- 再次重新计算
    assert(n == 3)
end

--class.preset 固定值：不被 flush 清理，getter 不再被调用
do
    ---@class J9: Class.Base
    local J9 = class.declare 'J9'

    local calls = 0
    function J9.__getter:x()
        calls = calls + 1
        return calls, true
    end

    local t = class.new 'J9' ()
    assert(rawget(t, '__class__') == 'J9') -- __class__ 是类名字符串
    class.preset(t, 'x', 100)
    assert(t.x == 100)
    assert(calls == 0) -- getter 不再被调用
    class.flush(t)
    assert(t.x == 100) -- preset 不被清
    assert(calls == 0)
end

--class.preset 压缩字段（自动换算整数槽位）
do
    ---@class J10: Class.Base
    local J10 = class.declare 'J10'
    class.compressKeys('J10', { 'x' })

    local calls = 0
    function J10.__getter:x()
        calls = calls + 1
        return calls, true
    end

    local t = class.new 'J10' ()
    class.preset(t, 'x', 100)
    assert(t.x == 100)
    class.flush(t)
    assert(t.x == 100) -- preset 不被清
    assert(calls == 0)
end

--class.preset 继承的压缩字段（合并 compress）
do
    ---@class J11P: Class.Base
    local J11P = class.declare 'J11P'
    class.compressKeys('J11P', { 'x' })

    ---@class J11: J11P
    local J11 = class.declare 'J11'
    class.extends('J11', 'J11P')

    local calls = 0
    function J11.__getter:x()
        calls = calls + 1
        return calls, true
    end

    local t = class.new 'J11' ()
    class.preset(t, 'x', 100)
    assert(t.x == 100)
    class.flush(t)
    assert(t.x == 100) -- preset 不被清
    assert(calls == 0)
end

--哨兵：getter 体内写自身字段，计算中 flush 后不残留哨兵
do
    ---@class J12: Class.Base
    local J12 = class.declare 'J12'

    local count = 0
    function J12.__getter:x()
        self.x = 'sentinel' -- 哨兵
        if self.triggerFlush then
            self.triggerFlush = nil
            class.flush(self) -- 计算中触发 flush
        end
        count = count + 1
        return 'real' .. count
    end

    local t = class.new 'J12' ()
    t.triggerFlush = true
    assert(t.x == 'real1')
    -- 若哨兵残留，此处会读到 'sentinel'
    assert(t.x == 'real2') -- 重新进入 getter
    assert(count == 2)
end

--不缓存的 getter 不写字段、不产生 __preset__ 残留
do
    ---@class J13: Class.Base
    local J13 = class.declare 'J13'

    function J13.__getter:x()
        return 1 -- 不缓存，也不写字段
    end

    local t = class.new 'J13' ()
    assert(t.x == 1)
    assert(t.x == 1)
    assert(rawget(t, '__preset__') == nil) -- 无 preset 残留
    class.flush(t) -- 无害
    assert(t.x == 1)
end

--reload（compress 变化）后 getterKeys 按新布局重建；新实例正常缓存与清理
do
    ---@class J14: Class.Base
    local J14 = class.declare 'J14'

    local n = 0
    function J14.__getter:x()
        n = n + 1
        return n, true
    end

    local t = class.new 'J14' ()
    assert(t.x == 1)
    assert(t.x == 1)

    -- 重载 + 压缩布局变化（模拟 reload）
    class.compressKeys('J14', { 'x' })
    class.declare 'J14'

    -- 旧实例在非压缩期写入的字符串键缓存会残留并遮蔽新 getter（孤儿字段）；
    -- flush 只按新布局（整数槽位）清理，不清旧字符串键 → t.x 仍读到旧缓存 1
    class.flush(t)
    assert(t.x == 1)
    assert(n == 1)

    -- 新实例按新布局正常缓存与清理
    local t2 = class.new 'J14' ()
    assert(t2.x == 2)
    class.flush(t2)
    assert(t2.x == 3)
end

--「reset 后第一次写入」必须和读取一样延迟初始化：
-- __newindex 里缺少 config:init() 时，继承来的 setter 尚未复制回子类，
-- 写入会被当成普通字段 rawset，甚至把整个类的 __newindex 置 nil 永久失效。
-- 1) 子类只有继承 setter；reset 父类后第一次操作是直接写
do
    ---@class RST_A: Class.Base
    local RST_A = class.declare 'RST_A'

    function RST_A.__getter:value()
        return self._value
    end

    function RST_A.__setter:value(v)
        self._value = v
    end

    ---@class RST_A_C: RST_A
    class.declare 'RST_A_C'
    class.extends('RST_A_C', 'RST_A')

    local childClass = class.get 'RST_A_C'

    local a = class.new 'RST_A_C' ()
    local b = class.new 'RST_A_C' ()

    a.value = true
    b.value = true
    assert(a._value == true)
    assert(b._value == true)

    -- 重复声明已有父类 → reset 传播到子类
    class.declare 'RST_A'

    -- reset 后第一次触碰子类是直接写
    a.value = false
    assert(a._value == false)
    assert(rawget(a, 'value') == nil)

    -- 类级影响：同类第二个实例
    b.value = false
    assert(b._value == false)
    assert(rawget(b, 'value') == nil)

    -- 第一次失败写入之后新建的实例
    local c = class.new 'RST_A_C' ()
    c.value = true
    assert(c._value == true)
    assert(rawget(c, 'value') == nil)

    -- 写陷阱没有被永久关闭
    assert(childClass.__newindex ~= nil)

    -- 直接 reset 子类本身，第一次操作依然是写
    class.declare 'RST_A_C'
    c.value = false
    assert(c._value == false)
    assert(rawget(c, 'value') == nil)
end

-- 2) reset 中间类（链条 P <- M <- C）
do
    ---@class RST_B_P: Class.Base
    local RST_B_P = class.declare 'RST_B_P'

    function RST_B_P.__setter:value(v)
        self._value = v
    end

    ---@class RST_B_M: RST_B_P
    class.declare 'RST_B_M'
    class.extends('RST_B_M', 'RST_B_P')

    ---@class RST_B_C: RST_B_M
    class.declare 'RST_B_C'
    class.extends('RST_B_C', 'RST_B_M')

    local leaf = class.new 'RST_B_C' ()
    leaf.value = 1
    assert(leaf._value == 1)

    -- reset 中间类，影响传播到叶子类
    class.declare 'RST_B_M'

    leaf.value = 2
    assert(leaf._value == 2)
    assert(rawget(leaf, 'value') == nil)
end

-- 3) 子类同时具有自有 setter 和继承 setter
do
    ---@class RST_C_P: Class.Base
    local RST_C_P = class.declare 'RST_C_P'

    function RST_C_P.__setter:px(v)
        self._px = v
    end

    ---@class RST_C_C: RST_C_P
    local RST_C_C = class.declare 'RST_C_C'
    class.extends('RST_C_C', 'RST_C_P')

    function RST_C_C.__setter:cx(v)
        self._cx = v
    end

    local t = class.new 'RST_C_C' ()
    t.px = 1
    t.cx = 2
    assert(t._px == 1)
    assert(t._cx == 2)

    -- reset 父类：自有 setter 不受影响，继承的 setter 必须重新复制回来
    class.declare 'RST_C_P'

    t.px = 3
    assert(t._px == 3)
    assert(rawget(t, 'px') == nil)

    t.cx = 4
    assert(t._cx == 4)
    assert(rawget(t, 'cx') == nil)
end

-- 4) 普通字段模式（无 setter、无 compress）在 reset 后依然正常
do
    class.declare 'RST_D_P'
    class.declare 'RST_D_C'
    class.extends('RST_D_C', 'RST_D_P')

    local t = class.new 'RST_D_C' ()
    t.x = 1
    assert(rawget(t, 'x') == 1)

    class.declare 'RST_D_P' -- reset

    t.y = 2
    assert(rawget(t, 'y') == 2)
    assert(class.get('RST_D_C').__newindex == nil)
end

-- 5) compressKeys 压缩字段模式
do
    ---@class RST_E_P: Class.Base
    local RST_E_P = class.declare 'RST_E_P'
    class.compressKeys('RST_E_P', { 'value' })

    function RST_E_P.__getter:value()
        return self._value
    end

    function RST_E_P.__setter:value(v)
        self._value = v
    end

    ---@class RST_E_C: RST_E_P
    class.declare 'RST_E_C'
    class.extends('RST_E_C', 'RST_E_P')

    local t = class.new 'RST_E_C' ()
    t.value = 1
    assert(t._value == 1)

    -- reset 父类，压缩列表通过 getCompress 合并到子类
    class.compressKeys('RST_E_P', { 'value' })

    t.value = 2
    assert(t._value == 2)
    assert(t.value == 2)
    assert(rawget(t, 1) == nil) -- 压缩槽位没有被直接写入
end

-- 6) 连续多次 reset 后重复写入
do
    ---@class RST_F_P: Class.Base
    local RST_F_P = class.declare 'RST_F_P'

    function RST_F_P.__setter:value(v)
        self._value = v
    end

    ---@class RST_F_C: RST_F_P
    class.declare 'RST_F_C'
    class.extends('RST_F_C', 'RST_F_P')

    local t = class.new 'RST_F_C' ()

    for i = 1, 5 do
        class.declare 'RST_F_P' -- 每次 reset 后的第一次操作都是写
        t.value = i
        assert(t._value == i)
        assert(rawget(t, 'value') == nil)
    end
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

test('访问getter（缓存命中）', function ()
    ---@class G4: Class.Base
    local g4 = class.declare 'G4'

    function g4.__getter:x()
        return 1, true
    end

    local t = class.new 'G4' ()
    assert(t.x == 1) -- 首次访问：计算并标记
    for _ = 1, count do
        local x = t.x -- 命中缓存
    end
end)

test('getter + flush 循环', function ()
    ---@class G5: Class.Base
    local g5 = class.declare 'G5'

    function g5.__getter:x()
        return 1, true
    end

    local t = class.new 'G5' ()
    for _ = 1, count do
        local x = t.x
        class.flush(t)
    end
end)

test('getter 缓存未命中（赋nil）', function ()
    ---@class G6: Class.Base
    local g6 = class.declare 'G6'

    function g6.__getter:x()
        return 1, true
    end

    local t = class.new 'G6' ()
    for _ = 1, count do
        local x = t.x
        t.x = nil -- 缓存未命中：下次访问重新计算
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
