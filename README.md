# onion

A Stack language compiled to lua. Aims to be like forth

## Usage


`lua onion.lua --compile script.fth`


## Plan


### Syntaxes:

- [x] `: name ( a b c -- d ) .. ;`
- [x] `: name { a b c -- d } .. ;`
- [x] `: name  **/* .. ;`
- [x] `: ( a b c -- d ) .. ;`
- [x] `: { a b c -- d } .. ;`
- [ ] `: **/* .. ;`
- [ ] `fn()`
- [ ] `fn(**)`
- [ ] `fn(**/**)`
- [x] `@value`
- [x] `if .. then`
- [x] `if .. else .. then`
- [ ] `do dir via .. loop`
- [ ] `do .. loop`
- [ ] `while .. repeat`
- [ ] `for .. each`
- [ ] `[ .. ].` 
- [ ] `[ .. ]`
