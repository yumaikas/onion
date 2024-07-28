\ Onion in Y minutes

\ Onion is a language that compiles to lua using a stack metaphor

\ Comments use `\` followed by a space

\ -- Values and Variables
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

\ -- Basic Onion word definitions
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
\ This compiles to lua that directly uses the function parameters
\ efficiency isn't a concern

\ Finally, words aren't required to have a name
: ( a b -- c ) + ; { var-add }
\ This allows you do things like return a function from a word
\ and word definitions -are- allowed to nest, unlike factor 
\ or Forth
: counter { init -- fn } : ( -- v ) init 1 + { init } init ; ;

\ now ctr is a reference to a counter function that starts at 1
1 counter { ctr } 
\ Words usually have semantics based on their stack effect
\ or being declared as a local variable
\ "behaves" alllows you to assign new default semantics to a word
behaves ctr (\*) 
\ either via a short-stack effect, or using @ to tell Onion to 
\ treat the word like a variable

ctr ctr ctr print(***)  \ prints "1    2    3"

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

\ -- Conditional statements
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

\ This is a specialization of if/else/then statements
\ The rule for them is that the true and false arms 
\ of the statement need to be the same overall effect on the stack
4 dx 2 mod? if "even" else "odd" then print(*)

\ This is why if statements without an else branch have to be balanced
\ since the implicit "else" is not changing the stack, so the stack
\ needs to have the same size after

\ Cond is the most general case of a conditional statement

4 dx { r }
cond 
    \ For now, the predicate/condition clause can't take any inputs
    \ and must only output one value. 
    r 1 eq? -> "one" of
    \ Meanwhile, every guarded clause needs to have the same stack effect, but can have 
    r 2 eq? -> "two" of
    r 3 eq? -> "three" of
    r 4 eq? -> "four" of
    \ TODO: Enforce a default clause if any clauses have outputs?
    true -> @nil of
end print(*)

\ -- Working with tables

table { t } \ Create an empty table
t 1 >a \ Set a field in it
t .a print(*) \ Get the field and use it

"b" { k }
t k 2 put \ Use a variable as the key, to set a table value like t[k] = 2
t k get \ Or to get it out


\ -- Loops
\ ----------------------------------------------------------------

\ Onion has a few different types of loops

\ The most basic is a counted loop:
10 1 do ", " .. io.write(*)  loop \ prints 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 

\ You can count backwards by specifying a custom step
1 10 -1 +do ", " .. io.write(*) loop \ prints 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 

\ If you want a loop that has a condition, you can do it like so
true { going } 
do? going while "Keep going? (y/n): " print(*) io.read() "y" eq? { going } loop 

\ Another counted loop example:
\ table creates a new, empty table
table { tbl }  
10 1 do tbl swap table.insert(**) loop

\ Then, there's your basic `each` loop, which is based on ipairs, but without the index
\ it starts with `each` and ends with `for`
\ each loops bodies are expected to have no outputs
tbl each "," .. io.write(*) for \ prints 1,2,3,4,5,6,7,8,9,10,

\ And, finally, a more general form that allows access to lua's full iterator protocol:
tbl ipairs[*\_*] "," .. io.write(*) for \ prints 1,2,3,4,5,6,7,8,9,10,
\ It uses square brackets instead of parens after a word, and compiles down
\ to a for loop in lua. The inputs go into the iterator function, 
\ and the outputs are fed to the loop body. An underscore can be used to 
\ not pass an output to the loop body, since not all uses of a given iterator are interested
\ in all of its per-iteration outputs

\ -- "it" stack
\ ----------------------------------------------------------------

\ The "it" stack is a specialization of how Forth uses the return stack for data
\ or how Factor uses a retain stack.

\ First things first, to push a value onto the "it" stack, use `[`
\ and use `]` to pop it off onto the value stack again
table [ ] { tbl } 

\ Due to Onion being compiled, functions you write that want to take an `it` parameter need to have 
\ a # as part of their stack effect.
\ You can also use # in a function call to indicate that it should take the current `it` value in parameter slot.
: , (#*\) table.insert(#*) ;

\ Additionally, Onion has some conveniences for working with tables on the `it` stack

: pos ( # -- ) it .x it .y ;
\ Can be shortened to this
: pos ( # -- ) x>> y>> ; 

: to-pos ( # x y -- ) it swap >y it swap >x ;
\ can be shorted to
: to-pos ( # x y -- ) >>y >>x ;

\ Another example of the it stack
: mov ( # x y -- ) y>> + >>y x>> + >>x ;

\ There is a convinence word for making a new table, t[
: <xy> ( x y -- t ) t[ to-pos ] ;


\ Finally, there's a way to use this to more easily construct module-style tables
\ ::name names the value on the top of the `it` stack, which allows `::` to
\ define words that are inside that table
t[ ::bubbles
:: spawn (**\) bubbles [ t[ to-pos 0 >>t ] , ]. ;
:: tic (\) bubbles each [ 0 -1 mov ++t ]. ;
]. 




