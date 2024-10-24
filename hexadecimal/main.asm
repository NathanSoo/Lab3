;
; hex.asm
;
; Created: 22/10/2024 4:48:59 PM
; Author : Siyuan Zhao
;
; r23-r26 are used here
; The ascii value will be stored in r27 and then sent to lcd


; Replace with your application code
hex_conversion:
	;lds r29, result
    ldi r29, 97          ; Load result (y) into register r29. 97 for the test

    ; Display '0x' prefix
    ldi r27, '0'
;    rcall lcd_send_data
    ldi r27, 'x'
;    rcall lcd_send_data

    ; Extract high nibble
    mov r27, r29          ; Copy number to r27
    lsr r27               ; Shift right by 4 to get high nibble
    lsr r27
    lsr r27
    lsr r27
    andi r27, 0x0F        ; Mask to get lower 4 bits (high nibble)
    rcall hex_to_ascii     ; Convert high nibble to ASCII
;    rcall lcd_send_data    ; Send to LCD

    ; Extract low nibble
    mov r27, r29          ; Copy number to r27 again
    andi r27, 0x0F        ; Mask to get low nibble
    rcall hex_to_ascii     ; Convert low nibble to ASCII
;    rcall lcd_send_data    ; Send to LCD

    ret

hex_to_ascii:
	ldi r26, 'A'-10
    cpi r27, 10           ; Compare if nibble is 0-9 or A-F
    brlo is_digit          ; If less than 10, it's a digit
    add r27, r26      ; Convert to 'A'-'F'
    rjmp done_hex_conversion

is_digit:
	ldi r23, '0'
    add r27, r23           ; Convert to ASCII '0'-'9'

done_hex_conversion:
    ret
