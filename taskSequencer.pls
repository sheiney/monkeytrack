; Sequence for training bar press and eye in window.  
; All randomization and task design done in script and passed to sequencer as table
; Can do eccentric fixation, saccade, pursuit (requires Spike2 v5)
; Uses DACs 2 and 3 for H and V laser, respectively
; DACs 0 and 1 control drum and chair, respectively
; Variable numbers changed in version 4.3
; Version 4.4 Implements step-ramp pursuit (not yet)
; Version 4.5 Does step-ramp pursuit, continuous sinusoidal stimuli, & increments reward
; Version 4.6 Adds reward randomization and sequential saccades.
; Version 4.7 Adds out-and-back saccades and chkfix routine\
; Version 4.8 Adds random fix time as implemented by Kay and revision on 1/22/08 also removes
; "P" mark for subsequent laser jumps during sequential saccades
; Version 5.0 Follows structural changes in script version 8.0; nothing changed in sequencer
; Version 5.1 Follows changes in script version 8.1; nothing changed in sequencer
; Version 5.2 Adds online crosstalk compensation from script 
; Version 5.3 Removes bar press components in execution (some variables may linger)
; Version 5.4 Changes eye in window routine to match changes in script
; Version 5.5 Changes eiwdelay routine, adds grace period, and blank task but is buggy
; Version 5.6 Adds prediction task and makes sine tasks compatible with earth fixed laser
;             Also removes remaining references to bar press training routines

; Use with userInterface.s2s


; Aug 28, 2006 Shane

            SET      0.100 1 0

            TABSZ  1300            ;13-D table, 100 elements per dimension, each element is trial
                ;0-99    starting h pos [offset=0]
                ;100-199 ending h pos [offset=100] 
                ;200-299 starting v pos [offset=200]
                ;300-399 ending v pos [offset=300]
                ;400-499 hold time [offset=400]
                ;500-599 reward time [offset=500]
                ;600-699 marker [offset=600]
                ;700-799 fixation times [**new in version 4.8]
                ;800-899 chair displacement [**new in version 4.3]
                ;900-999 step ramp H laser start point
                ;1000-1099 step ramp V laser start point
                ;1100-1199 hold time with stationary laser (target intercept task)
                ;1200-1299 hold time with moving laser (target intercept task)

    ;Bits
            VAR    V1,lz1on=243 ;[....00..]
            VAR    V2,lz1off=1267 ;[....01..]
            VAR    V3,lz2on=16575 ;[.1......]
            VAR    V4,lton=510     ;[.......1]
            VAR    V5,ltoff=254    ;[.......0]
            VAR    V6,rewoff=127
            VAR    V7,rewon=256*128+127
            VAR    V8,lz2off=191  ;[.0......]
;            VAR    V8,eoton=16575  ;[.1......]
;            VAR    V9,eotoff=191   ;[.0......]

    ;Flags
            VAR    V10,EOT=1       ;Eye on target/bar press flag 0=off,1=on
            VAR    V11,EYE=0       ;Use EYE flag 0=eye trial,1=eye continuous; 0 and 1 use EIW
            VAR    V12,TASK=1      ;0=no laser, 1=fixation, 2=saccade, 3=r pursuit, 4 s pursuit
            VAR    V13,SKIPWT=1    ;Internal counter to skip bar rel wait periods (don't set <1)
            VAR    V14,skipwtsc=1  ;Script value for SKIPWT for re/initialization
            VAR    V15,OKSLTON=0   ;Should OKS light be on during task?
            VAR    V16,LZON=1      ;Should laser be on during task?
            VAR    V17,OPTION=1    ;Task-specific option, such as step-ramp or out-and-back saccades
            VAR    V18,seqcntsc=1  ;Script value for sequence counter
            VAR    V19,SEQCNT=1    ;Sequence counter for sequential saccades
   ; Also see V29, which is a newly added flag for skipping reward, so the numbering is out of place

    ;General task variables
            VAR    V20,ITIA=ms(500)
            VAR    V21,ITIB=ms(500)
            VAR    V22,numtrl=0
            VAR    V23,numgood=0
            VAR    V24,gracetm
            VAR    V25,gracecnt=ms(50)
            VAR    V26,dlytm=ms(400) ;delay before eiw check from script
            VAR    V27,dlycnt=ms(400) ;internal var for delay before checking for eiw
            VAR    V28,holdcnt=ms(1000)/2
            VAR    V29,SKIPREW=0        ;Skip reward, e.g. during seq sac
            VAR    V30,fixcnt=ms(500)/2
            VAR    V31,rewdly=ms(150)
            VAR    V32,TARGET=0     ;0=laser 1 (moving), 1=laser 2 (fixed), 3=chair (e.g., VORC)
            VAR    V33,rewinc=ms(1) ;increment reward by this amount each correct trial
            VAR    V34,rewcnt=0

    ;Task control/movement variables
            VAR    V35,Htarget     ;Horizontal laser target position for ramp (loaded from table)
            VAR    V36,Vtarget     ;Vertical laser target position for ramp (loaded from table)
            VAR    V37,Hlvel=vdac32(1)/s(1) ;default Hlaser velocity
            VAR    V61,Vlvel=vdac32(1)/s(1) ;default Vlaser velocity
            VAR    V38,freq=VHz(0.5) ;Frequency for sinusoidal pursuit, chair, drum, etc
            VAR    V39,index=0     ;Index of table
            VAR    V40,cvel=vdac32(1)/ms(500) ;Default chair/drum velocity
            VAR    V41,gracest=ms(100) ;Grace period before bad trial

            VAR    V42,Tmp1=0      ;First temporary variable used for holding intermediate values

    ;Eye check related variables
            VAR    V43,Hcross      ;% of vertical to subtract from horizontal (x 128 in script)
            VAR    V44,Vcross      ;% of horizontal to subtract from vertical (x 128 in script)
            VAR    V45,HEP         ;Horizontal eye position for EIWCHK
            VAR    V46,VEP         ;Vertical eye position for EIWCHK
            VAR    V47,HCtr        ;Center of laser for horizontal
            VAR    V48,VCtr        ;ditto for vertical
            VAR    V49,HEScale     ;Horizontal scale factor for comparing eye to laser
            VAR    V50,HEOffset    ;Horizontal offset for comparing eye to laser
            VAR    V51,VEScale     ;Vertical scale factor for comparing eye to laser
            VAR    V52,VEOffset    ;Vertical offset for comparing eye to laser
            VAR    V53,WinSz       ;Window size used in calculation (set by one of below)
            VAR    V54,TkWinSz     ;Window size for task in DAC units
            VAR    V55,FxWinSz     ;Window size for initial fixation in DAC units

    ;Unnecessary variables
            VAR    V56,Tmp2=0      ;Second temporary variable for holding intermediate values

    ;Can't use V57-60, because used internally
    ;Vars 61-64 are available b/c they are used to emulate counters in LDBNZ, which we don't use

;Make sure no DAC outputs when program loads
INIT:  'I   RATE   0,0
            RATE   1,0
            RATE   2,0             ;Stop DACs if running
            RATE   3,0
            DAC    0,0
            DAC    1,0
            DAC    2,0             ;Set initial laser position of zero
            DAC    3,0
            DIGOUT lz1off
            DIGOUT lz2off
            DIGOUT ltoff
            DIGOUT rewoff
            HALT                   ;Wait until started >Stopped
    ;Initialize everything on start
START:  'G  DIGOUT lz1off        ;moving laser
            DIGOUT lz2off      ;fixed laser
            DIGOUT ltoff
            DIGOUT rewoff
            CALL   REQSTOP      ; Request DAC stop for everything in separate call so they're synced
            CALL   CHRSTOP
            CALL   DRMSTOP
            CALL   LZSTOP
            RATE   0,0
            RATE   1,0
            RATE   2,0             ;Stop DACs if running
            RATE   3,0
            DAC    2,0             ;Set initial laser position of zero
            DAC    3,0
;            MOV    SKIPWT,skipwtsc ;load counter
BTRIAL:     DELAY  ITIB            ;                   >Bad ITI
TRIAL:  'q  CALL   REQSTOP      ; Request DAC stop for everything in separate call so they're synced
            CALL   CHRSTOP         ;Stop Chair if running
            CALL   DRMSTOP
            CALL   LZSTOP
            RATE   0,0
            RATE   1,0
            RATE   2,0             ;Stop laser DACs if running
            RATE   3,0
            DIGOUT rewoff          ;Make sure reward is off!!!
            DAC    2,[index]
            DAC    3,[index+200]   ;Move laser to initial position here
            MARK   103             ;'g' ITI over, for checking latency until press
            DELAY  ITIA            ;                   >ITI
NODLY:      MOV    WinSz,FxWinSz   ;Set to fixation window size
            MOVI TARGET,0          ;Set target to main laser (laser 1)
            BEQ    LZON,0,NOLZ1    ;If doing OKSONLY, no laser
            BNE    TASK,10,LZ1     ;If not doing target intercept task, don't turn on fixed laser
            DIGOUT lz2on
            MOVI TARGET,1       ;Set to fixation target if doing prediction task
            JUMP NOLZ1
LZ1:        DIGOUT lz1on        ;For EIW, laser comes on before EOT=1
NOLZ1:      TABLD  fixcnt,[index+700] ;Refresh fixation counter
            TABLD  holdcnt,[index+400] ;Refresh hold counter
            MOV    dlycnt,dlytm ;Refresh delay before EIW counter
	    ;laser will already be dim if doing EIW
            BEQ    LZON,0,FIX      ;If doing OKSONLY, no laser
;            DELAY  ms(10)          ;To reduce errors from faulty spikes in bar switch
;            MARK 102               ; 'f' for beginning of fixation period
FIX:        CALL   CHKFIX          ;Total steps for loop = 3 + 21 = 24 >Check Fix
JMP1:   'j  MOV    WinSz,TkWinSz   ;Now set to task window size
            MARK   [index+600]     ;Mark trial type at beginning of trial
            BEQ    TASK,1,HOLD     ;FIXATE             >Check Hold
            BEQ    TASK,2,SAC      ;SACCADE            >Check Hold
            BEQ    TASK,3,RPUR     ;RAMP PURSUIT       >Check Hold
            BEQ    TASK,4,SPUR     ;SINE PURSUIT       >Check Hold
            BEQ    TASK,5,SCANCEL  ;Sinusoidal cancellation >Check Hold
            BEQ    TASK,6,SOKS     ;Sinusoidal OKS     >Check Hold
            BEQ    TASK,7,SVORL    ;VOR in light
            BEQ    TASK,8,VORD     ;VOR in dark
            BEQ    TASK,9,SEQSAC   ;Sequential saccade
            BEQ    TASK,10,PREDICT ;Target intercept (prediction)
HOLD:       CALL   CHKHOLD         ;Call routine to check for eye hold >Check Hold
GOODTRL:    ADDI   numtrl,1        ;Started trial, increment counter
            ADDI   numgood,1       ;Add a good trial to counter
;            MOV    SKIPWT,skipwtsc ;reload skip counter
            DELAY  rewdly          ;Delay fixed time before reward >Good trial
        'r  DIGOUT rewon           ;Turn reward on
            MARK   114             ;'r'
            DELAY  [index+500]     ;This time determines amount of reward dispensed >Reward
            DELAY  rewcnt          ;Increasing reward for consecutive good trials >Reward
            DIGOUT rewoff
            BEQ    EYE,1,CONT      ;If in continuous mode, don't start new trial
            DIGOUT lz1off        ;Keep laser on until reward is done
            MARK   88           ; 'X' for end of trial
            DELAY  ms(10)          ;To give laser a chance to completely turn off before jump
            ADDI   index,1         ;Increment index if good trial.  If bad, repeat
            ADD    rewcnt,rewinc   ;Increment reward duration
            BLT    rewcnt,2000,SK2
            MOVI   rewcnt,0
SK2:        BGT    index,99,RESET  ;Reset index once it gets to 99 or else we overflow
            BEQ    EYE,2,RESET     ;If doing seqsac, reset index
            JUMP   TRIAL
RESET:      MOVI   index,0
            JUMP   TRIAL



CONT:       BEQ    TASK,8,CONT1    ;if doing VORd, don't turn laser back on
            BEQ    LZON,0,CONT1    ;if laser not supposed to be on (e.g. OKS only)
            DIGOUT lz1on        ;Make sure this has same effect if laser already bright!>No EIW
CONT1:      TABLD  holdcnt,[index+400] ;Reload hold counter
CONT2:      CALL   EIWCHK               ;                   >No EIW
            BEQ    EOT,0,CONT2     ;Now wait until EIW>No EIW
            JUMP   HOLD

BADTRL:     BEQ    EYE,1,CONT      ;If continuous mode, don't count as bad trial
            ADDI   numtrl,1        ;Increment trial counter
            MOVI   rewcnt,0        ;reset counter for consecutive good trials
            MARK   120             ;'x' for "bad trial"
            DIGOUT lz1off        ;Turn laser 1 off
            DELAY  ms(10)          ;So laser is completely off before jump
            BEQ    EYE,2,RESET     ;If SEQUENTIAL, reset index
;            ADDI   SKIPWT,-1
;            BGT    SKIPWT,0,BTRIAL ;If skipping release, add another ITI...
            JUMP   TRIAL           ;Otherwise, start again

BADFIX:     DIGOUT lz1off        ;Turn everything off
;            ADDI   SKIPWT,-1       ;Decrement wait skip counter, but don't count as bad trial
;            BGE    EYE,0,NODLY     ;If in eye mode, don't impose new ITI
;            BGT    SKIPWT,0,BTRIAL ;If skipping release, add another ITI...
            ;Don't add BADITI for broken initial fixation
             JUMP   NODLY
;            JUMP   TRIAL           ;Otherwise, start again

CHKFIX:     CALL   EIWCHK          ;Total steps for loop = 3 + 21 = 24 >Check Fix
            BEQ    EOT,0,BADFIX    ;if monkey releases bar, bad fixation>Check Fix
            DBNZ   fixcnt,CHKFIX   ;Loop until hold time is over >Check Fix
            RETURN                 ;                   >Check Fix

;Generalized routine for checking EIW or Bar press
CHKHOLD:    CALL   EIWCHK          ;24 steps in loop   >Check Hold
            ;BEQ    EOT,0,GRACE     ;Not currently working well >Check hold
            BEQ    EOT,0,BADTRL    ;if monkey releases bar, bad trial>Check Hold
            DBNZ   holdcnt,CHKHOLD ;Loop until hold time is over >Check Hold
            RETURN                 ;                   >Check Hold

EIWDLY:     CALL    EIWCHK         ;>Wait for EIW
            BGT     EOT,0,EIWDLYR  ;>Wait for EIW
            DBNZ    dlycnt,EIWDLY  ;>Wait for EIW
            JUMP    BADTRL         ; If we get here, monkey took too long
EIWDLYR:    DELAY ms(50)
            CALL EIWCHK            ; Make sure eye still in window 10 ms later in case system noise
            BEQ     EOT,0,EIWDLY   ; If not, rejoin delay loop, otherwise go to next stage
            RETURN

;Not using grace period right now, because doesn't work properly
;GRACE:      DELAY  gracest         ;Give grace period  >Grace Period
;            MOVI   GRACEFL,0       ;Grace period used this trial--no more
;            CALL   MODECHK
;            BEQ    EOT,0,BADTRL    ;If still out of window, bad trial
;            RETURN

EIWCHK:     MOVI   EOT,1           ;                   >Check Eye
            BEQ   TARGET,1,STAT    ; if fixation laser, jump to stat
            CHAN  HCtr,9          ;Horiz Laser center in DAC bits>Check Eye
            CHAN  VCtr,10         ;Vert Laser center in DAC bits >Check Eye
            JUMP  SKIP5
STAT:       NOP
            MOVI  HCtr,0          ;Horiz Laser center in DAC bits>Check Eye
            MOVI  VCtr,0          ;Vert Laser center in DAC bits >Check Eye
SKIP5:      CHAN   HEP,3           ;Get Horizontal Eye Position in DAC bits>Check Eye
            CHAN   VEP,4           ;Get Vert Eye Pos in DAC bits >Check Eye
;Compensate for crosstalk based on values from script
            MOV    Tmp1,Hcross
            MUL    Tmp1,VEP,0,7    ;Multiply vertical eye position by percent to subtract,
;then divide by 128 to get real value
            MOV    Tmp2,Vcross
            MUL    Tmp2,HEP,0,7    ;Multiply horizontal eye position by percent to subtract,
;then divide by 128 to get real value
            SUB    HEP,Tmp1        ;Subtract percent of vertical position from horizontal
            SUB    VEP,Tmp2        ;Subtract percent of horizontal position from vertical
;Convert eye position bits into laser-referenced bits using ratio of eyebits/deg to lzbits/deg
;in script.  Script passes bit ratio and offset to sequencer for conversion.  To avoid roundoff
;errors, ratio is shifted 7 bits in script (multiplied by 128), which needs to be compensated
;for here before comparing eye bits with laser bits.

            MUL    HEP,HEScale,0,7 ;Scale eye to laser-based bits >Check Eye
            MUL    VEP,VEScale,0,7 ;Scale eye to laser-based bits >Check Eye
            ADD    HEP,HEOffset    ;Adjust eye offset  >Check Eye
            ADD    VEP,VEOffset    ;Adjust eye offset  >Check Eye
            SUB    HEP,HCtr        ;Get X distance     >Check Eye
            SUB    VEP,VCtr        ;Get Y distance     >Check Eye
			;Can't check abs(HEP) so need to check HEP/VEP and negations separately
            BGT    HEP,WinSz,MISS  ;If X is bigger than WinSz >Check Eye
            BGT    VEP,WinSz,MISS  ;If Y is bigger than WinSz >Check Eye
            NEG    HEP,HEP         ;Need this to check absolute value>Check Eye
            NEG    VEP,VEP         ;ditto              >Check Eye
            BGT    HEP,WinSz,MISS  ;If X is bigger than WinSz >Check Eye
            BGT    VEP,WinSz,MISS  ;If Y is bigger than WinSz >Check Eye
        ;    DIGOUT eoton           ;                   >Check Eye
            RETURN                 ;                   >Check Eye

MISS:       MOVI   EOT,0           ;Eye not on target/bar not pressed >BAD
         ;   DIGOUT eotoff          ;                   >BAD
            RETURN                 ;Do i need to call specific label here? >BAD

SAC:        DIGOUT lz1off        ;                   >Saccade
            DELAY  ms(10)
            DAC    2,[index+100]   ;                   >Saccade
            DAC    3,[index+300]   ;                   >Saccade
            DIGOUT lz1on        ;                   >Saccade
            CALL   EIWDLY           ;For saccade system delay>Saccade
            BNE    OPTION,1,SAC1   ;If not doing out-and-back, rejoin main loop >Saccade
            TABLD  fixcnt,[index+700] ;Refresh fixation counter for fix at end >Saccade
            CALL   CHKHOLD         ;                   >Saccade
            DELAY  ms(200)         ;                   >Saccade
            DIGOUT lz1off        ;                   >Saccade
            DAC    2,[index]       ;Go back to start pos >Saccade
            DAC    3,[index+200]   ;                   >Saccade
            MOV    dlycnt,dlytm     ;Refresh delay before EIW counter
            DIGOUT lz1on
            CALL   EIWDLY           ;For saccade system delay>Saccade
            CALL   CHKFIX          ;                   >Saccade
            MARK   100             ;                   >Saccade
            JUMP   GOODTRL
SAC1:       JUMP   HOLD            ;                   >Saccade

SEQSAC:     MOV    SEQCNT,seqcntsc ;Reload sequence counter
SEQSAC1:    DIGOUT lz1off
            DELAY  ms(10)          ;*** Removed delay on 1/29/08 (added again 5/20/08). ***
            MARK   74                   ;'J' for each jump
            DAC    2,[index+100]
            DAC    3,[index+300]
            MOV    dlycnt,dlytm     ;Refresh delay before EIW counter
            DIGOUT lz1on
            CALL   EIWDLY           ;For saccade system delay>Saccade
            CALL   CHKHOLD
            TABLD  holdcnt,[index+400]
;            DELAY  ms(200) ;(Not sure why delay is here? Removed 12/04/09)
            ADDI   index,1         ;Increment index if good trial.
            BEQ    SKIPREW,1,REWSKP  ;Skip reward if flag is set
            DIGOUT rewon           ;Turn reward on
            MARK   114             ;'r'
            DELAY  [index+500]     ;This time determines amount of reward dispensed >Reward
            DELAY  rewcnt          ;Increasing reward for consecutive good trials >Reward
            DIGOUT rewoff
            ADD    rewcnt,rewinc   ;Increment reward duration
REWSKP:     DBNZ   SEQCNT,SEQSAC1  ;Loop until sequence complete
            ADDI   index,-1        ;Go back to last index value so proper reward is delivered
            MOVI   rewcnt,0
            JUMP   GOODTRL

RPUR:       TABLD  Htarget,[index+100] ;load var from table >Pursuit
            TABLD  Vtarget,[index+300] ;load var from table >Pursuit
            BEQ    OPTION,0,SK3    ;If not doing step-ramp, skip next steps
            DIGOUT lz1off
            DELAY  ms(10)          ;*** Removed delay on 1/29/08 (Added again on 5/20/08). ***
            DAC    2,[index+900]   ;Jump lasers to starting point
            DAC    3,[index+1000]
            DIGOUT lz1on
SK3:        RAMP   2,Htarget,Hlvel ;start ramps        >Pursuit
            RAMP   3,Vtarget,Vlvel ; 
            CALL   EIWDLY           ;For pursuit system delay>Pursuit
            JUMP   HOLD            ;                   >Pursuit

PREDICT:    TABLD Htarget, [index+100]; load var from table
            TABLD Vtarget, [index+300]
            DIGOUT lz1on        ; Turn target laser on
            TABLD holdcnt, [index+1100] ; start using stat target fixation time
            CALL CHKHOLD ; make sure monkey ignoring target laser
            RAMP 2, Htarget, Hlvel ;start ramps
            RAMP 3, Vtarget, Vlvel
            MARK 104 ; h for third fixation
            TABLD holdcnt,[index+1200]; start using moving target fixation time
            CALL CHKHOLD; make sure ignoring moving laser
            MARK 112 ; start of pursuit period, fixlaser off
            DIGOUT lz2off ;turn fixation laser off
            ;CALL BREAK               ;                   >Moving hold period
            MOVI TARGET,0 ;set eiw to check moving laser
            TABLD holdcnt, [index+400]; load final pursuit hold time
            CALL EIWDLY ; for saccade system delay
            JUMP HOLD

; Need to look over this to make sure it works okay for eccentric and circular pursuit
SPUR:       TABLD  Htarget,[index+100] ;load var from table >Pursuit
            TABLD  Vtarget,[index+300] ;load var from table >Pursuit
            PHASE  2,-90           ;Make it Sine       >Pursuit
            ANGLE  2,0             ;Make it Sine       >Pursuit
            PHASE  3,-90           ;Make it Sine       >Pursuit
            ANGLE  3,0             ;Make it Sine       >Pursuit
            OFFSET 2,[index]       ;Add offset to match initial DAC >Pursuit
            OFFSET 3,[index+200]   ;Add offset to match initial DAC >Pursuit
SPURH:      SZ     2,Htarget       ;                   >Pursuit
SPURV:      SZ     3,Vtarget       ;                   >Pursuit
            RATE   2,freq          ;                   >Pursuit
            RATE   3,freq          ;                   >Pursuit 
            CALL   EIWDLY           ;For pursuit system delay>Pursuit
            JUMP   HOLD            ;                   >Pursuit


SCANCEL:    TABLD  Vtarget,[index+800] ;Vtarget holds chair position (16-bits) >VORC
            TABLD  Htarget,[index+100] ;Htarget holds laser displacement (16-bits) >VORC
;Cosine gives smoother acceleration because starting velocity is zero
            PHASE  1,0             ;Make it Cosine     >VORC
            ANGLE  1,0             ;Make it Cosine     >VORC
            OFFSET 1,0             ;No offset          >VORC
            SZ     1,Vtarget       ;16-bit var         >VORC
            PHASE  0,0             ;Make it Cosine     >VORC
            ANGLE  0,0             ;Make it Cosine     >VORC
            OFFSET 0,0             ;No offset          >VORC
            SZ     0,Htarget       ;16-bit var         >VORC
            PHASE  2,0           ;Make it Cosine     >VORC
            ANGLE  2,0             ;Make it Cosine     >VORC
            OFFSET 2,[index]       ;Horizontal offset  >VORC
            SZ     2,Htarget       ;16-bit var         >VORC
            MULI   Vtarget,65536   ;because RAMP uses 32-bit vars >VORC
            MULI   Htarget,65536   ;because RAMP uses 32-bit vars >VORC
            RAMP   1,Vtarget,cvel  ;Chair
            DELAY  ms(35)
            RAMP   2,Htarget,Hlvel ;Laser, slope scaled by ratio lz/chr in script
            BEQ    OKSLTON,0,RLOOP3  ;                     >VORC
            RAMP   0,Vtarget,cvel  ;Drum                >VORC
            DIGOUT lton         ;                     >VORC
RLOOP3:     WAITC  1,RLOOP3
            RATE   1,freq          ;chair              >VORC
            DELAY  ms(35)
            RATE   2,freq          ;laser              >VORC
            BEQ    OKSLTON,0,DLY3 ;                     >VORC
            RATE   0,freq          ;start drum         >VORC 
DLY3:       MOVI TARGET,1       ; use "stationary target", meaning zero eye movement
            CALL   EIWDLY           ;For pursuit system delay>VORC
            JUMP   HOLD            ;                    >VORC


SOKS:       TABLD  Htarget,[index+800] ;Use same table address as laser params
            PHASE  0,0             ;Make it Cosine     >OKS
            ANGLE  0,0             ;Make it Cosine     >OKS
            OFFSET 0,0             ;No offset          >OKS
            SZ     0,Htarget       ;16-bit var         >OKS
            DIGOUT lton
            RATE   0,freq          ;start drum         >OKS
            BEQ    LZON,1,DLY1
            DIGOUT lz1off 
DLY1:       CALL   EIWDLY           ;For pursuit system delay>OKS
            JUMP   HOLD            ;                   >OKS

VORD:       DIGOUT lz1off
            DIGOUT ltoff
            JUMP   SVORL

;Sinusoidal cancellation
SVORL:    TABLD  Htarget,[index+800] ;Use same table address as laser params
;Can we use sine or does it need to be cos?
;Cosine gives smoother acceleration because starting velocity is zero
            PHASE  1,0             ;Make it Cosine     >VORL
            ANGLE  1,0             ;Make it Cosine     >VORL
            OFFSET 1,0             ;No offset          >VORL
            SZ     1,Htarget       ;16-bit var         >VORL
            PHASE  0,0             ;Make it Cosine     >VORL
            ANGLE  0,0             ;Make it Cosine     >VORL
            OFFSET 0,0             ;No offset          >VORL
            SZ     0,Htarget       ;16-bit var         >VORL
            MULI   Htarget,65536   ;because RAMP uses 32-bit vars >VORC
            RAMP   1,Htarget,cvel
            BEQ    OKSLTON,0,RLOOP2 ;                   >VORL
            RAMP   0,Htarget,cvel
            DIGOUT lton          ;                   >VORL
RLOOP2:     WAITC  1,RLOOP2
            RATE   1,freq          ;                   >VORL
            BEQ    OKSLTON,0,DLY2  ;                   >VORL
            RATE   0,freq          ;start drum         >VORL 
DLY2:       CALL   EIWDLY           ;For pursuit system delay>VORL
            JUMP   HOLD            ;                   >VORL


; Consider combining drum and chair stop routines so they are in sync
; For now they are synchronized by requesting a stop on all DACs with a separate routine
CHRSTOP:    BEQ    VDAC1,0,CSKIP2  ;If last value written to DAC1 was non-zero...
;            RATEW  1,0             ;Request stop next cycle
CSTOPLP:    WAITC  1,CSTOPLP       ;...we are probably moving chair>Stopping Chair
CSKIP2:     RATE   1,0             ;Make sure it's stopped
            RAMP   1,0,cvel
CRAMPDN:    WAITC  1,CRAMPDN
            DAC    1,0
            RETURN 

DRMSTOP:    BEQ    VDAC0,0,DSKIP2  ;If last value written to DAC0 was non-zero...
;            RATEW  0,0             ;Request stop next cycle
DSTOPLP:    WAITC  0,DSTOPLP       ;...we are probably moving drum>Stopping Drum
DSKIP2:     RATE   0,0             ;Make sure it's stopped
            RAMP   0,0,cvel
DRAMPDN:    WAITC  0,DRAMPDN
            DAC    0,0
            RETURN 

LZSTOP:      NOP
;            BEQ    VDAC2,0,LZSKIP1  ;If last value written to DAC was non-zero...
;            CLRC   2
;LHSTOPLP:   WAITC  2,LHSTOPLP       ;...we are probably moving laser>Stopping laser
;LZSKIP1:    BEQ    VDAC3,0,LZSKIP2
;            CLRC   3
;LVSTOPLP:   WAITC  3,LVSTOPLP       ;...we are probably moving laser>Stopping laser
;LZSKIP2:    RATE   2,0             ;Make sure it's stopped
;            DAC    2,0
;            RATE   3,0             ;Make sure it's stopped
;            DAC    3,0
            RETURN

REQSTOP:    RATEW  0,0             ;Request stop next cycle
            RATEW  1,0             ;Request stop next cycle
            RATEW  2,0             ;Request stop next cycle
            RATEW  3,0             ;Request stop next cycle
            RETURN

STOP:   'X  DIGOUT lz1off
            DIGOUT lz2off
;            MARK   122             ;'z'
            DIGOUT rewoff
            DIGOUT ltoff
            CALL   REQSTOP
            CALL   CHRSTOP
            CALL   DRMSTOP
            CALL   LZSTOP
            DAC    0,0                  ;Make sure DACs zeroed
            DAC    1,0
            DAC    2,0
            DAC    3,0
            MARK   88           ; 'X' for end of trial
            HALT                   ;                   >Stopped

       
        '0  DIGOUT lz1off
            DIGOUT lz2off
            HALT   
 
        'z  DIGOUT lz1on     ;Laser number one (key is number "one")
            HALT   

        'Z  DIGOUT lz2on   ;Laser number two
            HALT
        
        'L  DIGOUT lton
            HALT   
        'l  DIGOUT ltoff        ;Key is letter "el"
            HALT   

