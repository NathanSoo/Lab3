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
.equ COLXORMASK		= 0b10000000
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
	eor		col_mask, col_xor_mask		; re-set left most bit and clear bit right of mask
	inc		cur_col						; increment column count
	rjmp	loop

resolve:
	lsl		cur_row
	lsl		cur_row
	mov		w, cur_row
	add		w, cur_col

	ldi		zh, high(lookup<<1)
	ldi		zl, low(lookup<<1)

	clr		r15
	add		zl, w
	adc		zh, r15

	lpm		w, z

	out		PORTB, w


	rjmp scan_keypad

halt:
	rjmp	halt

lookup:
	.db	0x31, 0x32, 0x33, 0x41, 0x34, 0x35, 0x36, 0x42, 0x37, 0x38, 0x39, 0x43, 0x2A, 0x30, 0x23, 0x44