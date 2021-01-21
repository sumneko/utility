---@class string.merger.diff
---@field start  integer # 替换开始的字节
---@field finish integer # 替换结束的字节
---@field text   string  # 替换的文本

---@alias string.merger.diffs string.merger.diff[]

local m = {}

---把文本与差异进行合并
---@param text  string
---@param diffs string.merger.diffs
---@return string
function m.mergeDiff(text, diffs)
    table.sort(diffs, function (a, b)
        return a.start < b.start
    end)
    local cur = 1
    local buf = {}
    for _, diff in ipairs(diffs) do
        buf[#buf+1] = text:sub(cur, diff.start - 1)
        buf[#buf+1] = diff.text
        cur = diff.finish + 1
    end
    buf[#buf+1] = text:sub(cur)
    return table.concat(buf)
end

return m
