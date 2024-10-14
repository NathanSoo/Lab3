;
; Lab4.asm
;
; Last Modified: 10 Oct 2024
; Author : Amy Willing

; Calculates linear function y = a*x-b, 
; where a, b, x, and y are 8-bit signed integers
; a, b, and x are positive, but the result y can be negative
; When there is an overflow in the calculation, the LED bar flashes.
; Overflow can only occur during multiplication

; Pass in parameters via:
; a = r20
; x = r21
; b = r22
; Possible conflict registers: r16, r17
; Result returned in r25:r24
; r25 set to 1 if overflow occurred, else 0
; Result (y) in r24 if no overflow occurred

.include "m2560def.inc"

.def temp = r17

; Causes LED bar to flash if overflow occurs
.macro flash        
	ser r16
	out PORTC, r16
	ldi r17, 0xFF   ; N.B. adjust to change length of flash
delay:
	dec r17
	brne delay
	clr r20
	out PORTC, r20
.endmacro

main:               ; main function for illustration only
	ser r16 
	out DDRC, r20   ; set port C for output
	clr r16
	out PORTC, r16  ; initial state off
	ldi r20, 8      ; a
	ldi r21, 36     ; x
	ldi r22, 8      ; b
	rcall linear
end:
	rjmp end

linear:
	push YL
	push YH         ; save r29:r28 in stack
	clr  r24       
	clr  r25        ; init r25:r24 to 0 
	in   YL, SPL
	in   YH, SPH    ; Initialise stack frame pointer value
	push r22        ; Pass in b
	push r21        ; Pass in x
	push r20        ; Pass in a
	pop  r16
	pop  r17        ; store a and x into registers
	muls r16, r17
	tst  r1         ; check if overflow
	brne overflow
	sbrc r0, 7      ; check if signed overflow
	rjmp overflow
	mov  r24, r0    ; else continue    
	pop  r16        ; store b into register
	sub  r24, r16
	rjmp done    
overflow:
	flash
	ldi r25, 1		; r25 set to 1 if overflow occurred, else 0 
done:
	pop YH
	pop YL
	ret             ; return to main
