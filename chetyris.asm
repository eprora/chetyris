/*
   Chetyris
   Copyright (c) 2026 EPRORA

   Distributed under the Boost Software License, Version 1.0.
   See below for the full license text.
*/

/*
Boost Software License - Version 1.0 - August 17th, 2003

Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license (the "Software") to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated
by a source language processor.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
*/

/*
   Disclaimer:
   Chetyris is an independent project and is not affiliated with,
   endorsed by, or sponsored by The Tetris Company, LLC.
   "Tetris" is a registered trademark of The Tetris Company, LLC.
*/

; registers
const next1 = r4; reserved temporarily
const next2 = r5; reserved temporarily
const next3 = r6; reserved temporarily
const next4 = r7; reserved temporarily
const last_key = r8; reserved all time
const last_time = r9; reserved all time
const piece1 = r10; reserved all time
const piece2 = r11; reserved all time
const piece3 = r12; reserved all time
const piece4 = r13; reserved all time

; screen values
const row_length_m2 = 94
const row_length = 96
const row_length_p2 = 98
const row_length_p4 = 100
const row_length_p6 = 102
const row_length_x2 = 192

; values
const KEY_ACCELERATE = 0x14
const KEY_LEFT = 0x17
const KEY_ROTATE = 0x18
const KEY_RIGHT = 0x19
const KEY_ACCELERATE_2 = 0xD1
const KEY_LEFT_2 = 0xD0
const KEY_ROTATE_2 = 0xC1
const KEY_RIGHT_2 = 0xD2

const ASCII_SPACE = 0x20
const ASCII_ZERO = 0x30
const DOUBLE_ASCII_SPACE = 0x2020
const DIFFICULTY_SETTING = 0x4E ; 30 + ASCII_ZERO, decreasing makes it harder

; addresses
const lines_number_location = 2384
const score_number_location = 2388
const next_piece_number_location = 2392
const spawn_location = 2344
const field_location = 2434
const lines_completed_location = 2514
const level_location = 2610
const score_location = 2800
const next_piece_location = 3370
const game_over_location = 4222

; SCREEN SETTINGS ===================================================================
mov r1, 0
screen r1, 0; ASCII-8 mode

mov r1, 2
mov r3, font_color
load_32 r2, [r3]
screen r1, r2; set font color

mov r1, 1
mov r2, 0; Offset, 32-bit mode need 4
add r2, r2, visual_data
screen r1, r2; set data offset

mov r2, ASCII_ZERO
store_8 [score_location], r2; set initial score

; PROGRAM STARTS HERE ===============================================================
; generate new piece
generate_first:
time_0 r1;
lsr r1, r1, 6
and r1, r1, 0b111
cmp r1, 7; r1 = pseudo random number in 0-7, but only 7 shapes exist
je generate_first; generate new number if 7 (no shape)
store_8 [next_piece_number_location], r1

; initialize piece in the game area
call generate_next; generate automatically herer

; test stuff here
;mov piece1, 2430
;debug_loop:
	;jmp debug_loop

; MAIN LOOP =========================================================================
main_loop:
	; get difficulty level
	load_8 r2, [level_location]
	mov r1, DIFFICULTY_SETTING
	sub r2, r1, r2
	
	; check time
    time_0 r1
    lsr r1, r1, r2; difficulty changes time intervall
    cmp r1, last_time
    je check_keys
    
	; let the block fall if it is time
    mov last_time, r1
    mov r1, row_length
    call move_piece
    cmp r1, 0
    jne check_keys
    
    ; block fell to ground
    call clear_lines; returns number of lines cleared in r1
    push r1; cache r1 content cause it is lost otherwise
    call add_lines_completed
    pop r3
    ; add special scores here
    mov r4, 0
    cmp r3, 1
    jb add_special_scores
    add r4, r4, 10; 10 points for 1 line
    cmp r3, 2
    jb add_special_scores
    add r4, r4, 20; 30 points for 2 lines
    cmp r3, 3
    jb add_special_scores
    add r4, r4, 30; 60 points for 3 lines
    cmp r3, 4
    jb add_special_scores
    add r4, r4, 40; 100 points for 4 lines
    add_special_scores:
	load_8 r5, [level_location]
	sub r5, r5, 0x2F
	call multiply; r4 = r4*r5
	mov r1, r4
    call add_score
    call generate_next

; CHECK KEYS ========================================================================
check_keys:
    ; --- 1) continuous accelerate based on last_key ---
    mov r2, last_key
    and r2, r2, 0xFF00        ; r2 = event type (high byte)
    cmp r2, 0x0100            ; 0x01?? = key-down event?
    jne skip_hold_check

    mov r3, last_key
    and r3, r3, 0x00FF        ; r3 = key code (low byte)
    cmp r3, KEY_ACCELERATE
    je do_accelerate
    cmp r3, KEY_ACCELERATE_2
    je do_accelerate
    
skip_hold_check:
    ; --- 2) read latest event ---
    keyboard r1
    ; skip if no new event or last key did not change
    cmp r1, 0
    je main_loop
    cmp r1, last_key
    je main_loop
    mov last_key, r1          ; store new latest event
    ; decode event type
    mov r2, r1
    and r2, r2, 0xFF00        ; r2 = event type (high byte)
    cmp r2, 0x0100            ; only react on key-down events
    jne main_loop             ; ignore key-up and others
    ; extract key code
    mov r3, r1
    and r3, r3, 0x00FF        ; r3 = key code (low byte)

    ; --- 3) normal key handling ---
    cmp r3, KEY_LEFT
    je do_left
    cmp r3, KEY_LEFT_2
    je do_left
    cmp r3, KEY_RIGHT
    je do_right
    cmp r3, KEY_RIGHT_2
    je do_right
    cmp r3, KEY_ROTATE
    je do_rotate
    cmp r3, KEY_ROTATE_2
    je do_rotate
    jmp main_loop

; --- 4) handlers ---
do_left:
    sub r1, zr, 2
    call move_piece
    jmp main_loop
do_right:
    add r1, zr, 2
    call move_piece
    jmp main_loop
do_rotate:
    call rotate_piece
    jmp main_loop
do_accelerate:
    mov r1, row_length
    call move_piece
    cmp r1, 0
    je skip_hold_check; only add score if move was able
    mov r1, 1
    call add_score
    jmp skip_hold_check
    
; CHECK LINES =======================================================================
; clear_lines (Two-Pointer Method, 20 rows, big-endian)
; Result: r1 = number of cleared lines

clear_lines:
    mov r1, 0           ; r1 = cleared lines count
    mov r2, 19          ; r2 = read_row (starts at bottom row 19)
    mov r3, 19          ; r3 = write_row (starts at bottom row 19)
    
scan_lines:
    ; calculate read_row base address -> r7
    ; r7 = field_location + r2 * row_length
    mov r4, r2
    mov r5, row_length
    call multiply
    add r7, r4, field_location
    
    ; Scan the current read_row to see if it is full
    mov r4, r7          ; r4 = moving pointer for scanning
    mov r5, r7
    add r5, r5, 20      ; r5 = end pointer (row base + 20 bytes)
    
check_block:
    cmp r4, r5
    je row_full
    
    load_8 r6, [r4]     ; load the first byte of the block
    cmp r6, 0x20        ; 0x20 is ASCII space
    je row_not_full
    
    add r4, r4, 2       ; skip to next block (2 bytes wide)
    jmp check_block
    
row_full:
    add r1, r1, 1       ; increment cleared count
    
    ; Check if we just processed the top row (row 0)
    cmp r2, 0
    je fill_top_lines
    
    sub r2, r2, 1       ; move read_row UP
    jmp scan_lines      ; write_row STAYS exactly where it is

row_not_full:
    cmp r2, r3
    je skip_copy        ; if read_row == write_row, no need to copy
    
    ; Copy read_row (r7) into write_row
    mov r4, r3
    mov r5, row_length
    call multiply; r4=r4*r5
    add r4, r4, field_location    ; r4 = write_row base pointer
    mov r5, r7
    add r5, r5, 20      ; end pointer for copy
    
copy_loop:
    cmp r7, r5          ; have we copied all 20 bytes?
    je skip_copy
    load_8 r6, [r7]     ; read byte from read_row
    store_8 [r4], r6    ; write byte to write_row
    add r7, r7, 1       ; advance read pointer
    add r4, r4, 1       ; advance write pointer
    jmp copy_loop
    
skip_copy:
    ; Check if we just processed the top row (row 0)
    cmp r2, 0
    je fill_top_lines
    sub r2, r2, 1       ; move read_row UP
    sub r3, r3, 1       ; move write_row UP
    jmp scan_lines

fill_top_lines:
    ; r1 holds the number of cleared lines. Clear the top r1 rows (0 to r1-1).
    cmp r1, 0
    je done             ; if 0 lines cleared, do nothing
    mov r6, 0x202E      ; load empty block pattern into r6
    mov r2, 0
    
clear_loop:
    cmp r2, r1          ; stop once we've cleared r1 rows
    je done
    ; calculate target row base address -> r7
    mov r4, r2
    mov r5, row_length
    call multiply; r4=r4*r5
    add r7, r4, field_location
    mov r4, r7
    add r4, r4, 20      ; r4 = end pointer (row base + 20)
    
clear_block_loop:
    cmp r7, r4
    je next_clear_row
    
    store_16 [r7], r6   ; write the full 2-byte empty block at once
    add r7, r7, 2
    jmp clear_block_loop
    
next_clear_row:
    add r2, r2, 1
    jmp clear_loop
    
done:
    ret
    
; SPAWN NEXT PIECE ==================================================================
generate_next:
	time_0 r1;
	lsr r2, r1, 3
	xor r1, r1, r2
	lsr r2, r1, 6
	xor r1, r1, r2
	and r1, r1, 0b111
	cmp r1, 7; r1 = pseudo random number in 0-7, but only 7 shapes exist
	je generate_next; generate new number if 7 (no shape)
	;jmp spawn_next
spawn_next: ; r1 = piece number to get next
	; clear field for next piece
	mov r2, DOUBLE_ASCII_SPACE
	mov r6, next_piece_location
	np_clear_loop_outer:
	mov r3, r6
	np_clear_loop:
	store_16 [r3], r2
	add r3, r3, 2
	sub r7, r3, r6
	cmp r7, 7
	jb np_clear_loop
	add r6, r6, row_length
	sub r7, r6, next_piece_location
	cmp r7, row_length_x2
	jb np_clear_loop_outer
	; draw next piece in its field
	call get_next
	add piece1, piece1, next_piece_location
	add piece2, piece2, next_piece_location
	add piece3, piece3, next_piece_location
	add piece4, piece4, next_piece_location
	call draw_piece
	; store new next piece number and load current
	load_8 r2, [next_piece_number_location]
	store_8 [next_piece_number_location], r1
	mov r1, r2
	; draw current piece at spawn location
	call get_next
	add next1, piece1, spawn_location
	add next2, piece2, spawn_location
	add next3, piece3, spawn_location
	add next4, piece4, spawn_location
	; check for game over
	call is_next_free
	cmp r2, ASCII_SPACE; compare with ASCII-space
	je draw_next_piece
	jmp game_over
	
get_next: ; r1 = piece number of next piece to draw
	; returns the next piece numbers in next1-4
	cmp r1, 0
	je o_shape
	cmp r1, 1
	je i_shape
	cmp r1, 2
	je z_shape
	cmp r1, 3
	je s_shape
	cmp r1, 4
	je j_shape
	cmp r1, 5
	je l_shape
	; default (t_shape)
	mov piece1, row_length_p2
	mov piece2, 2
	mov piece3, row_length
	mov piece4, row_length_p4
	ret
	
o_shape:
	mov piece1, 2
	mov piece2, 4
	mov piece3, row_length_p2
	mov piece4, row_length_p4
	ret
i_shape:
	mov piece1, 4
	mov piece2, 0
	mov piece3, 2
	mov piece4, 6
	ret
j_shape:
	mov piece1, row_length_p2
	mov piece2, row_length
	mov piece3, row_length_p4
	mov piece4, 0
	ret
l_shape:
	mov piece1, row_length_p2
	mov piece2, row_length
	mov piece3, row_length_p4
	mov piece4, 4
	ret
z_shape:
	mov piece1, row_length_p2
	mov piece2, 2
	mov piece3, 0
	mov piece4, row_length_p4
	ret
s_shape:
	mov piece1, row_length_p2
	mov piece2, 2
	mov piece3, row_length
	mov piece4, 4
	ret

; FUNCTIONS =========================================================================
rotate_part:
    ; r2 = relative offset
    sub r2, piece1, r1

    ; --- positive cases ---
    cmp r2, 2
    je case_left
    cmp r2, 4
    je case_left2
    cmp r2, row_length_p2
    je case_up_left
    cmp r2, row_length
    je case_up
    cmp r2, row_length_m2
    je case_up_right
    cmp r2, row_length_x2
    je case_up2

    ; --- negative cases ---
    sub r2, zr, r2

    cmp r2, 2
    je case_right
    cmp r2, 4
    je case_right2
    cmp r2, row_length_p2
    je case_down_right
    cmp r2, row_length
    je case_down
    cmp r2, row_length_m2
    je case_down_left
    ; default (down twice → left twice)
    sub r1, piece1, 4
    ret

; --- handlers ---
case_left:
    add r1, piece1, row_length
    ret
case_left2:
    add r1, piece1, row_length_x2
    ret
case_up_left:
    add r1, piece1, row_length_m2
    ret
case_up:
    sub r1, piece1, 2
    ret
case_up_right:
    sub r1, piece1, row_length_p2
    ret
case_up2:
    sub r1, piece1, 4
    ret
case_right:
    sub r1, piece1, row_length
    ret
case_right2:
    sub r1, piece1, row_length_x2
    ret
case_down_right:
    sub r1, piece1, row_length_m2
    ret
case_down:
    add r1, piece1, 2
    ret
case_down_left:
    add r1, piece1, row_length_p2
    ret

	
rotate_piece:
	; calculate next locations
	mov next1, piece1
	mov r1, piece2
	call rotate_part
	mov next2, r1
	mov r1, piece3
	call rotate_part
	mov next3, r1
	mov r1, piece4
	call rotate_part
	mov next4, r1
	jmp transform_piece
	
move_piece: ; r1 = offset, r1 = return success if not zero
	add next1, r1, piece1
	add next2, r1, piece2
	add next3, r1, piece3
	add next4, r1, piece4
	;jmp transform_piece

transform_piece:
	; delete old blocks
	mov r2, 0x202E ; " ."
	store_16 [piece1], r2
	store_16 [piece2], r2
	store_16 [piece3], r2
	store_16 [piece4], r2
	; check whether to move or not
	call is_next_free
	cmp r2, ASCII_SPACE; compare with ASCII-space
	je draw_next_piece
	mov r1, 0; return failure and do not move pieces
	jmp draw_piece

draw_next_piece:
	mov piece1, next1
	mov piece2, next2
	mov piece3, next3
	mov piece4, next4
	;jmp draw_piece

draw_piece:
	; draw new blocks
	mov r2, 0xDBDB; double full block
	store_16 [piece1], r2
	store_16 [piece2], r2
	store_16 [piece3], r2
	store_16 [piece4], r2
	ret
	
is_next_free: ; checks next1-4 if there are free.
	; r2 will have value of ASCII space if that is the case
	load_8 r2, [next1]
	load_8 r3, [next2]
	or r2, r2, r3
	load_8 r3, [next3]
	or r2, r2, r3
	load_8 r3, [next4]
	or r2, r2, r3
	ret

    
; DISPLAY SCORES ====================================================================
add_score:
	; adds the points in r1 to the score
	load_32 r2, [score_number_location]
    add r1, r2, r1
    store_32 [score_number_location], r1
    mov r2, score_location
    call display_number
    ; adapt level every decade after 100 to score if score is high enough
    sub r1, r2, score_location
    sub r1, zr, r1; get difference current_digit - score_location
    sub r1, r1, 2; subtract 2 decades
    add r1, r1, ASCII_ZERO
    cmp r1, ASCII_ZERO
    jae store_level
    mov r1, ASCII_ZERO
    store_level:
    store_8 [level_location], r1
    ret
    
add_lines_completed:
	; adds the number in r1 to the lines completed
	load_32 r2, [lines_number_location]
    add r1, r2, r1
    store_32 [lines_number_location], r1
    mov r2, lines_completed_location
	
display_number:
	; r1 = number in binary
	; r2 = localition of least significance
    mov r4, r1
    mov r5, 13108
    call multiply
    lsr r4, r4, 17
    mov r3, r4; r3 caches the number/10
    mov r5, 10
    call multiply
    sub r4, r1, r4; r4 has the lowest digit of the score
    add r4, r4, ASCII_ZERO
    store_8 [r2], r4
    sub r2, r2, 1
    mov r1, r3
    cmp r1, 0
    jne display_number
    ret
    
game_over:
	mov r2, game_over_location
	mov r1, 0x4741
	store_16 [r2], r1
	mov r1, 0x4D45
	add r2, r2, 2
	store_16 [r2], r1
	mov r1, 0x4F56
	add r2, r2, 3
	store_16 [r2], r1
	mov r1, 0x4552
	add r2, r2, 2
	store_16 [r2], r1
end:
	jmp end
	
; MULTIPLY ==========================================================================
; multiply: r4 * r5  → r4

multiply:
    push r6
    push r7
    mov r6, 0          ; result = 0

mul_loop:
    cmp r5, 0
    je mul_done

    ; check lowest bit of r5
    mov r7, r5
    and r7, r7, 1
    cmp r7, 1
    jne skip_add

    add r6, r6, r4 ; add r4 to result

skip_add:
    lsl r4, r4, 1 ; r8 <<= 1   (multiply by 2)
    lsr r5, r5, 1 ; r9 >>= 1   (divide by 2)
    jmp mul_loop

mul_done:
	mov r4, r6
	pop r7
	pop r6
    ret

; DATA ==============================================================================
@2300; need empty extra row
@2384; reserved for lines completed
@2388; reserved for score
@2392; first byte reserved for next piece number
font_color:
U32 0x007fff7f
@2396; first usable row
visual_data:
@2432; area starts here
"<! . . . . . . . . . .!>"
@2494
"LINES COMPLETED:    0"
@2528
"<! . . . . . . . . . .!>     7, "U8 0x1B": LEFT     9, "U8 0x1A": RIGHT"
@2590
"LEVEL:              0"
@2624
"<! . . . . . . . . . .!>             8, "U8 0x18": ROTATE"
@2686
"  SCORE:"
@2720
"<! . . . . . . . . . .!>     4, "U8 0x19": ACCELERATE  5: RESET"
@2816
"<! . . . . . . . . . .!>     1:  SHOW NEXT PIECE (ANYWAY)"
@2912
"<! . . . . . . . . . .!>     0:   ERASE THIS TEXT (NOT)"
@3008
"<! . . . . . . . . . .!>       SPACE - DOES NOTHING"
@3104
"<! . . . . . . . . . .!>"
@3200
"<! . . . . . . . . . .!>"
@3260
"  UPCOMING PIECE:"
@3296
"<! . . . . . . . . . .!>"
@3392
"<! . . . . . . . . . .!>"
@3488
"<! . . . . . . . . . .!>"
@3584
"<! . . . . . . . . . .!>"
@3680
"<! . . . . . . . . . .!>"
@3776
"<! . . . . . . . . . .!>"
@3872
"<! . . . . . . . . . .!>"
@3968
"<! . . . . . . . . . .!>"
@4064
"<! . . . . . . . . . .!>"
@4160
"<! . . . . . . . . . .!>"
@4256
"<! . . . . . . . . . .!>"
@4352
"<!====================!>"
@4448
U16 0x2020; double space
U16 0x5C2F; \+/
U16 0x5C2F
U16 0x5C2F
U16 0x5C2F
U16 0x5C2F
U16 0x5C2F
U16 0x5C2F
U16 0x5C2F
U16 0x5C2F
U16 0x5C2F
U16 0x2020