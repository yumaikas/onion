# onion

A Stack language compiled to lua. Aims to be like a bit like forth, with concessions made to needing to compile to lua, as well as first class support for a "subject stack" that allows a very pleasant stack-based version of object interaction.

## Requirements

The compiler needs LuaJIT, or Lua 5.2+. The generated Lua can be 5.1 depending on what function calls you use, but won't polyfill things for you.

## Guides

See [Onion in Y minutes](./docs/onion-in-y-minutes.fth) for an overview of the concepts of Onion.
There is a [Quick Reference](./docs/quick-ref.fth) as a one-pager/reminder of the various Onion concepts.


## Usage

### Run/compile code

Compile an Onion file to Lua:

```sh
lua cli.lua --compile script.fth out.lua
``` 
Execute an Onion file 

```sh
lua cli.lua --exec script.fth
```

### Assumption check commands

Print out the tokens as recognized by the lexer, delimited with `[` and `]`.
```sh
lua cli.lua --lex script.fth
```
Print out the lua resulting from compiling script.fth

```sh
lua cli.lua --comptest script.fth
```




## Plan

- Currently: Onion compiler in lua
- TODO: Onion compiler in Onion


