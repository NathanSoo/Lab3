;
; lab3.asm
;
; Created: 10/10/2024 2:11:24 PM
; Author : nsoo1
;	

.equ PORTCDIR		= 0b11110000
.equ PORTBDIR		= 0b00001111
.equ INITCOLMASK	= 0b01111111
.equ INITROWMASK	= 0b00001000
.equ CHECKROWMASK	= 0b00001111

.equ KEYPADSIZE		= 4
.equ NSTATES		= 3
.equ LARGESTDIGIT	= 9

.def w				= r16				; free to change
.def cur_col		= r2				; free to change outside of keypad loop
.def cur_row		= r3				; free to change outside of keypad loop
.def keypad_size	= r4				; please don't change
.def row_val		= r5				; free to change outside of keypad loop
.def temp			= r6				; free to change
.def arg0			= r10				; please don't change
.def arg1			= r11				; please don't change
.def arg2			= r12				; please don't change
.def row_mask		= r17				; please don't change
.def col_mask		= r18				; free to change outside of keypad loop
.def state			= r19				; please don't change

.cseg

.macro debounce
	ldi zl, 0b11111111
	ldi zh, 0b11111111

debounce_loop:
	nop
	subi zl, 1
	sbci zh, 0
	brne debounce_loop
.endmacro

.macro add_digit
	mov		r6, @0
	lsl		r6
	lsl		r6
	lsl		r6
	lsl		@0
	add		@0, r6
	add		@0, @1
.endmacro

.macro advance_state
	inc		state
	cpi		state, NSTATES
	brlt	end_advance
	clr		state
	clr		arg0
	clr		arg1
	clr		arg2
end_advance:
.endmacro

; Causes LED bar to flash if overflow occurs
.macro flash        
	ser r16
	out PORTB, r16
	ldi r17, 0x20   ; N.B. adjust to change length of flash
delay:
	debounce
	dec r17
	brne delay
	clr r16
	out PORTB, r16
.endmacro
	

	ldi		w, KEYPADSIZE				; initialise keypad size
	mov		keypad_size, w

	ldi		w, PORTCDIR					; initialise pin directions
	out		DDRC, w
	ldi		w, PORTBDIR
	out		DDRB, w
	;ser		r16 
	;out		DDRE, r20   ; set port C for output

	clr		state						; initialise input state
	clr		arg0
	clr		arg1
	clr		arg2

scan_keypad:
	clr		cur_col						; clear column
	ldi		col_mask, INITCOLMASK		; initialise column mask

loop:
	cp		cur_col, keypad_size		; if maximum columns reached
	brlt	push_mask
	ldi		col_mask, INITCOLMASK		; reset the column mask
	clr		cur_col						; reset column count
push_mask:
	out		PORTC, col_mask
	ldi		w, 0b11111111				; delay to allow pin to update
update_delay:
	dec		w
	brne	update_delay

	in		w, PINC						; read portc
	andi	w, CHECKROWMASK				; read only the inputs
	cpi		w, CHECKROWMASK
	breq	nextcol						; check if any of the buttons are pressed

	mov		row_val, w					; save copy of inputs
	clr		cur_row						; initialise row scan
	ldi		row_mask, INITROWMASK
row_loop:
	mov		w, row_val					; get input value
	and		w, row_mask					; mask out single bit
	brne	inc_row						; if button pressed
	debounce							; debounce button
	in		w, PINC						; read port again
	and		w, row_mask					; check value of pin again
	breq	resolve						; if button still pressed resolve value
inc_row:
	lsr		row_mask					; shift row mask
	inc		cur_row						; increment row count
	cp		cur_row, keypad_size
	brne	row_loop
nextcol:
	lsr		col_mask					; shift column mask right
	sbr		col_mask, 0b10000000		; re-set left most bit
	inc		cur_col						; increment column count
	rjmp	loop

resolve:
	lsl		cur_row						; get key index by adding row * 4 + column
	lsl		cur_row
	mov		w, cur_row
	add		w, cur_col

	ldi		zh, high(value_lookup<<1)	; get numeric value from lookup table (or ascii if non-numeric)
	ldi		zl, low(value_lookup<<1)

	clr		r15							
	add		zl, w
	adc		zh, r15

	lpm		w, z

	cpi		state, 0					; state machine
	breq	state0
	cpi		state, 1
	breq	state1
	cpi		state, 2
	breq	state2

	; below is where code to write to LCD can be written
state0:
	cpi		w, LARGESTDIGIT				; check if value is numeric
	brge	not_num0					; if not check if button advances state
	add_digit arg0, w					; if numeric then multiply existing argument by 10 and add new number
	rjmp	end_state
not_num0:
	cpi		w, 0x2A						; check if correct button is pressed otherwise do nothing	
	brne	end_state					
	advance_state						; otherwise advance the state machine
	rjmp	end_state
state1:
	cpi		w, LARGESTDIGIT
	brge	not_num1
	add_digit arg1, w
	rjmp	end_state
not_num1:
	cpi		w, 0x44
	brne	end_state
	advance_state
	rjmp	end_state
state2:
	cpi		w, LARGESTDIGIT
	brge	not_num2
	add_digit arg2, w
	rjmp	end_state
not_num2:
	cpi		w, 0x23
	brne	end_state
	rcall	linear
	advance_state						; note that advance state here will clear the r10, r11, r12
end_state:

hold_loop:								; wait until button is unpressed before continuing to read keypad
	in		w, PINC						; read port again
	and		w, row_mask					; check value of pin again
	breq	hold_loop					; if button still pressed don't allow key to be continually read

	rjmp	scan_keypad
	

halt:
	rjmp	halt
value_lookup:
	.db		1, 2, 3, 0x41, 4, 5, 6, 0x42, 7, 8, 9, 0x43, 0x2A, 0, 0x23, 0x44
ascii_lookup:
	.db		0x31, 0x32, 0x33, 0x41, 0x34, 0x35, 0x36, 0x42, 0x37, 0x38, 0x39, 0x43, 0x2A, 0x30, 0x23, 0x44

linear:
	push YL
	push YH         ; save r29:r28 in stack
	push ZL
	push ZH
	push r16
	push r17		; save conflict registers
	clr  r24       
	clr  r25        ; init r25:r24 to 0 
	in   YL, SPL
	in   YH, SPH    ; Initialise stack frame pointer value
	push r12        ; Pass in b
	push r11        ; Pass in x
	push r10        ; Pass in a
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
	pop r17
	pop r16         ; reset conflict registers
	pop ZH
	pop ZL
	pop YH
	pop YL
	ret             ; return to main
