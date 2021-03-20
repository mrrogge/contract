--[[
MIT License

Copyright (c) 2019 Matt Rogge

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

-- the module
local contract = {
    _callCache = {},
    _callCacheLen = 0
}

-- token enum
local TOKEN = {
    REQ='REQ',
    OR='OR',
    TYPE='TYPE',
    COMMA='COMMA',
    EOF='EOF'
}

local function isWhitespace(c)
    return c == ' ' or c == '\r' or c == '\n' or c == '\t' or c == nil or c == ''
end

local function emptyTable(t)
    for k,v in pairs(t) do
        t[k] = nil
    end
end

-- Lexer class
local Lexer = {}
Lexer.__index = Lexer

function Lexer:new()
    local o = {}
    setmetatable(o, self)
    return o
end

function Lexer:init(input)
    self.input = input or ''
    self.pos = 1
    self.errorLevel = 5
end

function Lexer:advance(i)
    i = i or 1
    self.pos = self.pos+i
    return self:current()
end

function Lexer:peek(i,j)
    i = i or 0
    j = j or i
    return string.lower(string.sub(self.input, self.pos+i, self.pos+j))
end

function Lexer:current()
    return self:peek(0)
end

function Lexer:process()
    --Processes the input string and returns the next token.
    local current = self:current()
    while current and current ~= '' do
        if isWhitespace(current) then
            current = self:advance()
        else
            if current == 'r' then
                current = self:advance()
                return TOKEN.REQ
            elseif current == '|' then
                current = self:advance()
                return TOKEN.OR
            elseif current == 'n' then
                current = self:advance(1)
                if self:peek(0,1) == 'um' then
                    current = self:advance(2)
                    if self:peek(0,2) == 'ber' then
                        current = self:advance(3)
                    end
                end
                return TOKEN.TYPE, 'number'
            elseif current == 's' then
                current = self:advance(1)
                if self:peek(0,1) == 'tr' then
                    current = self:advance(2)
                    if self:peek(0,2) == 'ing' then
                        current = self:advance(3)
                    end
                end
                return TOKEN.TYPE, 'string'
            elseif current == 'b' then
                current = self:advance(1)
                if self:peek(0,2) == 'ool' then
                    current = self:advance(3)
                    if self:peek(0,2) == 'ean' then
                        current = self:advance(3)
                    end
                end
                return TOKEN.TYPE, 'boolean'
            elseif current == 'u' then
                current = self:advance(1)
                if self:peek(0,1) == 'sr' then
                    current = self:advance(2)
                elseif self:peek(0,2) == 'ser' then
                    current = self:advance(3)
                    if self:peek(0,3) == 'data' then
                        current = self:advance(4)
                    end
                end
                return TOKEN.TYPE, 'userdata'
            elseif current == 'f' then
                current = self:advance(1)
                if self:peek(0,1) == 'nc' then
                    current = self:advance(2)
                elseif self:peek(0,2) == 'unc' then
                    current = self:advance(3)
                    if self:peek(0,3) == 'tion' then
                        current = self:advance(4)
                    end
                end
                return TOKEN.TYPE, 'function'
            elseif current == 't' then
                if self:peek(1) == 'h' then
                    current = self:advance(2)
                    if self:peek(0,3) == 'read' then
                        current = self:advance(4)
                    end
                    return TOKEN.TYPE, 'thread'
                else
                    current = self:advance(1)
                    if self:peek(0,1) == 'bl' then
                        current = self:advance(2)
                    elseif self:peek(0,3) == 'able' then
                        current = self:advance(4)
                    end
                    return TOKEN.TYPE, 'table'
                end
            elseif current == 'a' then
                current = self:advance(1)
                if self:peek(0,1) == 'ny' then
                    current = self:advance(2)
                end
                return TOKEN.TYPE, 'any'
            elseif current == ',' then
                current = self:advance(1)
                return TOKEN.COMMA
            else
                error(('Contract syntax error: pos %d, char %s'):format(
                    self.pos, self:current()), 2)
            end
        end
    end
    return TOKEN.EOF
end

-- Interpreter class
local Interpreter = {}
Interpreter.__index = Interpreter

function Interpreter:new()
    local o = {}
    setmetatable(o, self)
    return o
end

local ruleTypeList = {}
local argNameList, argValList = {}, {}
function Interpreter:init(lexer, input, ...)
    self.lexer = lexer
    self.lexer:init(input)
    self.argNameList, self.argValList = argNameList, argValList
    emptyTable(self.argNameList)
    emptyTable(self.argValList)
    local nargs = 0
    for i=1, select('#',...), 1 do
        if i%2 == 1 then
            nargs = nargs + 1
            local argName = select(i,...)
            table.insert(self.argNameList, argName)
        else
            local argVal = select(i,...)
            self.argValList[nargs] = argVal
        end
    end
    self.argInt = 1
    self.ruleTypeList = ruleTypeList
    emptyTable(self.ruleTypeList)
    self.req = false
    self.errorLevel = 5
end

function Interpreter:addNewType(val)
    table.insert(self.ruleTypeList, val)
end

function Interpreter:currentArgName()
    return self.argNameList[self.argInt]
end

function Interpreter:currentArgVal()
    return self.argValList[self.argInt]
end

function Interpreter:currentArgType()
    return type(self:currentArgVal())
end

function Interpreter:incErrorLevel()
    self.errorLevel = self.errorLevel + 1
    self.lexer.errorLevel = self.lexer.errorLevel + 1
end

function Interpreter:decErrorLevel()
    self.errorLevel = self.errorLevel - 1
    self.lexer.errorLevel = self.lexer.errorLevel - 1
end

function Interpreter:checkArg()
    self:incErrorLevel()
    local allowFalse = contract._config.allowFalseOptionalArgs
    if self.req then
        if self:currentArgVal() == nil then
            error(('Contract violated: arg pos "%d" is required.'):format(
                self.argInt), self.errorLevel)
        end
    else
        if (not allowFalse and self:currentArgVal() == nil)
                or (allowFalse and not self:currentArgVal()) then
            emptyTable(self.ruleTypeList)
            self.argInt = self.argInt + 1
            self.req = false
            self:decErrorLevel()
            return
        end
    end
    local isValid = false
    for _, t in ipairs(self.ruleTypeList) do
        if t == 'any' or t == self:currentArgType() then
            isValid = true
        end
    end
    if not isValid then
        if #self.ruleTypeList > 1 then
            error(('Contract violated: arg "%s" is type "%s" (%s), but must be one of: %s'):format(
                self:currentArgName(), self:currentArgType(), self:currentArgVal(),
                table.concat(self.ruleTypeList, '|')), self.errorLevel
            )
        else
            error(('Contract violated: arg "%s" is type "%s" (%s), but must be "%s"'):format(
                self:currentArgName(), self:currentArgType(), self:currentArgVal(),
                table.concat(self.ruleTypeList, '|')), self.errorLevel
            )
        end     
    end
    emptyTable(self.ruleTypeList)
    self.argInt = self.argInt + 1
    self.req = false
    self:decErrorLevel()
end

function Interpreter:eat(token)
    self:incErrorLevel()
    if self.token == token then
        self.token, self.tokenVal = self.lexer:process()
    else
        error(('Contract syntax error: expected token "%s", but got "%s"'):format(
            token, self.token), self.errorLevel)
    end
    self:decErrorLevel()
end

function Interpreter:type_()
    -- type = num|str|bool|user|fnc|th|tbl|any
    self:incErrorLevel()
    self:addNewType(self.tokenVal)
    self:eat(TOKEN.TYPE)
    self:decErrorLevel()
end

function Interpreter:argRule()
    -- argRule = ['r'] , type , ('|' , type)*
    self:incErrorLevel()
    if self.token == TOKEN.REQ then
        self.req = true
        self:eat(TOKEN.REQ)
    end
    self:type_()
    while self.token == TOKEN.OR do
        self:eat(TOKEN.OR)
        self:type_()
    end
    self:checkArg()
    self:decErrorLevel()
end

function Interpreter:contract()
    -- contract = '' | (argRule , (',' , argRule)*)
    if self.token == TOKEN.EOF then
        return
    end
    self:argRule()
    while self.token == TOKEN.COMMA do
        self:eat(TOKEN.COMMA)
        self:argRule()
    end
end

function Interpreter:run()
    self.token,self.tokenVal = self.lexer:process()
    self:contract()
end

-- cache-related functions
local tempTbl = {}
local function callToString(f, ...)
    -- returns a string representation of a function call. Uses the function's
    -- identity and the argument types.
    for k,v in pairs(tempTbl) do
        tempTbl[k] = nil
    end
    local nargs = select('#',...)
    for i=1, nargs, 1 do
        table.insert(tempTbl, type(select(i,...)))
    end
    return tostring(f)..'-'..table.concat(tempTbl, '-')
end

function contract.clearCallCache()
    for k,v in pairs(contract._callCache) do
        contract._callCache[k] = nil
    end
    contract._callCacheLen = 0
end

-- the check function re-uses local instances of lexer and interpreter each
-- time it is executed. This way the GC doesn't need to work as hard.
local lexer = Lexer:new()
local interpreter = Interpreter:new()
local argNameTbl, argValTbl, argTbl = {}, {}, {}
local function check(input, level)
    -- Checks the contract string input against the params of the function that
    -- is at the specified level in the calling stack.
    for k,v in pairs(argNameTbl) do
        argNameTbl[k] = nil
    end
    for k,v in pairs(argValTbl) do
        argValTbl[k] = nil
    end
    for k,v in pairs(argTbl) do
        argTbl[k] = nil
    end
    local argName, argVal
    local argCount, i = 1, 1
    while true do
        argName,argVal = debug.getlocal(level, argCount)
        if not argName then
            break
        else
            if argName == 'arg' and type(argVal) == 'table' then
                for j=1, argVal.n, 1 do
                    argNameTbl[argCount] = ('(vararg %d)'):format(j)
                    argValTbl[argCount] = argVal[j]
                    argTbl[i] = argNameTbl[argCount]
                    i = i + 1
                    argTbl[i] = argValTbl[argCount]
                    i = i + 1
                end
            else
                argNameTbl[argCount] = argName
                argValTbl[argCount] = argVal
                argTbl[i] = argName
                i = i + 1
                argTbl[i] = argVal
                i = i + 1
            end
            argCount = argCount + 1
        end
    end
    local vargIdx = -1
    while true do
        argName,argVal = debug.getlocal(level, vargIdx)
        if not argName then
            break
        else
            argNameTbl[argCount] = argName
            argValTbl[argCount] = argVal
            argTbl[i] = argName
            i = i + 1
            argTbl[i] = argVal
            i = i + 1
        end
        argCount = argCount + 1
        vargIdx = vargIdx - 1
    end
    local f = debug.getinfo(level, 'f').func
    local callString = callToString(f, unpack(argValTbl))
    if contract._callCache[callString] then
        return
    end
    interpreter:init(lexer, input, unpack(argTbl))
    interpreter:run()
    if contract._callCacheLen >= contract._config.callCacheMax
            and contract._config.callCacheMax >= 0 then
        if contract._config.onCallCacheOverflow == 'error' then
            error('call cache overflow')
        elseif contract._config.onCallCacheOverflow == 'clear' then
            contract.clearCallCache()
        end
    else
        contract._callCache[callString] = true
        contract._callCacheLen = contract._callCacheLen + 1
    end
end

local function nop()
    -- the check function is replaced with nop() when contract evaluation is
    -- turned off.
end

local function checkExplicitCall(input)
    if type(jit) == 'table' then
        return check(input, 2)
    else
        return check(input, 3)
    end
end

local function checkShortcutCall(_, input)
    if type(jit) == 'table' then
        return check(input, 2)
    else
        return check(input, 3)
    end
end

function contract.on()
    contract.check = checkExplicitCall
    local mt = getmetatable(contract)
    mt.__call = checkShortcutCall
end

function contract.off()
    contract.check = nop
    local mt = getmetatable(contract)
    mt.__call = nop
end

function contract.isOn()
    return contract.check == checkExplicitCall
end

function contract.toggle()
    if contract.isOn() then
        contract.off()
    else
        contract.on()
    end
end

function contract.config(options)
    contract._config = contract._config or {}
    --set defaults
    if contract._config.allowFalseOptionalArgs == nil then
        contract._config.allowFalseOptionalArgs = false
    end
    contract._config.callCacheMax = contract._config.callCacheMax or -1
    contract._config.onCallCacheOverflow = contract._config.onCallCacheOverflow or 'nothing'
    if not options then
        return
    end
    if options.allowFalseOptionalArgs ~= nil then
        contract._config.allowFalseOptionalArgs = options.allowFalseOptionalArgs
    end
    if options.callCacheMax ~= nil then
        contract._config.callCacheMax = options.callCacheMax
    end
    if options.errorOnCallCacheOverflow ~= nil then
        contract._config.errorOnCallCacheOverflow = options.errorOnCallCacheOverflow
    end
end

setmetatable(contract, {})
contract.on()
contract.config()

return contract