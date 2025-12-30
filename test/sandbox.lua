local new_sandbox = require 'sandbox'

local sandbox = new_sandbox('test', 'test.sandbox_test')

sandbox.require 'main'

assert(RESULTS == nil)
assert(type(sandbox.env.RESULTS) == 'table')
assert(sandbox.env.RESULTS[1] == 1)
assert(sandbox.env.RESULTS[2] == 2)
assert(sandbox.env.RESULTS[3] == 3)
