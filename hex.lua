local m = {}

local mt = {}
mt.__index = mt

local function splitDefine(def, i)
    local k, fmt = def:match '^(.-)%:(.+)$'
    local index
    local a, b = fmt:find '%[.-%]'
    if a then
        index = fmt:sub(a + 1, b - 1)
        fmt = fmt:sub(1, a - 1)
    end
    if k == nil or k:len() == 0 or k == "" then
        k = i
    end
    return k, fmt, index
end

function mt:decode(hex)
    local total_size = #hex
    local define = self._define
    local idx = 1
    local root = {}
    local buildExp, buildChunk, buildCase

    local cur_size = {}

    buildExp = function (ct, exp, i, stack,parent)
        local k, fmt, index = splitDefine(exp, i)
        local fmtDef = define[fmt]
        -- print(idx,exp,fmtDef,fmt,k)
        fmt = define[fmt] or fmt
        if fmtDef then
            if index then
                local cal = index:match('^%??(.*)')
                if cal then
                    cal = load('return '..cal,index,'t',setmetatable({},{__index=function(_,key)
                        local ret = ct[key] or _G[key]
                        if not ret and key == '_BufferSize' then return total_size end
                        return ret
                    end}))
                    if cal then
                        cal = cal()
                        -- print('计算',cal)
                    end
                else
                    error('格式错误:'..index)
                end
                ct[k] = setmetatable({},{__index = ct})
                if index:match('^%?') then
                    --cal是size
                    cur_size[stack] = cal
                    local idx = 1
                    while cur_size[stack]>0 do
                        ct[k][idx] = setmetatable({},{__index = ct[k]})
                        buildChunk(ct[k][idx], fmtDef, stack,ct)
                        idx = idx + 1
                    end
                    assert(cur_size[stack]==0,cur_size[stack]..'块大小不符合:'..index)
                    cur_size[stack] = nil
                else
                    if type(fmtDef) == 'table' then
                        for x = 1, cal do
                            ct[k][x] = setmetatable({},{__index = ct[k]})
                            buildChunk(ct[k][x], fmtDef, stack,ct)
                        end
                    else
                        --别名(支持数组)
                        for x = 1, cal do
                            buildExp(ct[k],fmtDef,x,ct)
                        end
                    end
                end
            else
                ct[k] = setmetatable({},{__index = ct})
                buildChunk(ct[k], fmtDef, stack,ct)
            end
        else
            local curidx = idx
            ct[k], idx = fmt:unpack(hex, idx)
            -- print(ct[k])
            local size = idx - curidx
            for key, value in pairs(cur_size) do
                cur_size[key] = value - size
                -- print('size',key,cur_size[key])
            end
        end
    end

    buildCase = function (ct, case, i, stack,...)
        local env = setmetatable({},{__index=function(_,key)
            local ret = ct[key] or _G[key]
            if not ret and key == '_BufferSize' then return total_size end
            return ret
        end})
        local caseBuf = 'return ' .. case.case
        local caseF = assert(load(caseBuf, caseBuf, 't', env))
        if caseF() then
            -- print(case.case..':true')
            buildExp(ct, case.exp, i, stack,...)
        end
    end

    buildChunk = function (ct, cdef, stack,...)
        for i = 1, #cdef do
            if type(cdef)=='string' then
                --别名
                buildExp(ct, cdef, i, stack + 1,...)
                break
            elseif type(cdef[i]) == 'string' then
                buildExp(ct, cdef[i], i, stack + 1,...)
            elseif cdef[i].type == 'case' then
                buildCase(ct, cdef[i], i, stack + 1,...)
            end
        end
        ct[''] = nil
    end

    buildChunk(root, define, 0)

    return root
end

function mt:encode(data)
    local define = self._define
    local buf = {}
    local buildChunk, buildExp, buildCase

    local map = {}

    buildExp = function (ct, exp, i, stack)
        local k, fmt, index = splitDefine(exp, i)
        local fmtDef = define[fmt]
        if fmtDef then
            if index then
                assert(ct[index], 'No index:' .. index)
                for x = 1, ct[index] do
                    buildChunk(ct[k][x], fmtDef, stack)
                end
            else
                buildChunk(ct[k], fmtDef, stack)
            end
        else
            local v = ct[k]
            if v then
                buf[#buf+1] = fmt:pack(v)
            else
                if fmt == 'z' then
                    buf[#buf+1] = '\0'
                else
                    local size = fmt:packsize()
                    buf[#buf+1] = ('\0'):rep(size)
                end
            end
        end
    end

    buildCase = function (ct, case, i, stack)
        local env = setmetatable({}, { __index = function (_, k)
            for a = stack, 0, -1 do
                if map[a] then
                    local v = map[a][k]
                    if v then
                        return v
                    end
                end
            end
        end })
        local caseBuf = 'return ' .. case.case
        local caseF = assert(load(caseBuf, caseBuf, 't', env))
        if caseF() then
            buildExp(ct, case.exp, i, stack)
        end
    end

    buildChunk = function (ct, cdef, stack)
        map[stack] = ct
        for i = 1, #cdef do
            if type(cdef[i]) == 'string' then
                buildExp(ct, cdef[i], i, stack + 1)
            elseif cdef[i].type == 'case' then
                -- TODO
                buildCase(ct, cdef[i], i, stack + 1)
            end
        end
    end

    buildChunk(data, define, 0)

    return table.concat(buf)
end

function m.case(case, exp)
    return {
        type = 'case',
        case = case,
        exp  = exp,
    }
end

function m.define(t)
    return setmetatable({
        _define = t,
        _encode = nil,
        _decode = nil,
    }, mt)
end

return m
