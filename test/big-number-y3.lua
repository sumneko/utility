local big = require 'big-number-y3'
local B = big.of

-- 定点运行时（Fix32）浮点上限约 2^46，做不到 IEEE 754 double 的量级
local FLOAT64 = 1e300 > 1e100

-- 构造与规格化
do
    local v = big.fromNumber(123)
    assert(v[1] == 123 and v[2] == 0)

    local v = big.fromNumber(1000000000)
    assert(v[1] == 100000000 and v[2] == 1)

    local v = big.fromNumber(-1234567890)
    assert(v[1] == -123456789 and v[2] == 1)

    local v = big.fromNumber(0)
    assert(v[1] == 0 and v[2] == 0)

    local v = big.fromParts(1, 9)
    assert(v[1] == 100000000 and v[2] == 1)

    local v = big.fromParts(1.5, 3)
    assert(v[1] == 1500 and v[2] == 0)

    local v = big.fromParts(0, 99)
    assert(v[1] == 0 and v[2] == 0)

    local v = big.fromString('  +1.23e5  ')
    assert(v[1] == 123000 and v[2] == 0)

    local v = big.fromString('-0.5')
    assert(v[1] == -5 and v[2] == -1)

    local v = big.fromString('.5')
    assert(v[1] == 5 and v[2] == -1)

    local v = big.fromString('5.')
    assert(v[1] == 5 and v[2] == 0)

    local v = big.fromString('1E3')
    assert(v[1] == 1000 and v[2] == 0)

    assert(big.isZero(big.zero()))
    assert(not big.isZero(big.fromNumber(1)))

    -- 边界：mininteger 尾数取负会溢出，仍须保持符号
    local v = big.fromParts(math.mininteger, 0)
    assert(v[1] == -922337203 and v[2] == 10)
    local v = big.fromParts(math.maxinteger, 0)
    assert(v[1] == 922337203 and v[2] == 10)
end

-- 缓存收参：同一 key 复用同一对象，大数原样写回
do
    local a = big.of(42)
    assert(rawequal(a, big.of(42)))
    assert(rawequal(a, big.of(a)))
    assert(rawequal(big.of('1.5'), big.of('1.5')))
    assert(big.toNumber(big.of('1.5')) == 1.5)
    assert(big.toNumber(big.of(0)) == 0)
end

-- 四则运算
do
    local function num(v)
        return big.toNumber(v)
    end

    assert(num(big.add(B(1), B(2))) == 3)
    assert(num(big.add(big.of(-1), big.of(-2))) == -3)
    assert(num(big.sub(big.of(3), big.of(5))) == -2)
    assert(num(big.mul(big.of(4), big.of(25))) == 100)
    assert(num(big.mul(big.of(-4), big.of(25))) == -100)
    assert(num(big.div(big.of(100), big.of(4))) == 25)
    assert(num(big.neg(big.of(7))) == -7)
    assert(num(big.abs(big.of(-7))) == 7)
    assert(num(big.abs(big.of(7))) == 7)

    -- 小刻度直接丢弃，不进位
    assert(num(big.add(big.of(1000000000), big.of(1))) == 1000000000)
    assert(num(big.add(big.of(500000000), big.of(500000000))) == 1000000000)

    -- 除法保留 9 位小数
    assert(big.toRatio(big.div(big.of(1), big.of(3))) == 0.333333333)
    assert(big.toRatio(big.div(big.of(-1000), big.of(24))) == -41.6666666)

    -- 尾数极小的除数也要能正确取整
    assert(big.format(big.div(big.of(1), big.fromParts(1, -10))) == '100.00亿')
    assert(big.format(big.div(big.of(1), big.fromParts(1, -15))) == '1000.00兆')

    -- 整数除法 / 百分比
    assert(num(big.divInt(big.of(100), 8)) == 12.5)
    assert(num(big.mulRatio(big.of(200), 15)) == 30)
    assert(num(big.mulRatio(big.of(-200), 15)) == -30)
    assert(num(big.mulRatio(big.of(100000000), 50)) == 50000000)

    -- 零的加法直接返回另一侧原对象
    assert(rawequal(big.add(big.zero(), big.of(5)), big.of(5)))
    assert(rawequal(big.add(big.of(5), big.zero()), big.of(5)))
    assert(big.isZero(big.mul(big.zero(), big.of(5))))
    assert(big.isZero(big.div(big.zero(), big.of(5))))
end

-- 大数乘法与回除
do
    local v = big.mul(big.of('123456789'), big.of('987654321'))
    assert(v[1] == 121932631 and v[2] == 9)
    assert(big.format(v) == '12.19京')
    assert(big.formatShort(v) == '12.2京')

    -- 尾数只有 9 位有效数字，回除存在末位误差
    local back = big.toNumber(big.div(v, big.of('987654321')))
    assert(math.abs(back - 123456789) <= 2)

    assert(big.format(big.mul(big.fromString('1e20'), big.fromString('1e20'))) == '1.00正')
    assert(big.format(big.mul(big.fromString('1e40'), big.fromString('1e40'))) == '1.00e+80')
    assert(big.format(big.mul(big.fromString('1e300'), big.fromString('1e300'))) == '1.00e+600')
    -- 尾数带小数残渣时内部放大到 1e11 量级，旧实现会撑爆 int64
    assert(big.format(big.mul(big.fromNumber(611.1000000252), big.fromNumber(614000000))) == '3752.15亿')
    -- 小数尾数 × 大整数尾数：浮点直乘在定点运行时会饱和（2^46）
    assert(big.format(big.mul(big.fromNumber(99999999.5), big.of(999999999))) == '10.00京')

    -- ×1.01：百分比类乘法的常见形态
    assert(big.toNumber(big.mul(big.fromString('100000000'), big.of(1.01))) == 101000000)
    assert(big.format(big.mul(big.fromString('123456789'), big.of(1.01))) == '1.25亿')
    assert(big.format(big.mul(big.fromString('1000000000000'), big.of(1.01))) == '1.01兆')

    -- 1正 = 1e40
    assert(big.format(big.mul(big.fromString('1e40'), big.of(1.01))) == '1.01正')
    assert(big.format(big.div(big.fromString('1e40'), big.of(1.01))) == '9900.99涧')
end

-- 比较
do
    assert(big.cmp(big.of(2), big.of(1)) == 1)
    assert(big.cmp(big.of(1), big.of(2)) == -1)
    assert(big.cmp(big.of(1), big.of(1)) == 0)
    assert(big.cmp(big.of(1), big.of(1000)) == -1)
    assert(big.cmp(big.of(-1), big.of(1)) == -1)
    assert(big.cmp(big.zero(), big.zero()) == 0)
    assert(big.cmp(big.fromParts(1, 5), big.fromParts(9, 2)) == 1)
    assert(big.cmp(big.fromParts(-1, 5), big.fromParts(-9, 2)) == -1)
    assert(big.cmp(big.fromParts(1, 20), big.fromParts(5, 2)) == 1)
end

-- 转换
do
    assert(big.toNumber(big.zero()) == 0)
    assert(big.toNumber(big.of(1000000)) == 1000000)
    assert(big.toNumber(big.of('0.125')) == 0.125)
    -- 超过 9 位有效数字的部分被截断
    assert(big.toNumber(big.fromString('99999999999999')) == 99999999900000)

    assert(big.toRatio(big.of(1)) == 1)
    if FLOAT64 then
        assert(big.toRatio(big.fromString('1e-15')) == 1e-15)
    end
    assert(big.toRatio(big.div(big.of(1), big.of(3))) == 0.333333333)
    -- 整数尾数乘 1e11 会超出 int64（定点运行时浮点饱和，只验证不为负）
    local ratio = big.toRatio(big.fromParts(857385043, 11))
    assert(ratio > 0)
    if FLOAT64 then
        assert(ratio == 8.57385043e19)
    end

    assert(not pcall(big.toNumber, big.fromString('1e14')))
    assert(not pcall(big.toNumber, big.fromString('1e15')))
    assert(not pcall(big.toNumber, big.fromString('1e-15')))
end

-- 向上取整：按数值，不是只取尾数
do
    assert(big.toNumber(big.ceil(big.of(12.5))) == 13)
    assert(big.toNumber(big.ceil(big.of(-12.5))) == -12)
    assert(big.toNumber(big.ceil(big.zero())) == 0)
    assert(rawequal(big.ceil(big.of(28)), big.of(28)))

    -- 乘区除法产物指数为负，尾数本身已是整数
    assert(big.toNumber(big.ceil(big.div(big.mul(big.of(100), big.of(100)), big.of(350)))) == 29)
    assert(big.toNumber(big.ceil(big.fromParts(285714285, -7))) == 29)
    local v = big.fromParts(285714285, 9)
    assert(rawequal(big.ceil(v), v))
    local w = big.div(big.mul(big.fromString('1e18'), big.of(100)), big.of(350))
    assert(rawequal(big.ceil(w), w))
end

-- 格式化
do
    assert(big.format(big.zero()) == '0')
    assert(big.format(big.fromNumber(9999)) == '9999')
    assert(big.format(big.fromNumber(1.5)) == '1.5')
    assert(big.format(big.fromNumber(-0.5)) == '-0.5')
    assert(big.format(big.fromNumber(0.125)) == '0.125')
    assert(big.formatShort(big.fromNumber(1.5)) == '1.5')
    if FLOAT64 then
        assert(big.format(big.fromParts(1, -10)) == '1e-10')
    end
    assert(big.format(big.fromNumber(10000)) == '1.00万')
    assert(big.formatShort(big.fromNumber(12345)) == '1.2万')
    assert(big.format(big.fromNumber(123456789)) == '1.23亿')
    assert(big.format(big.fromString('1e12')) == '1.00兆')
    assert(big.format(big.fromString('1e16')) == '1.00京')
    assert(big.format(big.fromString('1e20')) == '1.00垓')
    assert(big.format(big.fromString('1e48')) == '1.00极')
    assert(big.format(big.fromString('1e52')) == '1.00e+52')
    assert(big.formatShort(big.fromString('1e52')) == '1.0e+52')
    assert(big.format(big.fromString('12345')) == '1.23万')
    assert(big.format(big.fromNumber(-12345)) == '-1.23万')
    assert(big.format(big.add(big.of(999999999), big.of(1))) == '10.00亿')
end

-- 元方法
do
    assert(tostring(big.of(1000) + big.of(24)) == '1024')
    assert(tostring(big.of(1000) - big.of(24)) == '976')
    assert(tostring(big.of(1000) * big.of(24)) == '2.40万')
    assert(tostring(big.of(1000) / big.of(24)) == '41.6666666')
    assert(tostring(-big.of(1000)) == '-1000')

    -- 混合数值/字符串参与运算
    assert(tostring(big.of(1000) + 24) == '1024')
    assert(tostring(big.of(1000) - '24') == '976')
    assert(big.toNumber(big.of(1) + big.of(2) + big.of(3)) == 6)
    assert(big.toNumber(big.of(1) * 2 + 3) == 5)

    assert(big.of(1) < big.of(2))
    assert(not (big.of(2) < big.of(1)))
    assert(big.of(2) <= big.of(2))
    assert(big.of(1) < 2)
    assert(2 > big.of(1))
    assert(big.of('1e9') == big.of(1000000000))
    -- 同一数值的不同表示：12.5 与 100/8 的尾数/指数不同
    assert(big.of(12.5) == big.divInt(big.of(100), 8))
    assert(big.of(0.5) == big.of('0.5'))
    assert(not (big.of(12.5) == big.of(12.500001)))
    assert(big.cmp(big.of(12.5), big.divInt(big.of(100), 8)) == 0)
    assert(not (big.of(12.5) < big.divInt(big.of(100), 8)))
    assert(big.of(12.5) <= big.divInt(big.of(100), 8))
    assert(big.of(12.5) ~= big.of(12.6))

    -- 幂 / 整除 / 取模
    assert(big.toNumber(big.of(10) // big.of(3)) == 3)
    assert(big.toNumber(big.of(-10) // big.of(3)) == -4)
    assert(big.toNumber(big.of(10) % big.of(3)) == 1)
    assert(big.toNumber(big.of(-10) % big.of(3)) == 2)
    assert(big.toNumber(big.of(10) % big.of(-3)) == -2)
    assert(big.toNumber(big.of(2) ^ 10) == 1024)
    assert(big.toNumber(2 ^ big.of(10)) == 1024)
    assert(big.toNumber(big.of(2) ^ -2) == 0.25)
    assert(big.toNumber(big.of('1.5') ^ 3) == 3.375)
    assert(big.toNumber(big.of(0) ^ 0) == 1)
    assert(big.format(big.of(100) ^ 3) == '100.00万')
    assert(big.toNumber(big.floor(big.of('28.57'))) == 28)
    assert(big.toNumber(big.floor(big.of('-28.57'))) == -29)
    -- 非整数指数：a^b = 10^(b * log10(a))
    local sqrt2 = big.toNumber(big.of(2) ^ big.of('0.5'))
    assert(math.abs(sqrt2 - 1.4142135624) < 1e-8)
    local sqrt4 = big.toNumber(big.of(4) ^ big.of('0.5'))
    assert(math.abs(sqrt4 - 2) < 1e-8)
    assert(big.toNumber(big.of(100) ^ big.of('1.5')) == 1000)
    assert(big.format(big.of('1e100') ^ big.of('0.5')) == '100.00极')
    assert(big.toNumber(big.of(0) ^ big.of('0.5')) == 0)
    assert(not pcall(function() return big.of(0) ^ big.of('-0.5') end))
    assert(not pcall(function() return big.of(-2) ^ big.of('0.5') end))
    assert(not pcall(function() return big.of(1) % big.of(0) end))
    assert(not pcall(function() return big.of(1) // big.of(0) end))
    assert(big.of(1) ~= big.of(2))
    -- __eq 只对两侧都是大数生效
    assert(not (big.of(1) == 1))
end

-- 错误路径
do
    assert(not pcall(big.div, big.of(1), big.zero()))
    assert(not pcall(big.div, big.of(1), big.of(0)))
    assert(not pcall(big.fromString, 'abc'))
    assert(not pcall(big.fromString, ''))
    assert(not pcall(big.fromString, '1.2.3'))

    -- 非有限尾数 / 越界指数必须报错，不能死循环（定点运行时没有 inf/NaN，无法构造）
    if FLOAT64 then
        assert(not pcall(function() return big.fromNumber(1 / 0) end))
        assert(not pcall(function() return big.fromNumber(0 / 0) end))
        assert(not pcall(function() return big.fromParts(1, 0 / 0) end))
        assert(not pcall(big.fromString, ('9'):rep(400)))
        assert(not pcall(big.fromParts, 1, 1e24))
    end
end
