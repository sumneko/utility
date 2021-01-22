---@class string.merger.diff
---@field start  integer # 替换开始的字节
---@field finish integer # 替换结束的字节
---@field text   string  # 替换的文本

---@class string.merger.info: string.merger.diff
---@field delta integer  # 从开始到现在的差量值

---@alias string.merger.diffs string.merger.diff[]
---@alias string.merger.infos string.merger.info[]

-- 根据二分法找到最近的开始位置
---@param diffs  table
---@param offset any
---@return string.merger.info
local function getNearDiff(diffs, offset)
    local min = 1
    local max = #diffs
    while max > min do
        local middle = min + (max - min) // 2
        local diff  = diffs[middle]
        local ndiff = diffs[middle + 1]
        if diff.start > offset then
            max = middle
            goto CONTINUE
        end
        if not ndiff then
            return diff
        end
        if ndiff.start > offset then
            return diff
        end
        if min == middle then
            min = middle + 1
        else
            min = middle
        end
        ::CONTINUE::
    end
    return diffs[min]
end

local m = {}

---把文本与差异进行合并
---@param text  string
---@param diffs string.merger.diffs
---@return string
---@return string.merger.infos
function m.mergeDiff(text, diffs)
    local info = {}
    for i, diff in ipairs(diffs) do
        info[i] = {
            start  = diff.start,
            finish = diff.finish,
            text   = diff.text,
        }
    end
    table.sort(info, function (a, b)
        return a.start < b.start
    end)
    local cur = 1
    local buf = {}
    local delta = 0
    for _, diff in ipairs(info) do
        diff.delta = delta
        buf[#buf+1] = text:sub(cur, diff.start - 1)
        buf[#buf+1] = diff.text
        cur = diff.finish + 1
        delta = delta - (diff.finish - diff.start + 1) + #diff.text
    end
    buf[#buf+1] = text:sub(cur)
    return table.concat(buf), info
end

---根据转换前的位置获取转换后的位置
---@param info   string.merger.infos
---@param offset integer
---@return integer
function m.getOffset(info, offset)
    local diff = getNearDiff(info, offset)
    if offset <= diff.finish then
        return diff.start + diff.delta
    end
    return offset + diff.start - diff.finish - 1 + #diff.text + diff.delta
end

return m
