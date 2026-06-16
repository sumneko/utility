local seri = require 'serialization'
local util = require 'utility'

local function test(t, encodeHook, decodeHook)
    local c = os.clock()
    local r = seri.encode(t, encodeHook)
    local nt = seri.decode(r, decodeHook)
    local p = os.clock() - c
    assert(util.equal(t, nt))
    return r, p
end

test(nil)
test(123)
test(1.23)
test('xxxyy')
test(true)
test(false)
test({1, 2, 3})
test({x = 1, y = 2, z = 3})
test({x = 1, y = 2, z = 3, 10000, -1})
test({
    x = {
        1, 2, 3
    },
    y = {
        4, 5, 6
    }
})
test({
    x = {
        x1 = {
            1, 2, 3
        },
        x2 = {
            1, 2, 3
        }
    },
    y = {
        y1 = {
            1, 2, 3
        },
        y2 = {
            1, 2, 3
        }
    }
})
test({
    maximum = {
        x = 29.0652008056640625,
        y = 53.60010147094726562,
        z = 230,
    },
    minimum = {
        x = -29.00760078430175781,
        y = -53.45240020751953125,
        z = 1.41630995273590088,
    },
})

test({ 1, 2, nil, 3, 4, 5, 6, 7, 8 })
do
    local t = {1, 2, 3, 4, 5, 6, 7, 8}
    for i = 1, 5 do
        t[i] = nil
    end
    test(t)
end
do
    local t = {}
    t[5] = 5
    t[4] = 4
    t[3] = 3
    t[1] = 1
    test(t)
end

do
    test {
        [1] = 1,
        [2] = 2,
        [4] = 4,
        [5] = 5,
        x = 1,
        y = 2,
        z = 3,
    }
end

do
    test {
        x = {
            x = {
                x = 1
            }
        }
    }
end

local t = {}
for i = 1, 10000 do
    t[i] = i * 10
    t[i * 10000] = i * 100000000
end
test(t)

local t = {}
t.self = t
test(t)

local largeTable = require 'test.input.mz'
local bin, p = test(largeTable)
print('序列化+反序列化耗时：', p)
print('二进制大小：', #bin / 1024 / 1024, 'MB')

test({
    x = {
        __class__ = 'C1'
    },
    y = {
        __class__ = 'C2'
    },
    z = {
        ok = true,
    },
    s1 = {
        __string__ = '123'
    },
    s2 = {
        __string__ = '321'
    }
}, function (v)
    if v.__class__ then
        return {
            class = v.__class__
        }
    end
    if v.__string__ then
        return v.__string__
    end
end, function (v)
    if type(v) == 'table' then
        return {
            __class__ = v.class
        }
    end
    if type(v) == 'string' then
        return {
            __string__ = v
        }
    end
end)

-- 边界整数
do
    local boundaries = {
        0, 1, 2, 5, 9, 10, 11,
        127, 128, 254, 255, 256,
        65534, 65535, 65536,
        (1 << 24) - 1, (1 << 24), (1 << 24) + 1,
        (1 << 32) - 1, (1 << 32), (1 << 32) + 1,
        -1, -10, -255, -65536, -(1 << 32),
        math.maxinteger, math.mininteger,
    }
    for _, v in ipairs(boundaries) do
        test(v)
    end
    test(boundaries)
end

-- 浮点边界
do
    test(0.0)
    test(-0.0)
    test(1.5)
    test(-1.5)
    test(1e-300)
    test(1e300)
    test(math.pi)
    test(math.huge)
    test(-math.huge)
    -- NaN：util.equal 对 NaN 不一定相等，单独验证
    local nanBin = seri.encode(0/0)
    local nan = seri.decode(nanBin)
    assert(nan ~= nan, 'NaN 反序列化失败')
end

-- 字符串边界长度
do
    test('')
    test('a')      -- Char1
    test('ab')     -- Char2
    test('abc')    -- Str8 (len=3 <= RefStrLen=4，不入 ref)
    test('abcd')   -- Str8 (len=4 <= RefStrLen，不入 ref)
    test('abcde')  -- Str8 (len=5 > RefStrLen，入 ref)
    test(string.rep('x', 255))   -- Str8 上限
    test(string.rep('x', 256))   -- Str16 起点
    test(string.rep('x', 65535)) -- Str16 上限
    test(string.rep('x', 65536)) -- Str32 起点
end

-- 字符串引用复用：同一长字符串多次出现，编码体积应明显小于多份独立长串
do
    local s = string.rep('hello-world', 100)
    local t = { s, s, s, s, s }
    local bin = seri.encode(t)
    local nt = seri.decode(bin)
    assert(util.equal(t, nt))
    -- 体积应远小于 5*#s
    assert(#bin < #s + 200, '字符串复用未生效，bin=' .. #bin .. ' s=' .. #s)
end

-- 短字符串不复用：长度 <= RefStrLen 的不入 refMap
do
    local s = 'abcd' -- len=4
    local t = { s, s, s }
    test(t)
end

-- 空表 / 空数组
do
    test({})
    local nt = seri.decode(seri.encode({}))
    assert(type(nt) == 'table' and next(nt) == nil)
end

-- 多次引用同一子表（共享引用应被还原为同一 table）
do
    local sub = { v = 42 }
    local t = { a = sub, b = sub, c = { sub, sub } }
    local nt = seri.decode(seri.encode(t))
    assert(nt)
    assert(nt.a == nt.b)
    assert(nt.c[1] == nt.c[2])
    assert(nt.a == nt.c[1])
    assert(nt.a.v == 42)
end

-- 复杂循环引用
do
    local a = {}
    local b = { ref = a }
    a.ref = b
    a.self = a
    local nt = seri.decode(seri.encode(a))
    assert(nt)
    assert(nt.self == nt)
    assert(nt.ref.ref == nt)
end

-- 简易表 key-shape 复用：相同 key 集合的多个表
do
    local arr = {}
    for i = 1, 100 do
        arr[i] = { hp = i, mp = i * 2, name = 'unit_' .. i }
    end
    local bin = seri.encode(arr)
    local nt = seri.decode(bin)
    assert(util.equal(arr, nt))
    -- 100 个相同 shape 的表应明显小于不复用
    -- 粗略：每表 3 key + 3 value，复用后只有第一个表带 key 集合
    assert(#bin < 100 * (#'hp' + #'mp' + #'name' + 30), '简易表 shape 复用未生效，#bin=' .. #bin)
end

-- 数组+哈希混合，不同 shape 的混合表
do
    test {
        [1] = 'a',
        [2] = 'b',
        [4] = 'd',  -- 稀疏
        x = 1,
        y = 2,
    }
    test {
        [1] = 1, [2] = 2, [3] = 3,
        x = 'a', y = 'b',
    }
end

-- 含 nil 的数组（中间空洞）
do
    local t = { 1, 2, nil, 4, 5 }
    -- 内层 nil 序列化后会被填充为 Nil；解码后等价表
    local nt = seri.decode(seri.encode(t))
    assert(nt)
    assert(nt[1] == 1 and nt[2] == 2 and nt[3] == nil and nt[4] == 4 and nt[5] == 5)
end

-- 布尔值 / nil 在 table 中
do
    test { true, false, nil, true }
    test { a = true, b = false }
end

-- 负整数 / 浮点 key（bug 1 修复验证）
do
    local t = { [-1] = 'neg1', [-2] = 'neg2' }
    local nt = seri.decode(seri.encode(t))
    assert(nt)
    assert(nt[-1] == 'neg1' and nt[-2] == 'neg2', '负整数 key 丢失')

    local t2 = { [0.5] = 'half', [1.5] = 'one_half' }
    local nt2 = seri.decode(seri.encode(t2))
    assert(nt2)
    assert(nt2[0.5] == 'half' and nt2[1.5] == 'one_half', '浮点 key 丢失')

    -- 混合：负键 + 正键 + 字符串键
    local t3 = { [1] = 'a', [-1] = 'b', x = 'c' }
    local nt3 = seri.decode(seri.encode(t3))
    assert(nt3)
    assert(nt3[1] == 'a' and nt3[-1] == 'b' and nt3.x == 'c', '混合负键表丢失')
end

-- ignoreUnknownType：value 为未知类型时写 Nil 占位，不破坏结构（bug 7 修复验证）
do
    -- 默认应 error
    local t = { x = 1, fn = function () end, y = 2 }
    local ok = pcall(seri.encode, t)
    assert(not ok, '未忽略未知类型时应报错')

    -- 忽略后：fn value → Nil 占位，x/y 正常保留
    local t2 = { x = 1, fn = function () end, y = 2 }
    local bin = seri.encode(t2, nil, true)
    local nt2 = seri.decode(bin)
    assert(nt2)
    assert(nt2.x == 1, 'ignoreUnknownType: x 丢失')
    assert(nt2.y == 2, 'ignoreUnknownType: y 丢失')
    assert(nt2.fn == nil, 'ignoreUnknownType: fn 应为 nil')

    -- 数组中含未知类型 value → Nil 占位，索引不错位
    local t3 = { 10, function () end, 30 }
    local bin3 = seri.encode(t3, nil, true)
    local nt3 = seri.decode(bin3)
    assert(nt3)
    assert(nt3[1] == 10, 'ignoreUnknownType 数组: [1] 丢失')
    assert(nt3[2] == nil, 'ignoreUnknownType 数组: [2] 应为 nil')
    assert(nt3[3] == 30, 'ignoreUnknownType 数组: [3] 丢失')

    -- 未知类型 key → 整对跳过，不写入 nil key
    local co = coroutine.create(function () end)
    local t4 = setmetatable({}, {
        __pairs = function ()
            local data = { { co, 'bad_key_val' }, { 'ok', 'good' } }
            local i = 0
            return function ()
                i = i + 1
                if data[i] then return data[i][1], data[i][2] end
            end
        end
    })
    -- t4 实际上是普通表，直接用 next 不会遍历到 co key，
    -- 改用真实写法：table 本身含 coroutine key
    local t5 = {}
    t5[co] = 'coroutine_val'
    t5['normal'] = 'hi'
    local bin5 = seri.encode(t5, nil, true)
    local nt5 = seri.decode(bin5)
    assert(type(nt5) == 'table')
    -- coroutine key 整对跳过
    assert(nt5['normal'] == 'hi', 'ignoreUnknownType 未知 key 跳过后 normal 丢失')
    local count = 0
    for _ in pairs(nt5) do count = count + 1 end
    assert(count == 1, 'ignoreUnknownType 未知 key 未整对跳过，多余字段 count=' .. count)
end

-- Custom decode 缺 hook 应报错（bug 2 修复验证）
do
    local enc = function (v)
        if v.tag then return { tag = v.tag }, v.tag end
    end
    local bin = seri.encode({ tag = 'x' }, enc)
    -- 不传 hook 解码应 error
    local ok, err = pcall(seri.decode, bin)
    assert(not ok, '缺 hook 解码 Custom 数据应报错')
    assert(type(err) == 'string' and err:find('hook'), 'error 信息应提及 hook，实际：' .. tostring(err))
end

-- 顶层 nil
do
    assert(seri.decode(seri.encode(nil)) == nil)
    assert(seri.decode('') == nil)
end

-- 顶层 boolean / number / string
do
    assert(seri.decode(seri.encode(true)) == true)
    assert(seri.decode(seri.encode(false)) == false)
    assert(seri.decode(seri.encode(0)) == 0)
    assert(seri.decode(seri.encode(-1)) == -1)
    assert(seri.decode(seri.encode('hi')) == 'hi')
end

-- hook：返回 nil 时不走 Custom 路径
do
    local t = { a = 1, b = 2 }
    local hook = function () return nil end
    local nt = seri.decode(seri.encode(t, hook), hook)
    assert(util.equal(t, nt))
end

-- hook：带 tag 区分多种自定义类型
do
    local Vec = { __name = 'Vec' }
    Vec.__index = Vec
    local function newVec(x, y) return setmetatable({ x = x, y = y }, Vec) end

    local Color = { __name = 'Color' }
    Color.__index = Color
    local function newColor(r, g, b) return setmetatable({ r = r, g = g, b = b }, Color) end

    local t = {
        pos = newVec(1, 2),
        col = newColor(255, 128, 0),
        plain = { x = 9 },
    }
    local enc = function (v)
        if getmetatable(v) == Vec then
            return { x = v.x, y = v.y }, 'Vec'
        end
        if getmetatable(v) == Color then
            return { r = v.r, g = v.g, b = v.b }, 'Color'
        end
    end
    local dec = function (v, tag)
        if tag == 'Vec' then return newVec(v.x, v.y) end
        if tag == 'Color' then return newColor(v.r, v.g, v.b) end
        return v
    end
    local nt = seri.decode(seri.encode(t, enc), dec)
    assert(nt)
    assert(getmetatable(nt.pos) == Vec)
    assert(nt.pos.x == 1 and nt.pos.y == 2)
    assert(getmetatable(nt.col) == Color)
    assert(nt.col.r == 255 and nt.col.g == 128 and nt.col.b == 0)
    assert(getmetatable(nt.plain) == nil and nt.plain.x == 9)
end

-- hook 嵌套：自定义值内部含其它自定义值
do
    local enc = function (v)
        if v.tag == 'wrap' then
            return { inner = v.inner }, 'wrap'
        end
    end
    local dec = function (v, tag)
        if tag == 'wrap' then
            return { tag = 'wrap', inner = v.inner }
        end
    end
    local t = { tag = 'wrap', inner = { tag = 'wrap', inner = { value = 1 } } }
    local nt = seri.decode(seri.encode(t, enc), dec)
    assert(nt)
    assert(nt.tag == 'wrap')
    assert(nt.inner.tag == 'wrap')
    assert(nt.inner.inner.value == 1)
end

-- 长度切换边界附近的字符串拼接
do
    local parts = {}
    for i = 1, 1000 do
        parts[i] = string.rep('s' .. (i % 10), i % 7 + 1)
    end
    test(parts)
end

-- 大量数字混合：检测整数压缩与 ref 不冲突
do
    local t = {}
    for i = 1, 1000 do
        t[i] = i
        t['k' .. i] = i * 1.25
    end
    test(t)
end

-- 反复编解码：稳定性
do
    local t = { a = 1, b = { 'x', 'y', { z = true } } }
    local s = seri.encode(t)
    for _ = 1, 5 do
        local nt = seri.decode(s)
        local s2 = seri.encode(nt)
        assert(s == s2, '反复编解码后二进制不稳定')
        s = s2
    end
end

print('序列化测试完成')
