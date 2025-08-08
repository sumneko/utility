local attributeSystem = require 'attribute'

do
    local system = attributeSystem.create()

    system:define('攻击', false, 0, 10000)

    local instance = system:instance()

    instance:set('攻击', 1000)
    assert(instance:get('攻击') == 1000)

    instance:add('攻击', 500)
    assert(instance:get('攻击') == 1500)

    instance:add('攻击', -2000)
    assert(instance:get('攻击') == 0)

    instance:add('攻击', 1500)
    assert(instance:get('攻击') == 1000)

    instance:add('攻击%', 100)
    assert(instance:get('攻击!') == 1000)
    assert(instance:get('攻击%') == 100)
    assert(instance:get('攻击') == 2000)

    instance:set('攻击%', 10000)
    assert(instance:get('攻击!') == 1000)
    assert(instance:get('攻击%') == 10000)
    assert(instance:get('攻击') == 10000)
end

do
    local system = attributeSystem.create()

    system:define('生命', true, 0, 10000)

    local instance = system:instance()

    instance:set('生命', 1000)
    assert(instance:get('生命') == 1000)

    instance:add('生命', 500)
    assert(instance:get('生命') == 1500)

    instance:add('生命', -2000)
    assert(instance:get('生命') == 0)

    instance:add('生命', 1500)
    assert(instance:get('生命') == 1500)

    instance:add('生命', 1000000)
    assert(instance:get('生命') == 10000)

    instance:add('生命', -5000)
    assert(instance:get('生命') == 5000)
end

do
    local system = attributeSystem.create()

    system:define('攻击', false, 0, 10000)

    local instance = system:instance()

    local start = os.clock()
    for i = 1, 1000000 do
        instance:add('攻击', 1)
        instance:get('攻击')
    end
    local duration = os.clock() - start
    print('属性基准测试1耗时: ' .. duration .. '秒')

    local start = os.clock()
    for i = 1, 1000000 do
        instance:get('攻击')
    end
    local duration = os.clock() - start
    print('属性基准测试2耗时: ' .. duration .. '秒')
end

print('attribute 测试完成')
