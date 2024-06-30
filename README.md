# onion

A Stack language compiled to lua. Aims to be like a bit like forth, with concessions made to needing to compile to lua, as well as first class support for a "subject stack" that allows a very pleasant stack-based version of object interaction.

## Usage

`lua onion.lua --compile script.fth out.lua`


## Plan

- Currently: Onion compiler in lua
- TODO: Onion compiler in Onion


### Syntaxes:

- [x] `: name ( a b c -- d ) .. ;`
- [x] `: name { a b c -- d } .. ;`
- [ ] `: name  **\* .. ;`
- [x] `: ( a b c -- d ) .. ;`
- [x] `: { a b c -- d } .. ;`
- [ ] `: **\* .. ;`
- [x] `fn()`
- [x] `fn(**)`
- [x] `fn(**\**)`
- [x] `@GlobalAssumedNames`
- [x] `if .. then`
- [x] `if .. else .. then`
- [x] `do .. loop`
- [x] `+do .. loop` 
- [x] `each .. for`
- [x] `ipairs[*\*] .. for`
- [x] `ipairs(*\***) [***\*] .. for`
- [x] `val += var` and friends
- [ ] `while .. repeat`
- [x] `[ .. ].` 
- [x] `[ .. ]`
- [x] `.get`
- [x] `>>set`
- [x] `get>>`
- [x] `>get`
