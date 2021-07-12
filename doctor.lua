local type           = type
local next           = next
local pairs          = pairs
local ipairs         = ipairs
local rawget         = rawget
local pcall          = pcall
local getregistry    = debug.getregistry
local getmetatable   = debug.getmetatable
local getupvalue     = debug.getupvalue
local getuservalue   = debug.getuservalue
local getlocal       = debug.getlocal
local getinfo        = debug.getinfo
local maxinterger    = math.maxinteger
local mathType       = math.type
local _G             = _G
local registry       = getregistry()

local m = {}

_ENV = nil

local function getTostring(obj)
    local mt = getmetatable(obj)
    if not mt then
        return nil
    end
    local toString = rawget(mt, '__tostring')
    if not toString then
        return nil
    end
    local suc, str = pcall(toString, obj)
    if not suc then
        return nil
    end
    if type(str) ~= 'string' then
        return nil
    end
    return str
end

local function formatName(obj)
    local tp = type(obj)
    if tp == 'nil' then
        return 'nil:nil'
    elseif tp == 'boolean' then
        if obj == true then
            return 'boolean:true'
        else
            return 'boolean:false'
        end
    elseif tp == 'number' then
        if mathType(obj) == 'integer' then
            return ('number:%d'):format(obj)
        else
            -- 如果浮点数可以完全表示为整数，那么就转换为整数
            local str = ('%.10f'):format(obj):gsub('%.?[0]+$', '')
            if str:find('.', 1, true) then
                -- 如果浮点数不能表示为整数，那么再加上它的精确表示法
                str = ('%s(%q)'):format(str, obj)
            end
            return 'number:' .. str
        end
    elseif tp == 'string' then
        local str = ('%q'):format(obj)
        if #str > 100 then
            local new = ('%s...(len=%d)'):format(str:sub(1, 100), #str)
            if #new < #str then
                str = new
            end
        end
        return 'string:' .. str
    elseif tp == 'function' then
        local info = getinfo(obj, 'S')
        if info.what == 'c' then
            return ('function:%p(C)'):format(obj)
        elseif info.what == 'main' then
            return ('function:%p(main)'):format(obj)
        else
            return ('function:%p(%s:%d-%d)'):format(obj, info.source, info.linedefined, info.lastlinedefined)
        end
    elseif tp == 'table' then
        local id = getTostring(obj)
        if not id then
            if obj == _G then
                id = '_G'
            elseif obj == registry then
                id = 'registry'
            end
        end
        if id then
            return ('table:%p(%s)'):format(obj, id)
        else
            return ('table:%p'):format(obj)
        end
    elseif tp == 'userdata' then
        local id = getTostring(obj)
        if id then
            return ('userdata:%p(%s)'):format(obj, id)
        else
            return ('userdata:%p'):format(obj)
        end
    else
        return ('%s:%p'):format(tp, obj)
    end
end

--- 获取内存快照，生成一个内部数据结构。
--- 一般不用这个API，改用 report 或 catch。
---@return table
function m.snapshot()
    local mark = {}
    local find
    local pushtoqueue
    local queue = {}
    local exclude = {}

    if m._exclude then
        for _, o in ipairs(m._exclude) do
            exclude[o] = true
        end
    end

    local function findTable(t, result)
        result = result or {}
        local mt = getmetatable(t)
        local wk, wv
        if mt then
            local mode = rawget(mt, '__mode')
            if type(mode) == 'string' then
                if mode:find('k', 1, true) then
                    wk = true
                end
                if mode:find('v', 1, true) then
                    wv = true
                end
            end
        end
        for k, v in next, t do
            if not wk then
                local keyInfo = pushtoqueue(k)
                if keyInfo then
                    result[#result+1] = {
                        type = 'key',
                        name = formatName(k),
                        info = keyInfo,
                    }
                end
            end
            if not wv then
                local valueInfo = pushtoqueue(v)
                if valueInfo then
                    result[#result+1] = {
                        type = 'field',
                        name = formatName(k) .. '|' .. formatName(v),
                        info = valueInfo,
                    }
                end
            end
        end
        local MTInfo = pushtoqueue(getmetatable(t))
        if MTInfo then
            result[#result+1] = {
                type = 'metatable',
                name = '',
                info = MTInfo,
            }
        end
        if #result == 0 then
            return nil
        end
        return result
    end

    local function findFunction(f, result, trd, stack)
        result = result or {}
        for i = 1, maxinterger do
            local n, v = getupvalue(f, i)
            if not n then
                break
            end
            local valueInfo = pushtoqueue(v)
            if valueInfo then
                result[#result+1] = {
                    type = 'upvalue',
                    name = n,
                    info = valueInfo,
                }
            end
        end
        if trd then
            for i = 1, maxinterger do
                local n, l = getlocal(trd, stack, i)
                if not n then
                    break
                end
                local valueInfo = pushtoqueue(l)
                if valueInfo then
                    result[#result+1] = {
                        type = 'local',
                        name = n,
                        info = valueInfo,
                    }
                end
            end
        end
        if #result == 0 then
            return nil
        end
        return result
    end

    local function findUserData(u, result)
        result = result or {}
        for i = 1, maxinterger do
            local v, b = getuservalue(u, i)
            if not b then
                break
            end
            local valueInfo = pushtoqueue(v)
            if valueInfo then
                result[#result+1] = {
                    type = 'uservalue',
                    name = formatName(i),
                    info = valueInfo,
                }
            end
        end
        local MTInfo = pushtoqueue(getmetatable(u))
        if MTInfo then
            result[#result+1] = {
                type = 'metatable',
                name = '',
                info = MTInfo,
            }
        end
        if #result == 0 then
            return nil
        end
        return result
    end

    local function findThread(trd, result)
        -- 不查找主线程，主线程一定是临时的（视为弱引用）
        if trd == registry[1] then
            return nil
        end
        result = result or {}

        for i = 1, maxinterger do
            local info = getinfo(trd, i, 'Sf')
            if not info then
                break
            end
            local funcInfo = pushtoqueue(info.func, trd, i)
            if funcInfo then
                result[#result+1] = {
                    type = 'stack',
                    name = i .. '@' .. formatName(info.func),
                    info = funcInfo,
                }
            end
        end

        if #result == 0 then
            return nil
        end
        return result
    end

    function find(obj, trd, stack)
--        if mark[obj] then
--            return mark[obj]
--        end
        local tp = type(obj)
        if tp == 'table' then
--            mark[obj] = {}
            mark[obj] = findTable(obj, mark[obj])
        elseif tp == 'function' then
--            mark[obj] = {}
            mark[obj] = findFunction(obj, mark[obj], trd, stack)
        elseif tp == 'userdata' then
--           mark[obj] = {}
            mark[obj] = findUserData(obj, mark[obj])
        elseif tp == 'thread' then
--            mark[obj] = {}
            mark[obj] = findThread(obj, mark[obj])
        else
            return nil
        end
        if mark[obj] then
            mark[obj].object = obj
        end
        return mark[obj]
    end

    function pushtoqueue(obj, trd, stack)
        if obj ~= obj or obj == nil then
            return
        end
        if mark[obj] or obj == nil then
            return mark[obj]
        end
        mark[obj] = {}
        queue[#queue + 1] = {obj, trd, stack}
        return mark[obj]
    end

    local function bfs()
        for i = 1, maxinterger do
            if not queue[i] then
                break
            end
            if not exclude[queue[i][1]] then
                find(queue[i][1], queue[i][2], queue[i][3])
            end
        end
    end

    pushtoqueue(registry)
    bfs()
    return {
        name = formatName(registry),
        type = 'root',
        info = mark[registry]
    }
end

--- 遍历虚拟机，寻找对象的引用。
--- 返回字符串数组，每个字符串描述了如何从根节点引用到指定的对象。
--- 可以同时查找多个对象。
---@return string[]
function m.catch(...)
    local targets = {}
    for _, target in ipairs {...} do
        targets[target] = true
    end
    local report = m.snapshot()
    local path = {}
    local result = {}
    local mark = {}

    local function push()
        local resultPath = {}
        for i = 1, #path do
            resultPath[i] = path[i]
        end
        result[#result+1] = resultPath
    end

    local function search(t)
        path[#path+1] = ('(%s)%s'):format(t.type, t.name)
        local addTarget
        local point = ('%p'):format(t.info.object)
        if targets[t.info.object] then
            targets[t.info.object] = nil
            addTarget = t.info.object
            push()
        end
        if targets[point] then
            targets[point] = nil
            addTarget = point
            push()
        end
        if not mark[t.info] then
            mark[t.info] = true
            for _, obj in ipairs(t.info) do
                search(obj)
            end
        end
        path[#path] = nil
        if addTarget then
            targets[addTarget] = true
        end
    end

    search(report)

    return result
end

--- 生成一个内存快照的报告。
--- 会返回一个字符串数组，每个字符串描述了一个对象以及它被引用的次数。
--- 你应当将其输出到一个文件里再查看。
---@return string[]
function m.report()
    local snapshot = m.snapshot()
    local cache = {}
    local mark = {}

    local function scan(t)
        local obj = t.info.object
        local tp = type(obj)
        if tp == 'table'
        or tp == 'userdata'
        or tp == 'function'
        or tp == 'string'
        or tp == 'thread' then
            local point = ('%p'):format(obj)
            if not cache[point] then
                cache[point] = {
                    point  = point,
                    count  = 0,
                    name   = formatName(obj),
                    childs = #t.info,
                }
            end
            cache[point].count = cache[point].count + 1
        end
        if not mark[t.info] then
            mark[t.info] = true
            for _, child in ipairs(t.info) do
                scan(child)
            end
        end
    end

    scan(snapshot)
    local list = {}
    for _, info in pairs(cache) do
        list[#list+1] = info
    end
    return list
end

--- 在进行快照相关操作时排除掉的对象。
--- 你可以用这个功能排除掉一些数据表。
function m.exclude(...)
    m._exclude = {...}
end

--- 比较2个报告
---@return string
function m.compare(old, new)
    local newHash = {}
    local ret = {}
    for _, info in ipairs(new) do
        newHash[info.point] = info
    end
    for _, info in ipairs(old) do
        if newHash[info.point] then
            ret[#ret + 1] = {
                old = info,
                new = newHash[info.point]
            }
        end
    end
    return ret
end
