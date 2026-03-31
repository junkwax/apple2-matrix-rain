; ============================================================
;  APPLE ][ MATRIX RAIN SCREENSAVER
;
;  Author: timappl@junkwax.nl
;  Target: Apple II (NMOS 6502) | Assembler: ca65
;  Hardware: Standard Apple II (48K/64K)
; ============================================================

        .segment "CODE"

; ============================================================
;  USER CONFIGURATION (defaults — all adjustable at runtime)
; ============================================================

INIT_SPEED  = 3                 ; 1=Slow, 2=Normal, 3=Fast, 4=Hyper, 5=Ludicrous
MAX_SPEED   = 5
MIN_SPEED   = 1

INIT_DIM    = 0                 ; Index into DIM_VALS table (0=$55)
INIT_BODY   = 1                 ; Index into BODY_VALS table (1=$07)

; LFSR seed — change for a different startup pattern
LFSR_SEED_LO = $B4
LFSR_SEED_HI = $37

; ============================================================
;  Zero Page Definitions
; ============================================================
PTR_LO      = $00
PTR_HI      = $01
ROW         = $02
COL         = $03
BRIGHT      = $04
GIDX        = $05
SPEED       = $06               
FRAME       = $07
TMP         = $08
PHASE_BASE  = $09
GLYPH_BASE  = $0A   
COL_OFFSET  = $0B   
SHAD_LO     = $0C
SHAD_HI     = $0D
ROW17       = $0E
PTR_LO_BASE = $0F

H0          = $10
H1          = $11
H2          = $12
H3          = $13
H4          = $14
H5          = $15
H6          = $16
H7          = $17

LFSR_LO     = $18               
LFSR_HI     = $19

MENU_OPEN   = $1A               
GRID_ROWS   = $1B               
DIM_IDX     = $1C               
BODY_IDX    = $1D               
DIM_MASK_ZP = $1E               

; ============================================================
;  Hardware Constants
; ============================================================
KBD         = $C000
KBDCLR      = $C010
TXTCLR      = $C050
TXTSET      = $C051
MIXCLR      = $C052             
MIXSET      = $C053             
PAGE1       = $C054   
PAGE2       = $C055
HIRES       = $C057

HGR_PAGE    = $2000
GRID_W      = 40

BRIGHT_BUF  = $6000
HOME        = $FC58
COUT        = $FDED             
VTAB        = $FC22             

; CORRECTED: Text page line base addresses for rows 20-23
TXT_LINE21  = $0650
TXT_LINE22  = $06D0
TXT_LINE23  = $0750
TXT_LINE24  = $07D0

; Apple II key codes (high bit set)
KEY_ESC     = $9B
KEY_PLUS    = $AB
KEY_EQUAL   = $BD
KEY_MINUS   = $AD
KEY_Q       = $D1
KEY_q       = $F1
KEY_D       = $C4
KEY_d       = $E4
KEY_B       = $C2
KEY_b       = $E2
KEY_R       = $D2
KEY_r       = $F2

; ============================================================
;  Entry Point
; ============================================================
START:
        sei                     
        cld                     
        jsr  $FE89              
        jsr  $FE93              
        
        sta  $C000              
        sta  $C00C              
        
        lda  #0
        sta  $20                
        sta  $22                
        lda  #40
        sta  $21                
        lda  #24
        sta  $23                
        jsr  HOME
        
        ldx  #$FF
@DELAY_OUTER:
        ldy  #$FF
@DELAY_INNER:
        sta  KBDCLR
        dey
        bne  @DELAY_INNER
        dex
        bne  @DELAY_OUTER       

        jsr  INIT_ALL

        sta  $C00C              
        bit  $C056              
        bit  $C057              
        bit  $C054              
        bit  $C050              
        bit  MIXCLR             

; ============================================================
;  Main Loop
; ============================================================
MAIN_LOOP:
        lda  KBD
        bmi  @HAS_KEY           
        jmp  @DO_FRAME          
@HAS_KEY:
        sta  TMP                
        sta  KBDCLR

        lda  TMP
        cmp  #KEY_ESC
        beq  @TOGGLE_MENU
        cmp  #KEY_Q
        beq  @DO_QUIT
        cmp  #KEY_q
        beq  @DO_QUIT

        cmp  #KEY_PLUS
        beq  @SPEED_UP
        cmp  #KEY_EQUAL
        beq  @SPEED_UP
        cmp  #KEY_MINUS
        beq  @SPEED_DN

        ldx  MENU_OPEN
        beq  @DO_FRAME          

        cmp  #KEY_D
        beq  @DO_DIM
        cmp  #KEY_d
        beq  @DO_DIM
        cmp  #KEY_B
        beq  @DO_BODY
        cmp  #KEY_b
        beq  @DO_BODY
        cmp  #KEY_R
        beq  @DO_RESEED
        cmp  #KEY_r
        beq  @DO_RESEED
        jmp  @DO_FRAME          

@DO_QUIT:
        jmp  EXIT

@TOGGLE_MENU:
        lda  MENU_OPEN
        eor  #$01
        sta  MENU_OPEN
        bne  @MENU_NOW_OPEN
        lda  #24
        sta  GRID_ROWS
        bit  MIXCLR             
        jsr  INVALIDATE_BOTTOM  
        jmp  @DO_FRAME
@MENU_NOW_OPEN:
        lda  #20
        sta  GRID_ROWS
        bit  MIXSET             
        jsr  DRAW_MENU
        jmp  @DO_FRAME

@SPEED_UP:
        lda  SPEED
        cmp  #MAX_SPEED
        bcs  @SPD_DONE
        inc  SPEED
@SPD_DONE:
        lda  MENU_OPEN
        beq  @DO_FRAME
        jsr  DRAW_MENU
        jmp  @DO_FRAME

@SPEED_DN:
        lda  SPEED
        cmp  #MIN_SPEED+1
        bcc  @DO_FRAME
        dec  SPEED
        lda  MENU_OPEN
        beq  @DO_FRAME
        jsr  DRAW_MENU
        jmp  @DO_FRAME

@DO_DIM:
        jsr  CYCLE_DIM
        jsr  DRAW_MENU
        jmp  @DO_FRAME

@DO_BODY:
        jsr  CYCLE_BODY
        jsr  DRAW_MENU
        jmp  @DO_FRAME

@DO_RESEED:
        jsr  RESEED_RAIN
        jsr  DRAW_MENU
        jmp  @DO_FRAME

@DO_FRAME:
        lda  #<BRIGHT_BUF
        sta  SHAD_LO
        lda  #>BRIGHT_BUF
        sta  SHAD_HI

        ldy  #0
RS_ROW_LOOP:
        sty  ROW
        cpy  GRID_ROWS
        bcc  @ROW_OK
        jmp  RS_FRAME_DONE
@ROW_OK:
        
        lda  ROW_17_TBL,y
        sta  ROW17
        lda  CELL_LO_TBL,y
        sta  PTR_LO_BASE
        lda  CELL_HI_TBL,y
        sta  PTR_HI
        lda  ROW_X8_TBL,y
        tax
        lda  CELL_HI8_TBL+0,x
        sta  H0
        lda  CELL_HI8_TBL+1,x
        sta  H1
        lda  CELL_HI8_TBL+2,x
        sta  H2
        lda  CELL_HI8_TBL+3,x
        sta  H3
        lda  CELL_HI8_TBL+4,x
        sta  H4
        lda  CELL_HI8_TBL+5,x
        sta  H5
        lda  CELL_HI8_TBL+6,x
        sta  H6
        lda  CELL_HI8_TBL+7,x
        sta  H7

        ldx  #0
RS_COL_LOOP:
        stx  COL

        lda  FRAME
        ldy  SPEED
@SHIFT: asl
        dey
        bne  @SHIFT

        sta  TMP
        
        lda  COL_29_TBL,x
        tay
        lda  SINE_TABLE,y
        clc
        adc  TMP
        sta  PHASE_BASE
        lda  PHASE_BASE
        sec
        sbc  ROW17
        
        cmp  TAIL_LEN_TBL,x     
        bcs  @W_E      
        cmp  #41
        bcs  @W_D
        cmp  #11
        bcs  @W_M
        lda  #3
        jmp  @W_OK
@W_M:   lda  #2
        jmp  @W_OK
@W_D:   lda  #1
        jmp  @W_OK
@W_E:   lda  #0
@W_OK:  sta  BRIGHT

@SHADOW_CHECK:
        ldy  #0
        lda  (SHAD_LO),y        
        cmp  BRIGHT
        bne  @CHANGED
        jmp  CELL_SKIP_NODRAW
@CHANGED:
        lda  BRIGHT
        sta  (SHAD_LO),y

DO_CELL_DRAW:
        lda  COL
        sta  COL_OFFSET
        lda  PTR_LO_BASE
        clc
        adc  COL_OFFSET
        sta  PTR_LO
        
        ldx  COL
        lda  COL_7_TBL,x
        sta  GLYPH_BASE
        clc
        adc  ROW
        sta  TMP
        
        lda  BRIGHT
        cmp  #3
        beq  G_HEAD
        cmp  #2
        beq  G_BODY
        jmp  G_STATIC

G_HEAD:
        lda  TMP
        clc
        adc  FRAME
        sta  TMP
        jmp  G_STATIC

G_BODY:
        lda  FRAME
BODY_MASK_OP:
        and  #$07               
        bne  G_STATIC
        lda  TMP
        clc
        adc  FRAME
        sta  TMP

G_STATIC:
        lda  TMP
        and  #$0F
        asl
        asl
        asl
        sta  GIDX
        
        lda  BRIGHT
        tax
        jsr  DO_DISPATCH

CELL_ADVANCE:
CELL_SKIP_NODRAW:
        inc  SHAD_LO
        bne  @C2
        inc  SHAD_HI
@C2:    ldx  COL
        inx
        cpx  #GRID_W
        beq  RS_ROW_NEXT        
        jmp  RS_COL_LOOP        

RS_ROW_NEXT:
        ldy  ROW
        iny
        cpy  GRID_ROWS
        bcs  RS_FRAME_DONE      
        jmp  RS_ROW_LOOP        

RS_FRAME_DONE:
        inc  FRAME
        jmp  MAIN_LOOP

; ============================================================
;  Initialization
; ============================================================
INIT_ALL:
        lda  #0
        sta  FRAME
        sta  MENU_OPEN
        lda  #INIT_SPEED
        sta  SPEED
        lda  #24
        sta  GRID_ROWS
        
        lda  #INIT_DIM
        sta  DIM_IDX
        tax
        lda  DIM_VALS,x
        sta  DIM_MASK_ZP
        
        lda  #INIT_BODY
        sta  BODY_IDX
        tax
        lda  BODY_VALS,x
        sta  BODY_MASK_OP+1     
        
INIT_LFSR:
        lda  #LFSR_SEED_LO
        sta  LFSR_LO
        lda  #LFSR_SEED_HI
        sta  LFSR_HI
        
        jsr  SEED_TAILS_ONLY    
        jsr  INIT_SHADOW
        
HGR_CLEAR:
        lda  #$20
        sta  PTR_HI
        lda  #$00
        sta  PTR_LO
        tay
@P:     lda  #$00
@L:     sta  (PTR_LO),y
        iny
        bne  @L
        inc  PTR_HI
        lda  PTR_HI
        cmp  #$40
        bcc  @P
        rts

; ============================================================
;  LFSR & Rain Seeding
; ============================================================
LFSR_NEXT:
        lda  LFSR_HI
        lsr
        sta  LFSR_HI
        lda  LFSR_LO
        ror
        sta  LFSR_LO
        bcc  @NO_TAP
        lda  LFSR_HI
        eor  #$B4
        sta  LFSR_HI
@NO_TAP:
        rts

SEED_TAILS_ONLY:
        ldx  #0
ST_LOOP:
        ldy  #8                 ; Mix the bits 8 times for better randomness!
ST_MIX: 
        jsr  LFSR_NEXT
        dey
        bne  ST_MIX

        lda  LFSR_LO
        
        ; --- Guarantee the left and right edges always have rain ---
        cpx  #0                 ; Is it the far-left column?
        beq  ST_FORCE
        cpx  #39                ; Is it the far-right column?
        beq  ST_FORCE
        ; -----------------------------------------------------------

        cmp  #60                
        bcs  ST_STORE
        lda  #0
        beq  ST_STORE           ; Jump down to store the blank column

ST_FORCE:
        ora  #$80               ; Force the length to be at least 128
        
ST_STORE: 
        sta  TAIL_LEN_TBL,x
        inx
        cpx  #GRID_W
        bne  ST_LOOP
        rts

INIT_SHADOW:
        lda  #<BRIGHT_BUF
        sta  PTR_LO
        lda  #>BRIGHT_BUF
        sta  PTR_HI
        lda  #0
        tay
        ldx  #4
@LOOP:  sta  (PTR_LO),y
        iny
        bne  @LOOP
        inc  PTR_HI
        dex
        bne  @LOOP
        rts

INVALIDATE_ALL:
        lda  #<BRIGHT_BUF
        sta  PTR_LO
        lda  #>BRIGHT_BUF
        sta  PTR_HI
        lda  #$FF
        ldy  #0
        ldx  #4                 
@LOOP:  sta  (PTR_LO),y
        iny
        bne  @LOOP
        inc  PTR_HI
        dex
        bne  @LOOP
        rts

INVALIDATE_BOTTOM:
        lda  #$20
        sta  PTR_LO
        lda  #$63
        sta  PTR_HI
        lda  #$FF
        ldy  #0
@LOOP:  sta  (PTR_LO),y
        iny
        cpy  #160
        bne  @LOOP
        rts

; ============================================================
;  Settings Menu 
; ============================================================
DRAW_MENU:
        lda  #$A0               
        ldx  #0
@CLR:   sta  TXT_LINE21,x
        sta  TXT_LINE22,x
        sta  TXT_LINE23,x
        sta  TXT_LINE24,x
        inx
        cpx  #40
        bne  @CLR

        ldx  #0
@T1:    lda  MENU_TITLE,x
        beq  @T1_DONE
        ora  #$80               
        sta  TXT_LINE21,x
        inx
        bne  @T1
@T1_DONE:

        ldx  #0
@T2:    lda  MENU_LINE2,x
        beq  @T2_DONE
        ora  #$80
        sta  TXT_LINE22,x
        inx
        bne  @T2
@T2_DONE:

        lda  SPEED
        clc
        adc  #$B0               
        sta  TXT_LINE22+7       

        ldx  DIM_IDX
        lda  DIM_VALS,x
        pha
        lsr
        lsr
        lsr
        lsr
        tax
        lda  HEX_CHARS,x
        ora  #$80
        sta  TXT_LINE22+18      
        pla
        and  #$0F
        tax
        lda  HEX_CHARS,x
        ora  #$80
        sta  TXT_LINE22+19      

        ldx  BODY_IDX
        lda  BODY_VALS,x
        pha
        lsr
        lsr
        lsr
        lsr
        tax
        lda  HEX_CHARS,x
        ora  #$80
        sta  TXT_LINE22+32      
        pla
        and  #$0F
        tax
        lda  HEX_CHARS,x
        ora  #$80
        sta  TXT_LINE22+33      

        ldx  #0
@T3:    lda  MENU_LINE3,x
        beq  @T3_DONE
        ora  #$80
        sta  TXT_LINE23,x
        inx
        bne  @T3
@T3_DONE:

        lda  TXT_LINE23+1
        and  #$3F               
        sta  TXT_LINE23+1
        lda  TXT_LINE23+3
        and  #$3F
        sta  TXT_LINE23+3
        lda  TXT_LINE23+13
        and  #$3F
        sta  TXT_LINE23+13
        lda  TXT_LINE23+21
        and  #$3F
        sta  TXT_LINE23+21
        lda  TXT_LINE23+32
        and  #$3F
        sta  TXT_LINE23+32

        ldx  #0
@T4:    lda  MENU_LINE4,x
        beq  @T4_DONE
        ora  #$80
        sta  TXT_LINE24,x
        inx
        bne  @T4
@T4_DONE:
        lda  TXT_LINE24+1
        and  #$3F
        sta  TXT_LINE24+1
        lda  TXT_LINE24+2
        and  #$3F
        sta  TXT_LINE24+2
        lda  TXT_LINE24+3
        and  #$3F
        sta  TXT_LINE24+3
        lda  TXT_LINE24+23
        and  #$3F
        sta  TXT_LINE24+23

        rts

; ============================================================
;  Menu Key Handlers
; ============================================================
CYCLE_DIM:
        ldx  DIM_IDX
        inx
        cpx  #DIM_COUNT
        bcc  @OK
        ldx  #0
@OK:    stx  DIM_IDX
        lda  DIM_VALS,x
        sta  DIM_MASK_ZP        
        jsr  INVALIDATE_ALL     
        rts

CYCLE_BODY:
        ldx  BODY_IDX
        inx
        cpx  #BODY_COUNT
        bcc  @OK
        ldx  #0
@OK:    stx  BODY_IDX
        lda  BODY_VALS,x
        sta  BODY_MASK_OP+1     
        rts

RESEED_RAIN:
        lda  FRAME
        ora  #$01               
        sta  LFSR_LO
        lda  FRAME
        eor  #$A5
        ora  #$01
        sta  LFSR_HI
        jsr  SEED_TAILS_ONLY
        jsr  INVALIDATE_ALL     
        rts

EXIT:   
        bit  MIXCLR             
        bit  TXTSET             
        bit  PAGE1
        jsr  HOME
        jmp  $E003              

; ============================================================
;  Drawing Routines 
; ============================================================
DO_DISPATCH:
        lda  DRAW_DISPATCH_HI,x
        pha
        lda  DRAW_DISPATCH_LO,x
        pha
        rts

DRAW_DISPATCH_LO:
        .byte <(DRAW_ERASE-1), <(DRAW_DIM-1), <(DRAW_MED-1), <(DRAW_HEAD-1)
DRAW_DISPATCH_HI:
        .byte >(DRAW_ERASE-1), >(DRAW_DIM-1), >(DRAW_MED-1), >(DRAW_HEAD-1)

DRAW_ERASE:
        ldy  #0
        lda  #0
        sta  (PTR_LO),y
        .repeat 7, i
        lda  H1+i
        sta  PTR_HI
        ldy  #0
        lda  #0
        sta  (PTR_LO),y
        .endrepeat
        lda  H0
        sta  PTR_HI
        rts

DRAW_DIM:
        ldx  GIDX
        lda  FONT_DATA,x
        and  DIM_MASK_ZP        
        ldy  #0
        sta  (PTR_LO),y
        inx
        .repeat 7, i
        lda  H1+i
        sta  PTR_HI
        lda  FONT_DATA,x
        and  DIM_MASK_ZP
        ldy  #0
        sta  (PTR_LO),y
        inx
        .endrepeat
        lda  H0
        sta  PTR_HI
        rts

DRAW_MED:
        ldx  GIDX
        lda  FONT_DATA,x
        ldy  #0
        sta  (PTR_LO),y
        inx
        .repeat 7, i
        lda  H1+i
        sta  PTR_HI
        lda  FONT_DATA,x
        ldy  #0
        sta  (PTR_LO),y
        inx
        .endrepeat
        lda  H0
        sta  PTR_HI
        rts

DRAW_HEAD:
        ldy  #0
        lda  #$7F
        sta  (PTR_LO),y
        .repeat 7, i
        lda  H1+i
        sta  PTR_HI
        ldy  #0
        lda  #$7F
        sta  (PTR_LO),y
        .endrepeat
        lda  H0
        sta  PTR_HI
        rts

; ============================================================
;  Data Tables
; ============================================================

CELL_LO_TBL:  
        .repeat 24, i
        .byte <(HGR_PAGE + ((i / 8) * $28) + ((i .mod 8) * $80))
        .endrepeat

CELL_HI_TBL:  
        .repeat 24, i
        .byte >(HGR_PAGE + ((i / 8) * $28) + ((i .mod 8) * $80))
        .endrepeat

CELL_HI8_TBL: 
        .repeat 24, i
        .repeat 8, s
        .byte >(HGR_PAGE + ((i / 8) * $28) + ((i .mod 8) * $80) + (s * $0400))
        .endrepeat
        .endrepeat

ROW_X8_TBL:   
        .repeat 24, i
        .byte <(i * 8)
        .endrepeat

TAIL_LEN_TBL:
        .res 40

COL_7_TBL:    
        .repeat 40, i          
        .byte <(i * 7)
        .endrepeat

COL_29_TBL:
        .byte 23, 184, 91, 244, 45, 112, 203, 12, 156, 78
        .byte 219, 67, 134, 2, 198, 88, 145, 39, 172, 251
        .byte 14, 99, 210, 55, 128, 7, 189, 42, 233, 80
        .byte 115, 204, 33, 170, 5, 144, 255, 62, 101, 222

ROW_17_TBL:   
        .repeat 24, i
        .byte <(i * 17)
        .endrepeat

SINE_TABLE:
        .byte 128,131,134,137,140,143,146,149,152,156,159,162,165,168,171,174
        .byte 176,179,182,185,188,191,193,196,199,201,204,206,209,211,213,216
        .byte 218,220,222,224,226,228,230,232,234,236,237,239,241,242,243,245
        .byte 246,247,248,249,250,251,252,253,253,254,254,255,255,255,255,255
        .byte 255,255,255,255,255,255,254,254,253,253,252,251,250,249,248,247
        .byte 246,245,243,242,241,239,237,236,234,232,230,228,226,224,222,220
        .byte 218,216,213,211,209,206,204,201,199,196,193,191,188,185,182,179
        .byte 176,174,171,168,165,162,159,156,152,149,146,143,140,137,134,131
        .byte 128,124,121,118,115,112,109,106,103,99,96,93,90,87,84,81
        .byte 79,76,73,70,67,64,62,59,56,54,51,49,46,44,42,39
        .byte 37,35,33,31,29,27,25,23,21,19,18,16,14,13,12,10
        .byte 9,8,7,6,5,4,3,2,2,1,1,0,0,0,0,0
        .byte 0,0,0,0,0,0,1,1,2,2,3,4,5,6,7,8
        .byte 9,10,12,13,14,16,18,19,21,23,25,27,29,31,33,35
        .byte 37,39,42,44,46,49,51,54,56,59,62,64,67,70,73,76
        .byte 79,81,84,87,90,93,96,99,103,106,109,112,115,118,121,124

FONT_DATA:
        .byte $3E, $22, $22, $22, $22, $22, $3E, $00 ; Box
        .byte $3F, $20, $10, $08, $04, $02, $3F, $00 ; Z
        .byte $0E, $00, $1C, $00, $38, $00, $00, $00 ; Mi
        .byte $1E, $20, $1E, $20, $20, $10, $0C, $00 ; Hi
        .byte $3E, $10, $08, $24, $12, $08, $04, $00 ; Nu
        .byte $08, $00, $3E, $08, $08, $04, $04, $00 ; Wa
        .byte $3E, $10, $08, $24, $22, $22, $00, $00 ; Su
        .byte $3E, $20, $10, $08, $04, $04, $04, $00 ; Seven
        .byte $22, $22, $3E, $22, $3E, $22, $22, $00 ; Ho
        .byte $12, $12, $1E, $12, $12, $10, $08, $00 ; Ke
        .byte $10, $18, $14, $12, $3E, $10, $10, $00 ; Four
        .byte $1E, $20, $10, $08, $04, $02, $3E, $00 ; Two
        .byte $22, $14, $08, $14, $22, $22, $00, $00 ; Me
        .byte $3E, $02, $1E, $20, $20, $10, $0E, $00 ; Five
        .byte $1E, $02, $1E, $02, $1E, $00, $00, $00 ; Yo
        .byte $3E, $00, $3E, $08, $04, $02, $00, $00 ; Ra

MENU_TITLE:
        .byte "----------------------------------------", 0
                
MENU_LINE2:
        .byte " SPEED: /5  DIM:$    SHIMMER:$     ", 0

MENU_LINE3:
        .byte " +/- SPEED   D DIM   B SHIMMER  R RAND", 0

MENU_LINE4:
        .byte " ESC CLOSE             Q QUIT         ", 0

HEX_CHARS:
        .byte "0123456789ABCDEF"

DIM_VALS:
        .byte $55, $AA, $33, $11
DIM_COUNT = 4

BODY_VALS:
        .byte $00, $07, $03, $0F
BODY_COUNT = 4