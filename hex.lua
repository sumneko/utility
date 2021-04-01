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
    local define = self._define
    local idx = 1
    local root = {}
    local buildExp, buildChunk, buildCase

    local map = {}

    buildExp = function (ct, exp, i, stack)
        local k, fmt, index = splitDefine(exp, i)
        local fmtDef = define[fmt]
        if fmtDef then
            if index then
                assert(ct[index], 'No index:' .. index)
                ct[k] = {}
                for x = 1, ct[index] do
                    ct[k][x] = {}
                    buildChunk(ct[k][x], fmtDef, stack)
                end
            else
                ct[k] = {}
                buildChunk(ct[k], fmtDef, stack)
            end
        else
            ct[k], idx = fmt:unpack(hex, idx)
        end
    end

    buildCase = function (ct, case, i, stack)
        local env = setmetatable({}, { __index = function (_, k)
            for a = stack, 0, -1 do
                local v = map[a][k]
                if v then
                    return v
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
                buildCase(ct, cdef[i], i, stack + 1)
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
                local v = map[a][k]
                if v then
                    return v
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
