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
;    rcall lcd_send_data        ; Send '-' to the LCD
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
;    rcall lcd_send_data        ; Send hundreds digit to LCD

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
;    rcall lcd_send_data        ; Send tens digit to LCD

display_ones_digit:
    ; Ones place is left in r30 (remainder of tens division)
    add r30, r23              ; Convert to ASCII
	mov r27, r30
;    rcall lcd_send_data        ; Send ones digit to LCD

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
