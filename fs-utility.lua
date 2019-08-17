local fs           = require 'bee.filesystem'
local platform     = require 'bee.platform'

local type         = type
local ioOpen       = io.open
local pcall        = pcall
local pairs        = pairs
local setmetatable = setmetatable
local next         = next

_ENV = nil

local m = {}
--- 读取文件
---@param path string
function m.loadFile(path)
    if type(path) ~= 'string' then
        path = path:string()
    end
    local f, e = ioOpen(path, 'rb')
    if not f then
        return nil, e
    end
    if f:read(3) ~= '\xEF\xBB\xBF' then
        f:seek("set")
    end
    local buf = f:read 'a'
    f:close()
    return buf
end

--- 写入文件
---@param path string
---@param content string
function m.saveFile(path, content)
    if type(path) ~= 'string' then
        path = path:string()
    end
    local f, e = ioOpen(path, "wb")

    if f then
        f:write(content)
        f:close()
        return true
    else
        return false, e
    end
end

local function fileInfo()
    local info = {
        add = {},
        del = {},
        mod = {},
        err = {},
    }
    return info
end

local function fsAbsolute(path, info)
    if type(path) == 'string' then
        local suc, res = pcall(fs.path, path)
        if not suc then
            info.err[#info.err+1] = res
            return nil
        end
        path = res
    end
    local suc, res = pcall(fs.absolute, path)
    if not suc then
        info.err[#info.err+1] = res
        return nil
    end
    return res
end

local function fsIsDirectory(path, info)
    local suc, res = pcall(fs.is_directory, path)
    if not suc then
        info.err[#info.err+1] = res
        return false
    end
    return res
end

local function fsRemove(path, info)
    local suc, res = pcall(fs.remove, path)
    if not suc then
        info.err[#info.err+1] = res
    end
    info.del[#info.del+1] = path:string()
end

local function fsExists(path, info)
    local suc, res = pcall(fs.exists, path)
    if not suc then
        info.err[#info.err+1] = res
        return false
    end
    return res
end

local function fsCopy(source, target, info)
    local suc, res = pcall(fs.copy_file, source, target)
    if not suc then
        info.err[#info.err+1] = res
        return false
    end
    return true
end

local function fsCreateDirectories(path, info)
    local suc, res = pcall(fs.create_directories, path)
    if not suc then
        info.err[#info.err+1] = res
        return false
    end
    return true
end

local function fileRemove(path, info)
    if fsIsDirectory(path, info) then
        for child in path:list_directory() do
            fileRemove(child, info)
        end
    else
        if fsRemove(path, info) then
            info.del[#info.del+1] = path:string()
        end
    end
end

local function fileCopy(source, target, info)
    local isDir1   = fsIsDirectory(source, info)
    local isDir2   = fsIsDirectory(target, info)
    local isExists = fsExists(target, info)
    if isDir1 then
        if isDir2 or fsCreateDirectories(target) then
            for filePath in source:list_directory() do
                local name = filePath:filename()
                fileCopy(filePath, target / name, info)
            end
        end
    else
        if isExists and not isDir2 then
            local buf1, err1 = m.loadFile(source)
            local buf2, err2 = m.loadFile(target)
            if buf1 and buf2 then
                if buf1 ~= buf2 then
                    if fsCopy(source, target, info) then
                        info.mod[#info.mod+1] = target:string()
                    end
                end
            else
                if not buf1 then
                    info.err[#info.err+1] = err1
                end
                if not buf2 then
                    info.err[#info.err+1] = err2
                end
            end
        else
            if fsCopy(source, target, info) then
                info.add[#info.add+1] = target:string()
            end
        end
    end
end

local function fileSync(source, target, info)
    local isDir1   = fsIsDirectory(source, info)
    local isDir2   = fsIsDirectory(target, info)
    local isExists = fsExists(target, info)
    if isDir1 then
        if isDir2 then
            local fileList = m.fileList()
            for filePath in target:list_directory() do
                fileList[filePath] = true
            end
            for filePath in source:list_directory() do
                local name = filePath:filename()
                local targetPath = target / name
                fileSync(filePath, targetPath, info)
                fileList[targetPath] = nil
            end
            for path in pairs(fileList) do
                fileRemove(path, info)
            end
        else
            if isExists then
                fileRemove(target, info)
            end
            if fsCreateDirectories(target) then
                for filePath in source:list_directory() do
                    local name = filePath:filename()
                    fileCopy(filePath, target / name, info)
                end
            end
        end
    else
        if isDir2 then
            fileRemove(target, info)
        end
        if isExists then
            local buf1, err1 = m.loadFile(source)
            local buf2, err2 = m.loadFile(target)
            if buf1 and buf2 then
                if buf1 ~= buf2 then
                    if fsCopy(source, target, info) then
                        info.mod[#info.mod+1] = target:string()
                    end
                end
            else
                if not buf1 then
                    info.err[#info.err+1] = err1
                end
                if not buf2 then
                    info.err[#info.err+1] = err2
                end
            end
        else
            if fsCopy(source, target, info) then
                info.add[#info.add+1] = target:string()
            end
        end
    end
end

--- 文件列表
function m.fileList()
    local os = platform.OS
    local info = fileInfo()
    local keyMap = {}
    local fileList = {}
    local function computeKey(path)
        path = fsAbsolute(path, info)
        if not path then
            return nil
        end
        local key
        if os == 'Windows' then
            key = path:string():lower()
        else
            key = path:string()
        end
        return key
    end
    return setmetatable({}, {
        __index = function (_, path)
            local key = computeKey(path)
            return fileList[key]
        end,
        __newindex = function (_, path, value)
            local key = computeKey(path)
            if not key then
                return
            end
            if value == nil then
                keyMap[key] = nil
            else
                keyMap[key] = path
                fileList[key] = value
            end
        end,
        __pairs = function ()
            local key, path
            return function ()
                key, path = next(keyMap, key)
                return path, fileList[key]
            end
        end,
    })
end

--- 删除文件（夹）
function m.fileRemove(path)
    local info = fileInfo()
    path = fsAbsolute(path, info)

    fileRemove(path, info)

    return info
end

--- 复制文件（夹）
---@param source string
---@param target string
---@return table
function m.fileCopy(source, target)
    local info = fileInfo()
    source = fsAbsolute(source, info)
    target = fsAbsolute(target, info)

    fileCopy(source, target, info)

    return info
end

--- 同步文件（夹）
---@param source string
---@param target string
---@return table
function m.fileSync(source, target)
    local info = fileInfo()
    source = fsAbsolute(source, info)
    target = fsAbsolute(target, info)

    fileSync(source, target, info)

    return info
end

return m
