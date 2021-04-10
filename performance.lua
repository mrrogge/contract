local contract = require('contract')

ITERATIONS = 10000000

local function control_fnc(a,b,c)
    assert(type(a) == 'number', 'a must be a number')
    assert(type(b) == 'string', 'b must be a string')
    assert(type(c) == 'number' or type(c) == 'string', 'c must be a number or string')
end

local function test_fnc1(a,b,c)
    contract('rn,rs,rn|s', a, b, c)
end

local function test_fnc2(a,b,c)
    contract('rn,rs,rn|s')
end

local function runNTimes(n, f)
    start = os.clock()
    for i=1, n, 1 do
        f()
    end
    stop = os.clock()
    print('  Execution time: ', stop-start)
    print('  Time per call: ', (stop-start)/n)
end

print(('Running %s iterations per test'):format(ITERATIONS))
print('-------------------------------')
print('Control function:')
runNTimes(ITERATIONS, function()
    control_fnc(1,'two',3)
end)

print('Test function 1 (explicit args):')
runNTimes(ITERATIONS, function()
    test_fnc1(1,'two',3)
end)

print('Test function 2 (implicit args):')
runNTimes(ITERATIONS, function()
    test_fnc2(1,'two',3)
end)

print('Test function 1, module disabled:')
contract.off()
runNTimes(ITERATIONS, function()
    test_fnc1(1,'two',3)
end)