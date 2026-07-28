local mf = require 'merge-files'

do
    local value = math.random(1, 10000)
    io.open('temp.lua', 'wb'):write('return ' .. value)

    local list = {}
    for name in io.popen('dir /b *.lua'):read('*a'):gmatch('[^\r\n]+') do
        list[#list+1] = name
    end

    local result = mf.byFileList(list)

    os.remove('temp.lua')

    io.open('test/output/merged.lua', 'wb'):write(result):close()

    dofile('test/output/merged.lua')

    package.path = package.path .. ';?.lua'
    local v = require 'temp'
    assert(v == value)
end
