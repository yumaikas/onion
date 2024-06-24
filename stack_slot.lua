local Object = require("classic")

StackSlot = Object:extend()


--[[
	Stack slots....
	Can hold:
	- A constant, 0, 1 etc
	- An operation/expression, 1+2 etc
	- a variable

	Operations to a stack slot:

	- Create with constant -> 0 [s2]
	- Create with non-constant s3 = <expr>
	- Duplicate a constant -> s2 = 0, s3=s2; emit assignment, change to variable -- 
	- Duplicate a variable -> s3=s2, both on stack
	- 

]]
