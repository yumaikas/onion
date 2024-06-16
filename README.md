# onion

A Stack language compiled to lua. Aims to be like forth

## Usage


`lua onion.lua --compile script.fth`


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
- [x] `fn(**/**)`
- [x] `@value`
- [x] `if .. then`
- [x] `if .. else .. then`
- [ ] `do .. loop`
- [ ] `+do .. loop` Doing this instead of do .. +loop because lua expects the increment up front
- [ ] `while .. repeat`
- [ ] `for <iter> do _* .. each`
- [x] `[ .. ].` 
- [x] `[ .. ]`
- [x] `.get`
- [x] `>>set`
- [x] `get>>`
- [x] `>get`
