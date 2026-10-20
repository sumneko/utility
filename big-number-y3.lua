---@class BigNumber
---@field [1] number # 尾数：0 或 |值| ∈ [1, 1e9)；指数为 0 时即原值（可为小数）
---@field [2] integer # 十进制指数，值 = 尾数 * 10^指数；规格化时补位到 0 为止，搬移只向上

---@class bigNumberY3 # 大数工具命名空间（针对 y3 运行时：整数为 int64，浮点为定点实现，上限约 2^46）
local M = {}

local MANTISSA_MAX = 1000000000
local PAD_MAX = MANTISSA_MAX / 10
local NUMBER_MAX = 100000000000000
local DIV_SCALE = 9
local FLOAT_SAFE = 1e13

---@type integer[]
local POW10 = {
    1, 10, 100, 1000, 10000, 100000, 1000000, 10000000, 100000000, 1000000000,
    10000000000, 100000000000, 1000000000000, 10000000000000, 100000000000000,
    1000000000000000, 10000000000000000, 100000000000000000, 1000000000000000000,
}

---@param n integer
---@return integer
local function pow10(n)
    local v = POW10[n + 1]
    if not v then
        error('big-number: 10 的幂超出表范围: ' .. tostring(n))
    end
    return v
end

---@param m number
---@param k integer
---@return number
local function scale(m, k)
    -- 强制走浮点：整数尾数乘 pow10 可能超过 int64（如 857385043 * 1e11）
    m = m * 1.0
    while k >= 19 do
        m = m * pow10(18)
        k = k - 18
    end
    while k <= -19 do
        m = m / pow10(18)
        k = k + 18
    end
    if k >= 0 then
        return m * pow10(k)
    end
    return m / pow10(-k)
end

---@param value number
---@return integer
local function signOf(value)
    if value > 0 then
        return 1
    end
    if value < 0 then
        return -1
    end
    return 0
end

---@param value number
---@return integer
local function truncDiv10(value)
    local half
    if value >= 0 then
        half = value // 10
    else
        half = -((-value) // 10)
    end
    return math.tointeger(half) or half
end

---@param big BigNumber
---@return integer
---@return integer
local function asIntegerParts(big)
    local m = big[1]
    local e = big[2]
    local i = math.tointeger(m)
    if i then
        return i, e
    end
    -- 放大到整数为止，但不超过 |1e9|（保证整数乘法/长除法的中间量安全）
    while m < MANTISSA_MAX and m > -MANTISSA_MAX do
        m = m * 10
        e = e - 1
        if m % 1 == 0 then
            return math.floor(m + 0.5), e
        end
    end
    return math.floor(m + 0.5), e
end

---@param a BigNumber
---@param b BigNumber
---@return BigNumber
---@return BigNumber
local function align(a, b)
    if a[2] >= b[2] then
        return a, b
    end
    return b, a
end

---@type table<number | string | BigNumber, BigNumber>
local CACHE

-- 前向声明：交给下面的构造函数赋值
local fromNumber, fromString, format

---@param _ table
---@param key number | string | BigNumber
---@return BigNumber
local function buildAndCacheBigNumber(_, key)
    if type(key) == 'table' then
        ---@cast key BigNumber
        CACHE[key] = key
        return key
    end
    local big
    if type(key) == 'string' then
        big = fromString(key)
    else
        ---@cast key number
        big = fromNumber(key)
    end
    CACHE[key] = big
    return big
end

CACHE = setmetatable({}, { __mode = 'kv', __index = buildAndCacheBigNumber })

---@param mantissa number
---@param exp integer
---@return BigNumber
local function wrap(mantissa, exp)
    return setmetatable({ mantissa, exp }, M)
end

---宽容收参：数值 / 十进制字符串 / 大数一律查缓存（缺失由 `__index` 构造或原样写回）
---@param value number | string | BigNumber
---@return BigNumber
local function of(value)
    return CACHE[value]
end

---@return BigNumber
local function zero()
    return wrap(0, 0)
end

---@param big BigNumber
---@return boolean
local function isZero(big)
    return big[1] == 0
end

---规格化（内部运算专用，不做入参校验）
---@param m number
---@param e integer
---@return BigNumber
local function rebuild(m, e)
    if m == 0 then
        return wrap(0, 0)
    end
    while e > 0 and m >= -PAD_MAX and m <= PAD_MAX do
        m = m * 10
        e = e - 1
    end
    if m >= MANTISSA_MAX or m <= -MANTISSA_MAX then
        local i = math.tointeger(m)
        if i then
            local magnitude = i
            if i < 0 then
                -- mininteger 取负会溢出，用 maxinteger 代替（除以 1e10 后结果相同）
                magnitude = i == math.mininteger and math.maxinteger or -i
            end
            local drop = 1
            while drop < 10 and magnitude >= POW10[drop + 10] do
                drop = drop + 1
            end
            m = magnitude // POW10[drop + 1]
            if i < 0 then
                m = -m
            end
            e = e + drop
        else
            while m >= MANTISSA_MAX or m <= -MANTISSA_MAX do
                m = truncDiv10(m)
                e = e + 1
            end
        end
    end
    return wrap(m, e)
end

---规格化（入参校验 + 归一化）
---@param big BigNumber
---@return BigNumber
local function normalize(big)
    local m = big[1]
    if m ~= m or m == math.huge or m == -math.huge then
        error('big-number: 尾数不是有限数: ' .. tostring(m))
    end
    if m == 0 then
        return wrap(0, 0)
    end
    local e = big[2]
    if e ~= math.floor(e) or e > 1e15 or e < -1e15 then
        error('big-number: 指数必须是范围内的整数: ' .. tostring(e))
    end
    return rebuild(m, math.tointeger(e) or e)
end

---由普通数值构造（|n| < 1e9 时尾数即原值、指数 0）
---@param n number
---@return BigNumber
fromNumber = function(n)
    return normalize({ n, 0 })
end

---由尾数 + 指数构造
---@param mantissa number
---@param exp integer
---@return BigNumber
local function fromParts(mantissa, exp)
    return normalize({ mantissa, exp })
end

---由十进制字符串构造（支持正负号 / 小数 / e、E 指数）
---@param text string
---@return BigNumber
fromString = function(text)
    local sign, intPart, fracPart, expPart = text:match('^%s*([+-]?)(%d*)(%.?%d*)([eE]?[+-]?%d*)%s*$')
    if not sign then
        error('big-number: 不是合法的十进制字符串: ' .. tostring(text))
    end
    local frac = fracPart:gsub('%.', '')
    local digits = intPart .. frac
    if digits == '' then
        error('big-number: 不是合法的十进制字符串: ' .. tostring(text))
    end
    local value = tonumber(digits)
    local exp = math.floor((tonumber((expPart:gsub('[eE]', ''))) or 0) - #frac)
    if sign == '-' then
        value = -value
    end
    return normalize({ value, exp })
end

---@param a BigNumber
---@param b BigNumber
---@return BigNumber
local function add(a, b)
    if isZero(a) then
        return b
    end
    if isZero(b) then
        return a
    end
    local big, small = align(a, b)
    local diff = big[2] - small[2]
    if diff == 0 then
        return rebuild(big[1] + small[1], big[2])
    end
    if diff >= DIV_SCALE * 2 then
        return big
    end
    local drop = small[1] / pow10(diff)
    if math.abs(drop) < 0.5 then
        return big
    end
    return rebuild(big[1] + drop, big[2])
end

---@param a BigNumber
---@param b BigNumber
---@return BigNumber
local function sub(a, b)
    local am, bm = a[1], b[1]
    if bm == 0 then
        return a
    end
    if am == 0 then
        return wrap(-bm, b[2])
    end
    local ae, be = a[2], b[2]
    local diff = ae - be
    if diff == 0 then
        return rebuild(am - bm, ae)
    end
    if diff > 0 then
        if diff >= DIV_SCALE * 2 then
            return a
        end
        local drop = bm / pow10(diff)
        if math.abs(drop) < 0.5 then
            return a
        end
        return rebuild(am - drop, ae)
    end
    if diff <= -DIV_SCALE * 2 then
        return wrap(-bm, be)
    end
    local drop = am / pow10(-diff)
    if math.abs(drop) < 0.5 then
        return wrap(-bm, be)
    end
    return rebuild(drop - bm, be)
end

---@param a BigNumber
---@param b BigNumber
---@return BigNumber
local function mul(a, b)
    if isZero(a) or isZero(b) then
        return zero()
    end
    local am, bm = a[1], b[1]
    -- 快路径：乘积落在安全量级内直接浮点相乘（定点浮点饱和后约 7e13，护栏取 1e13）
    local product = am * bm
    if product < FLOAT_SAFE and product > -FLOAT_SAFE then
        if product >= MANTISSA_MAX / 10 or product <= -MANTISSA_MAX / 10 then
            -- 已占满 9 位有效数字，小数部分只会是浮点噪尾
            product = product >= 0 and math.floor(product) or -math.floor(-product)
        end
        return rebuild(product, a[2] + b[2])
    end
    local ai, bi = math.tointeger(am), math.tointeger(bm)
    if ai and bi then
        -- 整数尾数：乘积 < 1e18，int64 精确
        return rebuild(ai * bi, a[2] + b[2])
    end
    -- 小数尾数且乘积超大：展开成整数并压回 < 1e9，乘积同样 < 1e18
    -- （定点运行时浮点上限约 2^46，超量级时不能用浮点乘法）
    local x, xe = asIntegerParts(a)
    local y, ye = asIntegerParts(b)
    while x >= MANTISSA_MAX or x <= -MANTISSA_MAX do
        x = truncDiv10(x)
        xe = xe + 1
    end
    while y >= MANTISSA_MAX or y <= -MANTISSA_MAX do
        y = truncDiv10(y)
        ye = ye + 1
    end
    return rebuild(x * y, xe + ye)
end

---@param a BigNumber
---@param b BigNumber
---@return BigNumber
local function div(a, b)
    if isZero(b) then
        error('big-number: 除数为零')
    end
    if isZero(a) then
        return zero()
    end
    local am, ae = asIntegerParts(a)
    local bm, be = asIntegerParts(b)
    local negative = (am < 0) ~= (bm < 0)
    am, bm = math.abs(am), math.abs(bm)
    while am >= MANTISSA_MAX do
        am = truncDiv10(am)
        ae = ae + 1
    end
    while bm >= MANTISSA_MAX do
        bm = truncDiv10(bm)
        be = be + 1
    end
    -- 一次除法直接得到 DIV_SCALE 位小数（am < 1e9，乘 1e9 后 < 1e18，int64 安全）
    local q = am * pow10(DIV_SCALE) // bm
    if negative then
        q = -q
    end
    return rebuild(q, ae - be - DIV_SCALE)
end

---@param a BigNumber
---@return BigNumber
local function neg(a)
    return wrap(-a[1], a[2])
end

---@param a BigNumber
---@return BigNumber
local function abs(a)
    if a[1] < 0 then
        return neg(a)
    end
    return a
end

---@param a BigNumber
---@param b BigNumber
---@return integer
local function compare(a, b)
    local am, bm = a[1], b[1]
    local sa, sb = signOf(am), signOf(bm)
    if sa ~= sb then
        return signOf(sa - sb)
    end
    if sa == 0 then
        return 0
    end
    local d = a[2] - b[2]
    if d == 0 then
        return signOf(am - bm)
    end
    -- 先试算：量级不大时对齐后直接比，避免展开小数尾数
    if d > 0 then
        if d <= 8 then
            local scaled = am * pow10(d)
            if scaled < FLOAT_SAFE and scaled > -FLOAT_SAFE then
                return signOf(scaled - bm)
            end
        end
    elseif d >= -8 then
        local scaled = bm * pow10(-d)
        if scaled < FLOAT_SAFE and scaled > -FLOAT_SAFE then
            return signOf(am - scaled)
        end
    end
    -- 尾数可能带小数（如 12.5 与 125000000e-7），统一展开成整数再比
    local x, xe = asIntegerParts(a)
    local y, ye = asIntegerParts(b)
    while x >= MANTISSA_MAX or x <= -MANTISSA_MAX do
        x = truncDiv10(x)
        xe = xe + 1
    end
    while y >= MANTISSA_MAX or y <= -MANTISSA_MAX do
        y = truncDiv10(y)
        ye = ye + 1
    end
    local diff = xe - ye
    if diff >= 9 then
        return sa
    end
    if diff <= -9 then
        return -sa
    end
    if diff > 0 then
        return signOf(x * pow10(diff) - y)
    end
    return signOf(x - y * pow10(-diff))
end

---按百分比缩放（percent 为 0~100 的普通数值）
---@param big BigNumber
---@param percent number
---@return BigNumber
local function mulRatio(big, percent)
    return div(mul(big, of(percent)), of(100))
end

---除以整数
---@param big BigNumber
---@param n integer
---@return BigNumber
local function divInt(big, n)
    return div(big, of(n))
end

---按数值向上取整
---@param big BigNumber
---@return BigNumber
local function ceil(big)
    local mantissa, exp = big[1], big[2]
    if exp >= 0 then
        local value = math.ceil(mantissa)
        if value == mantissa then
            return big
        end
        return rebuild(value, exp)
    end
    return rebuild(math.ceil(scale(mantissa, exp)), 0)
end

---@param big BigNumber
---@return integer
local function powerOf(big)
    local m = math.abs(big[1])
    local n = 0
    while m >= 1 do
        m = truncDiv10(m)
        n = n + 1
    end
    return big[2] + n - 1
end

---转普通数值（仅 |值| < 1e14 允许，超出直接报错）
---@param big BigNumber
---@return number
local function toNumber(big)
    if isZero(big) then
        return 0
    end
    if big[2] >= 15 or big[2] <= -15 then
        error('big-number: 超出可转普通数值的范围: ' .. format(big))
    end
    local m = big[1]
    local e = big[2]
    local i = math.tointeger(m)
    if i then
        if e >= 0 then
            -- 整数尾数：用整数比较上界后走整数乘法（定点运行时大数浮点除会饱和）
            local p = pow10(e)
            if math.abs(i) >= (NUMBER_MAX + p - 1) // p then
                error('big-number: 超出可转普通数值的范围: ' .. format(big))
            end
            return i * p
        end
        local value = scale(m, e)
        return math.tointeger(value) or value
    end
    if powerOf(big) >= 14 then
        error('big-number: 超出可转普通数值的范围: ' .. format(big))
    end
    local value = scale(m, e)
    if value >= NUMBER_MAX or value <= -NUMBER_MAX then
        error('big-number: 超出可转普通数值的范围: ' .. format(big))
    end
    return math.tointeger(value) or value
end

---比值转普通数值（0~1 的小数：量级再小也直接按浮点返回，不触发「超出可转范围」的报错）
---@param big BigNumber
---@return number
local function toRatio(big)
    if isZero(big) then
        return 0
    end
    return scale(big[1], big[2])
end

---@type table<integer, string>
local UNITS = {
    [4] = '万', [8] = '亿', [12] = '兆', [16] = '京', [20] = '垓', [24] = '秭',
    [28] = '穰', [32] = '沟', [36] = '涧', [40] = '正', [44] = '载', [48] = '极',
}

---小数量级直出：整数照旧，非整数保留小数并去掉末尾 0
---@param big BigNumber
---@return string
local function renderFixed(big)
    local value = scale(big[1], big[2])
    local i = math.tointeger(value)
    if i then
        return string.format('%d', i)
    end
    local text = string.format('%.9f', value)
    text = text:gsub('0+$', '')
    text = text:gsub('%.$', '')
    if text == '0' or text == '-' or text == '-0' then
        return string.format('%.9g', value)
    end
    return text
end

---@param big BigNumber
---@param decimals integer
---@return string
local function render(big, decimals)
    local power = powerOf(big)
    if power < 4 then
        return renderFixed(big)
    end
    local unitPower = power - (power % 4)
    local unit = UNITS[unitPower]
    if unit then
        return string.format('%.' .. decimals .. 'f%s', scale(big[1], big[2] - unitPower), unit)
    end
    local digits = power - big[2] + 1
    return string.format('%.' .. decimals .. 'fe+%d', scale(big[1], -(digits - 1)), power)
end

---完整格式化（< 1e4 直出整数，否则折十进制数量级、保留 2 位小数）
---@param big BigNumber
---@return string
format = function(big)
    if isZero(big) then
        return '0'
    end
    return render(big, 2)
end

---跳字用短格式（< 1e4 直出整数，否则保留 1 位小数）
---@param big BigNumber
---@return string
local function formatShort(big)
    if isZero(big) then
        return '0'
    end
    return render(big, 1)
end

-- 对外 API
M.fromNumber = fromNumber
M.fromParts = fromParts
M.fromString = fromString
M.of = of
M.zero = zero
M.isZero = isZero
M.normalize = normalize
M.add = add
M.sub = sub
M.mul = mul
M.div = div
M.neg = neg
M.abs = abs
M.cmp = compare
M.mulRatio = mulRatio
M.divInt = divInt
M.ceil = ceil
M.toNumber = toNumber
M.toRatio = toRatio
M.format = format
M.formatShort = formatShort

-- 元方法
M.__add = function(a, b)
    return add(of(a), of(b))
end

M.__sub = function(a, b)
    return sub(of(a), of(b))
end

M.__mul = function(a, b)
    return mul(of(a), of(b))
end

M.__div = function(a, b)
    return div(of(a), of(b))
end

M.__unm = function(a)
    return neg(of(a))
end

M.__lt = function(a, b)
    -- 比较运算可能混入普通数值，此时才走收参
    if type(a) ~= 'table' then
        a = of(a)
    end
    if type(b) ~= 'table' then
        b = of(b)
    end
    local am, bm = a[1], b[1]
    local sa, sb = signOf(am), signOf(bm)
    if sa ~= sb then
        return sa < sb
    end
    if sa == 0 then
        return false
    end
    if a[2] == b[2] then
        return am < bm
    end
    return compare(a, b) < 0
end

M.__le = function(a, b)
    if type(a) ~= 'table' then
        a = of(a)
    end
    if type(b) ~= 'table' then
        b = of(b)
    end
    local am, bm = a[1], b[1]
    local sa, sb = signOf(am), signOf(bm)
    if sa ~= sb then
        return sa < sb
    end
    if sa == 0 then
        return true
    end
    if a[2] == b[2] then
        return am <= bm
    end
    return compare(a, b) <= 0
end

M.__eq = function(a, b)
    local am, bm = a[1], b[1]
    if am == bm then
        return am == 0 or a[2] == b[2]
    end
    if am == 0 or bm == 0 then
        return false
    end
    return compare(a, b) == 0
end

M.__tostring = function(a)
    return format(a)
end

return M
