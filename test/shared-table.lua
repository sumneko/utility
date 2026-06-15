---@diagnostic disable: duplicate-set-field
local sharedTable = require 'shared-table'

print('开始测试 SharedTable')

-- 基础：单层 set / dump / load / 修改 / exportChanges / importChanges
do
    local st = sharedTable.create()
    st.trap.x = 1
    st.trap.y = 2
    st.trap.z = true
    st.trap.s = 'hello'

    assert(st.value.x == 1)
    assert(st.value.y == 2)
    assert(st.value.z == true)
    assert(st.value.s == 'hello')
    assert(st:isTouched())

    local dump = st:dump()
    local recv = sharedTable.load(dump)
    assert(recv.x == 1)
    assert(recv.y == 2)
    assert(recv.z == true)
    assert(recv.s == 'hello')

    -- 第一次 export 含初始 set
    local changes = st:exportChanges()
    assert(changes ~= nil)
    assert(not st:isTouched())
    sharedTable.importChanges(recv, changes)
    assert(recv.x == 1)
    assert(recv.y == 2)
    assert(recv.z == true)
    assert(recv.s == 'hello')

    -- 二次修改
    st.trap.x = 100
    st.trap.y = nil
    st.trap.s = 'world'
    local c2 = st:exportChanges()
    assert(c2 ~= nil)
    sharedTable.importChanges(recv, c2)
    assert(recv.x == 100)
    assert(recv.y == nil)
    assert(recv.z == true)
    assert(recv.s == 'world')

    -- 无变更
    assert(st:exportChanges() == nil)
end

-- 嵌套子表
do
    local st = sharedTable.create({
        sub = { a = 1, b = { c = 2 } },
    })
    local dump = st:dump()
    local recv = sharedTable.load(dump)
    assert(recv.sub.a == 1)
    assert(recv.sub.b.c == 2)

    st.trap.sub.a = 11
    st.trap.sub.b.c = 22
    local c = st:exportChanges()
    assert(c)
    sharedTable.importChanges(recv, c)
    assert(recv.sub.a == 11)
    assert(recv.sub.b.c == 22)
end

-- 新插入的嵌套子表（核心：BFS 注册）
do
    local st = sharedTable.create()
    local dump = st:dump()
    local recv = sharedTable.load(dump)

    st:exportChanges() -- 清空首次的 set（root 此时为空）

    st.trap.tree = {
        left  = { v = 1, leaf = { x = 1 } },
        right = { v = 2 },
    }
    local c1 = st:exportChanges()
    assert(c1)
    assert(c1.newBind ~= nil)
    sharedTable.importChanges(recv, c1)
    assert(recv.tree.left.v == 1)
    assert(recv.tree.left.leaf.x == 1)
    assert(recv.tree.right.v == 2)

    -- 修改深处的叶子，验证嵌套子表已被正确绑定
    st.trap.tree.left.leaf.x = 999
    st.trap.tree.right.v = 22
    local c2 = st:exportChanges()
    assert(c2)
    sharedTable.importChanges(recv, c2)
    assert(recv.tree.left.leaf.x == 999)
    assert(recv.tree.right.v == 22)
end

-- 删除
do
    local st = sharedTable.create({ a = 1, b = 2, c = { d = 3 } })
    local recv = sharedTable.load(st:dump())
    st:exportChanges()

    st.trap.a = nil
    st.trap.c.d = nil
    local c = st:exportChanges()
    assert(c)
    assert(c.del ~= nil)
    sharedTable.importChanges(recv, c)
    assert(recv.a == nil)
    assert(recv.b == 2)
    assert(recv.c.d == nil)
end

-- 不支持的值类型应报错
do
    local st = sharedTable.create()
    local lastErr
    local rawError = error
    _G.error = function (msg) lastErr = msg end
    st.trap.bad = function () end
    _G.error = rawError
    assert(type(lastErr) == 'string')
    assert(lastErr:find('不支持的值类型'))
    assert(lastErr:find('bad'))
end

-- 嵌套路径中的不支持值
do
    local st = sharedTable.create({ a = { b = {} } })
    local lastErr
    local rawError = error
    _G.error = function (msg) lastErr = msg end
    st.trap.a.b.c = coroutine.create(function () end)
    _G.error = rawError
    assert(type(lastErr) == 'string')
    assert(lastErr:find('a%.b%.c'))
end

-- 同一子表被多个键引用（共享引用）
do
    local shared = { v = 1 }
    local st = sharedTable.create({ x = shared, y = shared })
    local recv = sharedTable.load(st:dump())
    -- 接收方 dump 阶段：x 和 y 是同一个 table
    assert(recv.x == recv.y)

    st.trap.x.v = 42
    local c = st:exportChanges()
    assert(c)
    sharedTable.importChanges(recv, c)
    assert(recv.x.v == 42)
    assert(recv.y.v == 42)
end

-- importChanges 对未 load 的表应报错
do
    local lastErr
    local rawError = error
    _G.error = function (msg) lastErr = msg end
    sharedTable.importChanges({}, { set = {} })
    _G.error = rawError
    assert(type(lastErr) == 'string')
    assert(lastErr:find('not a shared table'))
end

-- 多次连续修改的合并
do
    local st = sharedTable.create({ n = 0 })
    local recv = sharedTable.load(st:dump())
    st:exportChanges()

    for i = 1, 10 do
        st.trap.n = i
    end
    local c = st:exportChanges()
    assert(c)
    sharedTable.importChanges(recv, c)
    assert(recv.n == 10)
end

-- isTouched 行为
do
    local st = sharedTable.create()
    assert(not st:isTouched())
    st.trap.a = 1
    assert(st:isTouched())
    st:exportChanges()
    assert(not st:isTouched())
end

print('SharedTable 测试通过')

-- 性能测试
print('开始 SharedTable 性能测试')

-- create 大表（扁平）
do
    local n = 10000
    local data = {}
    for i = 1, n do
        data[i] = i
    end
    local times = 50
    local c1 = os.clock()
    for _ = 1, times do
        sharedTable.create(data)
    end
    local c2 = os.clock()
    local total = (c2 - c1) * 1000
    print(string.format('  create %d 元素扁平表 x %d: 总 %.3f 毫秒, 平均 %.4f 微秒/次',
        n, times, total, total * 1000 / times))
end

-- 顶层写入
do
    local n = 100000
    local times = 5
    local sts = {}
    for i = 1, times do
        sts[i] = sharedTable.create()
    end
    local c1 = os.clock()
    for k = 1, times do
        local trap = sts[k].trap
        for i = 1, n do
            trap[i] = i
        end
    end
    local c2 = os.clock()
    local total = (c2 - c1) * 1000
    print(string.format('  顶层写入 %d 次 x %d: 总 %.3f 毫秒, 平均 %.4f 微秒/次',
        n, times, total, total * 1000 / (n * times)))
end

-- 深层路径写入
do
    local n = 100000
    local times = 5
    local sts = {}
    for i = 1, times do
        sts[i] = sharedTable.create({ a = { b = { c = { d = { e = 0 } } } } })
    end
    local c1 = os.clock()
    for k = 1, times do
        local trap = sts[k].trap
        for i = 1, n do
            trap.a.b.c.d.e = i
        end
    end
    local c2 = os.clock()
    local total = (c2 - c1) * 1000
    print(string.format('  5层深路径写入 %d 次 x %d: 总 %.3f 毫秒, 平均 %.4f 微秒/次 ',
        n, times, total, total * 1000 / (n * times)))
end

-- exportChanges（少量顶层 set）
do
    local n = 50
    local times = 10000
    local sts = {}
    for k = 1, times do
        local st = sharedTable.create()
        local trap = st.trap
        for i = 1, n do
            trap[i] = i
        end
        sts[k] = st
    end
    local c1 = os.clock()
    for k = 1, times do
        sts[k]:exportChanges()
    end
    local c2 = os.clock()
    local total = (c2 - c1) * 1000
    print(string.format('  exportChanges (%d 顶层 set) x %d: 总 %.3f 毫秒, 平均 %.4f 毫秒/次',
        n, times, total, total / times))
end

-- importChanges（少量顶层 set）
do
    local n = 50
    local times = 10000
    local st = sharedTable.create()
    local recv = sharedTable.load(st:dump())
    local trap = st.trap
    for i = 1, n do
        trap[i] = i
    end
    local changes = st:exportChanges()
    assert(changes)
    local c1 = os.clock()
    for _ = 1, times do
        sharedTable.importChanges(recv, changes)
    end
    local c2 = os.clock()
    local total = (c2 - c1) * 1000
    print(string.format('  importChanges (%d 顶层 set) x %d: 总 %.3f 毫秒, 平均 %.4f 毫秒/次',
        n, times, total, total / times))
end

-- exportChanges（大量顶层 set）
do
    local n = 50000
    local times = 20
    local sts = {}
    for k = 1, times do
        local st = sharedTable.create()
        local trap = st.trap
        for i = 1, n do
            trap[i] = i
        end
        sts[k] = st
    end
    local c1 = os.clock()
    for k = 1, times do
        sts[k]:exportChanges()
    end
    local c2 = os.clock()
    local total = (c2 - c1) * 1000
    print(string.format('  exportChanges (%d 顶层 set) x %d: 总 %.3f 毫秒, 平均 %.4f 毫秒/次',
        n, times, total, total / times))
end

-- importChanges（大量顶层 set）
do
    local n = 50000
    local times = 20
    local st = sharedTable.create()
    local recv = sharedTable.load(st:dump())
    local trap = st.trap
    for i = 1, n do
        trap[i] = i
    end
    local changes = st:exportChanges()
    assert(changes)
    local c1 = os.clock()
    for _ = 1, times do
        sharedTable.importChanges(recv, changes)
    end
    local c2 = os.clock()
    local total = (c2 - c1) * 1000
    print(string.format('  importChanges (%d 顶层 set) x %d: 总 %.3f 毫秒, 平均 %.4f 毫秒/次',
        n, times, total, total / times))
end

-- 插入嵌套子表（写入阶段）
do
    local n = 5000
    local times = 20
    local sts = {}
    for k = 1, times do
        local st = sharedTable.create()
        st:exportChanges()
        sts[k] = st
    end
    local c1 = os.clock()
    for k = 1, times do
        local trap = sts[k].trap
        for i = 1, n do
            trap[i] = { id = i, sub = { v = i * 2 } }
        end
    end
    local c2 = os.clock()
    local total = (c2 - c1) * 1000
    print(string.format('  插入 %d 个嵌套子表 x %d (写入阶段): 总 %.3f 毫秒, 平均 %.4f 毫秒/次',
        n, times, total, total / times))
end

-- exportChanges（新嵌套 newBind）
do
    local n = 5000
    local times = 20
    local sts = {}
    for k = 1, times do
        local st = sharedTable.create()
        st:exportChanges()
        local trap = st.trap
        for i = 1, n do
            trap[i] = { id = i, sub = { v = i * 2 } }
        end
        sts[k] = st
    end
    local c1 = os.clock()
    for k = 1, times do
        sts[k]:exportChanges()
    end
    local c2 = os.clock()
    local total = (c2 - c1) * 1000
    print(string.format('  exportChanges (%d 新嵌套 newBind) x %d: 总 %.3f 毫秒, 平均 %.4f 毫秒/次',
        n * 2, times, total, total / times))
end

-- importChanges（新嵌套）
do
    local n = 5000
    local times = 20
    local st = sharedTable.create()
    local recv = sharedTable.load(st:dump())
    st:exportChanges()
    local trap = st.trap
    for i = 1, n do
        trap[i] = { id = i, sub = { v = i * 2 } }
    end
    local changes = st:exportChanges()
    assert(changes)
    local c1 = os.clock()
    for _ = 1, times do
        sharedTable.importChanges(recv, changes)
    end
    local c2 = os.clock()
    local total = (c2 - c1) * 1000
    print(string.format('  importChanges (%d 新嵌套) x %d: 总 %.3f 毫秒, 平均 %.4f 毫秒/次',
        n * 2, times, total, total / times))
end

-- create 深嵌套大表
do
    local function build(depth, width)
        if depth == 0 then
            return 1
        end
        local t = {}
        for i = 1, width do
            t[i] = build(depth - 1, width)
        end
        return t
    end
    local times = 20
    local datas = {}
    for k = 1, times do
        local d = build(5, 8) -- 8^5 = 32768 叶子
        ---@cast d table
        datas[k] = d
    end
    local c1 = os.clock()
    for k = 1, times do
        sharedTable.create(datas[k])
    end
    local c2 = os.clock()
    local total = (c2 - c1) * 1000
    print(string.format('  create 深嵌套大表 (depth=5,width=8) x %d: 总 %.3f 毫秒, 平均 %.4f 毫秒/次',
        times, total, total / times))
end

-- dump 深嵌套大表
do
    local function build(depth, width)
        if depth == 0 then
            return 1
        end
        local t = {}
        for i = 1, width do
            t[i] = build(depth - 1, width)
        end
        return t
    end
    local data = build(5, 8)
    ---@cast data table
    local st = sharedTable.create(data)
    local times = 50
    local c1 = os.clock()
    for _ = 1, times do
        st:dump()
    end
    local c2 = os.clock()
    local total = (c2 - c1) * 1000
    print(string.format('  dump 深嵌套大表 x %d: 总 %.3f 毫秒, 平均 %.4f 毫秒/次',
        times, total, total / times))
end

-- load 深嵌套大表
do
    local function build(depth, width)
        if depth == 0 then
            return 1
        end
        local t = {}
        for i = 1, width do
            t[i] = build(depth - 1, width)
        end
        return t
    end
    local times = 50
    local dumps = {}
    for k = 1, times do
        local d = build(5, 8)
        ---@cast d table
        dumps[k] = sharedTable.create(d):dump()
    end
    local c1 = os.clock()
    for k = 1, times do
        sharedTable.load(dumps[k])
    end
    local c2 = os.clock()
    local total = (c2 - c1) * 1000
    print(string.format('  load 深嵌套大表 x %d: 总 %.3f 毫秒, 平均 %.4f 毫秒/次',
        times, total, total / times))
end

-- 增量修改稳态（典型用例）
do
    local fields = 1000
    local rounds = 1000
    local st = sharedTable.create()
    local recv = sharedTable.load(st:dump())
    for i = 1, fields do
        st.trap[i] = { hp = 100, mp = 50 }
    end
    sharedTable.importChanges(recv, assert(st:exportChanges()))

    local trap = st.trap
    local c1 = os.clock()
    for r = 1, rounds do
        for i = 1, fields do
            trap[i].hp = r
        end
        sharedTable.importChanges(recv, assert(st:exportChanges()))
    end
    local c2 = os.clock()
    local total = (c2 - c1) * 1000
    print(string.format('  增量循环 %d 轮 x %d 字段: 总 %.3f 毫秒, 平均 %.4f 毫秒/轮',
        rounds, fields, total, total / rounds))
end

print('SharedTable 性能测试完成')
