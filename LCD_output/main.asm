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
	out PORTF, r19			; set data port
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

main:
	rcall INITIALISE_LCD
	ldi r19, 'A'
	rcall WRITE
	
	ldi r19, 'B'
	rcall WRITE
	ldi r19, 'C'
	rcall WRITE
	ldi r19, 'D'
	rcall WRITE
	ldi r19, 'E'
	rcall WRITE
	

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

	mov r16, r19	; change the arg register to display
	lcd_wait_busy
	lcd_write_data

	;epilogue
	adiw Y, 1
	out SPH, YH
	out SPL, YL
	pop YH
	pop YL
	pop r17
	pop r16


	ret