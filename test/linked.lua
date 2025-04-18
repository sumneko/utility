local linkedTable = require 'linked-table'

local lt = linkedTable.create()

lt:pushTail(1)
lt:pushTail(2)
lt:pushTail(3)
lt:pushHead(4)
assert(lt:dump() == '4 1 2 3')

lt:pop(2)
assert(lt:dump() == '4 1 3')

lt:popHead()
assert(lt:dump() == '1 3')

lt:pushHead(2)
lt:pushHead(4)
lt:pushHead(6)
lt:pushHead(8)
assert(lt:dump() == '8 6 4 2 1 3')

lt:popTail()
assert(lt:dump() == '8 6 4 2 1')

lt:pushAfter(5, 4)
assert(lt:dump() == '8 6 4 5 2 1')

lt:pushBefore(7, 4)
assert(lt:dump() == '8 6 7 4 5 2 1')

lt:replace(4, 3)
assert(lt:dump() == '8 6 7 3 5 2 1')
assert(lt:getSize() == 7)

assert(lt:dump(3) == '3 5 2 1')
assert(lt:dump(nil, true) == '1 2 5 3 7 6 8')
assert(lt:dump(3, true) == '3 7 6 8')

lt:reset()
assert(lt:dump() == '')
assert(lt:getSize() == 0)
