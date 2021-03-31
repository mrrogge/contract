# contract

`contract` is a module that checks whether or not function arguments satisfy a specified "contract" string. These strings define the argument type requirements for a given function using a custom mini-language.

`contract` provides two main benefits:
1. It provides a simple mechanism for checking argument datatypes.
2. It helps document the intended use of each function.

`contract` is NOT:
- A full unit-testing solution.
- A compile-time evaluator. All checks are performed at run-time, however they can be turned off for non-development builds. If you want something that evaluates your code prior to execution, consider something like [TypeScriptToLua](https://github.com/TypeScriptToLua/TypeScriptToLua).

## Installation

`contract` can be installed using luarocks:

```
luarocks install contract
```

You may also download the latest release and include contract.lua in your project folder.

`contract` is compatible with LUA versions 5.1 and up. It does not have any external dependencies.

## Usage

Consider the following function:

```lua
local function sum(a, b)
    assert(type(a) == 'number', 'arg "a" must be a number')
    assert(type(b) == 'number', 'arg "b" must be a number')
    return a + b
end
```

This function expects two numbers to be passed to it. Note the two assert calls - if any other value types are passed in, the asserts fail and an error is raised. We can think of the `sum()` function as having a "contract" that says, "I expect two number values to be passed to me, and as long as that is true I will run correctly."

`contract()` can be used as an alternative to writing out these asserts manually. For example:

```lua
local contract = require('contract')

local function sum2(a,b)
    contract('rn, rn', a, b)
    return a + b
end
```

Function `sum2()` is equivalent to `sum()` in that any non-number values for `a` and `b` will be rejected. 

The first argument passed to `contract()` is the contract string "rn, rn", which represents a contract for two required number arguments.

The arguments `a` and `b` are then passed after the contract string to verify if they satisfy the contract. If `sum2()` is called with arguments that violate this contract, an error will be raised:

```lua
sum2(1, 2)        --<passes>
sum2('one', 2)    --Contract violated: arg "1" is type "string", but must be "number".
sum2(1, 'two')    --Contract violated: arg "2" is type "string", but must be "number".
sum2(1)           --Contract violated: arg pos "2" is required.
```

### Contract string syntax
The syntax for contracts is quite simple:
* Each argument has a rule specifying its allowed datatype(s). For example, in the contract string above "rn" stands for "required number".
* The rules for each argument are listed in position order separated by commas.
* Contracts are not case-sensitive.
* All whitespace is ignored.

`contract` can be used to check any of the primitive Lua datatypes:

```lua
local function callIfTrue(bl, fnc)
    contract('rb, rf', bl, fnc)
    if bl then
        fnc()
    end
end

callIfTrue(true, function() print('hello') end)    --'hello'
callIfTrue(true, 'not a function')    --Contract violated: arg "2" is type "string", but must be "function".
```

There are multiple specifiers associated with each datatype. This allows you to be as brief or as explicit as you want:

```lua
contract('number', 1)    --<passes>
contract('s, str, string', 'one', 'two', 'three')    --<passes>
```

Here is a table listing all the acceptable specifiers for each Lua type:

| datatype | specifiers |
| --- | ---|
| number | "n", "num", "number" |
| string | "s", "str", "string" |
| boolean | "b", "bool", "boolean" |
| table | "t", "tbl", "table" |
| function | "f", "fnc", "func", "function" |
| thread | "th", "thread" |
| userdata | "u", "usr", "user", "userdata" |

Note that `contract` is intended for evaluating arguments passed to a calling function, but you can actually pass any values to it:

```lua
contract('rt, rs', {}, '')           --<passes>
contract('ru', 'not userdata')    --Contract violated: arg "1" is type "string", but must be "userdata".
contract('rf', print)              --<passes>
```

### Required and optional arguments
`contract` allows arguments to be specified as "required" or "optional". A type specifier preceeded by an "r" flags it as required. Any specifiers without an "r" are treated as optional.

Optional arguments can be omitted, but if they are passed they still must match their specified type for the contract to pass:

```lua
local function config(tbl, name, op1, val)
    contract('rt, s, rb, n', tbl, name, op1, val)
    tbl.name = name or 'default'
    tbl.op1 = op1
    tbl.val = val or 42
end

config({}, 'mytable', true, 19)    --<passes>
config({}, 'mytable', true)        --<passes>
config({}, nil, true)              --<passes>
config({}, 'mytable', true, 'not a number')    --Contract violated: arg "4" is type "string" but must be "number".
config({}, true)    --Contract violated: arg "2" is type "boolean" but must be "string".
```

Optional args at the end of the list can be completely omitted. Also, note that optional args can come before required args, but if they are being omitted they must have passed `nil` explicitly - just leaving these out will not work.

### Multi-type arguments
You can specify an argument that can be one of multiple types using the '|' operator:

```lua
contract('rn|s', 1)    --<passes>
contract('rn|s', 'one')    --<passes>
contract('rn|s', true)    --Contract violated: arg "1" is type "boolean" but must be one of: "number|string".
```

You can also use the "a" or "any" specifiers to accept values of any type:

```lua
contract('a', 1)    --<passes>
contract('any', 'one')    --<passes>
contract('a', true)    --<passes>
```

### Extra arguments are ignored
If more arguments are passed than are specified in the contract, then as long as the contract holds the extra arguments do not matter:

```lua
contract('rn', 1, 'two', 'three')    --<passes>
```

### Implicit argument lookup
There are actually two ways to use `contract()`. The first is by explicitly passing the argument values you wish to check against the contract (all of the examples above use this method). The second method automatically looks up the arguments from the function that called `contract()` without needing to pass them in:

```lua
local function sum(a, b)
    contract('rn, rn')    --implicit lookup of a & b
    return a + b
end

sum(1, 'two')    --Contract violated: arg "2" is type "string" but must be "number".
```

While this method uses less typing, it unfortunately takes longer to execute compared to the explicit method. You are free to use whichever method best suits your needs.

### Enabling/disabling checks

## Performance

## Contract language in [EBNF](https://en.wikipedia.org/wiki/Extended_Backus%E2%80%93Naur_form)

Here is the complete grammar for the contract string mini-language:

```ebnf
contract = '' | (argRule , (',' , argRule)*)
argRule = ['r'] , type , ('|' , type)*
type = num|str|bool|user|fnc|th|tbl|any
num = 'n'|'num'|'number'
str = 's'|'str'|'string'
bool = 'b'|'bool'|'boolean'
user = 'u'|'usr'|'user'|'userdata'
fnc = 'f'|'fnc'|'function'
th = 'th'|'thread'
tbl = 't'|'tbl'|'table'
any = 'a|any'
```

## API

### `contract.check(input, ...)`

Checks the argument list against the contract string `input`. If no arguments are passed, attempts to look up the arguments passed to the function that called `contract.check()`. Raises an error if the contract is violated.

### `contract(input, ...)`

Alias for `contract.check()`.

### `contract.on()`

Enables all contract checking (module is "on" by default).

### `contract.off()`

Turns off all contract checking.

### `contract.isOn()`

Returns `true` if contract checking is currently enabled; otherwise, returns `false`.

### `contract.toggle()`

Switches the on/off state of the module.

### `contract.clearCache()`

Clears the contract cache.

## Credits
`contract` is written and maintained by [Matt Rogge](https://mattrogge.com).

Portions of the interpreter code were inspired by [this great series of tutorials](https://ruslanspivak.com/lsbasi-part1/) written by [Ruslan Spivak](https://ruslanspivak.com/pages/about/).

## License

`contract` is licensed under the [MIT](https://choosealicense.com/licenses/mit/) license.
