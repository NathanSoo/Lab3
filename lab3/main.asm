;
; lab3.asm
;
; Created: 10/10/2024 2:11:24 PM
; Author : nsoo1
;	

.def	w = r16

	ldi w, 0b11110000

	out DDRC, w

	ldi w, 0b00001111

	out DDRB, w
	out PORTB, w


outer_key_scan_loop:

halt:
	rjmp halt
