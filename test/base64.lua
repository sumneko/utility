local base64 = require 'base64'

print('开始测试 Base64')

local ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

-- 独立的参考实现（不使用位运算），用于交叉验证
local function refEncode(s)
    local n = #s
    local out = {}
    local i = 1
    while i <= n do
        local a, b, c = s:byte(i, i + 2)
        local v, bits
        if c then
            v    = a * 0x10000 + b * 0x100 + c
            bits = 24
        elseif b then
            v    = (a * 0x100 + b) * 4
            bits = 18
        else
            v    = a * 16
            bits = 12
        end
        local chars = bits // 6
        for j = 0, chars - 1 do
            local shift = bits - 6 * (j + 1)
            local idx = math.floor(v / 2 ^ shift) % 64
            out[#out + 1] = ALPHABET:sub(idx + 1, idx + 1)
        end
        for _ = 1, 4 - chars do
            out[#out + 1] = '='
        end
        i = i + 3
    end
    return table.concat(out)
end

local function expectError(fn, label)
    local ok = pcall(fn)
    assert(not ok, '应当报错: ' .. tostring(label))
end

-- RFC 4648 标准测试向量
do
    local vectors = {
        { '',             '' },
        { 'f',            'Zg==' },
        { 'fo',           'Zm8=' },
        { 'foo',          'Zm9v' },
        { 'foob',         'Zm9vYg==' },
        { 'fooba',        'Zm9vYmE=' },
        { 'foobar',       'Zm9vYmFy' },
        { 'sure.',        'c3VyZS4=' },
        { 'Hello, World!', 'SGVsbG8sIFdvcmxkIQ==' },
    }
    for _, case in ipairs(vectors) do
        local raw, encoded = case[1], case[2]
        assert(base64.encode(raw) == encoded, '编码失败: ' .. raw)
        assert(base64.decode(encoded) == raw, '解码失败: ' .. encoded)
        assert(base64.decode(base64.encode(raw)) == raw)
    end
end

-- 全字节值（含 \0 等二进制内容）
do
    local parts = {}
    for i = 0, 255 do
        parts[#parts + 1] = string.char(i)
    end
    local raw = table.concat(parts)
    local encoded = base64.encode(raw)
    assert(encoded == refEncode(raw), '全字节值编码与参考实现不一致')
    assert(#encoded == math.ceil(#raw / 3) * 4)
    assert(base64.decode(encoded) == raw, '全字节值解码失败')
end

-- 与参考实现交叉验证各种长度
do
    for len = 0, 64 do
        local parts = {}
        for i = 1, len do
            parts[i] = string.char((i * 37 + len * 11) % 256)
        end
        local raw = table.concat(parts)
        assert(base64.encode(raw) == refEncode(raw), '长度 ' .. len .. ' 编码不一致')
    end
end

-- 解码：允许空白
do
    assert(base64.decode('Zm9v\nYmFy') == 'foobar')
    assert(base64.decode(' Zm9v YmFy ') == 'foobar')
    assert(base64.decode('Zm9v\r\n\tYmFy\r\n') == 'foobar')
    assert(base64.decode('Zg =\n= ') == 'f')
end

-- 解码：MIME 换行（快路径 + 慢路径混跑）
do
    math.randomseed(20261022)
    for round = 1, 50 do
        local len = math.random(0, 2000)
        local parts = {}
        for i = 1, len do
            parts[i] = string.char(math.random(0, 255))
        end
        local raw = table.concat(parts)
        local encoded = base64.encode(raw)
        local wrapped = encoded:gsub('(' .. ('.'):rep(76) .. ')', '%1\n')
        assert(base64.decode(wrapped) == raw, 'MIME 换行解码失败, round=' .. round)
        local spaced = encoded:gsub('(' .. ('.'):rep(5) .. ')', '%1 ')
        assert(base64.decode(spaced) == raw, '空格混排解码失败, round=' .. round)
    end
end

-- 解码：允许省略填充
do
    assert(base64.decode('Zg') == 'f')
    assert(base64.decode('Zm8') == 'fo')
    assert(base64.decode('Zm9vYg') == 'foob')
    assert(base64.decode('Zm9vYmE') == 'fooba')
end

-- 非法输入
do
    expectError(function () base64.decode('A') end, '长度为 1')
    expectError(function () base64.decode('Zm9v$') end, '非法字符')
    expectError(function () base64.decode('Zm9v YmFy!') end, '尾部非法字符')
    expectError(function () base64.decode('Zg==Zg==') end, '填充后还有数据')
    expectError(function () base64.decode('Zg=') end, '填充数量不足')
    expectError(function () base64.decode('Zm8===') end, '填充数量过多')
    expectError(function () base64.decode('Zm9v==') end, '多余填充')
    expectError(function () base64.decode('====') end, '全为填充')
    expectError(function () base64.decode('=') end, '仅一个填充')
end

-- 随机二进制往返测试
do
    math.randomseed(20261022)
    for round = 1, 500 do
        local len = math.random(0, 300)
        local parts = {}
        for i = 1, len do
            parts[i] = string.char(math.random(0, 255))
        end
        local raw = table.concat(parts)
        local encoded = base64.encode(raw)
        assert(encoded == refEncode(raw), '随机数据编码不一致, round=' .. round)
        assert(base64.decode(encoded) == raw, '随机数据解码不一致, round=' .. round)
        assert(base64.decode(encoded:gsub('=', '')) == raw, '省略填充解码不一致, round=' .. round)
    end
end

-- 大块数据
do
    local parts = {}
    for i = 1, 100000 do
        parts[i] = string.char(i % 256)
    end
    local raw = table.concat(parts)
    assert(base64.decode(base64.encode(raw)) == raw, '大块数据往返失败')
end

-- 参数错误位置与返回值
do
    assert(base64.encode('') == '')
    assert(base64.decode('') == '')
    assert(select('#', base64.decode('')) == 1)
end

print('Base64 测试完成')
