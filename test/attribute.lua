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

    system:define('生命', true, 0, '最大生命')
    system:define('最大生命', false, 1)

    local instance = system:instance()

    instance:set('最大生命', 1000)
    instance:set('生命', 2000)
    assert(instance:getMin('生命') == 0)
    assert(instance:getMax('生命') == 1000)
    assert(instance:get('生命') == 1000)

    instance:set('最大生命', 500)
    assert(instance:getMin('生命') == 0)
    assert(instance:getMax('生命') == 500)
    assert(instance:get('生命') == 500)

    instance:set('最大生命', 10000)
    assert(instance:getMin('生命') == 0)
    assert(instance:getMax('生命') == 10000)
    assert(instance:get('生命') == 500)
end

do
    local system = attributeSystem.create()

    system:define('生命', true, 0)
        : setMax('最大生命', true)
    system:define('最大生命', false, 1)

    local instance = system:instance()

    instance:set('最大生命', 1000)
    instance:set('生命', 500)

    instance:add('最大生命%', 100)
    assert(instance:get('最大生命') == 2000)
    assert(instance:get('生命') == 1000)
end

do
    local system = attributeSystem.create()

    system:define('最大生命')
        : setFormula('({!} + {力量} * 10) * (1 + 0.01 * {%})')
    system:define('力量')

    local instance = system:instance()

    instance:set('最大生命', 1000)
    instance:set('最大生命%', 100)
    assert(instance:get('最大生命!') == 1000)
    assert(instance:get('最大生命') == 2000)

    instance:set('力量', 100)
    assert(instance:get('最大生命!') == 1000)
    assert(instance:get('最大生命') == 4000)
end

local testSystem4
do
    local system = attributeSystem.create()
    testSystem4 = system

    system:define('攻击')
        : setFormula('({!} + {主属性提供的攻击}) * (1 + 0.01 * {%})')
    system:define('主属性', true)
    system:define('力量')
    system:define('敏捷')
    system:define('智力')
    system:define('主属性提供的攻击')
        : setFormula('({主属性} == 1 and {力量}) or ({主属性} == 2 and {敏捷}) or ({主属性} == 3 and {智力}) or 0')

    local instance = system:instance()
    instance:set('攻击', 1000)
    instance:set('力量', 100)
    instance:set('敏捷', 50)
    instance:set('智力', 30)

    assert(instance:get('攻击!') == 1000)
    assert(instance:get('攻击') == 1000)

    instance:set('主属性', 1) -- 力量
    assert(instance:get('攻击') == 1100)

    instance:set('主属性', 2) -- 敏捷
    assert(instance:get('攻击') == 1050)

    instance:set('主属性', 3) -- 智力
    assert(instance:get('攻击') == 1030)
end

local testSystem5
do
    local system = attributeSystem.create()
    testSystem5 = system

    system:define('攻击')
    system:define('防御')
    system:define('移动速度')
        : recordTouch()
    system:define('力量')
    system:define('最大生命')
        : setFormula('({!} + {力量} * 10) * (1 + 0.01 * {%})')
        : recordTouch()
    system:define('生命', true, 0)
        : setMax('最大生命', true)
        : recordTouch()

    local instance = system:instance()

    instance:set('攻击', 100)
    instance:set('防御', 100)
    instance:set('移动速度', 100)
    instance:set('力量', 10)
    instance:set('最大生命', 100)
    instance:set('生命', 100)

    local oldValues = system:getTouched()
    assert(oldValues)
    assert(oldValues[instance]['攻击'] == nil)
    assert(oldValues[instance]['防御'] == nil)
    assert(oldValues[instance]['移动速度'] == 0)
    assert(oldValues[instance]['力量'] == nil)
    assert(oldValues[instance]['最大生命'] == 0)
    assert(oldValues[instance]['生命'] == 0)

    local oldValues = system:getTouched()
    assert(oldValues == nil)

    instance:set('力量', 20)

    local oldValues = system:getTouched()
    assert(oldValues)
    assert(oldValues[instance]['攻击'] == nil)
    assert(oldValues[instance]['防御'] == nil)
    assert(oldValues[instance]['移动速度'] == nil)
    assert(oldValues[instance]['力量'] == nil)
    assert(oldValues[instance]['最大生命'] == 200)
    assert(oldValues[instance]['生命'] == 100)

    assert(instance:get('力量') == 20)
    assert(instance:get('最大生命') == 300)
    assert(instance:get('生命') == 150)
end

local testSystem6
do
    local system = attributeSystem.create()
    testSystem6 = system

    system:define('攻击')
    system:define('防御')
    system:define('移动速度')
    system:define('力量')
    system:define('最大生命')
        : setFormula('({!} + {力量} * 10) * (1 + 0.01 * {%})')
    system:define('生命', true, 0)
        : setMax('最大生命', true)

    local instance = system:instance()

    local values = {}
    local dispose = instance:event('生命', function (instance, newValue, oldValue)
        values[#values+1] = oldValue
        values[#values+1] = newValue
    end)

    instance:set('最大生命', 100)
    system:updateEvent()
    instance:set('生命', 100)
    system:updateEvent()
    instance:set('力量', 10)
    system:updateEvent()
    instance:set('力量', 20)
    system:updateEvent()

    dispose()

    instance:set('力量', 30)
    system:updateEvent()

    assert(#values == 6)
    assert(values[1] == 0)
    assert(values[2] == 100)
    assert(values[3] == 100)
    assert(values[4] == 200)
    assert(values[5] == 200)
    assert(values[6] == 300)
end

-------------- 性能测试 -------------

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

do
    local system = attributeSystem.create()

    system:define('生命', true, 0)
        : setMax('最大生命', true)
    system:define('最大生命', false, 1)

    local instance = system:instance()

    instance:set('最大生命', 1000)
    instance:set('生命', 500)

    local start = os.clock()
    for i = 1, 1000000 do
        instance:set('最大生命', i)
    end
    local duration = os.clock() - start
    print('属性基准测试3耗时: ' .. duration .. '秒')
end

do
    local instance = testSystem4:instance()
    instance:set('攻击', 1000)
    instance:set('力量', 100)
    instance:set('敏捷', 50)
    instance:set('智力', 30)
    instance:set('主属性', 1) -- 力量

    local start = os.clock()
    for i = 1, 1000000 do
        instance:set('力量', i)
        instance:get('攻击')
    end
    local duration = os.clock() - start
    print('属性基准测试4耗时: ' .. duration .. '秒')
end

do
    local instance = testSystem5:instance()

    local start = os.clock()
    for i = 1, 1000000 do
        instance:set('力量', i)
        instance:get('生命')
    end
    local duration = os.clock() - start
    print('属性基准测试5耗时: ' .. duration .. '秒')
end

do
    local instance = testSystem6:instance()

    local dispose = instance:event('生命', function () end)

    local start = os.clock()
    for i = 1, 1000000 do
        instance:set('生命', i)
    end
    local duration = os.clock() - start
    print('属性基准测试6-1耗时: ' .. duration .. '秒')

    local start = os.clock()
    for i = 1, 1000000 do
        instance:set('生命', i)
        testSystem6:updateEvent()
    end
    local duration = os.clock() - start
    print('属性基准测试6-2耗时: ' .. duration .. '秒')

    dispose()

    local start = os.clock()
    for i = 1, 1000000 do
        instance:set('生命', i)
        testSystem6:updateEvent()
    end
    local duration = os.clock() - start
    print('属性基准测试6-3耗时: ' .. duration .. '秒')

    local dispose1 = instance:event('生命', function () end)
    local dispose2 = instance:event('生命', function () end)
    local dispose3 = instance:event('生命', function () end)
    local dispose4 = instance:event('生命', function () end)
    local dispose5 = instance:event('生命', function () end)

    local start = os.clock()
    for i = 1, 1000000 do
        instance:set('生命', i)
        testSystem6:updateEvent()
    end
    local duration = os.clock() - start
    print('属性基准测试6-4耗时: ' .. duration .. '秒')

    dispose5()
    dispose4()
    dispose3()
    dispose2()
    dispose1()

    local start = os.clock()
    for i = 1, 1000000 do
        instance:set('生命', i)
        testSystem6:updateEvent()
    end
    local duration = os.clock() - start
    print('属性基准测试6-5耗时: ' .. duration .. '秒')
end

print('attribute 测试完成')
