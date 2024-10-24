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

.def overflow		= r25				; overflow from linear function
.def value			= r24				; value return from linear function
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
	cpi		overflow, 1
	brne	display
	advance_state						; note that advance state here will clear the r10, r11, r12
end_state:
	

	;out		PORTB, arg2

display: 
	rcall INITIALISE_LCD
	rcall decimal_conversion

	

hold_loop:								; wait until button is unpressed before continuing to read keypad
	in		w, PINC						; read port again
	and		w, row_mask					; check value of pin again
	breq	hold_loop					; if button still pressed don't allow key to be continually read

	rjmp	scan_keypad
	


	; linear function
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

;
; lab5_output.asm
;
; Created: 22/10/2024 9:06:18 PM
; Author : Owen
;

; parameter passed from r27
; Replace with your application code
.include "m2560def.inc"
.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5

.def data = r16
.def temp = r17
.def DL = r18
.def DH = r19

.macro lcd_write_cmd		; set LCD instructions, does not wait for BF
	out PORTF, data			; set data port
	clr temp	
	out PORTA, temp			; RS = 0, RW = 0 for a command write
	nop
	sbi PORTA, LCD_E		
	nop
	nop
	nop
	cbi PORTA, LCD_E
	nop
	nop
	nop
.endmacro

.macro lcd_write_data		; write data to LCD, waits for BF
	out PORTF, r27			; set data port
	ldi temp, (1 << LCD_RS)|(0 << LCD_RW)
	out PORTA, temp			; RS = 1, RW = 0 for data write
	nop
	sbi PORTA, LCD_E		;
	nop
	nop
	nop
	cbi PORTA, LCD_E
	nop
	nop
	nop
.endmacro

.macro lcd_wait_busy		; read from LCD until BF is clear
	clr temp
	out DDRF, temp			; read from LCD
	ldi temp, (0 << LCD_RS)|(1 << LCD_RW)
	out PORTA, temp			; RS = =, RW = 1, cmd port read
busy:
	nop						
	sbi PORTA, LCD_E		; turn on enable pin
	nop						; data delay
	nop
	nop
	in temp, PINF			; read value from LCD
	cbi PORTA, LCD_E		; clear enable pin
	sbrc temp, 7			; skip next if busy flag not set
	rjmp busy				; else loop

	nop
	nop
	nop
	clr temp
	out PORTA, temp			; RS, RW = 0, IR write
	ser temp
	out DDRF, temp			; output to LCD
	nop
	nop
	nop
.endmacro

.macro delay				; delay for 1us
loop1:
	ldi temp, 3				; 1
loop2:
	dec temp				; 1
	nop						; 1
	brne loop2				; 2 taken, 1 not ----> inner loop total is 11 cycles
	subi DL, 1				; 1
	sbci DH, 0				; 1
	brne loop1				; 2 taken, each outer iteration is 11 + 1 + 1 + 1 + 2 = 16 clock cycles at 16Mhz = 1us
.endmacro

INITIALISE_LCD:
	; prologue
	push r16
	push r17
	push r18
	push r19
	push YL
	push YH
	in YL, SPL
	in YH, SPH
	sbiw Y, 1

	ser temp
	out DDRF, temp
	out DDRA, temp
	clr temp
	out PORTF, temp
	out PORTA, temp
	;
	ldi DL, low(15000)		; delay 15ms
	ldi DH, high(15000)
	delay
	ldi data, 0b00111000	; 2 x 5 x 7 DL = 1, 8bits | N = 1, 2-line | F = 0, 5 x 7 dots
	lcd_write_cmd			; 1st function cmd set

	ldi DL, low(4100)		; delay 4.1ms
	ldi DH, high(4100)
	delay
	lcd_write_cmd			; 2nd function cmd set

	ldi DL, low(100)		; delay 4.1ms
	ldi DH, high(100)
	delay
	lcd_write_cmd			; 3rd function cmd set
	lcd_write_cmd			; final function cmd set
	;
	lcd_wait_busy			; wait until ready

	ldi data, 0b00001000	; LCD display off
	lcd_write_cmd
	lcd_wait_busy

	ldi data, 0b00000001	; LCD display clear
	lcd_write_cmd
	lcd_wait_busy

	ldi data, 0b00000110	; increment, no shift
	lcd_write_cmd
	lcd_wait_busy

	ldi data, 0b00001111	; LCD display on, cursor, blink
	lcd_write_cmd
	lcd_wait_busy

	;epilogue
	adiw Y, 1
	out SPH, YH
	out SPL, YL
	pop YH
	pop YL
	pop r19
	pop r18
	pop r17
	pop r16
	ret

WRITE:
	; write to data
	push r16
	push r17
	push YL
	push YH
	in YL, SPL
	in YH, SPH
	sbiw Y, 1

	mov data, r27	; change the arg register to display
	lcd_write_data
	lcd_wait_busy

	;epilogue
	adiw Y, 1
	out SPH, YH
	out SPL, YL
	pop YH
	pop YL
	pop r17
	pop r16
	ret


;
; Decimal_Hex.asm
;
; Created: 22/10/2024 3:49:27 PM
; Author : Siyuan Zhao z5554919
;

;   r27 will be the ascii value of the hundreds and tens
;   r30 will be the ascii value of the ones
;   r28-R23 are used here
	

decimal_conversion:
	ldi r23, '0'
    ldi r26, r24             ; Load result (y) r24 into register r26.
    tst r26                   ; Test if result is zero
    brpl positive_number       ; If positive, branch to handle positive numbers



    ; Handle negative number
    ldi r27, '-'              ; Load ASCII for '-'
    lcd_write_data
	lcd_wait_busy
    neg r26                   ; Negate the number to convert to positive

positive_number:
    ; Convert hundreds place
    ldi r28, 100              ; Load 100 for division
    rcall divide               ; Call divide subroutine
    mov r27, r29               ; Get the quotient (hundreds digit) in r27
    cpi r27, 0                ; Check if it's zero
    brne display_digit         ; If non-zero, display it
    rjmp check_tens_digit      ; Otherwise, move to tens place

display_digit:
    add r27, r23              ; Convert to ASCII ('0' = 0x30)
    lcd_write_data
	lcd_wait_busy

check_tens_digit:
    ; Convert tens place
    ldi r28, 10               ; Load 10 for division
    rcall divide               ; Call divide subroutine
    mov r27, r29               ; Get the quotient (tens digit) in r27
    cpi r27, 0                ; Check if it's zero
    brne display_tens_digit    ; If non-zero, display it
    rjmp display_ones_digit    ; Otherwise, move to ones place

display_tens_digit:
    add r27, r23              ; Convert to ASCII
    lcd_write_data
	lcd_wait_busy
display_ones_digit:
    ; Ones place is left in r30 (remainder of tens division)
    add r30, r23              ; Convert to ASCII
	mov r27, r30
    rcall WRITE        ; Send ones digit to LCDlcd_write_data
	lcd_wait_busy

    ret                        ; Return from subroutine

; Divide r26 by r28, result is quotient in r29 and remainder in r30
divide:
    clr r29                   ; Clear quotient register
    clr r30                   ; Clear remainder register

divide_loop:
    cp r26, r28               ; Compare r26 (dividend) with r28 (divisor)
    brlo divide_done           ; If r26 < r28, exit loop

    sub r26, r28              ; Subtract divisor from dividend
    inc r29                   ; Increment quotient
    rjmp divide_loop           ; Repeat until r26 < r28

divide_done:
    mov r30, r26              ; Store remainder in r30
    ret                        ; Return with quotient in r29 and remainder in r30