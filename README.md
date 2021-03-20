# contract

`contract` is a small library for LUA that implements a [design by contract](https://en.wikipedia.org/wiki/Design_by_contract) approach to writing code. In general, function calls are compared against a "contract string" at run time that defines what types are allowed for each function argument.

## Installation

`contract` can be installed using luarocks:

```
luarocks install contract
```

You may also download the latest release and include contract.lua in your project folder.

`contract` is compatible with LUA versions 5.1 and up. It does not have any external dependencies.

## Usage Example

```lua
local contract = require('contract')

local function foo(bar, baz)
    -- We want this function to require two parameters, "bar" as a number, and 
    -- "baz" as a string.
    contract('rn,rs')   --'rn'='required number', 'rs'='required string'
end

-- This call to foo() would be OK:
foo(42, 'bleh')

-- However, this would raise an error:
foo(true, {})   -- contract violated; bar must be a number, but it's a boolean.

-- This would also raise an error:
foo(13) -- contract violated; baz is required for foo().

-- Additional parameters not defined in the contract are ignored:
foo(1, 'two', 3)    -- OK

-- Contracts can be turned off, e.g. when the code is ready for release:
contract.off()
foo()   -- No error

```

## Why?

Dynamically-typed languages like LUA have a lot of flexibility, but can also lead to maintenance problems in larger codebases. This library gives you a mechanism to define how your functions are supposed to be used; it's essentially just an assert statement for arg types. Using `contract` can help you identify issues with your code faster, while also "documenting" your functions in a fairly easy-to-understand format.

Note that this library is NOT:
- A full unit-testing solution. `contract` handles only a small subset of errors that can occur in a program, and other testing solutions should be used alongside it.
- A compile-time evaluator. All checks are performed at run-time, however they can be turned off for non-development builds. If you want something that evaluates your code prior to execution, consider something like [TypeScriptToLua](https://github.com/TypeScriptToLua/TypeScriptToLua).

## Contract strings

`contract` defines a sort of "mini-language" for writing contract strings. Here's an explanation of the syntax:

- A contract is made up of "rules" for each argument, separated by commas.
- Each argument rule is a sequence of type codes, describing which of the primitive LUA types are allowed. Here are the corresponding codes for each type:
  - **string**: "s", "str", or "string"
  - **number**: "n", "num", or "number"
  - **boolean**: "b", "bool", or "boolean"
  - **table**: "t", "tbl", or "table"
  - **function**: "f", "fnc", "func", or "function"
  - **thread**: "th" or "thread"
  - **userdata**: "u", "usr", "user", "userdata"
  - **any**: "a" or "any" (used to allow an arg to be any type)
- The alternative string sequences for each type allow you to be as brief or as explicit as you want.
- If an argument has the option of being more than one type, use the "|" operator to separate the valid type codes. Example: "s|n|b" would allow the argument to be a string OR a number OR a boolean.
- For arguments that are required (i.e. cannot be nil), prefix the rule string with an "r".
- All letters are case-insensitive, and all whitespace is ignored.

### Examples

- "**s**": 1st arg must be a string or nil
- "**number**": 1st arg must be a number or nil
- "**rbool**": 1st arg must be a boolean (and cannot be nil)
- "**rt,s**": 1st arg must be a table, 2nd arg must be a string or nil
- "**rstring|rstring|boolean**": 1st and 2nd args must be strings, 3rd arg must be a boolean or nil
- "**a,b**": 1st arg can be anything, 2nd arg must be a boolean or nil
- "**rany,rany**": 1st and 2nd args can be anything (except for nil)

### Contract language in [EBNF](https://en.wikipedia.org/wiki/Extended_Backus%E2%80%93Naur_form)

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
th = 'f'|'fnc'|'function'
tbl = 't'|'tbl'|'table'
any = 'a|any'
```

## API

### `contract.check(input)`

Checks the calling function's arguments against the contract string `input`. Raises an error if the contract is violated.

### `contract(input)`

Alias for `contract.check()`.

### `contract.on()`

Enables all contract checking. When the library is first imported, contracts will be enabled.

### `contract.off()`

Turns off all contract checking.

### `contract.isOn()`

Returns `true` if contract checking is currently enabled; otherwise, returns `false`.

### `contract.toggle()`

Switches the on/off state of the module.

### `contract.config(options)`

Set the configuration settings for the module using a table `options`. Each key/value pair in this table should be the name and new value of an option from the following list:
- **allowFalseOptionalArgs**: *boolean*. When set to `true`, optional args can be omitted using the `false` value, and will not throw an error. Otherwise when set to `false`, only `nil` is used for omitting args. The default is `false`.
- **callCacheMax**: *number*. Sets the upper limit to the function call cache. This cache is used to keep track of redundant function calls that have already been checked and deemed valid. Setting this number to a positive value prevents the cache from growing beyond this number of records. Setting it to a negative number will let the cache grow unbounded. The default is -1 (unbounded).
- **onCallCacheOverflow**: *string*. Sets the behavior for when the call cache reaches its max number of records. When set to "error", an error will be raised. When set to "clear", the cache will be flushed. When set to "nothing", or any other value, no action will be taken. The default is "nothing".

### `contract.clearCallCache()`

Clears the contents of the function call cache.

## Credits
`contract` is written and maintained by [Matt Rogge](https://gitlab.com/mrogge_).

Portions of the interpreter code were inspired by [this great series of tutorials](https://ruslanspivak.com/lsbasi-part1/) written by [Ruslan Spivak](https://ruslanspivak.com/pages/about/).

## License

`contract` is licensed under the [MIT](https://choosealicense.com/licenses/mit/) license.
