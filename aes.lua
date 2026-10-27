--[[
纯 Lua AES 实现（AES-128 / AES-192 / AES-256）

性能取向：
  * 轮函数使用 4 张 32 位 T 表（Te0~Te3 / Td0~Td3），每列只需 4 次查表 + 4 次异或
  * 块内按 32 位字处理，整块 16 字节一次读入
  * 批量模式（ECB/CBC/CTR）的输出先进数字缓冲，按 4KB 用 char(unpack) 刷出，
    避免为每个 16 字节块生成一个会被 intern 的短字符串

用法：
  local aes = require 'aes'
  local ctx = aes.new(key)                  -- key 为 16 / 24 / 32 字节
  ctx:encryptBlock(block16)                 -- 单块，返回 16 字节
  ctx:decryptBlock(block16)
  ctx:encryptECB(data, padding)
  ctx:decryptECB(data, padding)
  ctx:encryptCBC(data, iv, padding)
  ctx:decryptCBC(data, iv, padding)
  ctx:encryptCTR(data, iv)                  -- 加解密同一函数
  ctx:decryptCTR(data, iv)
]]

local byte    = string.byte
local char    = string.char
local concat  = table.concat
local unpack  = table.unpack
local type    = type
local error   = error
local setmetatable = setmetatable

local M = {}

local BLOCK_SIZE = 16
local FLUSH_SIZE = 4096

-- ============================================================
-- GF(2^8) 与查表
-- ============================================================

---GF(2^8) 上乘 2（模 x^8 + x^4 + x^3 + x + 1）
---@param b integer
---@return integer
local function xtime(b)
    if b & 0x80 ~= 0 then
        return ((b << 1) & 0xFF) ~ 0x1B
    end
    return (b << 1) & 0xFF
end

---GF(2^8) 乘法，仅在建表时使用
---@param a integer
---@param b integer
---@return integer
local function gmul(a, b)
    local r = 0
    for _ = 1, 8 do
        if b & 1 == 1 then
            r = r ~ a
        end
        local hi = a & 0x80
        a = (a << 1) & 0xFF
        if hi ~= 0 then
            a = a ~ 0x1B
        end
        b = b >> 1
    end
    return r
end

---@param b integer
---@param n integer
---@return integer
local function rotl8(b, n)
    return ((b << n) | (b >> (8 - n))) & 0xFF
end

---S 盒与逆 S 盒：GF(2^8) 求逆后做仿射变换
local SBOX  = {}
local ISBOX = {}
do
    -- 以 3 为生成元打表，log/exp 用于求逆
    local exp, log = {}, {}
    local x = 1
    for i = 0, 254 do
        exp[i] = x
        log[x] = i
        x = x ~ xtime(x) -- x * 3
    end
    for a = 0, 255 do
        local inv = 0
        if a ~= 0 then
            inv = exp[(255 - log[a]) % 255]
        end
        local s = inv ~ rotl8(inv, 1) ~ rotl8(inv, 2) ~ rotl8(inv, 3) ~ rotl8(inv, 4) ~ 0x63
        SBOX[a]  = s
        ISBOX[s] = a
    end
end

---@param w integer
---@return integer
local function rotr32(w)
    return ((w >> 8) | (w << 24)) & 0xFFFFFFFF
end

local TE0, TE1, TE2, TE3 = {}, {}, {}, {}
local TD0, TD1, TD2, TD3 = {}, {}, {}, {}
do
    for a = 0, 255 do
        local s  = SBOX[a]
        local s2 = gmul(s, 2)
        local s3 = s2 ~ s
        local w  = (s2 << 24) | (s << 16) | (s << 8) | s3
        TE0[a] = w
        TE1[a] = rotr32(w)
        TE2[a] = rotr32(TE1[a])
        TE3[a] = rotr32(TE2[a])

        local t  = ISBOX[a]
        local t9  = gmul(t, 9)
        local t11 = gmul(t, 11)
        local t13 = gmul(t, 13)
        local t14 = gmul(t, 14)
        local v  = (t14 << 24) | (t9 << 16) | (t13 << 8) | t11
        TD0[a] = v
        TD1[a] = rotr32(v)
        TD2[a] = rotr32(TD1[a])
        TD3[a] = rotr32(TD2[a])
    end
end

-- ============================================================
-- 密钥扩展
-- ============================================================

---@param w integer
---@return integer
local function subWord(w)
    return (SBOX[w >> 24] << 24) | (SBOX[(w >> 16) & 0xFF] << 16)
        | (SBOX[(w >> 8) & 0xFF] << 8) | SBOX[w & 0xFF]
end

---@param w integer
---@return integer
local function rotWord(w)
    return ((w << 8) & 0xFFFFFFFF) | (w >> 24)
end

---对单个轮密钥字做 InvMixColumns（等价逆密码需要）
---@param w integer
---@return integer
local function invMixWord(w)
    return TD0[SBOX[w >> 24]]
        ~ TD1[SBOX[(w >> 16) & 0xFF]]
        ~ TD2[SBOX[(w >> 8) & 0xFF]]
        ~ TD3[SBOX[w & 0xFF]]
end

---@param key string
---@return table ek 加密轮密钥（1 基，4 * (nr + 1) 个字）
---@return table dk 解密轮密钥（1 基，等价逆密码顺序）
---@return integer nr 轮数
local function expandKey(key)
    local keyLen = #key
    local nk = keyLen // 4
    if keyLen % 4 ~= 0 or (nk ~= 4 and nk ~= 6 and nk ~= 8) then
        error('aes: 密钥长度必须是 16 / 24 / 32 字节')
    end
    local nr    = nk + 6
    local total = 4 * (nr + 1)
    local ek    = {}
    for i = 1, nk do
        local b1, b2, b3, b4 = byte(key, i * 4 - 3, i * 4)
        ek[i] = (b1 << 24) | (b2 << 16) | (b3 << 8) | b4
    end
    local rcon = 1
    for i = nk + 1, total do
        local t = ek[i - 1]
        local pos = i - 1
        if pos % nk == 0 then
            t = subWord(rotWord(t)) ~ (rcon << 24)
            rcon = xtime(rcon)
        elseif nk == 8 and pos % nk == 4 then
            t = subWord(t)
        end
        ek[i] = ek[i - nk] ~ t
    end

    local dk = {}
    local di = 1
    for c = total - 3, total do
        dk[di] = ek[c]
        di = di + 1
    end
    for r = nr - 1, 1, -1 do
        local base = r * 4
        for c = 1, 4 do
            dk[di] = invMixWord(ek[base + c])
            di = di + 1
        end
    end
    for c = 1, 4 do
        dk[di] = ek[c]
        di = di + 1
    end
    return ek, dk, nr
end

-- ============================================================
-- 轮函数（按 32 位字）
-- ============================================================

---@param ek table
---@param nr integer
---@param s0 integer
---@param s1 integer
---@param s2 integer
---@param s3 integer
---@return integer
---@return integer
---@return integer
---@return integer
local function encryptWords(ek, nr, s0, s1, s2, s3)
    s0 = s0 ~ ek[1]
    s1 = s1 ~ ek[2]
    s2 = s2 ~ ek[3]
    s3 = s3 ~ ek[4]
    local i = 5
    for _ = 1, nr - 1 do
        local t0 = TE0[s0 >> 24] ~ TE1[(s1 >> 16) & 0xFF] ~ TE2[(s2 >> 8) & 0xFF] ~ TE3[s3 & 0xFF] ~ ek[i]
        local t1 = TE0[s1 >> 24] ~ TE1[(s2 >> 16) & 0xFF] ~ TE2[(s3 >> 8) & 0xFF] ~ TE3[s0 & 0xFF] ~ ek[i + 1]
        local t2 = TE0[s2 >> 24] ~ TE1[(s3 >> 16) & 0xFF] ~ TE2[(s0 >> 8) & 0xFF] ~ TE3[s1 & 0xFF] ~ ek[i + 2]
        local t3 = TE0[s3 >> 24] ~ TE1[(s0 >> 16) & 0xFF] ~ TE2[(s1 >> 8) & 0xFF] ~ TE3[s2 & 0xFF] ~ ek[i + 3]
        s0, s1, s2, s3 = t0, t1, t2, t3
        i = i + 4
    end
    local t0 = (SBOX[s0 >> 24] << 24) ~ (SBOX[(s1 >> 16) & 0xFF] << 16)
        ~ (SBOX[(s2 >> 8) & 0xFF] << 8) ~ SBOX[s3 & 0xFF] ~ ek[i]
    local t1 = (SBOX[s1 >> 24] << 24) ~ (SBOX[(s2 >> 16) & 0xFF] << 16)
        ~ (SBOX[(s3 >> 8) & 0xFF] << 8) ~ SBOX[s0 & 0xFF] ~ ek[i + 1]
    local t2 = (SBOX[s2 >> 24] << 24) ~ (SBOX[(s3 >> 16) & 0xFF] << 16)
        ~ (SBOX[(s0 >> 8) & 0xFF] << 8) ~ SBOX[s1 & 0xFF] ~ ek[i + 2]
    local t3 = (SBOX[s3 >> 24] << 24) ~ (SBOX[(s0 >> 16) & 0xFF] << 16)
        ~ (SBOX[(s1 >> 8) & 0xFF] << 8) ~ SBOX[s2 & 0xFF] ~ ek[i + 3]
    return t0, t1, t2, t3
end

---@param dk table
---@param nr integer
---@param s0 integer
---@param s1 integer
---@param s2 integer
---@param s3 integer
---@return integer
---@return integer
---@return integer
---@return integer
local function decryptWords(dk, nr, s0, s1, s2, s3)
    s0 = s0 ~ dk[1]
    s1 = s1 ~ dk[2]
    s2 = s2 ~ dk[3]
    s3 = s3 ~ dk[4]
    local i = 5
    for _ = 1, nr - 1 do
        local t0 = TD0[s0 >> 24] ~ TD1[(s3 >> 16) & 0xFF] ~ TD2[(s2 >> 8) & 0xFF] ~ TD3[s1 & 0xFF] ~ dk[i]
        local t1 = TD0[s1 >> 24] ~ TD1[(s0 >> 16) & 0xFF] ~ TD2[(s3 >> 8) & 0xFF] ~ TD3[s2 & 0xFF] ~ dk[i + 1]
        local t2 = TD0[s2 >> 24] ~ TD1[(s1 >> 16) & 0xFF] ~ TD2[(s0 >> 8) & 0xFF] ~ TD3[s3 & 0xFF] ~ dk[i + 2]
        local t3 = TD0[s3 >> 24] ~ TD1[(s2 >> 16) & 0xFF] ~ TD2[(s1 >> 8) & 0xFF] ~ TD3[s0 & 0xFF] ~ dk[i + 3]
        s0, s1, s2, s3 = t0, t1, t2, t3
        i = i + 4
    end
    local t0 = (ISBOX[s0 >> 24] << 24) ~ (ISBOX[(s3 >> 16) & 0xFF] << 16)
        ~ (ISBOX[(s2 >> 8) & 0xFF] << 8) ~ ISBOX[s1 & 0xFF] ~ dk[i]
    local t1 = (ISBOX[s1 >> 24] << 24) ~ (ISBOX[(s0 >> 16) & 0xFF] << 16)
        ~ (ISBOX[(s3 >> 8) & 0xFF] << 8) ~ ISBOX[s2 & 0xFF] ~ dk[i + 1]
    local t2 = (ISBOX[s2 >> 24] << 24) ~ (ISBOX[(s1 >> 16) & 0xFF] << 16)
        ~ (ISBOX[(s0 >> 8) & 0xFF] << 8) ~ ISBOX[s3 & 0xFF] ~ dk[i + 2]
    local t3 = (ISBOX[s3 >> 24] << 24) ~ (ISBOX[(s2 >> 16) & 0xFF] << 16)
        ~ (ISBOX[(s1 >> 8) & 0xFF] << 8) ~ ISBOX[s0 & 0xFF] ~ dk[i + 3]
    return t0, t1, t2, t3
end

-- ============================================================
-- 字节 / 字辅助
-- ============================================================

---@param s string
---@param i integer
---@return integer
---@return integer
---@return integer
---@return integer
local function readWords(s, i)
    local b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16 = byte(s, i, i + 15)
    return (b1 << 24) | (b2 << 16) | (b3 << 8) | b4,
        (b5 << 24) | (b6 << 16) | (b7 << 8) | b8,
        (b9 << 24) | (b10 << 16) | (b11 << 8) | b12,
        (b13 << 24) | (b14 << 16) | (b15 << 8) | b16
end

---@param w0 integer
---@param w1 integer
---@param w2 integer
---@param w3 integer
---@return string
local function wordsToChar(w0, w1, w2, w3)
    return char(
        (w0 >> 24) & 0xFF, (w0 >> 16) & 0xFF, (w0 >> 8) & 0xFF, w0 & 0xFF,
        (w1 >> 24) & 0xFF, (w1 >> 16) & 0xFF, (w1 >> 8) & 0xFF, w1 & 0xFF,
        (w2 >> 24) & 0xFF, (w2 >> 16) & 0xFF, (w2 >> 8) & 0xFF, w2 & 0xFF,
        (w3 >> 24) & 0xFF, (w3 >> 16) & 0xFF, (w3 >> 8) & 0xFF, w3 & 0xFF
    )
end

---把 4 个字展开成 16 个字节写入数字缓冲
---@param tmp table
---@param k integer
---@param w0 integer
---@param w1 integer
---@param w2 integer
---@param w3 integer
---@return integer
local function appendWords(tmp, k, w0, w1, w2, w3)
    tmp[k + 1]  = (w0 >> 24) & 0xFF
    tmp[k + 2]  = (w0 >> 16) & 0xFF
    tmp[k + 3]  = (w0 >> 8) & 0xFF
    tmp[k + 4]  = w0 & 0xFF
    tmp[k + 5]  = (w1 >> 24) & 0xFF
    tmp[k + 6]  = (w1 >> 16) & 0xFF
    tmp[k + 7]  = (w1 >> 8) & 0xFF
    tmp[k + 8]  = w1 & 0xFF
    tmp[k + 9]  = (w2 >> 24) & 0xFF
    tmp[k + 10] = (w2 >> 16) & 0xFF
    tmp[k + 11] = (w2 >> 8) & 0xFF
    tmp[k + 12] = w2 & 0xFF
    tmp[k + 13] = (w3 >> 24) & 0xFF
    tmp[k + 14] = (w3 >> 16) & 0xFF
    tmp[k + 15] = (w3 >> 8) & 0xFF
    tmp[k + 16] = w3 & 0xFF
    return k + 16
end

---@param s string
---@return string
local function padPKCS7(s)
    local n = BLOCK_SIZE - #s % BLOCK_SIZE
    return s .. char(n):rep(n)
end

---@param s string
---@return string
local function unpadPKCS7(s)
    local n = #s
    if n == 0 or n % BLOCK_SIZE ~= 0 then
        error('aes: 密文长度必须是 16 的倍数')
    end
    local pad = byte(s, n)
    if pad < 1 or pad > BLOCK_SIZE then
        error('aes: 填充数据无效')
    end
    for i = n - pad + 1, n do
        if byte(s, i) ~= pad then
            error('aes: 填充数据无效')
        end
    end
    return s:sub(1, n - pad)
end

---@param name string
---@param value any
local function checkString(name, value)
    if type(value) ~= 'string' then
        error('aes: ' .. name .. ' 必须是字符串', 3)
    end
end

-- ============================================================
-- 上下文
-- ============================================================

---@class Aes
---@field ek table
---@field dk table
---@field nr integer
---@field keyLen integer
local Ctx = {}
Ctx.__index = Ctx

---创建 AES 上下文（按密钥长度自动选择 AES-128 / 192 / 256）
---@param key string
---@return Aes
function M.new(key)
    checkString('key', key)
    local ek, dk, nr = expandKey(key)
    return setmetatable({
        ek     = ek,
        dk     = dk,
        nr     = nr,
        keyLen = #key,
    }, Ctx)
end

---加密单个 16 字节块
---@param block string
---@return string
function Ctx:encryptBlock(block)
    checkString('block', block)
    if #block ~= BLOCK_SIZE then
        error('aes: 块长度必须是 16 字节', 2)
    end
    local b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16 = byte(block, 1, 16)
    local s0 = (b1 << 24) | (b2 << 16) | (b3 << 8) | b4
    local s1 = (b5 << 24) | (b6 << 16) | (b7 << 8) | b8
    local s2 = (b9 << 24) | (b10 << 16) | (b11 << 8) | b12
    local s3 = (b13 << 24) | (b14 << 16) | (b15 << 8) | b16
    local w0, w1, w2, w3 = encryptWords(self.ek, self.nr, s0, s1, s2, s3)
    return wordsToChar(w0, w1, w2, w3)
end

---解密单个 16 字节块
---@param block string
---@return string
function Ctx:decryptBlock(block)
    checkString('block', block)
    if #block ~= BLOCK_SIZE then
        error('aes: 块长度必须是 16 字节', 2)
    end
    local b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16 = byte(block, 1, 16)
    local s0 = (b1 << 24) | (b2 << 16) | (b3 << 8) | b4
    local s1 = (b5 << 24) | (b6 << 16) | (b7 << 8) | b8
    local s2 = (b9 << 24) | (b10 << 16) | (b11 << 8) | b12
    local s3 = (b13 << 24) | (b14 << 16) | (b15 << 8) | b16
    local w0, w1, w2, w3 = decryptWords(self.dk, self.nr, s0, s1, s2, s3)
    return wordsToChar(w0, w1, w2, w3)
end

-- ============================================================
-- ECB
-- ============================================================

---ECB 加密（padding 默认开启 PKCS#7）
---@param data string
---@param padding? boolean 传 false 关闭填充，此时数据长度必须是 16 的倍数
---@return string
function Ctx:encryptECB(data, padding)
    checkString('data', data)
    if padding ~= false then
        data = padPKCS7(data)
    elseif #data % BLOCK_SIZE ~= 0 then
        error('aes: 关闭填充时数据长度必须是 16 的倍数', 2)
    end
    local ek, nr = self.ek, self.nr
    local out, tmp, k = {}, {}, 0
    local n = #data
    local i = 1
    while i <= n do
        local s0, s1, s2, s3 = readWords(data, i)
        local w0, w1, w2, w3 = encryptWords(ek, nr, s0, s1, s2, s3)
        k = appendWords(tmp, k, w0, w1, w2, w3)
        if k >= FLUSH_SIZE then
            out[#out + 1] = char(unpack(tmp, 1, k))
            k = 0
        end
        i = i + BLOCK_SIZE
    end
    if k > 0 then
        out[#out + 1] = char(unpack(tmp, 1, k))
    end
    return concat(out)
end

---ECB 解密（padding 默认开启 PKCS#7）
---@param data string
---@param padding? boolean 传 false 关闭去填充
---@return string
function Ctx:decryptECB(data, padding)
    checkString('data', data)
    if #data % BLOCK_SIZE ~= 0 then
        error('aes: 密文长度必须是 16 的倍数', 2)
    end
    local dk, nr = self.dk, self.nr
    local out, tmp, k = {}, {}, 0
    local n = #data
    local i = 1
    while i <= n do
        local s0, s1, s2, s3 = readWords(data, i)
        local w0, w1, w2, w3 = decryptWords(dk, nr, s0, s1, s2, s3)
        k = appendWords(tmp, k, w0, w1, w2, w3)
        if k >= FLUSH_SIZE then
            out[#out + 1] = char(unpack(tmp, 1, k))
            k = 0
        end
        i = i + BLOCK_SIZE
    end
    if k > 0 then
        out[#out + 1] = char(unpack(tmp, 1, k))
    end
    local result = concat(out)
    if padding ~= false then
        result = unpadPKCS7(result)
    end
    return result
end

-- ============================================================
-- CBC
-- ============================================================

---@param iv string
local function checkIV(iv)
    checkString('iv', iv)
    if #iv ~= BLOCK_SIZE then
        error('aes: iv 必须是 16 字节', 3)
    end
end

---CBC 加密（padding 默认开启 PKCS#7）
---@param data string
---@param iv string 16 字节初始向量
---@param padding? boolean 传 false 关闭填充
---@return string
function Ctx:encryptCBC(data, iv, padding)
    checkString('data', data)
    checkIV(iv)
    if padding ~= false then
        data = padPKCS7(data)
    elseif #data % BLOCK_SIZE ~= 0 then
        error('aes: 关闭填充时数据长度必须是 16 的倍数', 2)
    end
    local ek, nr = self.ek, self.nr
    local p0, p1, p2, p3 = readWords(iv, 1)
    local out, tmp, k = {}, {}, 0
    local n = #data
    local i = 1
    while i <= n do
        local s0, s1, s2, s3 = readWords(data, i)
        s0 = s0 ~ p0
        s1 = s1 ~ p1
        s2 = s2 ~ p2
        s3 = s3 ~ p3
        local w0, w1, w2, w3 = encryptWords(ek, nr, s0, s1, s2, s3)
        k = appendWords(tmp, k, w0, w1, w2, w3)
        if k >= FLUSH_SIZE then
            out[#out + 1] = char(unpack(tmp, 1, k))
            k = 0
        end
        p0, p1, p2, p3 = w0, w1, w2, w3
        i = i + BLOCK_SIZE
    end
    if k > 0 then
        out[#out + 1] = char(unpack(tmp, 1, k))
    end
    return concat(out)
end

---CBC 解密（padding 默认开启 PKCS#7）
---@param data string
---@param iv string 16 字节初始向量
---@param padding? boolean 传 false 关闭去填充
---@return string
function Ctx:decryptCBC(data, iv, padding)
    checkString('data', data)
    checkIV(iv)
    if #data % BLOCK_SIZE ~= 0 then
        error('aes: 密文长度必须是 16 的倍数', 2)
    end
    local dk, nr = self.dk, self.nr
    local p0, p1, p2, p3 = readWords(iv, 1)
    local out, tmp, k = {}, {}, 0
    local n = #data
    local i = 1
    while i <= n do
        local c0, c1, c2, c3 = readWords(data, i)
        local w0, w1, w2, w3 = decryptWords(dk, nr, c0, c1, c2, c3)
        k = appendWords(tmp, k, w0 ~ p0, w1 ~ p1, w2 ~ p2, w3 ~ p3)
        if k >= FLUSH_SIZE then
            out[#out + 1] = char(unpack(tmp, 1, k))
            k = 0
        end
        p0, p1, p2, p3 = c0, c1, c2, c3
        i = i + BLOCK_SIZE
    end
    if k > 0 then
        out[#out + 1] = char(unpack(tmp, 1, k))
    end
    local result = concat(out)
    if padding ~= false then
        result = unpadPKCS7(result)
    end
    return result
end

-- ============================================================
-- CTR
-- ============================================================

---CTR 加解密（同一运算），计数器按大端自增
---@param data string
---@param iv string 16 字节初始计数器
---@return string
function Ctx:encryptCTR(data, iv)
    checkString('data', data)
    checkIV(iv)
    local ek, nr = self.ek, self.nr
    local c0, c1, c2, c3 = readWords(iv, 1)
    local out, tmp, k = {}, {}, 0
    local n = #data
    local i = 1
    while i + BLOCK_SIZE - 1 <= n do
        local s0, s1, s2, s3 = readWords(data, i)
        local w0, w1, w2, w3 = encryptWords(ek, nr, c0, c1, c2, c3)
        k = appendWords(tmp, k, s0 ~ w0, s1 ~ w1, s2 ~ w2, s3 ~ w3)
        if k >= FLUSH_SIZE then
            out[#out + 1] = char(unpack(tmp, 1, k))
            k = 0
        end
        c3 = (c3 + 1) & 0xFFFFFFFF
        if c3 == 0 then
            c2 = (c2 + 1) & 0xFFFFFFFF
            if c2 == 0 then
                c1 = (c1 + 1) & 0xFFFFFFFF
                if c1 == 0 then
                    c0 = (c0 + 1) & 0xFFFFFFFF
                end
            end
        end
        i = i + BLOCK_SIZE
    end
    if i <= n then
        local w0, w1, w2, w3 = encryptWords(ek, nr, c0, c1, c2, c3)
        local ks = { (w0 >> 24) & 0xFF, (w0 >> 16) & 0xFF, (w0 >> 8) & 0xFF, w0 & 0xFF,
            (w1 >> 24) & 0xFF, (w1 >> 16) & 0xFF, (w1 >> 8) & 0xFF, w1 & 0xFF,
            (w2 >> 24) & 0xFF, (w2 >> 16) & 0xFF, (w2 >> 8) & 0xFF, w2 & 0xFF,
            (w3 >> 24) & 0xFF, (w3 >> 16) & 0xFF, (w3 >> 8) & 0xFF, w3 & 0xFF }
        local j = 1
        while i <= n do
            k = k + 1
            tmp[k] = byte(data, i) ~ ks[j]
            j = j + 1
            i = i + 1
        end
    end
    if k > 0 then
        out[#out + 1] = char(unpack(tmp, 1, k))
    end
    return concat(out)
end

---@param data string
---@param iv string
---@return string
function Ctx:decryptCTR(data, iv)
    return self:encryptCTR(data, iv)
end

return M
