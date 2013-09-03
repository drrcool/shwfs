
source PMAC.tcl

proc axis { a m } {
        ivar $a $m iMaxVel  	16
        ivar $a $m iMaxAcc  	17
	ivar $a $m iHomeMaxAcc  19
	ivar $a $m iHomeAccTime 20
	ivar $a $m iHomeAccSCur 21
	ivar $a $m iHomeSpeed 	23
	ivar $a $m iFlagAddr    25
	ivar $a $m iHomeOffset  26
	ivar $a $m iTol  	28

	ax_iven $a $m iHomeTrig 02
	ax_iven $a $m iHomeFlag 03

	ax_pvar $a $m AxisFlip	01
	ax_pvar $a $m HomeSpeed	02
	ax_pvar $a $m HomeOff   03
	ax_pvar $a $m HomeDir   04
	ax_pvar $a $m FeedRate 	05
	ax_pvar $a $m AccTime 	06
	ax_pvar $a $m AccSCur 	07
	ax_pvar $a $m Tol  	08
	ax_pvar $a $m LimNudge	09

	ax_pvar $a $m TolScale	10
	ax_pvar $a $m AxisPos	11

	ax_mvdp $a $m Desired 	00 F
	ax_mvdp $a $m Homed 	01 X
	ax_mvdp $a $m HomePos	02 F
	ax_mvdp $a $m PLimPos	03 F
	ax_mvdp $a $m MLimPos	04 F
	ax_mvdp $a $m BrakDP    05 X
	ax_mvdp $a $m HFlagDP 	06 X
	ax_mvdp $a $m PLimDP 	07 X
	ax_mvdp $a $m MLimDP 	08 X
	ax_mvdp $a $m Check	09 X

	ax_mvsv $a $m Commanded	11 D 0x0028  60
	ax_mvsv $a $m Actual	12 D 0x002B  60
	ax_mvsv $a $m Target	13 D 0x080B 192
	ax_mvsv $a $m Bias	14 D 0x0813 192
	ax_mvsv $a $m PLimit	15 x 0x003D  60 21
	ax_mvsv $a $m MLimit	16 x 0x003D  60 22
	ax_mvsv $a $m IsMoving	17 x 0x003D  60 17
	ax_mvsv $a $m OLop	18 x 0x003D  60 18
	ax_mvsv $a $m VelZero	19 x 0x003D  60 13
	ax_mvsv $a $m DAC	20 X 0x003A  60

	ax_mvgt $a $m HomeFlag	21 x 20
	ax_mvgt $a $m PLimBit 	22 x 22
	ax_mvgt $a $m MLimBit 	23 x 21
	ax_mvgt $a $m Encoder 	25 X  1
	ax_mvgt $a $m AmpEnable 26 x 14 
	ax_mvgt $a $m AmpFault	27 x 23
	ax_mvgt $a $m Enc3rdCh	28 x 19

	ax_mvsv $a $m StopLim   30 y 0x0814 192 11
	ax_mvsv $a $m FolErr    31 y 0x0814 192  2
	ax_mvsv $a $m InPos     32 y 0x0814 192  0

	puts ""
}

pvar WFSCam		p70
pvar SciCam		p71
pvar WFSTOff		p72
pvar SciTOff		p73
pvar WFSFOff		p74
pvar SciFOff		p75

pvar PosCount		p80
pvar BrakTimeOut	p82
pvar DelayLoop		p89

pvar GatherData		p94
pvar EStopped		p95

pvar Check		p98
pvar Running		p99

mvar MBrake 		m1  Y:\$FFC2,8,1
mvar TBrake		m2  Y:\$FFC2,9,1
mvar CBrake		m3  Y:\$FFC2,10,1
mvar FBrake 		m4  Y:\$FFC2,11,1
mvar EncoderPower 	m5  Y:\$FFC2,12,1
mvar ServoPower		m6  Y:\$FFC2,13,1
mvar BrakeOveride	m7  Y:\$FFC2,14,1

mvar MAxisPosCapture	m25 X:\$C003,0,24,S
mvar TAxisPosCapture	m26 X:\$C007,0,24,S
mvar CAxisPosCapture	m27 X:\$C00B,0,24,S
mvar FAxisPosCapture	m28 X:\$C00F,0,24,S

mvar MHFlag 		m11  Y:\$FFC2,0,1
mvar THFlag		m12  Y:\$FFC2,1,1
mvar CHFlag		m13  Y:\$FFC2,2,1
mvar FHFlag 		m14  Y:\$FFC2,3,1

mvar EStop		m30 Y:\$FFC2,4,1
mvar EStopDP		m31 X:\$D290,0,16

mvar CopyDone		m32 X:\$D291,0,16
mvar StowedSafe		m33 X:\$D292,0,16
mvar MoveTime		m34 F:\$D293
mvar Error		m36 X:\$D295,0,16,S
mvar Done		m37 X:\$D296,0,16,S
mvar BrakDP		m38 X:\$D297,0,16,S

mvar ProgramRunning	m40 X:\$0818,0,1
mvar Timer0		m41 X:\$0700,0,24,s
mvar Timer1		m42 Y:\$0700,0,24,s
mvar Timer2		m43 X:\$0701,0,24,s
mvar Timer3		m44 Y:\$0701,0,24,s

mvar MBrakSave 		m51 *
mvar TBrakSave		m52 *
mvar CBrakSave		m53 *
mvar FBrakSave 		m54 *

mvar dbg1		m900 F:\$D280
mvar dbg2		m901 F:\$D281
mvar dbg3		m902 F:\$D282
mvar dbg4		m903 F:\$D283
mvar dbg5		m904 F:\$D284
mvar dbg6		m905 F:\$D285

axis M 1
axis T 2
axis C 3
axis F 4

exit

; M Variables Definition
;



State->Y:$D220,0,16

MoveTime->F:$D259

InPos->Y:$0817,17,1
FollowingWar->Y:$0817,18,1
FollowingErr->Y:$0817,19,1
AmpFault->Y:$0817,20,1
RTError->Y:$0817,22,1

MAxisScale->L:$0B26
TAxisScale->L:$08E3
CAxisScale->L:$09A4
FAxisScale->L:$0B22


MFolErr->Y:$0A54,2,1
TFolErr->Y:$08D4,2,1
CFolErr->Y:$0994,2,1
FFolErr->Y:$0B14,2,1


