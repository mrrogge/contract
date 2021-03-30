local contract = require('contract')

local function run(f)
    print('function', f)
    start = os.clock()
    f()
    stop = os.clock()
    print('Execution time: ', stop-start)
end

run(function()
    for i=1, 10000000, 1 do
        contract('rn', 1)
    end
end)

local tempTbl = {}
run(function()
    for i=1, 10000000, 1 do
        contract('rn,rs,rb,rt', 1, '', true, tempTbl)
    end
end)

run(function()
    local function f(x) contract('rn') end
    for i=1, 10000000, 1 do f(1) end
end)