require 'globalclass'
local pool = require 'pool'

print('开始测试 Pool')

local p1 = pool.create()

for i = 1, 1700 do
    p1:add(tostring(i), i)
end

local max = 10
local results
local c1 = os.clock()
for i = 1, max do
    results = p1:random_n(24)
end
local c2 = os.clock()
table.sort(results, function (a, b)
    return tonumber(a) > tonumber(b)
end)
print('随机抽取耗时:', (c2 - c1) / max * 1000, '毫秒,最后一次结果为：', table.concat(results, ','))

print('Pool 测试完成')
