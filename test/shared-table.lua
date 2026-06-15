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
