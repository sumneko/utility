---@class BigNumber
---@field [1] number # 尾数：0 或 |值| ∈ [1, 1e9)；指数为 0 时即原值（可为小数）
---@field [2] integer # 十进制指数，值 = 尾数 * 10^指数；规格化时补位到 0 为止，搬移只向上

---@class bigNumberY3 # 大数工具命名空间（针对 y3 运行时：整数为 int64，浮点为定点实现，上限约 2^46）
local M = {}

local MANTISSA_MAX = 1000000000
local NUMBER_MAX = 100000000000000
local DIV_SCALE = 9
local CMP_SCALE = 3

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
        i = math.tointeger(m)
        if i then
            return i, e
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
        big = M.fromString(key)
    else
        ---@cast key number
        big = M.fromNumber(key)
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

---由普通数值构造（|n| < 1e9 时尾数即原值、指数 0）
---@param n number
---@return BigNumber
function M.fromNumber(n)
    return M.normalize({ n, 0 })
end

---由尾数 + 指数构造
---@param mantissa number
---@param exp integer
---@return BigNumber
function M.fromParts(mantissa, exp)
    return M.normalize({ mantissa, exp })
end

---由十进制字符串构造（支持正负号 / 小数 / e、E 指数）
---@param text string
---@return BigNumber
function M.fromString(text)
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
    return M.normalize({ value, exp })
end

---宽容收参：数值 / 十进制字符串 / 大数一律查缓存（缺失由 `__index` 构造或原样写回）
---@param value number | string | BigNumber
---@return BigNumber
function M.of(value)
    return CACHE[value]
end

---@return BigNumber
function M.zero()
    return wrap(0, 0)
end

---@param big BigNumber
---@return boolean
function M.isZero(big)
    return big[1] == 0
end

---规格化：指数 > 0 时先把尾数补位到最细刻度（指数降到 0 为止），再在 |尾数| ≥ 1e9 时逐位右移
---@param big BigNumber
---@return BigNumber
function M.normalize(big)
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
    e = math.tointeger(e) or e
    while e > 0 and m >= -MANTISSA_MAX / 10 and m <= MANTISSA_MAX / 10 do
        m = m * 10
        e = e - 1
    end
    while m >= MANTISSA_MAX or m <= -MANTISSA_MAX do
        m = truncDiv10(m)
        e = e + 1
    end
    return wrap(m, e)
end

---@param a BigNumber
---@param b BigNumber
---@return BigNumber
function M.add(a, b)
    if M.isZero(a) then
        return b
    end
    if M.isZero(b) then
        return a
    end
    local big, small = align(a, b)
    local diff = big[2] - small[2]
    if diff == 0 then
        return M.normalize({ big[1] + small[1], big[2] })
    end
    if diff >= DIV_SCALE * 2 then
        return big
    end
    local drop = small[1] / pow10(diff)
    if math.abs(drop) < 0.5 then
        return big
    end
    return M.normalize({ big[1] + drop, big[2] })
end

---@param a BigNumber
---@param b BigNumber
---@return BigNumber
function M.sub(a, b)
    return M.add(a, M.neg(b))
end

---@param a BigNumber
---@param b BigNumber
---@return BigNumber
function M.mul(a, b)
    if M.isZero(a) or M.isZero(b) then
        return M.zero()
    end
    local am, bm = a[1], b[1]
    local ai, bi = math.tointeger(am), math.tointeger(bm)
    if ai and bi then
        -- 整数尾数：乘积 < 1e18，int64 精确
        return M.normalize({ ai * bi, a[2] + b[2] })
    end
    -- 小数尾数：展开成整数并压回 < 1e9，乘积同样 < 1e18
    -- （定点运行时浮点上限约 2^46，不能直接做浮点乘法）
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
    return M.normalize({ x * y, xe + ye })
end

---@param a BigNumber
---@param b BigNumber
---@return BigNumber
function M.div(a, b)
    if M.isZero(b) then
        error('big-number: 除数为零')
    end
    if M.isZero(a) then
        return M.zero()
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
    ---@type number
    local q = am // bm
    local r = am % bm
    for _ = 1, DIV_SCALE do
        r = r * 10
        q = q * 10 + r // bm
        r = r % bm
    end
    if negative then
        q = -q
    end
    return M.normalize({ q, ae - be - DIV_SCALE })
end

---@param a BigNumber
---@return BigNumber
function M.neg(a)
    return wrap(-a[1], a[2])
end

---@param a BigNumber
---@return BigNumber
function M.abs(a)
    if a[1] < 0 then
        return M.neg(a)
    end
    return a
end

---@param a BigNumber
---@param b BigNumber
---@return integer
function M.cmp(a, b)
    local sa, sb = signOf(a[1]), signOf(b[1])
    if sa ~= sb then
        return signOf(sa - sb)
    end
    if sa == 0 then
        return 0
    end
    local diff = a[2] - b[2]
    if diff >= CMP_SCALE then
        return sa
    end
    if diff <= -CMP_SCALE then
        return -sa
    end
    if diff >= 0 then
        return signOf(a[1] * pow10(diff) - b[1])
    end
    return signOf(a[1] - b[1] * pow10(-diff))
end

---按百分比缩放（percent 为 0~100 的普通数值）
---@param big BigNumber
---@param percent number
---@return BigNumber
function M.mulRatio(big, percent)
    return M.div(M.mul(big, M.fromNumber(percent)), M.fromNumber(100))
end

---除以整数
---@param big BigNumber
---@param n integer
---@return BigNumber
function M.divInt(big, n)
    return M.div(big, M.fromNumber(n))
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
function M.toNumber(big)
    if M.isZero(big) then
        return 0
    end
    if big[2] >= 15 or big[2] <= -15 then
        error('big-number: 超出可转普通数值的范围: ' .. M.format(big))
    end
    if powerOf(big) >= 14 then
        error('big-number: 超出可转普通数值的范围: ' .. M.format(big))
    end
    local m = big[1]
    local e = big[2]
    local i = math.tointeger(m)
    if i and e >= 0 then
        -- 整数尾数走整数乘法：不受浮点精度与上限影响（定点运行时浮点上限约 2^46）
        return i * pow10(e)
    end
    local value = scale(m, e)
    if value >= NUMBER_MAX or value <= -NUMBER_MAX then
        error('big-number: 超出可转普通数值的范围: ' .. M.format(big))
    end
    return math.tointeger(value) or value
end

---比值转普通数值（0~1 的小数：量级再小也直接按浮点返回，不触发「超出可转范围」的报错）
---@param big BigNumber
---@return number
function M.toRatio(big)
    if M.isZero(big) then
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
function M.format(big)
    if M.isZero(big) then
        return '0'
    end
    return render(big, 2)
end

---跳字用短格式（< 1e4 直出整数，否则保留 1 位小数）
---@param big BigNumber
---@return string
function M.formatShort(big)
    if M.isZero(big) then
        return '0'
    end
    return render(big, 1)
end

function M.__add(a, b)
    return M.add(M.of(a), M.of(b))
end

function M.__sub(a, b)
    return M.sub(M.of(a), M.of(b))
end

function M.__mul(a, b)
    return M.mul(M.of(a), M.of(b))
end

function M.__div(a, b)
    return M.div(M.of(a), M.of(b))
end

function M.__unm(a)
    return M.neg(M.of(a))
end

function M.__lt(a, b)
    return M.cmp(M.of(a), M.of(b)) < 0
end

function M.__le(a, b)
    return M.cmp(M.of(a), M.of(b)) <= 0
end

function M.__eq(a, b)
    return M.cmp(M.of(a), M.of(b)) == 0
end

function M.__tostring(a)
    return M.format(a)
end

return M
