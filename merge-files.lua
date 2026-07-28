local function merge(list, contents)
    local buf = {}

    buf[#buf+1] = 'local files = {}'
    buf[#buf+1] = [[
local function loader(name, path)
    return load(files[path], '@' .. path)()
end

package.searchers[#package.searchers+1] = function (name)
    local err = ''
    name = name:gsub('%.', '/')
    for path in package.path:gmatch '[^;]+' do
        local fileName = path:gsub('%?', name)
        if files[fileName] then
            return loader, fileName
        else
            err = err .. "no file '" .. fileName .. "'\n\t"
        end
    end
    return err
end
]]

    for _, fileName in ipairs(list) do
        local content = contents[fileName]
        if content then
            buf[#buf+1] = string.format('files[%q] = %q', fileName:gsub('\\', '/'), content)
        end
    end

    return table.concat(buf, '\n')
end

local API = {}

function API.byFileList(list, alias)
    local contents = {}
    for i, fileName in ipairs(list) do
        local f = io.open(fileName, 'rb')
        if f then
            if alias and alias[i] then
                fileName = alias[i]
            end
            contents[fileName] = f:read 'a'
            f:close()
        end
    end
    return merge(list, contents)
end

return API
