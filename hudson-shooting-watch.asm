; ============================================================
; HUDSON SHOOTING WATCH  -  Commodore 64 (6502 assembly)
; Tribute to the Hudson Soft "Shooting Watch" (Schwatch)
;
;   1. 10-second shot counter (space bar or joystick 2 fire)
;   2. UFO number match mini-game
;   3. Stopwatch (1/100 sec display)
;   4. Clock with alarm (uses the CIA1 time-of-day clock)
;
; Starts with a 5 second intro picture (hires bitmap at $2000,
; colour data copied to screen RAM at $0400) and a funky SID tune:
; filtered pulse bass, PWM pulse lead stabs and a drum track on voice 3.
; The music is stepped from the jiffy clock (no IRQ needed).
;
; Load address $0801 with a BASIC stub: 10 SYS 2061
; Syntax: 64tass-style (labels end in a colon)
; ============================================================

CHROUT = $FFD2
GETIN  = $FFE4
PLOT   = $FFF0
JIFHI  = $A1            ; jiffy clock, middle byte
JIFLO  = $A2            ; jiffy clock, low byte
KEYBUF = $C6            ; number of chars in keyboard buffer
MATRIX = $C5            ; matrix code of key being held (60 = space)
PALFLG = $02A6          ; 0 = NTSC, 1 = PAL
PTR    = $FB            ; zero page pointer
SCR    = $0400+40*10+18 ; screen spot of the UFO

        * = $0801
        .byte $0B,$08,$0A,$00,$9E
        .text "2061"
        .byte 0,0,0

; ------------------------------------------------------------
start:
        jsr init
        jsr intro
menu:
        lda #147
        jsr CHROUT
        lda #158
        jsr CHROUT
        lda #<m_title
        ldy #>m_title
        jsr printmsg
        lda #5
        jsr CHROUT
        lda #<m_best
        ldy #>m_best
        jsr printmsg
        lda best
        sta num
        lda best+1
        sta num+1
        jsr printnum
        lda #<s_shots
        ldy #>s_shots
        jsr printstr
        lda #<m_o1
        ldy #>m_o1
        jsr printmsg
        lda #<m_o2
        ldy #>m_o2
        jsr printmsg
        lda #<m_o3
        ldy #>m_o3
        jsr printmsg
        lda #<m_o4
        ldy #>m_o4
        jsr printmsg
        lda #<m_o5
        ldy #>m_o5
        jsr printmsg
        lda #<m_o6
        ldy #>m_o6
        jsr printmsg
mkey:
        jsr GETIN
        beq mkey
        cmp #49
        bne mk2
        jsr shot
        jmp menu
mk2:
        cmp #50
        bne mk3
        jsr ufo
        jmp menu
mk3:
        cmp #51
        bne mk4
        jsr stopw
        jmp menu
mk4:
        cmp #52
        bne mk5
        jsr clock
        jmp menu
mk5:
        cmp #53
        bne mkey
quit:
        lda #0
        sta $CC             ; cursor blink back on
        lda #14
        sta $D020
        lda #6
        sta $D021
        lda #154
        jsr CHROUT
        lda #147
        jsr CHROUT
        rts

; ------------------------------------------------------------
; init: colours, PAL/NTSC timing, SID, time-of-day clock
; ------------------------------------------------------------
init:
        lda #1
        sta $CC             ; cursor blink off (it would corrupt the bitmap)
        lda #0
        sta $D020
        sta $D021
        lda #5
        jsr CHROUT
        lda PALFLG
        beq in_ntsc
        lda #50
        sta jps
        lda #5
        sta tj
        lda #6
        sta stp
        lda #<500
        sta ten
        lda #>500
        sta ten+1
        lda #10
        sta ufow
        lda $DC0E
        ora #$80
        sta $DC0E
        jmp in_rest
in_ntsc:
        lda #60
        sta jps
        lda #6
        sta tj
        lda #7
        sta stp
        lda #<600
        sta ten
        lda #>600
        sta ten+1
        lda #12
        sta ufow
        lda $DC0E
        and #$7F
        sta $DC0E
in_rest:
        lda $DC0F
        and #$7F
        sta $DC0F
        lda #15
        sta $D418
        lda #$FF
        sta $D40E
        sta $D40F
        lda #$80
        sta $D412
        lda $DC0B
        lda $DC08
        sta tmp
        ldx #12
        jsr delay
        lda $DC0B
        lda $DC08
        cmp tmp
        bne in_done
        lda #$12            ; clock was stopped: start it at 12:00:00 AM
        sta $DC0B
        lda #0
        sta $DC0A
        sta $DC09
        sta $DC08
in_done:
        rts

; ------------------------------------------------------------
; intro: show the picture for 5 seconds
; ------------------------------------------------------------
intro:
        ldx #0
in_cp:
        lda picscr,x        ; colour info -> screen RAM $0400-$07FF
        sta $0400,x
        lda picscr+256,x
        sta $0500,x
        lda picscr+512,x
        sta $0600,x
        lda picscr+768,x
        sta $0700,x
        inx
        bne in_cp
        lda #$3B            ; bitmap mode on
        sta $D011
        lda #$18            ; screen at $0400, bitmap at $2000
        sta $D018
        jsr musicinit
        lda ten+1           ; tot = ten / 2 = 5 seconds in jiffies
        lsr
        sta tot+1
        lda ten
        ror
        sta tot
        lda JIFLO
        sta seen
in_w:
        lda seen
        cmp JIFLO
        beq in_w
        inc seen            ; one pass per jiffy
        jsr mtick
        lda tot
        bne in_d1
        dec tot+1
in_d1:
        dec tot
        lda tot
        ora tot+1
        bne in_w
        jsr musicoff
        lda #$1B            ; back to text mode
        sta $D011
        lda #$15
        sta $D018
        lda #0
        sta KEYBUF
        rts


; ------------------------------------------------------------
; intro music
; voice 1 = filtered pulse bass, voice 2 = PWM pulse lead,
; voice 3 = drums (triangle kick, noise snare and hi-hat)
; ------------------------------------------------------------
musicinit:
        lda PALFLG
        bne mi_pal
        ldx #15
mi_c1:
        lda nfl_n,x
        sta nfl,x
        lda nfh_n,x
        sta nfh,x
        dex
        bpl mi_c1
        jmp mi_go
mi_pal:
        ldx #15
mi_c2:
        lda nfl_p,x
        sta nfl,x
        lda nfh_p,x
        sta nfh,x
        dex
        bpl mi_c2
mi_go:
        lda #0
        sta $D402           ; voice 1 pulse width $0800
        sta $D409           ; voice 2 pulse width
        sta $D415
        lda #8
        sta $D403
        sta $D40A
        lda #$05            ; bass: A=0 D=5
        sta $D405
        lda #$63            ; bass: S=6 R=3
        sta $D406
        lda #$04            ; lead stab: A=0 D=4
        sta $D40C
        lda #$00
        sta $D40D
        lda #$F1            ; resonance 15, filter on voice 1
        sta $D417
        lda #$1F            ; low-pass, volume 15
        sta $D418
        lda #0
        sta mpos
        sta kick
        lda #1
        sta mdiv            ; first step on the first tick
        lda #10
        sta fcut
        lda #8
        sta pwm
        rts

musicoff:
        lda #$40
        sta $D404
        sta $D40B
        lda #$80            ; voice 3 back to silent noise generator
        sta $D412
        lda #$FF
        sta $D40E
        sta $D40F
        lda #0
        sta $D417
        lda #15
        sta $D418
        rts

mtick:                      ; called once per jiffy
        lda fcut            ; filter sweep opens up
        sta $D416
        cmp #240
        bcs mt_f
        inc fcut
mt_f:
        inc pwm             ; pulse width modulation on the lead
        lda pwm
        sta $D40A
        lda kick            ; kick drum pitch drop
        beq mt_nk
        lda kfreq
        cmp #4
        bcc mt_nk
        sbc #3
        sta kfreq
        sta $D40F
mt_nk:
        lda tot+1           ; fade out during the last 0.5 seconds
        bne mt_nf
        lda tot
        cmp #30
        bcs mt_nf
        lsr
        ora #$10
        sta $D418
mt_nf:
        dec mdiv
        bne mt_x
        lda stp
        sta mdiv
        jsr mstep
mt_x:
        rts

mstep:                      ; play one 16th-note step of the pattern
        ldx mpos
        lda bass,x
        cmp #$FF
        beq ms_br
        tay
        lda nfl,y
        sta $D400
        lda nfh,y
        sta $D401
        lda #$40
        sta $D404
        lda #$41
        sta $D404
        jmp ms_lead
ms_br:
        lda #$40
        sta $D404
ms_lead:
        lda lead,x
        cmp #$FF
        beq ms_drum
        tay
        lda nfl,y
        sta $D407
        lda nfh,y
        sta $D408
        lda #$40
        sta $D40B
        lda #$41
        sta $D40B
ms_drum:
        lda drum,x
        beq ms_next
        cmp #1
        bne ms_d2
        lda #$04            ; kick: triangle with a falling pitch
        sta $D413
        lda #$00
        sta $D414
        sta $D40E
        lda #$14
        sta kfreq
        sta $D40F
        lda #1
        sta kick
        lda #$10
        sta $D412
        lda #$11
        sta $D412
        jmp ms_next
ms_d2:
        cmp #2
        bne ms_d3
        lda #0              ; snare: noise, medium decay
        sta kick
        sta $D414
        sta $D40E
        lda #$05
        sta $D413
        lda #$60
        sta $D40F
        lda #$80
        sta $D412
        lda #$81
        sta $D412
        jmp ms_next
ms_d3:
        lda #0              ; hi-hat: noise, very short decay
        sta kick
        sta $D414
        sta $D40E
        lda #$01
        sta $D413
        lda #$C0
        sta $D40F
        lda #$80
        sta $D412
        lda #$81
        sta $D412
ms_next:
        inc mpos
        lda mpos
        and #15
        sta mpos
        rts

; ------------------------------------------------------------
; small helpers
; ------------------------------------------------------------
delay:                      ; wait X jiffies (X > 0)
        lda JIFLO
dl_w:
        cmp JIFLO
        beq dl_w
        lda JIFLO
        dex
        bne dl_w
        rts

getj:                       ; jl/jh = jiffy clock (race-free read)
        lda JIFHI
        sta jh
        lda JIFLO
        sta jl
        lda JIFHI
        cmp jh
        bne getj
        rts

readbtn:                    ; A = 1 if space or joystick-2 fire
        lda MATRIX
        cmp #60
        beq rb_y
        lda $DC00
        and #16
        beq rb_y
        lda #0
        rts
rb_y:
        lda #1
        rts

rnddig:                     ; A = random digit 0-9 (SID noise)
        lda $D41B
        and #15
        cmp #10
        bcs rnddig
        rts

beep:
        lda #15
        sta $D418
        lda #$09
        sta $D405
        lda #$00
        sta $D406
        sta $D400
        lda #40
        sta $D401
        lda #$11
        sta $D404
        ldx #8
        jsr delay
        lda #$10
        sta $D404
        rts

waitkey:
        ldx #45
        jsr delay
        lda #0
        sta KEYBUF
        lda #<m_anykey
        ldy #>m_anykey
        jsr printmsg
wk_l:
        jsr GETIN
        beq wk_l
        rts

; ------------------------------------------------------------
; printing
; ------------------------------------------------------------
printmsg:                   ; A/Y -> record: row, col, text, 0
        sta PTR
        sty PTR+1
        ldy #0
        lda (PTR),y
        tax
        iny
        lda (PTR),y
        tay
        clc
        jsr PLOT
        ldy #2
pm_l:
        lda (PTR),y
        beq pm_d
        jsr CHROUT
        iny
        bne pm_l
pm_d:
        rts

printstr:                   ; A/Y -> text, 0
        sta PTR
        sty PTR+1
        ldy #0
ps_l:
        lda (PTR),y
        beq ps_d
        jsr CHROUT
        iny
        bne ps_l
ps_d:
        rts

printnum:                   ; print 16-bit num in decimal (num is destroyed)
        ldx #0
        stx pf
pn_next:
        ldy #0
pn_sub:
        sec
        lda num
        sbc pl,x
        sta tmp
        lda num+1
        sbc ph,x
        bcc pn_out
        sta num+1
        lda tmp
        sta num
        iny
        jmp pn_sub
pn_out:
        tya
        bne pn_prt
        lda pf
        bne pn_prt
        cpx #4
        bne pn_skip
pn_prt:
        lda #1
        sta pf
        tya
        clc
        adc #48
        jsr CHROUT
pn_skip:
        inx
        cpx #5
        bne pn_next
        rts

printdec2:                  ; A (0-99) as two digits
        ldx #48
        sec
pd_l:
        cmp #10
        bcc pd_d
        sbc #10
        inx
        jmp pd_l
pd_d:
        pha
        txa
        jsr CHROUT
        pla
        clc
        adc #48
        jmp CHROUT

printbcd:                   ; A (BCD) as two digits
        pha
        lsr
        lsr
        lsr
        lsr
        clc
        adc #48
        jsr CHROUT
        pla
        and #15
        clc
        adc #48
        jmp CHROUT

printampm:                  ; bit 7 of A: 1 = PM
        and #$80
        bne pa_pm
        lda #65
        jsr CHROUT
        jmp pa_m
pa_pm:
        lda #80
        jsr CHROUT
pa_m:
        lda #77
        jmp CHROUT

div10:                      ; num = num / 10, rem = remainder
        lda #0
        sta q
        sta q+1
d10_l:
        lda num+1
        bne d10_s
        lda num
        cmp #10
        bcc d10_d
d10_s:
        sec
        lda num
        sbc #10
        sta num
        lda num+1
        sbc #0
        sta num+1
        inc q
        bne d10_l
        inc q+1
        jmp d10_l
d10_d:
        lda num
        sta rem
        lda q
        sta num
        lda q+1
        sta num+1
        rts

; ------------------------------------------------------------
; 1. 10-SECOND SHOT COUNTER
; ------------------------------------------------------------
shot:
        lda #147
        jsr CHROUT
        lda #<m_shot1
        ldy #>m_shot1
        jsr printmsg
        lda #<m_shot2
        ldy #>m_shot2
        jsr printmsg
        lda #<m_shot3
        ldy #>m_shot3
        jsr printmsg
        lda #<m_time
        ldy #>m_time
        jsr printmsg
        lda #<s_t10
        ldy #>s_t10
        jsr printstr
sh_rel:
        jsr readbtn
        bne sh_rel
sh_wait:
        jsr readbtn
        beq sh_wait
        lda #1
        sta cnt
        sta last
        lda #0
        sta cnt+1
        lda #$FF
        sta lsec            ; force first countdown redraw
        jsr getj
        lda jl
        sta t0
        lda jh
        sta t0+1
        jsr showcnt
sh_loop:
        jsr readbtn
        sta cur
        beq sh_np
        lda last
        bne sh_np
        inc cnt
        bne sh_nc
        inc cnt+1
sh_nc:
        jsr showcnt
sh_np:
        lda cur
        sta last
        jsr getj
        sec
        lda jl
        sbc t0
        sta el
        lda jh
        sbc t0+1
        sta el+1
        cmp ten+1
        bcc sh_more
        bne sh_done
        lda el
        cmp ten
        bcs sh_done
sh_more:
        jsr showtime
        jmp sh_loop
sh_done:
        lda ten             ; show 00.0 before the beep
        sta el
        lda ten+1
        sta el+1
        lda #$FF
        sta lsec
        jsr showtime
        jsr beep
        lda #147
        jsr CHROUT
        lda #<m_tup
        ldy #>m_tup
        jsr printmsg
        lda #<m_res1
        ldy #>m_res1
        jsr printmsg
        lda cnt
        sta num
        lda cnt+1
        sta num+1
        jsr printnum
        lda #<m_res2
        ldy #>m_res2
        jsr printmsg
        lda cnt
        sta num
        lda cnt+1
        sta num+1
        jsr div10
        jsr printnum
        lda #46
        jsr CHROUT
        lda rem
        clc
        adc #48
        jsr CHROUT
        lda #<s_persec
        ldy #>s_persec
        jsr printstr
        lda cnt+1           ; new personal best?
        cmp best+1
        bcc sh_nobest
        bne sh_newbest
        lda cnt
        cmp best
        bcc sh_nobest
        beq sh_nobest
sh_newbest:
        lda cnt
        sta best
        lda cnt+1
        sta best+1
        lda #<m_new
        ldy #>m_new
        jsr printmsg
sh_nobest:
        ldx #4              ; rank: 0..4 by thresholds 50/80/120/160
        lda cnt+1
        bne sh_rk
        ldx #0
sh_rl:
        lda cnt
        cmp thr,x
        bcc sh_rk
        inx
        cpx #4
        bne sh_rl
sh_rk:
        lda rkl,x
        ldy rkh,x
        jsr printmsg
        jmp waitkey

showtime:                   ; countdown: ten - el, shown as SS.T
        sec
        lda ten
        sbc el
        sta rl
        lda ten+1
        sbc el+1
        sta rl+1
        bcs sht_ok
        lda #0              ; already past the end
        sta rl
        sta rl+1
sht_ok:
        lda #0
        sta tsec
sht_sl:                     ; seconds = remaining / jiffies-per-second
        lda rl+1
        bne sht_ss
        lda rl
        cmp jps
        bcc sht_sd
sht_ss:
        sec
        lda rl
        sbc jps
        sta rl
        lda rl+1
        sbc #0
        sta rl+1
        inc tsec
        jmp sht_sl
sht_sd:
        lda #0
        sta tten
sht_tl:                     ; tenths = leftover / jiffies-per-tenth
        lda rl
        cmp tj
        bcc sht_td
        sbc tj
        sta rl
        inc tten
        jmp sht_tl
sht_td:
        lda tsec
        cmp lsec
        bne sht_pr
        lda tten
        cmp lten
        beq sht_x
sht_pr:
        lda tsec
        sta lsec
        lda tten
        sta lten
        lda #<m_time
        ldy #>m_time
        jsr printmsg
        lda tsec
        jsr printdec2
        lda #46
        jsr CHROUT
        lda tten
        clc
        adc #48
        jsr CHROUT
sht_x:
        rts

showcnt:
        lda #<m_cnt
        ldy #>m_cnt
        jsr printmsg
        lda cnt
        sta num
        lda cnt+1
        sta num+1
        jmp printnum

; ------------------------------------------------------------
; 2. UFO NUMBER MATCH
; ------------------------------------------------------------
ufo:
        lda #0
        sta KEYBUF
        lda #147
        jsr CHROUT
        lda #<m_ufo1
        ldy #>m_ufo1
        jsr printmsg
        lda #<m_ufo2
        ldy #>m_ufo2
        jsr printmsg
        lda #0
        sta score
        sta round
uf_round:
        inc round
        jsr rnddig
        sta tgt
        lda #<m_blank
        ldy #>m_blank
        jsr printmsg
        lda #<m_round
        ldy #>m_round
        jsr printmsg
        lda round
        sta num
        lda #0
        sta num+1
        jsr printnum
        lda #<s_target
        ldy #>s_target
        jsr printstr
        lda tgt
        clc
        adc #48
        jsr CHROUT
uf_rel:
        jsr readbtn
        bne uf_rel
        lda #0
        sta k
uf_step:
        jsr rnddig
        sta ufn
        lda $D41B
        cmp #77             ; about 30% of steps show the target
        bcs uf_nm
        lda tgt
        sta ufn
uf_nm:
        lda #40
        sta SCR-1
        lda #60
        sta SCR
        lda ufn
        clc
        adc #48
        sta SCR+1
        lda #62
        sta SCR+2
        lda #41
        sta SCR+3
        jsr getj
        lda jl
        sta t0
uf_w:
        jsr readbtn
        bne uf_hit
        jsr getj
        lda jl
        sec
        sbc t0
        cmp ufow
        bcc uf_w
        inc k
        lda k
        cmp #20
        bne uf_step
        lda #<m_slow
        ldy #>m_slow
        jmp uf_msg
uf_hit:
        lda ufn
        cmp tgt
        bne uf_wrong
        inc score
        lda #<m_hit
        ldy #>m_hit
        jmp uf_msg
uf_wrong:
        lda #<m_wrong
        ldy #>m_wrong
uf_msg:
        jsr printmsg
        lda #<m_score
        ldy #>m_score
        jsr printmsg
        lda score
        sta num
        lda #0
        sta num+1
        jsr printnum
        ldx #50
        jsr delay
        lda round
        cmp #10
        beq uf_end
        jmp uf_round
uf_end:
        lda #<m_final
        ldy #>m_final
        jsr printmsg
        lda score
        sta num
        lda #0
        sta num+1
        jsr printnum
        lda #<s_of10
        ldy #>s_of10
        jsr printstr
        jmp waitkey

; ------------------------------------------------------------
; 3. STOPWATCH
; ------------------------------------------------------------
stopw:
        lda #147
        jsr CHROUT
        lda #<m_sw1
        ldy #>m_sw1
        jsr printmsg
        lda #<m_sw2
        ldy #>m_sw2
        jsr printmsg
        lda #0
        sta KEYBUF
sw_k1:
        jsr GETIN
        beq sw_k1
        lda #0
        sta swh
        sta sws
        sta swm
        sta swrem
        lda JIFLO
        sta seen
sw_loop:
        lda seen
        cmp JIFLO
        beq sw_show
        inc seen
        jsr swtick
        jmp sw_loop
sw_show:
        jsr swdisp
        jsr GETIN
        beq sw_loop
        lda #<m_swfin
        ldy #>m_swfin
        jsr printmsg
        jmp waitkey

swtick:                     ; advance the stopwatch by one jiffy
        clc
        lda swrem
        adc #100
        sta swrem
st_l:
        lda swrem
        cmp jps
        bcc st_d
        sbc jps
        sta swrem
        inc swh
        jmp st_l
st_d:
        lda swh
        cmp #100
        bcc st_r
        lda #0
        sta swh
        sta swrem
        inc sws
        lda sws
        cmp #60
        bcc st_r
        lda #0
        sta sws
        inc swm
        lda swm
        cmp #100
        bcc st_r
        lda #0
        sta swm
st_r:
        rts

swdisp:
        lda #<m_sw
        ldy #>m_sw
        jsr printmsg
        lda swm
        jsr printdec2
        lda #58
        jsr CHROUT
        lda sws
        jsr printdec2
        lda #46
        jsr CHROUT
        lda swh
        jmp printdec2

; ------------------------------------------------------------
; 4. CLOCK AND ALARM
; ------------------------------------------------------------
clock:
        lda #0
        sta KEYBUF
        lda #147
        jsr CHROUT
        lda #<m_clk1
        ldy #>m_clk1
        jsr printmsg
        lda #<m_clk2
        ldy #>m_clk2
        jsr printmsg
        lda #<m_clk3
        ldy #>m_clk3
        jsr printmsg
ck_loop:
        lda #<m_ckt
        ldy #>m_ckt
        jsr printmsg
        lda $DC0B           ; read hours first (latches), tenths last
        sta th
        lda $DC0A
        sta tm
        lda $DC09
        sta ts
        lda $DC08
        lda th
        and #$1F
        jsr printbcd
        lda #58
        jsr CHROUT
        lda tm
        jsr printbcd
        lda #58
        jsr CHROUT
        lda ts
        jsr printbcd
        lda #32
        jsr CHROUT
        lda th
        jsr printampm
        lda #<m_ckal
        ldy #>m_ckal
        jsr printmsg
        lda alon
        bne ck_aon
        lda #<s_off
        ldy #>s_off
        jsr printstr
        jmp ck_chk
ck_aon:
        lda alhr
        and #$1F
        jsr printbcd
        lda #58
        jsr CHROUT
        lda almin
        jsr printbcd
        lda #32
        jsr CHROUT
        lda alhr
        jsr printampm
ck_chk:
        lda alon
        beq ck_keys
        lda tm
        cmp almin
        bne ck_clr
        lda th
        cmp alhr
        bne ck_clr
        lda fired
        bne ck_keys
        lda #1
        sta fired
        jsr ring
        jmp ck_keys
ck_clr:
        lda #0
        sta fired
ck_keys:
        jsr GETIN
        bne ck_got
        jmp ck_loop
ck_got:
        cmp #88             ; X = exit
        bne ck_n1
        rts
ck_n1:
        cmp #84             ; T = set time
        bne ck_n2
        jsr settime
        jmp clock
ck_n2:
        cmp #65             ; A = set alarm
        bne ck_n3
        jsr setalarm
        jmp clock
ck_n3:
        cmp #79             ; O = alarm off
        bne ck_n4
        lda #0
        sta alon
ck_n4:
        jmp ck_loop

ring:
        lda #<m_ring
        ldy #>m_ring
        jsr printmsg
        lda #6
        sta rc
rg_l:
        jsr beep
        ldx #10
        jsr delay
        dec rc
        bne rg_l
        lda #<m_blank9
        ldy #>m_blank9
        jmp printmsg

readdig:                    ; read ndig digits into buf
        lda #0
        sta idx
rd_k:
        jsr GETIN
        beq rd_k
        cmp #48
        bcc rd_k
        cmp #58
        bcs rd_k
        pha
        ldx idx
        sec
        sbc #48
        sta buf,x
        pla
        jsr CHROUT
        inc idx
        lda idx
        cmp ndig
        bne rd_k
        rts

pair:                       ; A = BCD of buf[x], buf[x+1]
        lda buf,x
        asl
        asl
        asl
        asl
        ora buf+1,x
        rts

askap:                      ; pmf = $80 for PM, 0 for AM
        lda #<m_ap
        ldy #>m_ap
        jsr printmsg
        lda #0
        sta pmf
ap_l:
        jsr GETIN
        cmp #65
        beq ap_d
        cmp #80
        bne ap_l
        lda #$80
        sta pmf
ap_d:
        rts

settime:
        lda #0
        sta KEYBUF
        lda #147
        jsr CHROUT
        lda #<m_st1
        ldy #>m_st1
        jsr printmsg
        lda #6
        sta ndig
        jsr readdig
        ldx #0
        jsr pair
        cmp #$13
        bcs st_bad
        cmp #1
        bcc st_bad
        ldx #2
        jsr pair
        cmp #$60
        bcs st_bad
        ldx #4
        jsr pair
        cmp #$60
        bcs st_bad
        jsr askap
        lda $DC0F
        and #$7F
        sta $DC0F
        ldx #0
        jsr pair
        ora pmf
        sta $DC0B           ; hours first: stops the clock
        ldx #2
        jsr pair
        sta $DC0A
        ldx #4
        jsr pair
        sta $DC09
        lda #0
        sta $DC08           ; tenths last: starts the clock
        rts
st_bad:
        lda #<m_bad
        ldy #>m_bad
        jsr printmsg
        ldx #90
        jsr delay
        jmp settime

setalarm:
        lda #0
        sta KEYBUF
        lda #147
        jsr CHROUT
        lda #<m_sa1
        ldy #>m_sa1
        jsr printmsg
        lda #4
        sta ndig
        jsr readdig
        ldx #0
        jsr pair
        cmp #$13
        bcs sa_bad
        cmp #1
        bcc sa_bad
        ldx #2
        jsr pair
        cmp #$60
        bcs sa_bad
        jsr askap
        ldx #0
        jsr pair
        ora pmf
        sta alhr
        ldx #2
        jsr pair
        sta almin
        lda #1
        sta alon
        lda #0
        sta fired
        rts
sa_bad:
        lda #<m_bad
        ldy #>m_bad
        jsr printmsg
        ldx #90
        jsr delay
        jmp setalarm

; ------------------------------------------------------------
; data
; ------------------------------------------------------------
best:   .word 0
cnt:    .word 0
t0:     .word 0
el:     .word 0
ten:    .word 600
num:    .word 0
q:      .word 0
last:   .byte 0
cur:    .byte 0
jps:    .byte 60
ufow:   .byte 12
jl:     .byte 0
jh:     .byte 0
rem:    .byte 0
pf:     .byte 0
tmp:    .byte 0
score:  .byte 0
round:  .byte 0
tgt:    .byte 0
ufn:    .byte 0
k:      .byte 0
swh:    .byte 0
sws:    .byte 0
swm:    .byte 0
swrem:  .byte 0
seen:   .byte 0
th:     .byte 0
tm:     .byte 0
ts:     .byte 0
alhr:   .byte 0
almin:  .byte 0
alon:   .byte 0
fired:  .byte 0
pmf:    .byte 0
ndig:   .byte 0
idx:    .byte 0
rc:     .byte 0
buf:    .fill 6,0
tj:     .byte 6
rl:     .word 0
tsec:   .byte 0
tten:   .byte 0
lsec:   .byte 0
lten:   .byte 0


stp:    .byte 7
mpos:   .byte 0
mdiv:   .byte 1
kick:   .byte 0
kfreq:  .byte 0
fcut:   .byte 0
pwm:    .byte 0
tot:    .word 0
nfl:    .fill 16,0
nfh:    .fill 16,0

; note numbers: 0=A1 1=C2 2=D2 3=E2 4=G2 5=A2 6=C3 7=E3 8=G3 9=A3
;               10=C4 11=D4 12=E4 13=G4 14=A4 15=C5   ($FF = rest)
nfl_n:  .byte $86,$31,$B4,$48,$48,$0C,$62,$90,$8F,$19,$C4,$D1,$1F,$1F,$32,$88
nfh_n:  .byte $03,$04,$04,$05,$06,$07,$08,$0A,$0C,$0E,$10,$12,$15,$19,$1C,$21
nfl_p:  .byte $A9,$5A,$E2,$7B,$85,$51,$B3,$F6,$0A,$A2,$67,$89,$ED,$13,$45,$CE
nfh_p:  .byte $03,$04,$04,$05,$06,$07,$08,$0A,$0D,$0E,$11,$13,$15,$1A,$1D,$22
bass:   .byte $00,$FF,$05,$00,$FF,$00,$05,$FF,$04,$FF,$04,$03,$FF,$02,$03,$FF
lead:   .byte $FF,$FF,$0A,$FF,$FF,$0C,$0A,$FF,$FF,$FF,$0D,$FF,$FF,$0C,$0B,$FF
drum:   .byte $01,$00,$03,$00,$02,$00,$03,$01,$01,$00,$03,$00,$02,$01,$03,$00      ; 0 none, 1 kick, 2 snare, 3 hat

pl:     .byte <10000,<1000,<100,<10,<1
ph:     .byte >10000,>1000,>100,>10,>1
thr:    .byte 50,80,120,160
rkl:    .byte <m_rk0,<m_rk1,<m_rk2,<m_rk3,<m_rk4
rkh:    .byte >m_rk0,>m_rk1,>m_rk2,>m_rk3,>m_rk4

; message records: row, column, text, 0
m_title:  .byte 1,5
          .text "*** HUDSON SHOOTING WATCH ***"
          .byte 0
m_best:   .byte 3,8
          .text "BEST: "
          .byte 0
s_shots:  .text " SHOTS / 10 SEC"
          .byte 0
m_o1:     .byte 6,8
          .text "1. 10-SECOND SHOT COUNTER"
          .byte 0
m_o2:     .byte 8,8
          .text "2. UFO NUMBER MATCH"
          .byte 0
m_o3:     .byte 10,8
          .text "3. STOPWATCH"
          .byte 0
m_o4:     .byte 12,8
          .text "4. CLOCK AND ALARM"
          .byte 0
m_o5:     .byte 14,8
          .text "5. QUIT"
          .byte 0
m_o6:     .byte 19,2
          .text "BUTTON = SPACE BAR OR JOYSTICK 2 FIRE"
          .byte 0
m_anykey: .byte 23,12
          .text "PRESS ANY KEY..."
          .byte 0

m_shot1:  .byte 1,8
          .text "10-SECOND SHOT COUNTER"
          .byte 0
m_shot2:  .byte 4,4
          .text "MASH THE BUTTON! 16 PER SEC = 160"
          .byte 0
m_shot3:  .byte 6,10
          .text "PRESS BUTTON TO START"
          .byte 0
m_time:   .byte 11,12
          .text "TIME LEFT: "
          .byte 0
s_t10:    .text "10.0"
          .byte 0
m_cnt:    .byte 9,14
          .text "SHOTS: "
          .byte 0
m_tup:    .byte 2,16
          .text "TIME UP!"
          .byte 0
m_res1:   .byte 5,10
          .text "SHOTS: "
          .byte 0
m_res2:   .byte 7,10
          .text "SPEED: "
          .byte 0
s_persec: .text " PER SEC"
          .byte 0
m_new:    .byte 9,10
          .text "NEW BEST!"
          .byte 0
m_rk0:    .byte 12,10
          .text "RANK: KEEP PRACTICING"
          .byte 0
m_rk1:    .byte 12,10
          .text "RANK: ROOKIE"
          .byte 0
m_rk2:    .byte 12,10
          .text "RANK: GOOD HANDS"
          .byte 0
m_rk3:    .byte 12,10
          .text "RANK: ELITE SHOOTER"
          .byte 0
m_rk4:    .byte 12,10
          .text "RANK: MEIJIN CLASS!!"
          .byte 0

m_ufo1:   .byte 1,12
          .text "UFO NUMBER MATCH"
          .byte 0
m_ufo2:   .byte 3,3
          .text "HIT THE BUTTON WHEN UFO = TARGET"
          .byte 0
m_round:  .byte 6,12
          .text "ROUND "
          .byte 0
s_target: .text "  TARGET: "
          .byte 0
m_blank:  .byte 14,14
          .text "          "
          .byte 0
m_hit:    .byte 14,14
          .text "HIT!      "
          .byte 0
m_wrong:  .byte 14,14
          .text "WRONG!    "
          .byte 0
m_slow:   .byte 14,14
          .text "TOO SLOW! "
          .byte 0
m_score:  .byte 16,14
          .text "SCORE: "
          .byte 0
m_final:  .byte 19,10
          .text "FINAL SCORE: "
          .byte 0
s_of10:   .text " / 10"
          .byte 0

m_sw1:    .byte 1,15
          .text "STOPWATCH"
          .byte 0
m_sw2:    .byte 3,5
          .text "PRESS ANY KEY TO START / STOP"
          .byte 0
m_sw:     .byte 8,16
          .byte 0
m_swfin:  .byte 11,16
          .text "STOPPED!"
          .byte 0

m_clk1:   .byte 1,13
          .text "CLOCK / ALARM"
          .byte 0
m_clk2:   .byte 3,6
          .text "T = SET TIME   A = SET ALARM"
          .byte 0
m_clk3:   .byte 4,6
          .text "O = ALARM OFF   X = EXIT"
          .byte 0
m_ckt:    .byte 7,15
          .byte 0
m_ckal:   .byte 9,11
          .text "ALARM: "
          .byte 0
s_off:    .text "OFF        "
          .byte 0
m_ring:   .byte 12,14
          .text "** ALARM **"
          .byte 0
m_blank9: .byte 12,14
          .text "           "
          .byte 0
m_st1:    .byte 4,4
          .text "SET TIME HHMMSS (12H): "
          .byte 0
m_sa1:    .byte 4,4
          .text "SET ALARM HHMM (12H): "
          .byte 0
m_ap:     .byte 6,4
          .text "AM OR PM (A/P)? "
          .byte 0
m_bad:    .byte 9,4
          .text "INVALID TIME - TRY AGAIN"
          .byte 0

; ------------------------------------------------------------
; intro picture (320x192 hires bitmap, converted from the
; supplied image; 2 colours per 8x8 cell)
; ------------------------------------------------------------
picscr:                     ; 1000 bytes of cell colours (+24 padding)
        .byte $A7,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70
        .byte $70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70
        .byte $70,$70,$70,$70,$70,$70,$70,$A7,$70,$70,$71,$71,$71,$71,$71,$71
        .byte $71,$71,$71,$71,$71,$71,$71,$71,$71,$71,$71,$71,$71,$71,$71,$71
        .byte $71,$71,$71,$71,$71,$71,$71,$71,$71,$71,$71,$71,$71,$71,$70,$70
        .byte $70,$70,$71,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
        .byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
        .byte $10,$10,$10,$10,$10,$71,$71,$70,$70,$71,$10,$10,$10,$10,$71,$71
        .byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$71,$71,$71,$71
        .byte $71,$71,$71,$71,$71,$71,$71,$71,$71,$71,$71,$10,$10,$10,$71,$70
        .byte $70,$71,$10,$10,$71,$71,$A7,$A7,$71,$71,$10,$10,$10,$10,$10,$10
        .byte $10,$10,$10,$10,$71,$F7,$F7,$F7,$F7,$F7,$F7,$F7,$F7,$F7,$F7,$F7
        .byte $F7,$F7,$71,$10,$10,$10,$71,$70,$70,$71,$10,$10,$71,$A7,$A8,$A8
        .byte $A7,$71,$10,$B1,$B1,$B1,$B1,$10,$10,$10,$10,$10,$71,$F0,$F0,$F0
        .byte $F0,$F0,$F0,$F0,$FB,$FB,$F0,$F0,$F0,$F3,$71,$10,$10,$71,$71,$70
        .byte $70,$71,$10,$10,$A7,$A8,$80,$80,$A7,$71,$B1,$F0,$70,$F0,$10,$97
        .byte $B1,$C1,$10,$10,$71,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$FB,$FB,$F0,$F0
        .byte $F0,$F3,$71,$10,$71,$71,$70,$70,$70,$71,$10,$10,$71,$A7,$A8,$A8
        .byte $A7,$71,$91,$70,$C0,$70,$70,$97,$70,$B1,$10,$10,$71,$F0,$F0,$F0
        .byte $F0,$F0,$F0,$F0,$FB,$FB,$F0,$F0,$F0,$F3,$71,$71,$70,$70,$A7,$70
        .byte $70,$71,$10,$10,$71,$A7,$A7,$A7,$71,$71,$70,$F0,$97,$70,$F0,$B1
        .byte $B1,$B1,$F1,$B1,$71,$FB,$F9,$FB,$F7,$F7,$F7,$F7,$F7,$F7,$F7,$F7
        .byte $F7,$F7,$70,$70,$75,$70,$70,$70,$70,$71,$10,$10,$10,$71,$71,$71
        .byte $B1,$97,$97,$70,$70,$10,$70,$10,$B1,$B1,$91,$C1,$71,$71,$71,$71
        .byte $71,$71,$71,$71,$71,$71,$71,$71,$71,$70,$70,$97,$70,$10,$70,$70
        .byte $70,$71,$10,$10,$10,$10,$10,$10,$B1,$70,$B1,$91,$70,$70,$70,$10
        .byte $B1,$91,$F1,$10,$10,$10,$F1,$10,$71,$F1,$F1,$F1,$F1,$F1,$F1,$71
        .byte $70,$70,$70,$70,$10,$50,$70,$70,$70,$71,$10,$10,$10,$10,$10,$10
        .byte $71,$B1,$10,$71,$91,$91,$91,$C1,$91,$10,$10,$10,$10,$10,$F1,$10
        .byte $F1,$C1,$F1,$F1,$F1,$71,$71,$70,$87,$70,$50,$10,$70,$70,$70,$70
        .byte $70,$71,$10,$10,$10,$C1,$C1,$F1,$C1,$C1,$C1,$10,$10,$C1,$C1,$C1
        .byte $C1,$F1,$10,$10,$10,$10,$F1,$C1,$F1,$F1,$F1,$71,$71,$71,$70,$97
        .byte $70,$10,$10,$70,$97,$70,$70,$70,$70,$71,$10,$10,$10,$C1,$C1,$C1
        .byte $C1,$F1,$C1,$10,$10,$C1,$C1,$C1,$F1,$10,$10,$10,$10,$10,$10,$71
        .byte $71,$71,$71,$97,$97,$70,$97,$70,$A0,$50,$70,$97,$70,$70,$97,$70
        .byte $70,$71,$10,$10,$71,$71,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70
        .byte $70,$71,$71,$10,$10,$71,$71,$A7,$A7,$A7,$71,$97,$87,$70,$A7,$A7
        .byte $87,$97,$97,$97,$70,$50,$70,$70,$70,$71,$10,$71,$71,$70,$A7,$A7
        .byte $A7,$A7,$70,$70,$70,$A7,$A7,$A7,$A7,$70,$71,$10,$10,$71,$87,$A0
        .byte $90,$A0,$A7,$97,$97,$87,$A0,$90,$A0,$A7,$97,$70,$10,$10,$70,$70
        .byte $70,$71,$10,$71,$70,$87,$80,$B0,$B0,$B0,$B7,$70,$97,$B0,$B0,$B0
        .byte $80,$87,$70,$71,$10,$71,$70,$10,$10,$90,$97,$70,$97,$70,$10,$10
        .byte $B0,$97,$70,$10,$50,$70,$70,$70,$70,$71,$10,$71,$70,$87,$A0,$B0
        .byte $B0,$80,$B7,$70,$97,$B0,$B0,$B0,$B7,$87,$70,$71,$10,$71,$97,$10
        .byte $B0,$B0,$97,$70,$97,$70,$10,$B0,$B0,$97,$70,$70,$70,$70,$70,$70
        .byte $70,$71,$10,$71,$71,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70
        .byte $70,$70,$71,$71,$71,$71,$87,$A0,$C9,$B7,$A7,$97,$97,$B7,$97,$C9
        .byte $B7,$A7,$70,$97,$70,$97,$97,$70,$70,$71,$10,$10,$71,$71,$71,$71
        .byte $71,$71,$71,$71,$71,$71,$71,$71,$71,$71,$71,$71,$70,$70,$97,$87
        .byte $A7,$A7,$70,$70,$70,$97,$87,$A7,$A7,$A7,$70,$70,$70,$70,$70,$70
        .byte $70,$71,$71,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
        .byte $10,$71,$71,$70,$97,$70,$90,$A0,$97,$87,$70,$97,$70,$80,$A0,$70
        .byte $97,$70,$A7,$70,$80,$10,$70,$70,$70,$70,$71,$71,$71,$71,$71,$71
        .byte $71,$71,$71,$71,$71,$71,$71,$71,$71,$70,$70,$87,$70,$A0,$A0,$70
        .byte $97,$70,$87,$97,$A0,$A0,$70,$97,$70,$A7,$97,$A0,$A0,$70,$87,$70
        .byte $70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70
        .byte $70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70
        .byte $70,$70,$70,$70,$70,$70,$70,$70,$A7,$A7,$70,$70,$70,$70,$70,$70
        .byte $70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70
        .byte $70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$A7
        .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

        * = $2000
picbmp:                     ; 8000 bytes of bitmap
        .byte $04,$00,$20,$00,$80,$00,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$18,$04,$00,$00,$00,$00,$00,$00
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FE,$FF,$FF,$FF,$FF,$FF,$FF,$FC,$00
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$07,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$3F
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $F8,$F0,$E0,$C0,$80,$00,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$0F,$03,$01,$00,$00,$00,$00,$00
        .byte $FF,$FF,$FF,$FF,$FF,$7F,$3F,$3F,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FE,$FE,$FE,$FC,$FC,$FE,$FE,$FE
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $00,$00,$00,$00,$00,$00,$00,$FF,$00,$00,$00,$00,$00,$00,$00,$FC
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $00,$00,$00,$00,$00,$00,$03,$0F,$00,$00,$00,$00,$00,$00,$FF,$FF
        .byte $00,$00,$00,$00,$00,$00,$FF,$FF,$00,$00,$00,$00,$00,$00,$FF,$FF
        .byte $00,$00,$00,$00,$00,$00,$FF,$FF,$00,$00,$00,$00,$00,$00,$FF,$FF
        .byte $00,$00,$00,$00,$00,$00,$FF,$FF,$00,$00,$00,$00,$00,$00,$FF,$FF
        .byte $00,$00,$00,$00,$00,$00,$FF,$FF,$00,$00,$00,$00,$00,$00,$FF,$FF
        .byte $00,$00,$00,$00,$00,$00,$FF,$FF,$00,$00,$00,$00,$00,$00,$FF,$FF
        .byte $00,$00,$00,$00,$00,$00,$FF,$FF,$00,$00,$00,$00,$00,$00,$FF,$FF
        .byte $00,$00,$00,$00,$00,$00,$80,$E0,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $00,$00,$00,$00,$01,$01,$03,$07,$07,$1F,$3F,$FF,$FF,$FF,$FF,$FF
        .byte $00,$00,$00,$00,$00,$00,$1F,$FF,$00,$00,$00,$00,$00,$00,$C0,$F8
        .byte $00,$C0,$F0,$F8,$FC,$FE,$FF,$FF,$00,$00,$00,$00,$00,$00,$00,$80
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $1F,$1F,$3F,$3F,$3F,$3F,$3F,$3F,$00,$00,$00,$1F,$FF,$FF,$FF,$FF
        .byte $00,$00,$00,$FF,$FF,$FF,$FF,$FF,$00,$00,$00,$FF,$FF,$FF,$FF,$FF
        .byte $00,$00,$00,$FF,$FF,$FF,$FF,$FF,$00,$00,$00,$FF,$FF,$FF,$FF,$FF
        .byte $00,$00,$00,$FF,$FF,$FF,$FF,$FF,$00,$00,$00,$FF,$FF,$FF,$FF,$FF
        .byte $00,$00,$00,$FF,$FF,$FF,$FF,$FF,$00,$00,$00,$FF,$FF,$FF,$FF,$FF
        .byte $00,$00,$00,$FF,$FF,$FF,$FF,$FF,$00,$00,$00,$FF,$FF,$FF,$FF,$FF
        .byte $00,$00,$00,$FF,$FF,$FF,$FF,$FF,$00,$00,$00,$F0,$FE,$FF,$FF,$FF
        .byte $F0,$F0,$F8,$F8,$F8,$F8,$F8,$F8,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $0F,$1F,$1F,$3F,$3F,$7F,$7F,$7F,$03,$07,$0F,$1F,$3F,$3F,$7F,$7F
        .byte $80,$00,$00,$00,$00,$00,$00,$00,$07,$01,$1F,$0F,$07,$01,$01,$00
        .byte $00,$80,$C0,$C0,$E0,$E0,$F0,$F0,$80,$C0,$E0,$E0,$E0,$F0,$F8,$F8
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$07,$07,$07,$07
        .byte $00,$00,$00,$00,$00,$87,$1F,$FF,$00,$00,$00,$00,$00,$E0,$F0,$F9
        .byte $00,$00,$00,$00,$00,$1E,$7E,$FC,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FE,$FC,$F8,$F8,$F8,$F8,$F8,$F8,$03,$01,$00,$00,$F8,$F8,$F8,$F8
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FD,$FD,$FD,$FD,$FD,$FD,$FD,$FD
        .byte $F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$00,$03,$07,$1F
        .byte $1F,$1F,$3F,$7F,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $00,$00,$00,$01,$01,$01,$01,$00,$C0,$80,$80,$00,$80,$80,$80,$80
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $F8,$F8,$F8,$F8,$FC,$FC,$FC,$FC,$F8,$F8,$F8,$FC,$FC,$FC,$FC,$F8
        .byte $00,$00,$00,$03,$07,$0F,$0E,$1C,$F0,$E0,$E0,$00,$18,$FE,$C6,$87
        .byte $0F,$1C,$38,$38,$78,$78,$3F,$3F,$C2,$E0,$70,$30,$33,$73,$E7,$E0
        .byte $1F,$3F,$3F,$1F,$04,$80,$00,$00,$00,$00,$03,$FF,$FF,$E0,$80,$FF
        .byte $00,$08,$FC,$FC,$F0,$00,$00,$FF,$00,$00,$00,$00,$00,$00,$00,$E0
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $F8,$F8,$FD,$FF,$F9,$F8,$F8,$F8,$F8,$F8,$F8,$FC,$FC,$F8,$F8,$F8
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FD,$FD,$FD,$FD,$FD,$FD,$FD,$FD
        .byte $F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $00,$00,$00,$03,$07,$0F,$3F,$7F,$3F,$7F,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$7F,$7F,$7F,$3F,$3F,$FF,$FF,$FF,$FF,$7F,$7F,$3F,$1F
        .byte $00,$00,$00,$00,$00,$00,$00,$80,$00,$00,$00,$00,$00,$01,$03,$0F
        .byte $F8,$F8,$F8,$F8,$F0,$F0,$E0,$C0,$F8,$F8,$F8,$F9,$F9,$F1,$E1,$E0
        .byte $1C,$1C,$1C,$1C,$FE,$FF,$FF,$1F,$83,$87,$C6,$FE,$FC,$F8,$00,$00
        .byte $1F,$0F,$60,$60,$04,$0E,$3C,$70,$80,$00,$00,$00,$00,$00,$3E,$7E
        .byte $00,$00,$00,$00,$38,$3F,$1F,$0F,$FF,$C0,$C0,$FE,$FF,$03,$00,$00
        .byte $00,$FF,$FF,$FF,$0F,$00,$F0,$FE,$F0,$F0,$00,$00,$00,$80,$C0,$80
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $F8,$F8,$F8,$F8,$F8,$FC,$FF,$FF,$F8,$F8,$F8,$00,$00,$01,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FD,$FD,$FD,$FD,$FD,$FD,$FD,$FD
        .byte $F8,$F8,$F8,$F8,$F8,$F8,$F9,$FF,$01,$03,$07,$1F,$3F,$7F,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $00,$00,$00,$00,$00,$00,$00,$30,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $1F,$1F,$0F,$07,$07,$03,$00,$00,$0F,$07,$00,$00,$00,$00,$00,$00
        .byte $FF,$FF,$FF,$7F,$0F,$00,$00,$00,$FF,$FF,$FC,$F8,$C0,$00,$00,$00
        .byte $FF,$FF,$FF,$FF,$FF,$FE,$FC,$F8,$E0,$C0,$80,$80,$00,$00,$00,$03
        .byte $E3,$E7,$C0,$E0,$E0,$C0,$80,$01,$80,$10,$30,$01,$03,$03,$E3,$E7
        .byte $FF,$F8,$80,$00,$00,$00,$00,$00,$FE,$FC,$FC,$F8,$F0,$E0,$C0,$80
        .byte $07,$03,$01,$00,$00,$00,$00,$00,$00,$00,$00,$80,$80,$C0,$C0,$C0
        .byte $00,$00,$00,$01,$03,$03,$07,$07,$00,$00,$00,$F8,$FC,$FC,$0E,$0E
        .byte $00,$00,$00,$00,$00,$00,$00,$03,$00,$00,$00,$00,$00,$00,$3E,$FE
        .byte $3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$FF,$FF,$FC,$FC,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$7F,$3F,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$00
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$00
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$00
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$00
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$00,$FF,$FF,$FF,$FF,$FF,$FE,$FC,$00
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FE,$FF,$FF,$FE,$F8,$F0,$E0,$80,$00
        .byte $8F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$3F,$1F,$07,$00,$00,$00,$00,$00
        .byte $FF,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF,$FF,$F8,$00,$00,$00,$00
        .byte $00,$00,$00,$00,$00,$01,$03,$07,$03,$07,$1C,$38,$71,$E3,$C7,$87
        .byte $FD,$7B,$73,$E6,$CE,$9C,$98,$38,$E3,$E3,$E0,$E0,$F0,$F0,$F0,$F0
        .byte $F8,$C0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$02,$06,$06,$0E,$1C,$3C,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F
        .byte $06,$0E,$0E,$0E,$0F,$07,$07,$07,$0E,$0E,$0E,$1C,$1C,$1C,$39,$BB
        .byte $07,$0F,$1E,$3C,$78,$F0,$E0,$C0,$FC,$80,$00,$00,$00,$00,$00,$00
        .byte $3F,$1F,$1F,$07,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$00,$00,$00,$00
        .byte $FF,$FF,$FF,$FF,$BE,$1C,$1C,$1C,$FF,$FF,$FF,$FF,$02,$00,$00,$00
        .byte $FF,$FF,$FF,$FF,$F2,$70,$70,$70,$FF,$FF,$FF,$FF,$03,$01,$01,$01
        .byte $FF,$FF,$FF,$FF,$C8,$80,$80,$80,$FF,$FF,$FF,$FF,$4E,$0E,$0E,$0E
        .byte $FF,$FF,$FF,$FF,$40,$00,$00,$00,$FF,$FF,$FF,$FF,$B9,$38,$38,$38
        .byte $FF,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$00,$00,$00,$00
        .byte $FF,$FF,$FF,$FF,$9F,$1F,$3F,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$00,$00,$03,$07
        .byte $FE,$F8,$F0,$C0,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $1F,$3E,$7C,$F0,$20,$01,$01,$01,$F1,$E3,$C3,$86,$8E,$1C,$18,$38
        .byte $70,$F0,$E0,$C0,$C0,$80,$00,$00,$0F,$0F,$07,$07,$07,$03,$03,$01
        .byte $00,$00,$00,$00,$03,$3F,$3F,$1F,$00,$01,$07,$1F,$FF,$FF,$FF,$FF
        .byte $FC,$F8,$F8,$F0,$F0,$E0,$C0,$80,$3F,$3F,$3F,$3F,$3F,$3F,$1F,$07
        .byte $03,$01,$00,$01,$03,$07,$1F,$FE,$FF,$FF,$FE,$F0,$C0,$80,$00,$00
        .byte $C0,$80,$00,$00,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $70,$70,$70,$70,$70,$70,$70,$70,$01,$01,$01,$01,$01,$01,$01,$01
        .byte $80,$80,$80,$80,$80,$80,$99,$BF,$0E,$0E,$0E,$06,$06,$00,$EC,$FF
        .byte $F0,$F8,$F8,$70,$60,$60,$60,$F8,$33,$37,$33,$31,$31,$01,$00,$00
        .byte $C0,$E0,$E0,$C0,$80,$80,$00,$00,$01,$03,$0F,$1F,$3F,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FC,$F8,$F0,$C0,$F0,$C0,$80,$00,$00,$00,$00,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03
        .byte $0F,$0F,$0F,$0F,$1F,$7F,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $01,$00,$00,$00,$00,$00,$00,$00,$0F,$1E,$1E,$1C,$00,$00,$00,$00
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$01,$00,$00,$00,$00,$00,$00,$00
        .byte $F8,$7F,$3F,$1F,$07,$00,$00,$00,$03,$FF,$FF,$FF,$FC,$00,$00,$00
        .byte $FF,$FF,$FC,$C0,$00,$00,$00,$00,$FF,$F9,$00,$00,$00,$00,$00,$00
        .byte $FC,$F0,$00,$00,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $70,$70,$70,$70,$67,$67,$73,$73,$01,$01,$00,$00,$F3,$FB,$7F,$7F
        .byte $BF,$BE,$3C,$00,$E0,$E0,$E0,$E0,$F9,$9F,$1F,$00,$00,$00,$00,$00
        .byte $F8,$F0,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$07,$0F,$1F
        .byte $0F,$1F,$3F,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $00,$00,$00,$00,$00,$00,$00,$01,$FF,$FF,$FC,$F8,$E0,$C0,$80,$00
        .byte $80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$00,$00,$00,$03,$07,$0F,$07,$0F,$1F,$7F,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$00,$00,$07,$0F
        .byte $00,$00,$00,$00,$00,$00,$FF,$FF,$00,$00,$00,$00,$00,$00,$60,$F1
        .byte $00,$00,$00,$00,$00,$00,$F9,$FB,$00,$00,$00,$00,$00,$00,$FF,$FF
        .byte $00,$00,$00,$00,$00,$00,$F0,$F0,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$00,$00,$7F,$7F
        .byte $00,$00,$00,$00,$00,$00,$FC,$FC,$00,$00,$00,$00,$00,$00,$07,$CF
        .byte $00,$00,$00,$00,$00,$00,$CF,$FF,$00,$00,$00,$00,$00,$00,$E0,$E0
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $0C,$0C,$0D,$0F,$0D,$0D,$09,$00,$00,$00,$00,$FB,$FF,$FF,$F1,$00
        .byte $20,$00,$E6,$FF,$DF,$FF,$FF,$00,$7F,$00,$73,$FF,$FB,$DB,$9B,$00
        .byte $E0,$00,$06,$BF,$FD,$FF,$3F,$00,$00,$00,$00,$00,$80,$80,$80,$00
        .byte $00,$00,$01,$07,$0F,$1F,$7F,$FF,$7F,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$00,$01,$03,$07
        .byte $FC,$F8,$F0,$C0,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$07,$0F,$3F,$7F
        .byte $E0,$80,$00,$00,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$0F,$0F,$0F,$0F,$00,$00,$00,$00
        .byte $7E,$FE,$FF,$FF,$00,$00,$00,$00,$61,$61,$7D,$7F,$00,$00,$00,$00
        .byte $F3,$F3,$FB,$FB,$00,$00,$00,$00,$00,$00,$FC,$FC,$00,$00,$00,$00
        .byte $C0,$C0,$C0,$C0,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$F7,$7F,$7F,$7F,$00,$00,$00,$00
        .byte $31,$33,$37,$37,$00,$00,$00,$00,$EE,$EF,$7F,$3C,$00,$00,$00,$00
        .byte $73,$F3,$F3,$73,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$00,$03,$3F,$FF
        .byte $00,$00,$00,$00,$00,$FF,$FF,$FF,$00,$00,$00,$00,$00,$00,$F0,$FC
        .byte $00,$00,$00,$00,$00,$00,$01,$07,$00,$00,$00,$00,$00,$1F,$1C,$18
        .byte $00,$00,$00,$00,$00,$F8,$18,$08,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $00,$00,$00,$01,$03,$0F,$0E,$00,$E0,$C0,$80,$00,$00,$00,$FF,$FF
        .byte $00,$00,$00,$00,$00,$00,$E0,$FC,$00,$00,$00,$00,$00,$00,$01,$03
        .byte $00,$03,$07,$0F,$3F,$7F,$FE,$FE,$00,$00,$00,$00,$00,$C0,$E0,$F0
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FE,$FC,$F0,$E0
        .byte $00,$10,$70,$F0,$F0,$F0,$F0,$F0,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $00,$00,$00,$00,$01,$03,$07,$0F,$01,$0F,$3F,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$00,$E0,$F8,$FC,$FF,$FF,$FF,$FF
        .byte $00,$00,$00,$00,$00,$80,$C0,$E0,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$00,$00,$01,$03
        .byte $03,$0F,$1F,$3F,$7F,$FF,$FF,$FF,$00,$00,$00,$00,$00,$00,$00,$03
        .byte $00,$00,$00,$00,$00,$00,$00,$FF,$00,$00,$00,$00,$00,$00,$00,$80
        .byte $0F,$DF,$FF,$FF,$FF,$FF,$FF,$FF,$1F,$1F,$18,$18,$1F,$0C,$00,$00
        .byte $F8,$FC,$0C,$1C,$FC,$F0,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $00,$00,$00,$00,$00,$00,$00,$03,$00,$00,$00,$00,$00,$00,$00,$FF
        .byte $03,$00,$00,$00,$00,$00,$00,$00,$F8,$F0,$20,$00,$00,$00,$00,$00
        .byte $03,$06,$07,$0F,$1C,$00,$00,$00,$30,$38,$F8,$FC,$0E,$00,$00,$00
        .byte $FF,$FF,$FE,$F8,$F0,$E0,$80,$00,$C0,$00,$00,$00,$00,$00,$00,$00
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$00,$00,$01,$01
        .byte $1F,$3F,$3F,$7F,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $00,$00,$00,$00,$00,$00,$00,$07,$00,$00,$00,$00,$00,$00,$00,$FF
        .byte $00,$00,$00,$00,$00,$00,$00,$FF,$00,$00,$00,$00,$00,$00,$00,$F8
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$00,$00,$00,$3F
        .byte $00,$00,$00,$00,$00,$00,$00,$FF,$00,$00,$00,$00,$00,$00,$00,$FF
        .byte $00,$00,$00,$00,$00,$00,$00,$E0,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $F0,$F8,$F8,$FC,$FC,$FE,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$07,$07,$0F,$0F,$1F,$1F,$1F,$3F
        .byte $00,$00,$00,$00,$01,$03,$07,$07,$FF,$F8,$E0,$C0,$80,$00,$00,$00
        .byte $FF,$01,$00,$00,$00,$00,$00,$00,$FF,$7F,$1F,$07,$03,$01,$01,$00
        .byte $00,$00,$00,$00,$00,$00,$80,$C0,$00,$00,$00,$00,$00,$01,$07,$0F
        .byte $00,$0C,$18,$78,$F0,$F0,$E0,$E0,$00,$00,$00,$00,$01,$03,$07,$07
        .byte $FF,$F8,$E0,$C0,$00,$00,$00,$00,$FF,$01,$00,$00,$00,$00,$00,$00
        .byte $FF,$3F,$1F,$07,$03,$01,$01,$00,$00,$00,$00,$00,$00,$00,$80,$C0
        .byte $00,$00,$00,$00,$00,$00,$03,$07,$FE,$F8,$F0,$E0,$80,$00,$00,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$1F,$7F,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$01,$03,$03,$03,$03,$03,$03,$03
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$01,$01,$03,$03,$03,$03
        .byte $FF,$FC,$E0,$80,$80,$00,$00,$00,$FF,$FF,$00,$00,$00,$00,$00,$00
        .byte $FF,$FF,$00,$00,$00,$00,$00,$00,$FF,$FF,$00,$00,$00,$00,$00,$00
        .byte $00,$80,$C0,$C0,$E0,$E0,$E0,$F0,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $00,$03,$07,$07,$0F,$0F,$0F,$0F,$FF,$FF,$80,$00,$00,$00,$00,$00
        .byte $FF,$FF,$00,$00,$00,$00,$00,$00,$FF,$FF,$00,$00,$00,$00,$00,$00
        .byte $FF,$0F,$03,$01,$01,$03,$03,$03,$00,$00,$00,$00,$80,$80,$80,$C0
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$00,$80,$80,$80,$80,$80,$80,$80
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$3F,$3F,$7F,$7F,$7F,$7F,$7F,$7F
        .byte $F8,$F0,$F0,$F0,$F0,$E0,$E0,$E0,$00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$03,$03,$01,$01,$01,$01
        .byte $C0,$C0,$E0,$E0,$E0,$E0,$E0,$E0,$F0,$F0,$F0,$F0,$F0,$F8,$F8,$F8
        .byte $E0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$F8,$F0,$F0,$F0,$F0,$F0,$E0,$E0
        .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$02,$00,$01,$01,$01,$01,$C0,$C0,$E0,$E0,$E0,$E0,$E0,$E0
        .byte $F0,$F0,$F0,$F0,$F8,$F8,$F8,$F8,$00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$00,$00,$00,$00,$01,$03,$00,$03,$07,$0F,$1F,$7F,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$03,$03,$03,$03,$03,$03,$01,$01
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$03,$03,$03,$01,$01,$00,$00,$00
        .byte $00,$00,$00,$00,$80,$CF,$F0,$FF,$00,$00,$00,$00,$FF,$FF,$FF,$FF
        .byte $00,$00,$01,$03,$FF,$FF,$FF,$FF,$00,$01,$FF,$FF,$FF,$FD,$FF,$FF
        .byte $E0,$E0,$E0,$E0,$C0,$80,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $0F,$0F,$0F,$07,$07,$03,$00,$00,$00,$00,$00,$00,$FF,$FF,$FF,$FF
        .byte $00,$00,$00,$00,$FF,$FF,$FF,$FF,$00,$00,$07,$1F,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FE,$F8,$20,$80,$80,$80,$80,$00,$00,$00,$00
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$80,$80,$80,$80,$80,$80,$00,$00
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$7F,$7F,$7F,$7F,$7F,$3F,$3F,$3F
        .byte $1F,$1F,$1F,$1F,$0F,$0F,$0F,$07,$00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$03,$0F,$1F,$3F,$7F,$7F,$01,$01,$F3,$FF,$FE,$FE,$FC,$FC
        .byte $E0,$E0,$E0,$E0,$C0,$C0,$C0,$80,$F8,$F8,$F0,$F0,$F0,$F0,$F0,$E0
        .byte $C0,$C0,$C0,$C0,$C0,$C0,$E0,$E0,$E0,$F0,$F0,$F0,$F0,$F0,$F8,$F8
        .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03,$0F,$1F,$3F,$7F,$7F
        .byte $01,$01,$F3,$FF,$FE,$FE,$FC,$FC,$E0,$E0,$E0,$E0,$E0,$C0,$C0,$80
        .byte $F8,$F8,$F8,$F0,$F0,$F0,$F0,$F0,$00,$00,$00,$00,$00,$03,$07,$0F
        .byte $07,$0F,$3F,$7F,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$01,$00,$00,$00,$00,$00,$00,$00
        .byte $FF,$FF,$FF,$7F,$7F,$3F,$1F,$0F,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FE,$FE,$FC,$FC,$F8,$F0,$E0,$00,$00,$00,$00,$00,$00,$00,$01
        .byte $00,$01,$03,$0F,$1F,$3F,$7F,$FF,$7F,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $07,$03,$01,$00,$00,$00,$00,$00,$00,$00,$00,$80,$C0,$F0,$FC,$FF
        .byte $7F,$7F,$7F,$FE,$00,$00,$00,$FF,$FF,$FF,$FE,$FC,$F8,$F0,$C0,$00
        .byte $80,$00,$00,$00,$00,$00,$01,$03,$1F,$1F,$3E,$3C,$78,$E0,$C0,$00
        .byte $C0,$80,$00,$00,$00,$00,$00,$00,$07,$03,$01,$00,$00,$00,$00,$00
        .byte $FF,$FF,$FF,$FF,$7F,$3F,$0F,$01,$7F,$7F,$7F,$7E,$00,$00,$00,$FF
        .byte $FF,$FF,$FE,$FC,$F8,$F0,$C0,$00,$80,$80,$00,$00,$00,$00,$01,$03
        .byte $E0,$E0,$C1,$C3,$87,$8F,$3F,$7F,$E0,$80,$00,$00,$00,$00,$00,$00
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$00,$00,$03,$07
        .byte $00,$00,$00,$30,$70,$F0,$F0,$F0,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $07,$03,$01,$00,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$3F,$1F,$03,$00
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$00
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$00
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$00
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$00
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$00
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$00,$FF,$FF,$FF,$FE,$F8,$F0,$80,$00
        .byte $C0,$80,$00,$00,$00,$01,$03,$0F,$03,$0F,$1F,$3F,$7F,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $00,$00,$00,$00,$00,$0C,$3E,$7F,$00,$00,$00,$00,$00,$00,$00,$C0
        .byte $FC,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$10
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$00,$0C,$1E,$3F
        .byte $00,$00,$00,$00,$00,$00,$00,$C0,$FC,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$1C,$03,$04,$08,$00,$00,$00,$00,$00
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FE,$F8,$F0,$E0,$F0,$E0,$80,$00,$00,$00,$00,$00
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FE,$FE,$FE,$FE,$FE,$FF,$FF,$FF
        .byte $00,$00,$00,$00,$00,$00,$00,$80,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$00,$01,$07,$0F,$1F,$3F
        .byte $1F,$3F,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $00,$00,$00,$00,$00,$00,$01,$03,$FF,$FE,$F8,$F0,$C0,$80,$00,$00
        .byte $80,$00,$00,$00,$00,$00,$00,$00,$3F,$03,$00,$00,$00,$00,$00,$00
        .byte $00,$FF,$FF,$FF,$FE,$FC,$F0,$E0,$70,$E0,$C0,$00,$00,$00,$00,$00
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$00,$00,$00,$01
        .byte $FF,$FE,$FC,$F0,$E0,$C0,$80,$00,$80,$00,$00,$00,$00,$00,$00,$00
        .byte $1F,$03,$00,$00,$00,$00,$00,$00,$FF,$86,$00,$00,$01,$03,$07,$1F
        .byte $78,$F0,$C0,$80,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $00,$00,$00,$00,$00,$00,$00,$01,$FF,$FF,$FE,$F8,$F0,$E0,$80,$00
        .byte $C0,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        .byte $0F,$0F,$1F,$1F,$1F,$1F,$3F,$3F,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $C0,$E0,$F0,$F8,$FC,$FF,$FF,$FF,$00,$00,$00,$00,$00,$00,$FF,$FF
        .byte $00,$00,$00,$00,$00,$00,$FF,$FF,$00,$00,$00,$00,$00,$00,$FF,$FF
        .byte $00,$00,$00,$00,$00,$00,$FF,$FF,$00,$00,$00,$00,$00,$00,$FF,$FF
        .byte $00,$00,$00,$00,$00,$00,$FF,$FF,$00,$00,$00,$00,$00,$00,$FF,$FF
        .byte $00,$00,$00,$00,$00,$00,$FF,$FF,$00,$00,$00,$00,$00,$00,$FF,$FF
        .byte $00,$00,$00,$00,$00,$00,$FF,$FF,$00,$00,$00,$00,$00,$00,$FF,$FF
        .byte $00,$00,$00,$00,$00,$00,$FF,$FF,$00,$00,$00,$00,$00,$00,$FF,$FF
        .byte $00,$01,$03,$0F,$1F,$7F,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$01,$03,$07,$00
        .byte $F8,$F0,$C0,$80,$00,$00,$00,$FF,$00,$00,$00,$00,$00,$00,$FF,$FF
        .byte $00,$00,$00,$00,$00,$00,$FF,$FF,$00,$00,$01,$07,$0F,$1F,$7F,$FF
        .byte $80,$00,$00,$00,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $00,$00,$00,$00,$00,$01,$03,$00,$07,$0F,$1F,$7F,$FF,$FF,$FF,$00
        .byte $00,$00,$00,$00,$00,$00,$FF,$FF,$00,$00,$00,$00,$00,$00,$FF,$FF
        .byte $00,$00,$01,$03,$0F,$1F,$3F,$FF,$C0,$80,$00,$00,$00,$00,$00,$00
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$00,$01,$01,$00
        .byte $03,$07,$1F,$3F,$7F,$FF,$FF,$00,$00,$00,$00,$00,$00,$00,$FF,$FF
        .byte $00,$00,$00,$00,$00,$00,$FF,$FF,$00,$00,$01,$03,$0F,$1F,$FF,$FF
        .byte $80,$00,$00,$00,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $00,$80,$C0,$E0,$F0,$FC,$3F,$3F,$00,$00,$00,$00,$00,$00,$00,$80
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$00,$01,$03,$0F,$1F,$3E
        .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
