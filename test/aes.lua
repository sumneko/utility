local aes = require 'aes'
local byte = string.byte

print('开始测试 AES')

local function hex(s)
    return (s:gsub('%x%x', function (b)
        return string.char(tonumber(b, 16))
    end))
end

local function unhex(s)
    return (s:gsub('.', function (c)
        return ('%02x'):format(c:byte())
    end))
end

-- FIPS-197 单块测试向量
do
    local vectors = {
        {
            key  = '000102030405060708090a0b0c0d0e0f',
            plain  = '00112233445566778899aabbccddeeff',
            cipher = '69c4e0d86a7b0430d8cdb78070b4c55a',
        },
        {
            key  = '000102030405060708090a0b0c0d0e0f1011121314151617',
            plain  = '00112233445566778899aabbccddeeff',
            cipher = 'dda97ca4864cdfe06eaf70a0ec0d7191',
        },
        {
            key  = '000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f',
            plain  = '00112233445566778899aabbccddeeff',
            cipher = '8ea2b7ca516745bfeafc49904b496089',
        },
    }
    for i, v in ipairs(vectors) do
        local ctx = aes.new(hex(v.key))
        local block = hex(v.plain)
        local encrypted = ctx:encryptBlock(block)
        assert(unhex(encrypted) == v.cipher, ('FIPS-197 第 %d 组加密失败'):format(i))
        assert(unhex(ctx:decryptBlock(encrypted)) == v.plain, ('FIPS-197 第 %d 组解密失败'):format(i))
    end
end

-- NIST SP 800-38A CBC 向量
do
    local plain = hex('6bc1bee22e409f96e93d7e117393172a'
        .. 'ae2d8a571e03ac9c9eb76fac45af8e51'
        .. '30c81c46a35ce411e5fbc1191a0a52ef'
        .. 'f69f2445df4f9b17ad2b417be66c3710')
    local iv = hex('000102030405060708090a0b0c0d0e0f')

    local cases = {
        {
            key = '2b7e151628aed2a6abf7158809cf4f3c',
            out = '7649abac8119b246cee98e9b12e9197d'
                .. '5086cb9b507219ee95db113a917678b2'
                .. '73bed6b8e3c1743b7116e69e22229516'
                .. '3ff1caa1681fac09120eca307586e1a7',
        },
        {
            key = '8e73b0f7da0e6452c810f32b809079e562f8ead2522c6b7b',
            out = '4f021db243bc633d7178183a9fa071e8'
                .. 'b4d9ada9ad7dedf4e5e738763f69145a'
                .. '571b242012fb7ae07fa9baac3df102e0'
                .. '08b0e27988598881d920a9e64f5615cd',
        },
        {
            key = '603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4',
            out = 'f58c4c04d6e5f1ba779eabfb5f7bfbd6'
                .. '9cfc4e967edb808d679f777bc6702c7d'
                .. '39f23369a9d9bacfa530e26304231461'
                .. 'b2eb05e2c39be9fcda6c19078c6a9d1b',
        },
    }
    for i, v in ipairs(cases) do
        local ctx = aes.new(hex(v.key))
        local encrypted = ctx:encryptCBC(plain, iv, false)
        assert(unhex(encrypted) == v.out, ('SP800-38A CBC 第 %d 组加密失败'):format(i))
        assert(ctx:decryptCBC(encrypted, iv, false) == plain, ('SP800-38A CBC 第 %d 组解密失败'):format(i))
    end
end

-- NIST SP 800-38A CTR 向量（AES-128）
do
    local plain = hex('6bc1bee22e409f96e93d7e117393172a'
        .. 'ae2d8a571e03ac9c9eb76fac45af8e51'
        .. '30c81c46a35ce411e5fbc1191a0a52ef'
        .. 'f69f2445df4f9b17ad2b417be66c3710')
    local expected = '874d6191b620e3261bef6864990db6ce'
        .. '9806f66b7970fdff8617187bb9fffdff'
        .. '5ae4df3edbd5d35e5b4f09020db03eab'
        .. '1e031dda2fbe03d1792170a0f3009cee'
    local ctx = aes.new(hex('2b7e151628aed2a6abf7158809cf4f3c'))
    local counter = hex('f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff')
    local encrypted = ctx:encryptCTR(plain, counter)
    assert(unhex(encrypted) == expected, 'SP800-38A CTR 加密失败')
    assert(ctx:decryptCTR(encrypted, counter) == plain, 'SP800-38A CTR 解密失败')
end

-- PKCS#7 填充与各长度往返
do
    local key = hex('2b7e151628aed2a6abf7158809cf4f3c')
    local iv = hex('000102030405060708090a0b0c0d0e0f')
    local ctx = aes.new(key)
    for len = 0, 64 do
        local parts = {}
        for i = 1, len do
            parts[i] = string.char((i * 37 + len) % 256)
        end
        local plain = table.concat(parts)

        local c1 = ctx:encryptCBC(plain, iv)
        assert(#c1 % 16 == 0)
        assert(#c1 == (len // 16 + 1) * 16)
        assert(ctx:decryptCBC(c1, iv) == plain, 'CBC 往返失败, len=' .. len)

        local c2 = ctx:encryptECB(plain)
        assert(ctx:decryptECB(c2) == plain, 'ECB 往返失败, len=' .. len)

        local c3 = ctx:encryptCTR(plain, iv)
        assert(#c3 == len)
        assert(ctx:decryptCTR(c3, iv) == plain, 'CTR 往返失败, len=' .. len)
    end
end

-- 随机往返：三种密钥长度 × 三种模式
do
    math.randomseed(20261027)
    local keyLens = { 16, 24, 32 }
    local iv = string.rep('\0', 16)
    for _, keyLen in ipairs(keyLens) do
        local kp = {}
        for i = 1, keyLen do
            kp[i] = string.char(math.random(0, 255))
        end
        local key = table.concat(kp)
        local ctx = aes.new(key)
        for round = 1, 30 do
            local parts = {}
            for i = 1, math.random(0, 200) do
                parts[i] = string.char(math.random(0, 255))
            end
            local plain = table.concat(parts)
            assert(ctx:decryptCBC(ctx:encryptCBC(plain, iv), iv) == plain, '随机 CBC 失败')
            assert(ctx:decryptECB(ctx:encryptECB(plain)) == plain, '随机 ECB 失败')
            assert(ctx:decryptCTR(ctx:encryptCTR(plain, iv), iv) == plain, '随机 CTR 失败')
        end
    end
end

-- CTR 计数器进位：末块跨 32 位边界
do
    local ctx = aes.new(hex('2b7e151628aed2a6abf7158809cf4f3c'))
    local counter = hex('000000000000000000000000ffffffff')
    local plain = string.rep('a', 64)
    local encrypted = ctx:encryptCTR(plain, counter)
    assert(ctx:decryptCTR(encrypted, counter) == plain)
    -- 与直接对计数器做 ECB 加密后异或的结果一致
    local function keystream(c)
        return ctx:encryptBlock(c)
    end
    local expect = {}
    local c = counter
    for _ = 1, 4 do
        local ks = keystream(c)
        for i = 1, 16 do
            expect[#expect + 1] = string.char(byte(plain, #expect + 1) ~ byte(ks, i))
        end
        -- 大端自增
        local b = { byte(c, 1, 16) }
        for i = 16, 1, -1 do
            b[i] = (b[i] + 1) % 256
            if b[i] ~= 0 then
                break
            end
        end
        c = string.char(table.unpack(b))
    end
    assert(encrypted == table.concat(expect), 'CTR 计数器进位错误')
end

-- 非法入参
do
    local function expectError(fn, label)
        local ok = pcall(fn)
        assert(not ok, '应当报错: ' .. label)
    end
    expectError(function () aes.new('short') end, '密钥长度')
    expectError(function () aes.new(string.rep('k', 15)) end, '密钥长度 15')
    expectError(function () aes.new(123) end, '密钥类型')

    local ctx = aes.new(string.rep('k', 16))
    local iv = string.rep('\0', 16)
    expectError(function () ctx:encryptBlock('123') end, '块长度')
    expectError(function () ctx:encryptBlock(123) end, '块类型')
    expectError(function () ctx:decryptBlock('') end, '空块')
    expectError(function () ctx:encryptCBC('x', 'iv') end, 'iv 长度')
    expectError(function () ctx:encryptCBC('123', iv, false) end, '关闭填充但长度不合法')
    expectError(function () ctx:encryptCTR('x', 'iv') end, 'CTR iv 长度')
    expectError(function () ctx:decryptCBC('123', iv) end, '密文长度不合法')
    expectError(function () ctx:decryptECB('123') end, 'ECB 密文长度不合法')

    -- 填充损坏
    local cipher = ctx:encryptECB('hello world')
    local broken = cipher:sub(1, -2) .. string.char(0xEE)
    expectError(function () ctx:decryptECB(broken) end, '填充字节非法')

    -- 数据长度正好 16 且关闭填充时应当成功
    local blockData = string.rep('a', 16)
    local raw = ctx:encryptCBC(blockData, iv, false)
    assert(#raw == 16)
    assert(ctx:decryptCBC(raw, iv, false) == blockData)
end

-- 吞吐量（仅供观察，不做断言）
do
    local ctx = aes.new(string.rep('\1', 16))
    local size = 256 * 1024
    local data = string.rep('\0', size)
    local t1 = os.clock()
    local encrypted = ctx:encryptCTR(data, string.rep('\0', 16))
    local encTime = os.clock() - t1
    local t2 = os.clock()
    local decrypted = ctx:decryptCTR(encrypted, string.rep('\0', 16))
    local decTime = os.clock() - t2
    assert(#decrypted == size)
    print(('AES-128 CTR 吞吐：加密 %.2f MB/s，解密 %.2f MB/s')
        :format(size / 1024 / 1024 / encTime, size / 1024 / 1024 / decTime))
end

print('AES 测试完成')
