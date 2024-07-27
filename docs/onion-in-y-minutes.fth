\ Onion in Y minutes

\ Onion is a language that compiles to lua using a stack metaphor

\ Comments use `\` followed by a space

\ -- values and variables
\ ---------------------------------------------------------
\ To add two numbers and print them
1 2 + print(*) \ prints "3"

\ Or to concatenate two strings and print them
"foo" "bar" .. print(*) \ prints "foobar"

\ If you want to define a local variable in Onion, use { } like so
"Onion" { name }

\ then you can refer to it later
"Hello " name print(**) \ prints "Hello Onion"

\ Onion -is- stack based, which means you can define more than one variable at one
0 0 { x y }

\ -- Lua Function calls
\ ---------------------------------------------------------

\ If an identifier has () after it, it means it's a lua function call
\ The general form is (*\*) where the number of `*` before the `\` is the number of function inputs
\ and the number of `*` after the `\` is the number of outputs

\ this call to `assert` takes two inputs, and leaves one output on the stack
"a result" @nil assert(**\*) 
io.read(\*) \ This leaves one output on the stack
print(**)  \ this prints both of those stack values

\ -- Onion word definitions
\ ----------------------------------------------------------------
\ A word definition in Onion can take a few different forms

\ This is the classic forth or factor style form, where each 
\ input and output in the stack effect is given a name for
\ documentation purposes
: add ( a b -- c ) + ; 

\ This form uses the call syntax as a short-form for a stack effect 
\ It's useful for when the definition is short, or when the names
\ don't add much documenation value
: divide (**\*) div ;

\ This form uses a modified form of the locals syntax
\ to show the stack effect of the function
\ Notably, it does -not- push the inputs onto the stack
\ assuming that you'll access them via the locals
: +xy { x y dx dy -- x' y' } x dx + y dy + ;

\ If you're familiar with other stack languages, this is 
\ mostly meant for when you'd have to do a lot of stack
\ shuffling to express something. 
\ Detail: This compiles to lua that
\ directly uses the function parameters, there isn't
\ a return stack involved


\ -- Stack effect checking
\ ----------------------------------------------------------------
\ Onion, because it compiles to lua, has to make sure that every
\ word has a balanced stack effect. 

\ Will error with "expected **\*, got [ * * - * ]" 
\ TODO: Fix error message in compiler to better match existing effects
: fails-to-compile (*\**) + ; 

\ Onion does this in a way that prevents runtime stack underflows
\ so that it can emit "straight line" lua, aka lua that doesn't have
\ a "stack" at runtime.

\ -- Control flow
\ ----------------------------------------------------------------
\ This allows us to talk about control flow

\ If statements take the top of the stack, and conditionally execute
\ their body, which ends in `then` based on if it is truthy

2 1 > if "two is greater than one" print(*) then

\ some helpers 
: dX (*\*) 1 swap math.random(**\*) ;
: mod? ( n m -- ? ) mod 0 eq? ;

\ An if statement is required to have a balanced stack effect
\ aka, for every input it takes, it must have the same number
\ of outupts

4 dX 2 mod? if 1 + then \ This is valid
4 dX 3 mod? if + then \ This is not, because + has an effect of (**\*)

\ This is a generalization of if/else/then statements
\ The rule for them is that the true and false arms 
\ of the statement need to be the same overall effect on the stack
4 dx 2 mod? if "even" else "odd" then print(*)

\ This is why if statements without an else branch have to be balanced
\ since the implicit "else" is not changing the tack

\ Cond is the most general case of a conditional statement

4 dx { r }
cond 
    \ For now, the predicate/condition clause can't take any inputs
    \ and must only output one value. 
    r 1 eq? -> "one" of
    \ Meanwhile, every guarded clause needs to have the same stack effect
    r 2 eq? -> "two" of
    r 3 eq? -> "three" of
    r 4 eq? -> "four" of
    \ TODO: Enforce a default clause if any clauses have outputs?
    true -> @nil of
end print(*)


















