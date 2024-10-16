;
; lab3.asm
;
; Created: 10/10/2024 2:11:24 PM
; Author : nsoo1
;	

.equ PORTCDIR		= 0b11110000
.equ PORTBDIR		= 0b00001111
.equ INITCOLMASK	= 0b01110000
.equ INITROWMASK	= 0b00001000
.equ COLXORMASK		= 0b10001000
.equ CHECKROWMASK	= 0b00001111

.equ KEYPADSIZE		= 4

.def w				= r16				; free to change
.def cur_col		= r2				; free to change
.def cur_row		= r3				; free to change
.def col_xor_mask	= r4				; please don't change
.def keypad_size	= r5				; please don't change
.def row_val		= r6				; free to change
.def row_mask		= r17				; free to change
.def col_mask		= r18				; free to change

.macro debounce
	ldi zl, 0b11111111
	ldi zh, 0b11111111

debounce_loop:
	nop
	subi zl, 1
	sbci zh, 0
	brne debounce_loop

.endmacro

	ldi		w, COLXORMASK				; initialise xor mask
	mov		col_xor_mask, w

	ldi		w, KEYPADSIZE				; initialise keypad size
	mov		keypad_size, w

	ldi		w, PORTCDIR					; initialise pin directions
	out		DDRC, w
	ldi		w, PORTBDIR
	out		DDRB, w

scan_keypad:
	clr		cur_col						; clear column

	ldi		col_mask, INITCOLMASK		; initialise column mask

loop:
	cp		cur_col, keypad_size		; if maximum columns reached
	breq	push_mask
	ldi		col_mask, INITCOLMASK		; reset the column mask
	clr		cur_col						; reset column count
push_mask:
	out		PORTC, col_mask
	ldi		w, 0b11111111				; delay to allow pin to update
update_delay:
	dec		w
	brne	update_delay

	in		w, PINB						; read portb
	andi	w, CHECKROWMASK				; read only the inputs
	cpi     w, CHECKROWMASK				; check if any of the buttons are pressed
	breq	nextcol

	clr		cur_row						; clear row
	ldi		row_mask, INITROWMASK		; initialise
	mov		row_val, w					; move value of inputs to another register
row_loop:
	mov		w, row_val					; get input value
	and		w, row_mask					; mask out single bit
	brne	inc_row						; if button pressed
	debounce							; debounce button
	in		w, PINB						; read port again
	and		w, row_mask					; check value of pin again
	breq	resolve						; if button still pressed resolve value
inc_row:
	lsr		row_mask					; shift row mask
	inc		cur_row						; increment row count
	cp		cur_row, keypad_size
	brne	row_loop
nextcol:
	lsr		col_mask					; shift column mask right
	eor		col_mask, col_xor_mask		; re-set left most bit and clear bit right of mask
	inc		cur_col							; increment column count
	rjmp	loop

resolve:
	lsl		cur_row
	lsl		cur_row
	mov		w, cur_row
	add		w, cur_col




	rjmp scan_keypad
