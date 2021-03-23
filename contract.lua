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
    _callCacheLen = 0,
    enabled=true
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

---Advances lexer position by i characters and returns the new character.
function Lexer:advance(i)
    i = i or 1
    self.pos = self.pos+i
    return self:current()
end

---Returns a substring from the input.
-- i is the starting offset from the current position. If 0, the current position is used. Similarly, j is the ending offset.
function Lexer:peek(i,j)
    i = i or 0
    j = j or i
    return string.lower(string.sub(self.input, self.pos+i, self.pos+j))
end

---Returns the character at the current position.
function Lexer:current()
    return self:peek(0)
end

---Processes the input string and returns the next token.
function Lexer:process()
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
                return nil, ('Contract syntax error: pos %d, char %s'):format(
                    self.pos, self:current())
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

---Sets up the Interpreter object to check a list of arguments against a contract.
function Interpreter:init(lexer, input, ...)
    self.lexer = lexer
    self.lexer:init(input)
    --argTypeList will hold the type string of each of the passed in arguments.
    self.argList = self.argList or {}
    emptyTable(self.argList)
    for i=1, select('#',...), 1 do
        local argVal = select(i, ...)
        table.insert(self.argList, argVal)
    end
    --ruleTypeList will hold each of the allowed type strings for the given argument defined by the contract.
    self.ruleTypeList = self.ruleTypeList or {}
    emptyTable(self.ruleTypeList)
    --req holds whether or not the current argument being looked at is required according to the contract.
    self.req = false
    --argInt holds the current argument number being looked at.
    self.argInt = 1
    --token/tokenVal will hold the latest token info fed from the lexer.
    self.token, self.tokenVal = nil, nil
    return self
end

---Returns the current argument value.
function Interpreter:currentArgVal()
    return self.argList[self.argInt]
end

---Returns the type string of the current argument value.
function Interpreter:currentArgType()
    return type(self:currentArgVal())
end

---Checks the current argument against its corresponding contract info.
-- Returns true if argument passes, otherwise returns nil and an error string.
function Interpreter:checkArg()
    local allowFalse = contract._config.allowFalseOptionalArgs
    if self.req then
        if self:currentArgVal() == nil then
            return nil, 
                ('Contract violated: arg pos "%d" is required.'):format(
                self.argInt)
        end
    else
        if (not allowFalse and self:currentArgVal() == nil)
        or (allowFalse and not self:currentArgVal()) 
        then
            emptyTable(self.ruleTypeList)
            self.argInt = self.argInt + 1
            self.req = false
            return true
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
            return nil, 
                ('Contract violated: arg "%d" is type "%s" (%s), but must be one of: %s'):format(
                self.argInt, self:currentArgType(), self:currentArgVal(),
                table.concat(self.ruleTypeList, '|'))
        else
            return nil,
                ('Contract violated: arg "%d" is type "%s" (%s), but must be "%s"'):format(
                self.argInt, self:currentArgType(), self:currentArgVal(),
                table.concat(self.ruleTypeList, '|'))
            
        end     
    end
    emptyTable(self.ruleTypeList)
    self.argInt = self.argInt + 1
    self.req = false
    return true
end

---Advances the lexer and checks that the passed token matches the returned token.
-- If matched, returns true, otherwise returns nil and an error string.
function Interpreter:eat(token)
    if self.token == token then
        self.token, self.tokenVal = self.lexer:process()
    else
        return nil,
            ('Contract syntax error: expected token "%s", but got "%s"'):format(
            token, self.token)
    end
    return true
end

---Consume function for a type symbol.
function Interpreter:type_()
    -- type = num|str|bool|user|fnc|th|tbl|any
    table.insert(self.ruleTypeList, self.tokenVal)
    return self:eat(TOKEN.TYPE)
end

---Consume function for an argRule symbol.
function Interpreter:argRule()
    -- argRule = ['r'] , type , ('|' , type)*
    if self.token == TOKEN.REQ then
        self.req = true
        local ok, err = self:eat(TOKEN.REQ)
        if not ok then return nil, err end
    end
    local ok, err = self:type_()
    if not ok then return nil, err end
    while self.token == TOKEN.OR do
        local ok, err = self:eat(TOKEN.OR)
        if not ok then return nil, err end
        ok, err = self:type_()
        if not ok then return nil, err end
    end
    return self:checkArg()
end

---Consume function for a contract symbol.
function Interpreter:contract()
    -- contract = '' | (argRule , (',' , argRule)*)
    if self.token == TOKEN.EOF then
        return true
    end
    local ok, err = self:argRule()
    if not ok then return nil, err end
    while self.token == TOKEN.COMMA do
        local ok, err = self:eat(TOKEN.COMMA)
        if not ok then return nil, err end
        ok, err = self:argRule()
        if not ok then return nil, err end
    end
    return true
end

---Runs the interpreter, checking the arg list against the contract string.
function Interpreter:run()
    self.token, self.tokenVal = self.lexer:process()
    if not self.token then return nil, self.tokenVal end
    return self:contract()
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

-- local argNameTbl, argValTbl, argTbl = {}, {}, {}
-- local function check(input, level)
--     -- Checks the contract string input against the params of the function that
--     -- is at the specified level in the calling stack.
--     for k,v in pairs(argNameTbl) do
--         argNameTbl[k] = nil
--     end
--     for k,v in pairs(argValTbl) do
--         argValTbl[k] = nil
--     end
--     for k,v in pairs(argTbl) do
--         argTbl[k] = nil
--     end
--     local argName, argVal
--     local argCount, i = 1, 1
--     while true do
--         argName,argVal = debug.getlocal(level, argCount)
--         if not argName then
--             break
--         else
--             if argName == 'arg' and type(argVal) == 'table' then
--                 for j=1, argVal.n, 1 do
--                     argNameTbl[argCount] = ('(vararg %d)'):format(j)
--                     argValTbl[argCount] = argVal[j]
--                     argTbl[i] = argNameTbl[argCount]
--                     i = i + 1
--                     argTbl[i] = argValTbl[argCount]
--                     i = i + 1
--                 end
--             else
--                 argNameTbl[argCount] = argName
--                 argValTbl[argCount] = argVal
--                 argTbl[i] = argName
--                 i = i + 1
--                 argTbl[i] = argVal
--                 i = i + 1
--             end
--             argCount = argCount + 1
--         end
--     end
--     local vargIdx = -1
--     while true do
--         argName,argVal = debug.getlocal(level, vargIdx)
--         if not argName then
--             break
--         else
--             argNameTbl[argCount] = argName
--             argValTbl[argCount] = argVal
--             argTbl[i] = argName
--             i = i + 1
--             argTbl[i] = argVal
--             i = i + 1
--         end
--         argCount = argCount + 1
--         vargIdx = vargIdx - 1
--     end
--     local f = debug.getinfo(level, 'f').func
--     local callString = callToString(f, unpack(argValTbl))
--     if contract._callCache[callString] then
--         return
--     end
--     interpreter:init(lexer, input, unpack(argTbl))
--     interpreter:run()
--     if contract._callCacheLen >= contract._config.callCacheMax
--             and contract._config.callCacheMax >= 0 then
--         if contract._config.onCallCacheOverflow == 'error' then
--             error('call cache overflow')
--         elseif contract._config.onCallCacheOverflow == 'clear' then
--             contract.clearCallCache()
--         end
--     else
--         contract._callCache[callString] = true
--         contract._callCacheLen = contract._callCacheLen + 1
--     end
-- end

---Checks the input contract against the list of arguments. 
-- If no arguments were passed, this function will try to lookup the arguments passed to the function that called this one and check those.
-- Returns true if arguments pass, otherwise returns nil and an error string.
local checkArgList = {}
local function check(input, ...)
    if not contract.enabled then return end
    for k,v in pairs(checkArgList) do
        checkArgList[k] = nil
    end
    local nargs = select('#',...)
    if nargs > 0 then
        for i=1, nargs, 1 do
            table.insert(checkArgList, select(i,...))
        end
    else
        --try to get the argument values passed to the function two levels above this one (i.e. the function that called contract.check() or contract()).
        local i = 1
        while true do
            local argName, argVal = debug.getlocal(2, i)
            if not argName then
                break
            else
                if argName == 'arg' and type(argVal) == 'table' then
                    for j=1, argVal.n, 1 do
                        table.insert(checkArgList, argVal[j])
                    end
                else
                    table.insert(checkArgList, argVal)
                end
            end
            i = i + 1
        end        
    end
    print(unpack(checkArgList))
    interpreter:init(lexer, input, unpack(checkArgList))
    local ok, err = interpreter:run()
    if not ok then
        error(err)
    end
end

function contract.check(input, ...)
    return check(input, ...)
end

function contract.on()
    contract.enabled = true
end

function contract.off()
    contract.enabled = false
end

function contract.isOn()
    return contract.enabled
end

function contract.toggle()
    contract.enabled = not contract.enabled
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

setmetatable(contract, {
    __call=function(t, input, ...)
        return check(input, ...)
    end
})
contract.on()
contract.config()

return contract