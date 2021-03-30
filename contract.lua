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

local defaultConfigTable = {
    allowFalseOptionalArgs=false,
    checkCacheMax=-1,
    onCheckCacheOverflow='nothing'
}

-- the module
local contract = {
    _enabled=true,
    _config={
        allowFalseOptionalArgs=defaultConfigTable.allowFalseOptionalArgs,
        checkCacheMax=defaultConfigTable.checkCacheMax,
        onCheckCacheOverflow=defaultConfigTable.onCheckCacheOverflow
    },
    _checkCache = {},
    _checkCacheLen = 0
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

-- ContractRule class. Used by the Cotract class to represent a singular rule for an arg.
local ContractRule = {}
ContractRule.__index = ContractRule

function ContractRule:new()
    local o = {}
    setmetatable(o, self)
    return o
end

function ContractRule:init()
    self.req = false
    self.typeList = {}
    return self
end

function ContractRule:addType(t)
    self.typeList[t] = true
end

-- Contract class. An intermediate representation of a contract string that is built by running a Parser.
local Contract = {}
Contract.__index = Contract

function Contract:new()
    local o = {}
    setmetatable(o, self)
    return o
end

function Contract:init()
    self.ruleList = {}
    return self
end

-- Check a list of args against this contract. Returns true if valid, otherwise, returns nil and an error string.
function Contract:checkArgs(argList)
    for i, rule in ipairs(self.ruleList) do
        local arg = argList[i]
        if arg == nil then
            if self.ruleList[i].req then
                return nil,
                    ('Contract violated: arg pos "%d" is required.'):format(i)
            end
        else
            if not self.ruleList[i].typeList['any']
            and not self.ruleList[i].typeList[type(arg)]
            then
                local validTypes = {}
                for k,v in pairs(self.ruleList[i].typeList) do
                    table.insert(validTypes, k)
                end
                if #validTypes > 1 then
                    return nil,
                        ('Contract violated: arg "%d" is type "%s" (%s), but must be one of: %s'):format(
                        i, type(arg), arg, 
                        table.concat(validTypes, '|'))
                else
                    return nil,
                        ('Contract violated: arg "%d" is type "%s" (%s), but must be "%s"'):format(
                        i, type(arg), arg, validTypes[1])                 
                end
            end
        end
    end
    return true
end

-- Parser class. Responsible for processing tokens through the lexer and building an intermediate Contract object based on the input string.
local Parser = {}
Parser.__index = Parser

function Parser:new()
    local o = {}
    setmetatable(o, self)
    return o
end

function Parser:init(input)
    self.lexer = self.lexer or Lexer:new()
    self.lexer:init(input)
    self.input = input
    self.ruleIdx = 0
    self.token = nil
    self.tokenVal = nil
    self.cache = self.cache or {}
    self.o, self.done = self:getContractObject(input)
    return self
end

-- Returns a new Contract object for a given input, and a found flag. The Parser gradually caches Contract objects for a given input so that they can be reused. If calling this function returned a newly created instance of Contract, found is false, otherwise found is true.
function Parser:getContractObject(input)
    if self.cache[input] then
        return self.cache[input], true
    else
        self.cache[input] = Contract:new():init()
        return self.cache[input], false
    end
end

-- Clears the cache table of Contract objects.
function Parser:clearCache()
    for k,v in pairs(self.cache) do
        self.cache[k] = nil
    end
end

function Parser:addRule()
    table.insert(self.o.ruleList, ContractRule:new():init())
    self.ruleIdx = self.ruleIdx + 1
end

function Parser:getCurrentRule()
    return self.o.ruleList[self.ruleIdx]
end

---Advances the lexer and checks that the passed token matches the returned token.
-- If matched, returns true, otherwise returns nil and an error string.
function Parser:eat(token)
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
function Parser:type_()
    -- type = num|str|bool|user|fnc|th|tbl|any
    self:getCurrentRule():addType(self.tokenVal)
    return self:eat(TOKEN.TYPE)
end

---Consume function for an argRule symbol.
function Parser:argRule()
    -- argRule = ['r'] , type , ('|' , type)*
    self:addRule()
    if self.token == TOKEN.REQ then
        self:getCurrentRule().req = true
        self:eat(TOKEN.REQ)
    end
    local ok, err = self:type_()
    if not ok then return nil, err end
    while self.token == TOKEN.OR do
        local ok, err = self:eat(TOKEN.OR)
        ok, err = self:type_()
        if not ok then return nil, err end
    end
    return true
end

---Consume function for a contract symbol.
function Parser:contract()
    -- contract = '' | (argRule , (',' , argRule)*)
    if self.token == TOKEN.EOF then
        return true
    end
    local ok, err = self:argRule()
    if not ok then return nil, err end
    while self.token == TOKEN.COMMA do
        local ok, err = self:eat(TOKEN.COMMA)
        ok, err = self:argRule()
        if not ok then return nil, err end
    end
    ok, err = self:eat(TOKEN.EOF)
    if not ok then return nil, err end
    return true
end

-- Runs the parser and builds the Contract object from the input string. The Contract object can be accessed by the o member of this object. Once the parser completes a run, it will set the done member to true; the parser will then need to be reinitialized to be run again. 
-- Returns true if parser succeeded, otherwise returns nil and an error string.
function Parser:run()
    if self.done then return true end
    self.token, self.tokenVal = self.lexer:process()
    if not self.token then return nil, self.tokenVal end
    return self:contract()
end

-- the check function re-uses local instances of lexer and parser each
-- time it is executed. This way the GC doesn't need to work as hard.
local parser = Parser:new():init('')

-- cache-related functions
local tempTbl = {}
local function argTypesToString(t)
    -- for a given list of args t, returns a string representation of the types of each arg. This is used to avoid re-running a contract check that is equivalent to a previous one, since a check will always yield the same result for a given input string and the same type list.
    for k,v in pairs(tempTbl) do
        tempTbl[k] = nil
    end
    for i=1, t.n, 1 do
        table.insert(tempTbl, type(t[i]))
    end
    return table.concat(tempTbl, '-')
end

-- Clears the caches for the module.
function contract.clearCache()
    parser:clearCache()
    for k,v in pairs(contract._checkCache) do
        contract._checkCache[k] = nil
    end
    contract._checkCacheLen = 0
end

---Checks the input contract against the list of arguments. 
-- If no arguments were passed, this function will try to lookup the arguments passed to the function that called this one and check those.
local checkArgList = {}
local function check(input, ...)
    if not contract._enabled then return end
    if input == nil then return end
    if input == '' then return end
    if type(input) ~= 'string' then
        error('contract must be a string type.')
    end
    for k,v in pairs(checkArgList) do
        checkArgList[k] = nil
    end
    local nargs = select('#',...)
    if nargs > 0 then
        checkArgList.n = nargs
        for i=1, nargs, 1 do
            checkArgList[i] = select(i, ...)
        end
    else
        --try to get the argument values passed to the function two levels above this one (i.e. the function that called contract.check() or contract()). Note that accessing varargs through debug.getlocal() is only supported on Lua v5.2+, NOT v5.1.
        local i = 1
        while true do
            local argName, argVal = debug.getlocal(2, i)
            if not argName then
                break
            else
                checkArgList[i] = argVal
            end
            i = i + 1
        end
        if i > 1 then
            checkArgList.n = i-1
        else
            error('Implicit arg lookup failed. Note that vararg lookup is not supported; varargs can still be passed explicitly.')
        end
    end
    -- check the cache for any equivalent calls made in the past. If found, we can return early without having to rerun the parser/checkArgs() function.
    local argTypesString = argTypesToString(checkArgList)
    if contract._checkCache[input]
    and contract._checkCache[input][argTypesString] then
        return
    end
    parser:init(input)
    local ok, err = parser:run()
    if not ok then error(err) end
    ok, err = parser.o:checkArgs(checkArgList)
    if not ok then error(err) end
    -- if checkArgs() passed, then we can add this input string and list of arg types to the checkCache table to avoid having to do the work again next time an equivalent check is requested.
    contract._checkCache[input] = contract._checkCache[input] or {}
    contract._checkCache[input][argTypesString] = true
end

function contract.check(input, ...)
    return check(input, ...)
end

function contract.on()
    contract._enabled = true
end

function contract.off()
    contract._enabled = false
end

function contract.isOn()
    return contract._enabled
end

function contract.toggle()
    contract._enabled = not contract._enabled
end

function contract.config(options)
    if not options then
        options = defaultConfigTable
    end
    if type(options) ~= 'table' then
        error(('options arg must be a table, not %s.'):format(type(options)))
    end
    if options.allowFalseOptionalArgs ~= nil then
        contract._config.allowFalseOptionalArgs = not not options.allowFalseOptionalArgs
    end
    if type(options.callCacheMax) == 'number' then
        contract._config.callCacheMax = options.callCacheMax
    end
    if type(options.errorOnCallCacheOverflow) == 'string' then
        contract._config.errorOnCallCacheOverflow = options.errorOnCallCacheOverflow
    end
end

setmetatable(contract, {
    __call=function(t, input, ...)
        return check(input, ...)
    end
})

return contract