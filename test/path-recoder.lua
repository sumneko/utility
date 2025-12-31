local pr = require 'path-recoder'

local instance = pr.create()

do
    local u = instance:root()

    local m = u[1].x.b[{}].c

    assert(instance:view(m) == '[1].x.b.?.c')
    assert(instance:view(m, '[unknown]') == '[1].x.b[unknown].c')
end
