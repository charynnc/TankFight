TITLE Windows Application                   (WinApp_v2.asm)

; Another version of WinApp.asm
; Modified by: HenryFox
; Last update: 10/13/21
; Original version uses Irvine32 and GraphWin, this version uses windows.inc

; This program displays a resizable application window and
; several popup message boxes.
; Thanks to Tom Joyce for creating a prototype
; from which this program was derived.

.386
.model flat, stdcall
option casemap: none

include         windows.inc
include         gdi32.inc
includelib      gdi32.lib
include         user32.inc
includelib      user32.lib
include         kernel32.inc
includelib      kernel32.lib
include         masm32.inc
includelib      masm32.lib
include         msvcrt.inc
includelib      msvcrt.lib
include         shell32.inc
includelib      shell32.lib
include			fpu.inc
includelib		fpu.lib

printf          PROTO C :ptr sbyte, :VARARG

;------------------ Structures ----------------

WNDCLASS STRUC
  style           DWORD ?
  lpfnWndProc     DWORD ?
  cbClsExtra      DWORD ?
  cbWndExtra      DWORD ?
  hInstance       DWORD ?
  hIcon           DWORD ?
  hCursor         DWORD ?
  hbrBackground   DWORD ?
  lpszMenuName    DWORD ?
  lpszClassName   DWORD ?
WNDCLASS ENDS

MSGStruct STRUCT
  msgWnd        DWORD ?
  msgMessage    DWORD ?
  msgWparam     DWORD ?
  msgLparam     DWORD ?
  msgTime       DWORD ?
  msgPt         POINT <>
MSGStruct ENDS

;坦克结构体
tank STRUCT
	image		DWORD ?
	posX		DWORD ?
	posY		DWORD ?
	direction	DWORD ?
	status		DWORD ?
	speed		DWORD ?
tank ENDS

; 子弹结构体
bullet STRUCT
	image		DWORD ?
	posX		DWORD ?
	posY		DWORD ?
	direction	DWORD ?
	speed		DWORD ?
bullet ENDS

MAIN_WINDOW_STYLE = WS_VISIBLE+WS_DLGFRAME+WS_CAPTION+WS_BORDER+WS_SYSMENU \
	+WS_MAXIMIZEBOX+WS_MINIMIZEBOX+WS_THICKFRAME

;==================== DATA =======================
.data 

AppLoadMsgTitle BYTE "Application Loaded",0
AppLoadMsgText  BYTE "This window displays when the WM_CREATE "
	            BYTE "message is received",0

PopupTitle BYTE "Popup Window",0
PopupText  BYTE "This window was activated by a "
	       BYTE "WM_LBUTTONDOWN message",0

GreetTitle BYTE "Main Window Active",0
GreetText  BYTE "This window is shown immediately after "
	       BYTE "CreateWindow and UpdateWindow are called.",0

CloseMsg   BYTE "WM_CLOSE message received",0

ErrorTitle  BYTE "Error",0
WindowName  BYTE "ASM Windows App",0
className   BYTE "ASMWin",0

msg	      MSGStruct <>
winRect   RECT <>
hMainWnd  DWORD ?
hInstance DWORD ?

bulletImage DWORD ?
bulletArray DWORD 50 DUP(?)
bulletNum DWORD 0
ansMsg			byte    "%d   " 
; 定义定时器 ID
TIMER_ID EQU 1

; Define the Application's Window class structure.
MainWin WNDCLASS <NULL,WinProc,NULL,NULL,NULL,NULL,NULL, \
	COLOR_WINDOW,NULL,className>

RedTank tank <NULL,100,100,0,1,10>

;RedTank TANKstruct<IDI_ICON1,point<200,200>,0,1>

;=================== CODE =========================
.code
; 定义函数参数
; icon - 图标（以 DWORD 形式存储）
; angle - 旋转角度（以度为单位）
; 返回值 - 旋转后的图标（以 DWORD 形式存储）

WinMain PROC
	IDI_ICON1 = 101
	IDI_ICON2 = 102

; Get a handle to the current process.
	INVOKE GetModuleHandle, NULL
	mov hInstance, eax
	mov MainWin.hInstance, eax

; Load the program's icon and cursor.
	INVOKE LoadIcon, NULL, IDI_APPLICATION
	mov MainWin.hIcon, eax
	INVOKE LoadCursor, NULL, IDC_ARROW
	mov MainWin.hCursor, eax
	; 加载icon
	INVOKE LoadIcon, hInstance, IDI_ICON1
	mov RedTank.image, eax
	INVOKE LoadIcon, hInstance, IDI_ICON2
	mov bulletImage, eax

; Register the window class.
	INVOKE RegisterClass, ADDR MainWin
	.IF eax == 0
	  call ErrorHandler
	  jmp Exit_Program
	.ENDIF

; Create the application's main window.
; Returns a handle to the main window in EAX.
	INVOKE CreateWindowEx, 0, ADDR className,
	  ADDR WindowName,MAIN_WINDOW_STYLE,
	  CW_USEDEFAULT,CW_USEDEFAULT,CW_USEDEFAULT,
	  CW_USEDEFAULT,NULL,NULL,hInstance,NULL
	mov hMainWnd,eax

; If CreateWindowEx failed, display a message & exit.
	.IF eax == 0
	  call ErrorHandler
	  jmp  Exit_Program
	.ENDIF

; Show and draw the window.
	INVOKE ShowWindow, hMainWnd, SW_SHOW
	INVOKE UpdateWindow, hMainWnd

	; 在窗口创建时创建定时器
	invoke SetTimer, hMainWnd, TIMER_ID, 100, NULL

; Display a greeting message.
	INVOKE MessageBox, hMainWnd, ADDR GreetText,
	  ADDR GreetTitle, MB_OK

; Begin the program's message-handling loop.
Message_Loop:
	; Get next message from the queue.
	INVOKE GetMessage, ADDR msg, NULL,NULL,NULL

	; Quit if no more messages.
	.IF eax == 0
	  jmp Exit_Program
	.ENDIF

	; Relay the message to the program's WinProc.
	INVOKE DispatchMessage, ADDR msg
    jmp Message_Loop

Exit_Program:
	  INVOKE ExitProcess,0
WinMain ENDP

;-----------------------------------------------------
WinProc PROC,
	hWnd:DWORD, localMsg:DWORD, wParam:DWORD, lParam:DWORD
; The application's message handler, which handles
; application-specific messages. All other messages
; are forwarded to the default Windows message
; handler.
;-----------------------------------------------------
	
	local ps:PAINTSTRUCT
	local deltaX:DWORD
	local deltaY:DWORD
	local i:DWORD
	local tempImage:DWORD

	mov eax, localMsg

	.IF eax == WM_LBUTTONDOWN		; mouse button?
	  INVOKE MessageBox, hWnd, ADDR PopupText,
	    ADDR PopupTitle, MB_OK
	  jmp WinProcExit
	.ELSEIF eax == WM_CREATE		; create window?
	  INVOKE MessageBox, hWnd, ADDR AppLoadMsgText,
	    ADDR AppLoadMsgTitle, MB_OK

	  jmp WinProcExit
	.ELSEIF eax == WM_CLOSE		; close window?
	  INVOKE MessageBox, hWnd, ADDR CloseMsg,
	    ADDR WindowName, MB_OK
	  INVOKE PostQuitMessage,0
	  jmp WinProcExit

	.ELSEIF eax == WM_PAINT
		INVOKE BeginPaint, hWnd, ADDR ps
		;invoke rotate, RedTank.image, 45
		;mov tempImage, eax
		INVOKE DrawIconEx, ps.hdc, RedTank.posX, RedTank.posY, RedTank.image, 32, 32, 0, NULL, DI_NORMAL
		
		mov ecx, bulletNum  ; 获取已实例化的 bullet 对象的数量
		mov i, ecx
	    mov esi, OFFSET bulletArray  ; 获取指向 bulletArray 数组的指针
		whileloop:
			cmp i, 0  ; 检查是否还有未遍历的 bullet 对象
			je endwhileloop  ; 如果没有，则跳出循环
			;invoke printf, offset ansMsg, esi
			INVOKE DrawIconEx, ps.hdc, DWORD PTR [esi+4], DWORD PTR [esi+8], bulletImage, 16, 16, 0, NULL, DI_NORMAL
			add esi, TYPE bullet  ; 移动指向下一个 bullet 对象的指针
			dec i  ; 减少未遍历的 bullet 对象的数量
			jmp whileloop  ; 跳转到循环的开头
		endwhileloop:

		INVOKE EndPaint, hWnd, ADDR ps
		jmp WinProcExit
	
	; 响应键盘按下事件
	.ELSEIF eax == WM_KEYDOWN
        .IF wParam == VK_UP
		  ;INVOKE sin, RedTank.direction
		  ;mov deltaY, eax
		  ;INVOKE cos, RedTank.direction
		  ;mov deltaX, eax
		  ;imul deltaY, RedTank.speed 
		  ;imul deltaX, RedTank.speed
		  add RedTank.posX, 5
		  ;sub RedTank.posY, deltaY
		  INVOKE InvalidateRect, hWnd, NULL, TRUE
          INVOKE UpdateWindow, hWnd
          jmp WinProcExit
		.ELSEIF wParam == VK_DOWN
		  sub RedTank.posX, 5
		  ;sub RedTank.posY, deltaY
		  INVOKE InvalidateRect, hWnd, NULL, TRUE
          INVOKE UpdateWindow, hWnd
          jmp WinProcExit
		.ELSEIF wParam == VK_LEFT
		  add RedTank.direction, 5
		  INVOKE InvalidateRect, hWnd, NULL, TRUE
          INVOKE UpdateWindow, hWnd
          jmp WinProcExit
		.ELSEIF wParam == VK_RIGHT
		  sub RedTank.direction, 5
		  INVOKE InvalidateRect, hWnd, NULL, TRUE
          INVOKE UpdateWindow, hWnd
          jmp WinProcExit
		.ELSEIF wParam == VK_SPACE
			mov eax, bulletNum  ; 获取当前可用的数组索引
			imul eax, TYPE bullet
			mov ebx, OFFSET bulletArray  ; 获取指向 bullet 对象的指针
			add ebx, eax
			inc bulletNum
			mov ecx, RedTank.posX
			add ecx, 48
			mov edx, RedTank.posY
			add edx, 8
			mov DWORD PTR [ebx], 1  ; 设置 image 的值
			mov DWORD PTR [ebx + 4], ecx  ; 设置 posX 的值
			mov DWORD PTR [ebx + 8], edx  ; 设置 posY 的值
			mov DWORD PTR [ebx + 12], 0  ; 设置 direction 的值
			mov DWORD PTR [ebx + 16], 1  ; 设置 speed 的值
			;invoke printf, offset ansMsg, ebx

		  INVOKE InvalidateRect, hWnd, NULL, TRUE
          INVOKE UpdateWindow, hWnd
          jmp WinProcExit
        .ENDIF
	; 响应计时器事件
	.ELSEIF eax == WM_TIMER
		mov ecx, bulletNum  ; 获取已实例化的 bullet 对象的数量
		mov i, ecx
	    mov esi, OFFSET bulletArray  ; 获取指向 bulletArray 数组的指针
		moveloop:
			cmp i, 0  ; 检查是否还有未遍历的 bullet 对象
			je endmoveloop  ; 如果没有，则跳出循环
			add DWORD PTR [esi+4], 10
			add esi, TYPE bullet  ; 移动指向下一个 bullet 对象的指针
			dec i  ; 减少未遍历的 bullet 对象的数量
			jmp moveloop  ; 跳转到循环的开头
		endmoveloop:
		INVOKE InvalidateRect, hWnd, NULL, TRUE
        INVOKE UpdateWindow, hWnd
		jmp WinProcExit

	.ELSE		; other message?
	  INVOKE DefWindowProc, hWnd, localMsg, wParam, lParam
	  jmp WinProcExit
	.ENDIF

WinProcExit:
	ret
WinProc ENDP

;---------------------------------------------------
ErrorHandler PROC
; Display the appropriate system error message.
;---------------------------------------------------
.data
pErrorMsg  DWORD ?		; ptr to error message
messageID  DWORD ?
.code
	INVOKE GetLastError	; Returns message ID in EAX
	mov messageID,eax

	; Get the corresponding message string.
	INVOKE FormatMessage, FORMAT_MESSAGE_ALLOCATE_BUFFER + \
	  FORMAT_MESSAGE_FROM_SYSTEM,NULL,messageID,NULL,
	  ADDR pErrorMsg,NULL,NULL

	; Display the error message.
	INVOKE MessageBox,NULL, pErrorMsg, ADDR ErrorTitle,
	  MB_ICONERROR+MB_OK

	; Free the error message string.
	INVOKE LocalFree, pErrorMsg
	ret
ErrorHandler ENDP

END WinMain