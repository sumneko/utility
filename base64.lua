local byte   = string.byte
local char   = string.char
local sub    = string.sub
local concat = table.concat
local unpack = table.unpack
local format = string.format

local M = {}

local ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

-- 编码表：索引为 0~63
local encodeMap = {}
for i = 1, 64 do
    encodeMap[i - 1] = sub(ALPHABET, i, i)
end

-- 双字符编码表：索引为 12 bit 值，一次写入 2 个字符
-- 惰性构建，避免只用解码时为空表付出内存
---@type table<integer, string>
local pairMap = nil

local function buildPairMap()
    local map = {}
    for i = 0, 4095 do
        map[i] = encodeMap[i >> 6] .. encodeMap[i & 0x3F]
    end
    pairMap = map
end

-- 解码表：键为字节值
local decodeMap = {}
for i = 1, 64 do
    decodeMap[byte(ALPHABET, i)] = i - 1
end

local PAD = byte('=')

---判断是否为可忽略的空白字符（空格、制表、换行、回车）
---@param b integer
---@return boolean
local function isSpace(b)
    return b == 32 or b == 9 or b == 10 or b == 13
end

---Base64 编码，使用标准字符表与填充
---@param s string
---@return string
function M.encode(s)
    local n   = #s
    local buf = {}
    local pos = 1
    local i   = 1

    local pmap = pairMap
    if not pmap then
        buildPairMap()
        pmap = pairMap
    end

    -- 一次取 45 字节（15 组），每组写入 1 个双字符
    while i + 44 <= n do
        local b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15,
              b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30,
              b31, b32, b33, b34, b35, b36, b37, b38, b39, b40, b41, b42, b43, b44, b45 = byte(s, i, i + 44)
        local v1  = b1  * 0x10000 + b2  * 0x100 + b3
        local v2  = b4  * 0x10000 + b5  * 0x100 + b6
        local v3  = b7  * 0x10000 + b8  * 0x100 + b9
        local v4  = b10 * 0x10000 + b11 * 0x100 + b12
        local v5  = b13 * 0x10000 + b14 * 0x100 + b15
        local v6  = b16 * 0x10000 + b17 * 0x100 + b18
        local v7  = b19 * 0x10000 + b20 * 0x100 + b21
        local v8  = b22 * 0x10000 + b23 * 0x100 + b24
        local v9  = b25 * 0x10000 + b26 * 0x100 + b27
        local v10 = b28 * 0x10000 + b29 * 0x100 + b30
        local v11 = b31 * 0x10000 + b32 * 0x100 + b33
        local v12 = b34 * 0x10000 + b35 * 0x100 + b36
        local v13 = b37 * 0x10000 + b38 * 0x100 + b39
        local v14 = b40 * 0x10000 + b41 * 0x100 + b42
        local v15 = b43 * 0x10000 + b44 * 0x100 + b45
        buf[pos]      = pmap[v1 >> 12]
        buf[pos + 1]  = pmap[v1 & 0xFFF]
        buf[pos + 2]  = pmap[v2 >> 12]
        buf[pos + 3]  = pmap[v2 & 0xFFF]
        buf[pos + 4]  = pmap[v3 >> 12]
        buf[pos + 5]  = pmap[v3 & 0xFFF]
        buf[pos + 6]  = pmap[v4 >> 12]
        buf[pos + 7]  = pmap[v4 & 0xFFF]
        buf[pos + 8]  = pmap[v5 >> 12]
        buf[pos + 9]  = pmap[v5 & 0xFFF]
        buf[pos + 10] = pmap[v6 >> 12]
        buf[pos + 11] = pmap[v6 & 0xFFF]
        buf[pos + 12] = pmap[v7 >> 12]
        buf[pos + 13] = pmap[v7 & 0xFFF]
        buf[pos + 14] = pmap[v8 >> 12]
        buf[pos + 15] = pmap[v8 & 0xFFF]
        buf[pos + 16] = pmap[v9 >> 12]
        buf[pos + 17] = pmap[v9 & 0xFFF]
        buf[pos + 18] = pmap[v10 >> 12]
        buf[pos + 19] = pmap[v10 & 0xFFF]
        buf[pos + 20] = pmap[v11 >> 12]
        buf[pos + 21] = pmap[v11 & 0xFFF]
        buf[pos + 22] = pmap[v12 >> 12]
        buf[pos + 23] = pmap[v12 & 0xFFF]
        buf[pos + 24] = pmap[v13 >> 12]
        buf[pos + 25] = pmap[v13 & 0xFFF]
        buf[pos + 26] = pmap[v14 >> 12]
        buf[pos + 27] = pmap[v14 & 0xFFF]
        buf[pos + 28] = pmap[v15 >> 12]
        buf[pos + 29] = pmap[v15 & 0xFFF]
        pos = pos + 30
        i   = i + 45
    end

    while i + 2 <= n do
        local a, b, c = byte(s, i, i + 2)
        local v = a * 0x10000 + b * 0x100 + c
        buf[pos]     = pmap[v >> 12]
        buf[pos + 1] = pmap[v & 0xFFF]
        pos = pos + 2
        i   = i + 3
    end

    local left = n - i + 1
    if left == 1 then
        local a = byte(s, i)
        buf[pos]     = pmap[a << 4]
        buf[pos + 1] = '=='
    elseif left == 2 then
        local a, b = byte(s, i, i + 1)
        local v = a * 0x100 + b
        buf[pos]     = pmap[v >> 4]
        buf[pos + 1] = encodeMap[(v & 0x0F) << 2]
        buf[pos + 2] = '='
    end

    return concat(buf)
end

---Base64 解码，忽略空白字符，允许省略填充
---@param s string
---@return string
function M.decode(s)
    local n     = #s
    local buf   = {}
    local pos   = 0
    local count = 0
    local pad   = 0
    local acc   = 0
    local bits  = 0
    local i     = 1

    -- 快路径：一次取 24 个合法字符（6 组），产出 18 字节后再一次性 char(unpack)
    local tmp = {}
    local k   = 0
    while i <= n do
        -- 仅在组对齐且未遇到填充时走快路径
        if bits == 0 and pad == 0 then
            while i + 23 <= n do
                local c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12,
                      c13, c14, c15, c16, c17, c18, c19, c20, c21, c22, c23, c24 = byte(s, i, i + 23)
                local v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12,
                      v13, v14, v15, v16, v17, v18, v19, v20, v21, v22, v23, v24 =
                    decodeMap[c1], decodeMap[c2], decodeMap[c3], decodeMap[c4], decodeMap[c5], decodeMap[c6],
                    decodeMap[c7], decodeMap[c8], decodeMap[c9], decodeMap[c10], decodeMap[c11], decodeMap[c12],
                    decodeMap[c13], decodeMap[c14], decodeMap[c15], decodeMap[c16], decodeMap[c17], decodeMap[c18],
                    decodeMap[c19], decodeMap[c20], decodeMap[c21], decodeMap[c22], decodeMap[c23], decodeMap[c24]
                if v1 and v2 and v3 and v4 and v5 and v6 and v7 and v8 and v9 and v10 and v11 and v12
                    and v13 and v14 and v15 and v16 and v17 and v18 and v19 and v20 and v21 and v22 and v23 and v24 then
                    tmp[k + 1]  = (v1 << 2) | (v2 >> 4)
                    tmp[k + 2]  = ((v2 & 0x0F) << 4) | (v3 >> 2)
                    tmp[k + 3]  = ((v3 & 0x03) << 6) | v4
                    tmp[k + 4]  = (v5 << 2) | (v6 >> 4)
                    tmp[k + 5]  = ((v6 & 0x0F) << 4) | (v7 >> 2)
                    tmp[k + 6]  = ((v7 & 0x03) << 6) | v8
                    tmp[k + 7]  = (v9 << 2) | (v10 >> 4)
                    tmp[k + 8]  = ((v10 & 0x0F) << 4) | (v11 >> 2)
                    tmp[k + 9]  = ((v11 & 0x03) << 6) | v12
                    tmp[k + 10] = (v13 << 2) | (v14 >> 4)
                    tmp[k + 11] = ((v14 & 0x0F) << 4) | (v15 >> 2)
                    tmp[k + 12] = ((v15 & 0x03) << 6) | v16
                    tmp[k + 13] = (v17 << 2) | (v18 >> 4)
                    tmp[k + 14] = ((v18 & 0x0F) << 4) | (v19 >> 2)
                    tmp[k + 15] = ((v19 & 0x03) << 6) | v20
                    tmp[k + 16] = (v21 << 2) | (v22 >> 4)
                    tmp[k + 17] = ((v22 & 0x0F) << 4) | (v23 >> 2)
                    tmp[k + 18] = ((v23 & 0x03) << 6) | v24
                    k      = k + 18
                    count  = count + 24
                    i      = i + 24
                    if k >= 900 then
                        pos = pos + 1
                        buf[pos] = char(unpack(tmp, 1, k))
                        k = 0
                    end
                else
                    break
                end
            end
            if k > 0 then
                pos = pos + 1
                buf[pos] = char(unpack(tmp, 1, k))
                k = 0
            end
        end
        if i > n then
            break
        end

        -- 慢路径：单字符处理（空白、填充、非法字符、组尾）
        local b = byte(s, i)
        local v = decodeMap[b]
        if v then
            if pad > 0 then
                error('base64: unexpected data after padding', 3)
            end
            acc  = (acc << 6) | v
            bits = bits + 6
            count = count + 1
            if bits >= 8 then
                bits = bits - 8
                pos  = pos + 1
                buf[pos] = char((acc >> bits) & 0xFF)
                if bits == 0 then
                    acc = 0
                else
                    acc = acc & ((1 << bits) - 1)
                end
            end
        elseif b == PAD then
            pad = pad + 1
        elseif not isSpace(b) then
            error(format('base64: invalid character %q at %d', char(b), i), 3)
        end
        i = i + 1
    end

    local rest = count % 4
    if rest == 1 then
        error('base64: invalid length', 3)
    end
    if pad > 0 and pad ~= (4 - rest) % 4 then
        error(format('base64: invalid padding for %d characters', count), 3)
    end

    return concat(buf)
end

return M
