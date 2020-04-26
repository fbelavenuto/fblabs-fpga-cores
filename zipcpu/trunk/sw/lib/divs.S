;
;	DIVS
;
;	Given R0,R1, computer R0 = R0/R1 and R1 = R0%R1 for signed R0,R1.
;	We'll call R0 (input) x, R1(input) y, result is such that
;	R0 * y + R1 = x.  Now let's work through our signs with an example
;	where x = +/- 22, and y = +/- 4:
;
;	x y
;	+ +	No change, just call divu
;	- +	(x=-22,y= 4,R0=-5,R1=-2)
;	+ -	(x= 22,y=-4,R0=-5,R1= 2)
;	- -	(x=-22,y=-4,R0= 5,R1=-2)
;
;
;
lib_divs: ; Given R0,R1, computer R0 = R0/R1 and R1 = R0%R1 for signed R0,R1
	SUB	2,SP
	STO	R2,(SP)
	STO	R3,2(SP)
	;
	CLR	R3		; Keep track of resulting sign in R2
	TST	-1,R0		; Is R0 negative?
	MOV	ret_div32s(PC),R2
	LLO.LT	3,R3		; If so, resulting sign will be negative, and
	NEG.LT	R0		; then we negate R0 (R0 = ABS(R0))
	MOV.LT	divu_divs_return(PC),R2
	TST	-1,R1		; Is R1 negative?
	XOR.LT	1,R3		; If so, result will be opposite sign of before
	NEG.LT	R1		; Now we get R1=ABS(R1)
	MOV.LT	divu_divs_return(PC),R2
	BRA	lib_divu	; Do our unsigned multiply
	; JSR	divu		; Do our unsigned multiply
divu_divs_return:
	TST	1,R3		; Check resulting sign
	NEG.NE	R0		; Need to flip the sign of our result
	TST	2,R3		; Now, if R1 was originally negative
	NEG.NE	R1		; Then negate R1
ret_div32s:
	LOD	(SP),R2
	LOD	2(SP),R3
	ADD	2,SP
	JMP	R2

