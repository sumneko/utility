local m = {}

local mt = {}
mt.__index = mt

local function splitDefine(def)
    local k, fmt = def:match '^(.-)%:(.+)$'
    local index
    local a, b = fmt:find '%[.-%]'
    if a then
        index = fmt:sub(a + 1, b - 1)
        fmt = fmt:sub(1, a - 1)
    end
    return k, fmt, index
end

function mt:decode(hex)
    local define = self._define
    local idx = 1
    local link = {}
    local root = {}
    local buildExp, buildChunk, buildCase

    local function newLink(p)
        local t = {}
        link[t] = p
        return t
    end

    local function getIndex(t, k)
        if not t then
            return nil
        end
        if t[k] ~= nil then
            return t[k]
        end
        return getIndex(link[t], k)
    end

    buildExp = function (ct, exp)
        local k, fmt, index = splitDefine(exp)
        local fmtDef = define[fmt]
        if fmtDef then
            if index then
                assert(ct[index], 'No index:' .. index)
                ct[k] = {}
                for x = 1, ct[index] do
                    ct[k][x] = newLink(ct)
                    buildChunk(ct[k][x], fmtDef)
                end
            else
                ct[k] = newLink(ct)
                buildChunk(ct[k], fmtDef)
            end
        else
            ct[k], idx = fmt:unpack(hex, idx)
        end
    end

    buildCase = function (ct, case)
        local env = setmetatable({}, { __index = function (_, k)
            return getIndex(ct, k)
        end })
        local caseBuf = 'return ' .. case.case
        local caseF = assert(load(caseBuf, caseBuf, 't', env))
        if caseF() then
            buildExp(ct, case.exp)
        end
    end

    buildChunk = function (ct, cdef)
        for i = 1, #cdef do
            if type(cdef[i]) == 'string' then
                buildExp(ct, cdef[i])
            elseif cdef[i].type == 'case' then
                buildCase(ct, cdef[i])
            end
        end
        ct[''] = nil
    end

    buildChunk(root, define)

    return root
end

function mt:encode(data)
    local define = self._define
    local buf = {}
    local buildChunk, buildExp

    buildExp = function (ct, exp)
        local k, fmt, index = splitDefine(exp)
        local fmtDef = define[fmt]
        if fmtDef then
            if index then
                assert(ct[index], 'No index:' .. index)
                for x = 1, ct[index] do
                    buildChunk(ct[k][x], fmtDef)
                end
            else
                buildChunk(ct[k], fmtDef)
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

    buildChunk = function (ct, cdef)
        for i = 1, #cdef do
            if type(cdef[i]) == 'string' then
                buildExp(ct, cdef[i])
            elseif cdef[i].type == 'case' then
                -- TODO
                --buildCase(ct, cdef[i])
            end
        end
    end

    buildChunk(data, define)

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
