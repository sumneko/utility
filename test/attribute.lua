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

print('attribute 测试完成')
