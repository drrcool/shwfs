/*

	SBIGUDRV.H

	Contains the function prototypes and enumerated constants
	for the Universal Parallel/USB/Ethernet driver.

	This supports the following devices:

		ST-7E/8E/9E/10E
		ST-5C/237/237A (PixCel255/237)
		ST-1K
        AO-7
 
    Version 4.28 - February 24, 2003

	(c)1995-2002 - Santa Barbara Instrument Group

*/
#ifndef _PARDRV_
#define _PARDRV_

/*

	SBIG Specific Code

*/
#ifndef TARGET
 #define ENV_DOS		0				/* Target for DOS environment */
 #define ENV_WIN		1				/* Target for Windows environment */
 #define ENV_WINVXD		2				/* SBIG Use Only, Win 9X VXD */
 #define ENV_WINSYS		3				/* SBIG Use Only, Win NT SYS */
 #define ENV_ESRVJK		4				/* SBIG Use Only, Ethernet Remote */
 #define ENV_ESRVWIN	5				/* SBIG Use Only, Ethernet Remote */
 #define ENV_MACOSX     10				/* SBIG Use Only, Mac OSX */
 #define TARGET			ENV_WIN			/* Set for your target */
#endif

/*

	Enumerated Constants

	Note that the various constants are declared here as enums
	for ease of declaration but in the structures that use the
	enums unsigned shorts are used to force the various
	16 and 32 bit compilers to use 16 bits.

*/

/*

	Supported Camera Commands

	These are the commands supported by the driver.
	They are prefixed by CC_ to designate them as
	camera commands and avoid conflicts with other
	enums.

	Some of the commands are marked as SBIG use only
	and have been included to enhance testability
	of the driver for SBIG.

*/
typedef enum {
	/*

		General Use Commands

	*/
	/* 1 - 10 */
	CC_START_EXPOSURE=1, CC_END_EXPOSURE, CC_READOUT_LINE,
	CC_DUMP_LINES, CC_SET_TEMPERATURE_REGULATION,
	CC_QUERY_TEMPERATURE_STATUS, CC_ACTIVATE_RELAY, CC_PULSE_OUT,
	CC_ESTABLISH_LINK, CC_GET_DRIVER_INFO,

	/* 11 - 20 */
	CC_GET_CCD_INFO, CC_QUERY_COMMAND_STATUS, CC_MISCELLANEOUS_CONTROL,
	CC_READ_SUBTRACT_LINE, CC_UPDATE_CLOCK, CC_READ_OFFSET,
	CC_OPEN_DRIVER, CC_CLOSE_DRIVER,
	CC_TX_SERIAL_BYTES, CC_GET_SERIAL_STATUS,

	/* 21 - 30 */
	CC_AO_TIP_TILT, CC_AO_SET_FOCUS, CC_AO_DELAY,
    CC_GET_TURBO_STATUS, CC_END_READOUT, CC_GET_US_TIMER,
	CC_OPEN_DEVICE, CC_CLOSE_DEVICE, CC_SET_IRQL, CC_GET_IRQL,

	/* 31 - 40 */
	CC_GET_LINE, CC_GET_LINK_STATUS, CC_GET_DRIVER_HANDLE,
	CC_SET_DRIVER_HANDLE, CC_START_READOUT, CC_GET_ERROR_STRING,
	CC_SET_DRIVER_CONTROL, CC_GET_DRIVER_CONTROL,
	CC_USB_AD_CONTROL, CC_QUERY_USB,

	/* 41 - 50 */
	CC_GET_PENTIUM_CYCLE_COUNT, CC_RW_USB_I2C, 

	/*

		SBIG Use Only Commands

	*/
	CC_SEND_BLOCK=90, CC_SEND_BYTE, CC_GET_BYTE, CC_SEND_AD,
	CC_GET_AD, CC_CLOCK_AD, CC_SYSTEM_TEST,
	CC_GET_DRIVER_OPTIONS, CC_SET_DRIVER_OPTIONS,
	CC_LAST_COMMAND} PAR_COMMAND;

/*

	Return Error Codes

	These are the error codes returned by the driver
	function.  They are prefixed with CE_ to designate
	them as camera errors.

*/
#ifndef CE_ERROR_BASE
#define CE_ERROR_BASE 1
#endif
typedef enum {
	/* 0 - 10 */
	CE_NO_ERROR, CE_CAMERA_NOT_FOUND=CE_ERROR_BASE,
	CE_EXPOSURE_IN_PROGRESS, CE_NO_EXPOSURE_IN_PROGRESS,
	CE_UNKNOWN_COMMAND, CE_BAD_CAMERA_COMMAND, CE_BAD_PARAMETER,
	CE_TX_TIMEOUT, CE_RX_TIMEOUT, CE_NAK_RECEIVED, CE_CAN_RECEIVED,

	/* 11 - 20 */
	CE_UNKNOWN_RESPONSE, CE_BAD_LENGTH,
	CE_AD_TIMEOUT, CE_KBD_ESC, CE_CHECKSUM_ERROR, CE_EEPROM_ERROR,
	CE_SHUTTER_ERROR, CE_UNKNOWN_CAMERA,
	CE_DRIVER_NOT_FOUND, CE_DRIVER_NOT_OPEN,

	/* 21 - 30 */
	CE_DRIVER_NOT_CLOSED, CE_SHARE_ERROR, CE_TCE_NOT_FOUND, CE_AO_ERROR,
	CE_ECP_ERROR, CE_MEMORY_ERROR, CE_DEVICE_NOT_FOUND,
	CE_DEVICE_NOT_OPEN, CE_DEVICE_NOT_CLOSED,
	CE_DEVICE_NOT_IMPLEMENTED,
	
	/* 31 - 40 */
	CE_DEVICE_DISABLED, CE_OS_ERROR, CE_SOCK_ERROR, CE_SERVER_NOT_FOUND,
	CE_NEXT_ERROR  } PAR_ERROR;

/*

	Camera Command State Codes

	These are the return status codes for the Query
	Command Status command.  Theyt are prefixed with
	CS_ to designate them as camera status.

*/
typedef enum { CS_IDLE, CS_IN_PROGRESS, CS_INTEGRATING,
	CS_INTEGRATION_COMPLETE } PAR_COMMAND_STATUS;
#define CS_PULSE_IN_ACTIVE 0x8000
#define CS_WAITING_FOR_TRIGGER 0x8000

/*
	Misc. Enumerated Constants

	ABG_STATE7 - Passed to Start Exposure Command
	MY_LOGICAL - General purpose type
	DRIVER_REQUEST - Used with Get Driver Info command
	CCD_REQUEST - Used with Imaging commands to specify CCD
	CCD_INFO_REQUEST - Used with Get CCD Info Command
	PORT - Used with Establish Link Command
	CAMERA_TYPE - Returned by Establish Link and Get CCD Info commands
	SHUTTER_COMMAND, SHUTTER_STATE7 - Used with Start Exposure
		and Miscellaneous Control Commands
	TEMPERATURE_REGULATION - Used with Enable Temperature Regulation
	LED_STATE - Used with the Miscellaneous Control Command
	FILTER_COMMAND, FILTER_STATE - Used with the Miscellaneous
		Control Command
	AD_SIZE, FILTER_TYPE - Used with the GetCCDInfo3 Command
	AO_FOCUS_COMMAND - Used with the AO Set Focus Command
	SBIG_DEVICE_TYPE - Used with Open Device Command
	DRIVER_CONTROL_PARAMS - Used with Get/SetDriverControl

*/
typedef enum { ABG_LOW7, ABG_CLK_LOW7, ABG_CLK_MED7, ABG_CLK_HI7 } ABG_STATE7;
typedef unsigned short MY_LOGICAL;
#define FALSE 0
#define TRUE 1
typedef enum { DRIVER_STD, DRIVER_EXTENDED } DRIVER_REQUEST;
typedef enum { CCD_IMAGING, CCD_TRACKING } CCD_REQUEST;
typedef enum { CCD_INFO_IMAGING, CCD_INFO_TRACKING,
	CCD_INFO_EXTENDED, CCD_INFO_EXTENDED_5C, CCD_INFO_EXTENDED2_IMAGING,
	CCD_INFO_EXTENDED2_TRACKING } CCD_INFO_REQUEST;
typedef enum { ABG_NOT_PRESENT, ABG_PRESENT } IMAGING_ABG;
typedef enum { BR_AUTO, BR_9600, BR_19K, BR_38K, BR_57K, BR_115K } PORT_RATE;
typedef enum { ST7_CAMERA=4, ST8_CAMERA, ST5C_CAMERA, TCE_CONTROLLER,
  ST237_CAMERA, STK_CAMERA, ST9_CAMERA, STV_CAMERA, ST10_CAMERA,
  ST1K_CAMERA, ST2K_CAMERA, STL_CAMERA, NEXT_CAMERA, NO_CAMERA=0xFFFF } CAMERA_TYPE;
typedef enum { SC_LEAVE_SHUTTER, SC_OPEN_SHUTTER, SC_CLOSE_SHUTTER,
	 SC_INITIALIZE_SHUTTER} SHUTTER_COMMAND;
typedef enum { SS_OPEN, SS_CLOSED, SS_OPENING, SS_CLOSING } SHUTTER_STATE7;
typedef enum { REGULATION_OFF, REGULATION_ON,
	REGULATION_OVERRIDE, REGULATION_FREEZE, REGULATION_UNFREEZE,
	REGULATION_ENABLE_AUTOFREEZE, REGULATION_DISABLE_AUTOFREEZE } TEMPERATURE_REGULATION;
#define REGULATION_FROZEN_MASK 0x8000
typedef enum { LED_OFF, LED_ON, LED_BLINK_LOW, LED_BLINK_HIGH } LED_STATE;
typedef enum { FILTER_LEAVE, FILTER_SET_1, FILTER_SET_2, FILTER_SET_3,
	FILTER_SET_4, FILTER_SET_5, FILTER_STOP, FILTER_INIT } FILTER_COMMAND;
typedef enum { FS_MOVING, FS_AT_1, FS_AT_2, FS_AT_3,
	FS_AT_4, FS_AT_5, FS_UNKNOWN } FILTER_STATE;
typedef enum { AD_UNKNOWN, AD_12_BITS, AD_16_BITS } AD_SIZE;
typedef enum { FW_UNKNOWN, FW_EXTERNAL, FW_VANE, FW_FILTER_WHEEL } FILTER_TYPE;
typedef enum { AOF_HARD_CENTER, AOF_SOFT_CENTER, AOF_STEP_IN,
  AOF_STEP_OUT } AO_FOCUS_COMMAND;
typedef enum { DEV_NONE, DEV_LPT1, DEV_LPT2, DEV_LPT3,
  DEV_USB=0x7F00, DEV_ETH, DEV_USB1, DEV_USB2, DEV_USB3, DEV_USB4 } SBIG_DEVICE_TYPE;
typedef enum { DCP_USB_FIFO_ENABLE, DCP_CALL_JOURNAL_ENABLE,
	DCP_IVTOH_RATIO, DCP_USB_FIFO_SIZE, DCP_USB_DRIVER, DCP_LAST } DRIVER_CONTROL_PARAM;
typedef enum { USB_AD_IMAGING_GAIN, USB_AD_IMAGING_OFFSET, USB_AD_TRACKING_GAIN,
	USB_AD_TRACKING_OFFSET } USB_AD_CONTROL_COMMAND;
typedef enum { USBD_SBIGE, USBD_SBIGI, USBD_SBIGJ, USBD_NEXT } ENUM_USB_DRIVER;


/*

	General Purpose Flags

*/
#define END_SKIP_DELAY 0x8000       /* set in ccd parameter of EndExposure
									   command to skip synchronization
									   delay - Use this to increase the
									   rep rate when taking darks to later
									   be subtracted from SC_LEAVE_SHUTTER
									   exposures such as when tracking and
									   imaging */
#define START_SKIP_VDD	0x8000		/* set in ccd parameter of StartExposure
									   command to skip lowering Imaging CCD
									   Vdd during integration. - Use this to
									   increase the rep rate when you don't
									   care about glow in the upper-left
									   corner of the imaging CCD */
#define EXP_WAIT_FOR_TRIGGER_IN 0x80000000  /* set in exposureTime to wait
											   for trigger in pulse */
#define EXP_SEND_TRIGGER_OUT    0x40000000  /* set in exposureTime to send
											   trigger out Y- */
#define EXP_LIGHT_CLEAR			0x20000000	/* set to do light clear of the
											   CCD (Kaiser only) */
#define EXP_TIME_MASK           0x00FFFFFF  /* mask with exposure time to
											   remove flags */

/*

  Capabilities Bits - Bit Field Definitions for the 
	capabilitiesBits in the GetCCDInfoResults4 struct.

*/
#define CB_CCD_TYPE_MASK			0x0001			/* mask for CCD type */
#define CB_CCD_TYPE_FULL_FRAME		0x0000			/* b0=0 is full frame CCD */
#define CB_CCD_TYPE_FRAME_TRANSFER	0x0001			/* b0=1 is frame transfer CCD */

/*

	Defines

*/
#define MIN_ST7_EXPOSURE    12  /* Minimum exposure is 12/100ths second */

/*

	Command Parameter and Results Structs

	Make sure you set your compiler for byte structure alignment
	as that is how the driver was built.

*/
typedef struct {
	unsigned short /* CCD_REQUEST */ ccd;
	unsigned long exposureTime;
	unsigned short /* ABG_STATE7 */ abgState;
	unsigned short /* SHUTTER_COMMAND */ openShutter;
	} StartExposureParams;

typedef struct {
	unsigned short /* CCD_REQUEST */ ccd;
	} EndExposureParams;

typedef struct {
	unsigned short /* CCD_REQUEST */ ccd;
	unsigned short readoutMode;
	unsigned short pixelStart;
	unsigned short pixelLength;
	} ReadoutLineParams;

typedef struct {
	unsigned short /* CCD_REQUEST */ ccd;
	unsigned short readoutMode;
	unsigned short lineLength;
	} DumpLinesParams;

typedef struct {
	unsigned short /* CCD_REQUEST */ ccd;
	} EndReadoutParams;

typedef struct {
	unsigned short /* CCD_REQUEST */ ccd;
	unsigned short readoutMode;
	unsigned short top;
	unsigned short left;
	unsigned short height;
	unsigned short width;
} StartReadoutParams;

typedef struct {
	unsigned short /* TEMPERATURE_REGULATION */ regulation;
	unsigned short ccdSetpoint;
	} SetTemperatureRegulationParams;

typedef struct {
	MY_LOGICAL enabled;
	unsigned short ccdSetpoint;
	unsigned short power;
	unsigned short ccdThermistor;
	unsigned short ambientThermistor;
	} QueryTemperatureStatusResults;

typedef struct {
	unsigned short tXPlus;
	unsigned short tXMinus;
	unsigned short tYPlus;
	unsigned short tYMinus;
	} ActivateRelayParams;

typedef struct {
	unsigned short numberPulses;
	unsigned short pulseWidth;
	unsigned short pulsePeriod;
	} PulseOutParams;

typedef struct {
	unsigned short dataLength;
	unsigned char data[256];
	} TXSerialBytesParams;

typedef struct {
	unsigned short bytesSent;
	} TXSerialBytesResults;

typedef struct {
	MY_LOGICAL clearToCOM;
	} GetSerialStatusResults;

typedef struct {
	unsigned short sbigUseOnly;
	} EstablishLinkParams;

typedef struct {
	unsigned short /* CAMERA_TYPE */ cameraType;
	} EstablishLinkResults;

typedef struct {
	unsigned short /* DRIVER_REQUEST */ request;
	} GetDriverInfoParams;
typedef struct {
	unsigned short version;
	char name[64];
	unsigned short maxRequest;
	} GetDriverInfoResults0;

typedef struct {
	unsigned short /* CCD_INFO_REQUEST */ request;
	} GetCCDInfoParams;
typedef struct {
	unsigned short mode;
	unsigned short width;
	unsigned short height;
	unsigned short gain;
	unsigned long pixel_width;
	unsigned long pixel_height;
	} READOUT_INFO;
typedef struct {
	unsigned short firmwareVersion;
	unsigned short /* CAMERA_TYPE */ cameraType;
	char name[64];
	unsigned short readoutModes;
	struct {
		unsigned short mode;
		unsigned short width;
		unsigned short height;
		unsigned short gain;
		unsigned long pixelWidth;
		unsigned long pixelHeight;
		} readoutInfo[20];
	} GetCCDInfoResults0;
typedef struct {
	unsigned short badColumns;
	unsigned short columns[4];
	unsigned short /* IMAGING_ABG */ imagingABG;
	char serialNumber[10];
	} GetCCDInfoResults2;
typedef struct {
	unsigned short /* AD_SIZE */ adSize;
	unsigned short /* FILTER_TYPE */ filterType;
	} GetCCDInfoResults3;
typedef struct {
	unsigned short capabilitiesBits;
	unsigned short dumpExtra;
} GetCCDInfoResults4;
typedef struct {
	unsigned short command;
	} QueryCommandStatusParams;
typedef struct {
	unsigned short status;
	} QueryCommandStatusResults;

typedef struct {
	MY_LOGICAL fanEnable;
	unsigned short /* SHUTTER_COMMAND */ shutterCommand;
	unsigned short /* LED_STATE */ ledState;
	} MiscellaneousControlParams;

typedef struct {
	unsigned short /* CCD_REQUEST */ ccd;
	} ReadOffsetParams;

typedef struct {
	unsigned short offset;
	} ReadOffsetResults;

typedef struct {
	unsigned short xDeflection;
	unsigned short yDeflection;
	} AOTipTiltParams;

typedef struct {
	unsigned short /* AO_FOCUS_COMMAND */ focusCommand;
	} AOSetFocusParams;

typedef struct {
	unsigned long delay;
    } AODelayParams;

typedef struct {
	MY_LOGICAL turboDetected;
    } GetTurboStatusResults;

typedef struct {
	unsigned short	deviceType;		/* SBIG_DEVICE_TYPE, specifies LPT, Ethernet, etc */
	unsigned short	lptBaseAddress;	/* DEV_LPTN: Windows 9x Only, Win NT uses deviceSelect */
	unsigned long	ipAddress;		/* DEV_ETH:  Ethernet address */
	} OpenDeviceParams;

typedef struct {
	unsigned short level;
	} SetIRQLParams;

typedef struct {
	unsigned short level;
	} GetIRQLResults;

typedef struct {
	MY_LOGICAL	linkEstablished;
	unsigned short baseAddress;
	unsigned short /* CAMERA_TYPE */ cameraType;
    unsigned long comTotal;
    unsigned long comFailed;
    } GetLinkStatusResults;

typedef struct {
	unsigned long count;
	} GetUSTimerResults;

typedef struct {
	unsigned short port;
	unsigned short length;
	unsigned char *source;
	} SendBlockParams;

typedef struct {
	unsigned short port;
	unsigned short data;
	} SendByteParams;

typedef struct {
	unsigned short /* CCD_REQUEST */ ccd;
	unsigned short readoutMode;
	unsigned short pixelStart;
	unsigned short pixelLength;
    } ClockADParams;

typedef struct {
	unsigned short testClocks;
	unsigned short testMotor;
    unsigned short test5800;
	} SystemTestParams;

typedef struct {
    unsigned short outLength;
    unsigned char *outPtr;
    unsigned short inLength;
    unsigned char *inPtr;
	} SendSTVBlockParams;

typedef struct {
	unsigned short errorNo;
	} GetErrorStringParams;

typedef struct {
	char errorString[64];
	} GetErrorStringResults;

typedef struct {
	short handle;
	} SetDriverHandleParams;

typedef struct {
	short handle;
	} GetDriverHandleResults;

typedef struct {
	unsigned short /* DRIVER_CONTROL_PARAM */ controlParameter;
	unsigned long controlValue;
} SetDriverControlParams; 

typedef struct {
	unsigned short /* DRIVER_CONTROL_PARAM */ controlParameter;
} GetDriverControlParams; 

typedef struct {
	unsigned long controlValue;
} GetDriverControlResults;

typedef struct {
	unsigned short /* USB_AD_CONTROL_COMMAND */ command;
	short data;
} USBADControlParams;

typedef struct {
	MY_LOGICAL cameraFound;
	unsigned short /* CAMERA_TYPE */ cameraType;
	char name[64];
	char serialNumber[10];
} QUERY_USB_INFO;

typedef struct {
	unsigned short camerasFound;
	QUERY_USB_INFO usbInfo[4];
} QueryUSBResults;

typedef struct {
	unsigned long countLow;
	unsigned long countHigh;
} GetPentiumCycleCountResults;

typedef struct {
	unsigned char address;
	unsigned char data;
	MY_LOGICAL write;
	unsigned char deviceAddress;
	} RWUSBI2CParams;
typedef struct {
	unsigned char data;
	} RWUSBI2CResults;
	

/*

	Function Prototypes

	This are the driver interface functions.

    SBIGUnivDrvCommand() - Supports ST-7/8/9/10, ST-5C/237, PixCel255/237
    					   ST-1K and AO-7
    TCEDrvCommand() - Supports the TCE-1
    STVDrvCommand() - Supports the STV

	Each function takes a command parameter and pointers
	to parameters and results structs.

	The calling program needs to allocate the memory for
	the parameters and results structs and these routines
	read them and fill them in respectively.

*/
#if TARGET == ENV_DOS
  #ifdef __cplusplus
	extern "C" short SBIGUnivDrvCommand(short command, void*Params, void*Results);
  #else
	extern short SBIGUnivDrvCommand(short command, void*Params, void*Results);
  #endif
#elif TARGET == ENV_WIN
  #ifdef __cplusplus
	extern "C" short __stdcall SBIGUnivDrvCommand(short command, void*Params, void*Results);
  #else
	extern short __stdcall SBIGUnivDrvCommand(short command, void*Params, void*Results);
  #endif
#endif

#endif
