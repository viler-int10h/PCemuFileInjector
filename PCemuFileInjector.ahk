#SingleInstance force
#Persistent
#NoTrayIcon ; for EXE

selfWinTitle :="File Injector for PCem/86Box (v0.1)"
Gui, New,  , %selfWinTitle%

; File select button

Gui, Font, S8 CDefault, MS Sans Serif
Gui, Font, S8 CDefault, Segoe UI
Gui, Add, Button, vFileSelectButton gSelectFiles x12 y13 w162 h30 , Select file(s) to copy...

; List Box + debug output (CUSTOM font) 

FileList := "Or drop file(s) here"
Gui, Font, S9 CDefault, Courier New
Gui, Font, S9 CDefault, Consolas
Gui, Font, S9 CDefault, Andale Mono
Gui, Font, S9 CDefault, IBM Plex Mono
Gui, Font, S9 CDefault, Fira Mono
Gui, Add, ListBox, vFileListbox x12 y53 w162 h226 +0x4000 -0x200000 -Background, %FileList%  ; +NoSelect, -ScrollBar

DebugOutput := ""
Gui, Add, Edit, vDebugBox x12 y280 h164 w416 +Hidden +ReadOnly -Wrap +HScroll, %DebugOutput%

; Disk image

Gui, Font, S8 CDefault, MS Sans Serif
Gui, Font, S8 CDefault, Segoe UI
Gui, Add, GroupBox, x185 y11 w142 h128 , Temporary disk image
Gui, Add, Radio, Group vrImgSize x195 y29 w60 h16 +Checked, 360 KB
Gui, Add, Radio,                 x195 y45 w60 h16         , 720 KB
Gui, Add, Radio,                 x195 y61 w60 h16         , 1200 KB
Gui, Add, Radio,                 x195 y77 w60 h16         , 1440 KB
Gui, Add, Radio,                 x195 y93 w60 h16         , 2880 KB
;Gui, Add, Text, x197 y101 w110 h30 , (Size must match the emulated drive type!)
Gui, Add, Text, x192 y114 w130 h16 , (Must match guest drive)

; Emulator

Gui, Add, GroupBox, x337 y11 w90  h60 , Emulator
Gui, Add, Radio, Group vrEmu x347 y29 w76 h16 +Checked, PCem v15
Gui, Add, Radio,             x347 y45 w76 h16         , 86Box v2.x

; Mount as (guest)

Gui, Add, GroupBox, x337 y79 w90  h60 , Mount as
Gui, Add, Radio, Group vrEmuDrive  x347 y97 w68 h16 +Checked, Drive A:
Gui, Add, Radio,                   x347 y113 w68 h16         , Drive B:

; Post-mount action select

Gui, Add, GroupBox, x185 y147 w244 h80 , After mounting
Gui, Add, Radio, Group vrDosAction x195 y167 w100 h16         , Do nothing
Gui, Add, Radio,                   x195 y183 w220 h16 +Checked, COPY files to current directory (DOS)
Gui, Add, Radio,                   x195 y199 w220 h16         , XCOPY files to current directory (DOS)

; Action section

Gui, Add, Checkbox, vDebug    gSetDebugBox x185 y238 w90 h30           , Debug output
Gui, Add, Button,   vGoButton gDoIt        x285 y238 w144 h30 +Disabled, Inject file(s)

; SET UP SOME VARIABLES

Separator = `n---------------------`n
SetTitleMatchMode, 1                     ; Window title matching: must *start* with WinTitle
EnvGet, tempFolder, TMP                  ; Resolve location of %TMP% directory
VirtualDrive := ""
FileArray := []
ListLen := 15

For each, Letter in StrSplit("ABCDEFGHIJKLMNOPQRSTUVWXYZ") {
	DriveGet, driveList, List
	if not InStr(driveList, Letter)  {   ; choose the first invalid drive
	  VirtualDrive := Letter . ":"
	  break
	}	
}
if (SubStr(VirtualDrive, StrLen(VirtualDrive), 1)!=":") {
	MsgBox, 16, Error, Could not find a free drive letter on the host!
	ExitApp
}	 

; Show dialog (dimensions depend on debug box status)

Gosub SetDebugBox
Return

; Exit

GuiEscape:
GuiClose:
    ;MsgBox, % FileArray.MaxIndex()
    ExitApp
    Return

;-----------------------------------------------------------------------------
; ################################# SUBROUTINES ##############################
;-----------------------------------------------------------------------------

;++++++++++++++++++++++++++++++++++++++++
DoIt:   ; Action button

	Gui, Submit, NoHide                    ; Make the control variables count
	GuiControl, Disable, GoButton          ; Disable go button
	GuiControl, Disable, Debug             ; and debug checkbox
	SetKeyDelay, -1,40                     ; for guest interaction, otherwise keystrokes are missed

  ;Create command lines / vars
  
	emuWinPrefix := (rEmu == 1 ? "PCem v" : "86Box v")
  emuDrive := (rEmuDrive == 1 ? "A:" : "B:")
  tempImage := tempFolder .  "\____INJ" . rEmu . "-" . rEmuDrive . ".TMP.IMA"
	cmdLineMount    := "imdisk -a -t file -m " . VirtualDrive . " -o rem -f """ . tempImage . """ -p ""/fs:FAT /y /q"" -s "
	cmdLineList     := "imdisk -l -m " . VirtualDrive
	cmdLineUnmount  := "imdisk -d -m " . VirtualDrive
	cmdLineForceOut := "imdisk -D -m " . VirtualDrive
	switch rImgSize {
		case 1: cmdLineMount .= "360K"
		case 2:	cmdLineMount .= "720K"
		case 3:	cmdLineMount .= "1200K"
		case 4:	cmdLineMount .= "1440K"
		case 5:	cmdLineMount .= "2880K"
	}

  ;Find emulated machine window

	if !WinExist(emuWinPrefix) {
		errAbort("Cannot find active emulator window")
		Return
	}
	WinGetTitle, emuWinTitle           ; Get title of "Last Found" window from WinExist invocation
	WinGet, emuPID, PID,               ; Get process ID too for later comparison
	WinGet, emuHWND, ID,               ; And the window handle (only used for 86box)

  ;Log emu window findings + virtual drive info
  
  tempDebugOutput := ""
  if (Debug) {
		tempDebugOutput = EMULATOR: Window title = "%emuWinTitle%"`nEMULATOR: PID=%emuPID%, HWND=%emuHWND%`n
		GuiControl, Text, DebugBox, %tempDebugOutput%
		tempDebugOutput .= "EMULATOR: Ejecting drive " . emuDrive . "`nHOST: Temporary drive letter for virtual disk = " . VirtualDrive . "`n"
	}
	GuiControl, Text, DebugBox, %tempDebugOutput%

  ;Step 0: Eject emulated drive
  
  GuiControl, Text, GoButton, Guest: Ejecting...	
 	Sleep 50
  if (rEmu=1) ;PCem
  	switch rEmuDrive {
  		case 1: 	WinMenuSelectItem, %emuWinPrefix%, , 2&, 3& ; Eject drive A
  		case 2: 	WinMenuSelectItem, %emuWinPrefix%, , 2&, 4& ; Eject drive B
		}
	else { ;86box
		GetClientSize(emuHWND, emuWinW, emuWinH)
		WinActivate, ahk_id %emuHWND% ; activate 86box window
		CoordMode, Mouse, Client      ; make mouse commands relative to client size
		MouseGetPos, origX, origY     ; backup mouse position
		Send {Pause}                  ; FREEZE INPUT
		Sleep 100
		MouseClick, , (rEmuDrive == 1 ? 11 : 36), emuWinH-11  ; Icon X-pos for A:=11, B:=36
		Send {J}                      ; "eJect" menu option
		Send {BS}{BS}{BS}{Pause}      ; UNFREEZE INPUT
		MouseMove, origX, origY       ; restore mouse position
		WinActivate, %selfWinTitle%   ; back to ourselves
	}

  ;Step 1: create + attach image w/IMDISK
  
  exitCode:=0
	GuiControl, Text, GoButton, Host: Attaching image...	
	if (Debug) {
		gotError:=0
		;ImDisk: create/mount image
		tempDebugOutput = %tempDebugOutput%%Separator%HOST: ATTACHING TEMPORARY IMAGE`n> %cmdLineMount%`n`n
		GuiControl, Text, DebugBox, %tempDebugOutput%
		tempDebugOutput .= RunWaitLogged(cmdLineMount)
		tempDebugOutput := StrReplace(tempDebugOutput, "Error undefining temporary drive letter: Access is denied. `r`n") ; Ignore false error
		GuiControl, Text, DebugBox, %tempDebugOutput%
		gotError:=exitCode
		;ImDisk: get image info - debug only
		tempDebugOutput = %tempDebugOutput%%Separator%HOST: TEMPORARY IMAGE INFORMATION`n> %cmdLineList%`n`n
		tempDebugOutput .= RunWaitLogged(cmdLineList)
		GuiControl, Text, DebugBox, %tempDebugOutput%
		if gotError {
			Gosub justAbort
			Return
		}
	}
	else {
		RunWait, %cmdLineMount%, , Hide UseErrorLevel
		if (A_LastError=2) {  ; System error code (https://docs.microsoft.com/en-us/windows/win32/debug/system-error-codes--0-499-)
			errAbort("ImDisk Virtual Disk Driver not installed,`nor not in PATH")
			Return
		} else if (ErrorLevel) { ; ImDisk exit code
			errAbort("Image creation error`n(enable debug output for more information)")
			Return
		}
	}
	
	;Step 2: copy files
	
	GuiControl, Text, GoButton, Host: Copying files...
	Sleep 50
	errCount := 0
 	Needle := "[^\\]+$"  ; for directories: match all characters that are not a "\" starting from the end of the haystack
 	if (Debug)
 		tempDebugOutput = %tempDebugOutput%%Separator%HOST: COPYING FILES/FOLDERS TO TEMPORARY IMAGE`n
	for i, file in FileArray {
		FileGetAttrib, Attrs, %file%
	  if InStr(Attrs, "D") {
			RegExMatch(file, Needle, strippedDir) ; strip everything before the last backslash
	  	FileCopyDir, %file%, %VirtualDrive%\%strippedDir%
	  } else
	  	FileCopy, %file%, %VirtualDrive%\
	  errCount += ErrorLevel
		if (Debug) {
			tempDebugOutput := tempDebugOutput . file . " ... " . (ErrorLevel ? "ERROR" : "OK") . "`n"
			GuiControl, Text, DebugBox, %tempDebugOutput%
		}	  
	}
	if (!Debug && errCount) {
		MsgBox, 48, Warning, %errCount% files/folders could not be copied - insufficient disk image space?`n(try debug output for more information)
		;Do not abort - we have to unmount!
	}
	
	;Step 3: Detach image w/IMDISK
	
	exitCode:=0
	Sleep 300
  GuiControl, Text, GoButton, Host: Detaching image...
	tempDebugOutput = %tempDebugOutput%%Separator%HOST: DETACHING TEMPORARY IMAGE`n> %cmdLineUnmount%`n`n
	tempDebugOutput .= RunWaitLogged(cmdLineUnmount)
	if (exitCode)
		; TRY AGAIN 5 times
		Loop, 5 {
			Sleep, 250
			tempDebugOutput .= "`nTRYING AGAIN (#" . A_Index . "):`n" . RunWaitLogged(cmdLineUnmount)
			if (!exitCode)
				Break
		}
	if (exitCode) {
		; STILL HAVING ISSUES? FORCE IT
		Sleep 1000
		GuiControl, Text, GoButton, Host: Force-detaching...
		tempDebugOutput = %tempDebugOutput%%Separator%HOST: FORCE-DETACHING TEMPORARY IMAGE`n> %cmdLineForceOut%`n`n
		tempDebugOutput .= RunWaitLogged(cmdLineForceOut)
	}
	if (Debug)
		GuiControl, Text, DebugBox, %tempDebugOutput%
	if (!Debug && exitCode) {
		errAbort("Could not unmount temporary image`n(enable debug output for more information)")
		Return
	}
	if errCount {  ;Had any trouble copying files? - abort now
		Gosub justAbort
		Return
	}

  ;Step 4: Mount image in emulated drive
  
  WinActivate, %selfWinTitle%    ; activate script window, for looped check
  activeWinTitle := selfWinTitle 
  
	if (Debug) {
		tempDebugOutput = %tempDebugOutput%%Separator%EMULATOR: Mounting image as %emuDrive%`n
		GuiControl, Text, DebugBox, %tempDebugOutput%
	}
  GuiControl, Text, GoButton, Guest: Mounting...	
  ; ---- PCem -----
  if (rEmu=1) {
  	switch rEmuDrive {
  		case 1: 	WinMenuSelectItem, %emuWinPrefix%, , 2&, 1& ; Change drive A
  		case 2: 	WinMenuSelectItem, %emuWinPrefix%, , 2&, 2& ; Change drive B
		}
		While (activeWinTitle = selfWinTitle) {  ; wait for file open dialog to activate
			Sleep 10
			WinGetActiveTitle, activeWinTitle
		}
	}
	; ---- 86box -----
	else {
		GetClientSize(emuHWND, emuWinW, emuWinH)
		WinActivate, ahk_id %emuHWND% ; activate 86box window
		CoordMode, Mouse, Client      ; make mouse commands relative to client size
		MouseGetPos, origX, origY     ; backup mouse position
		Send {Pause}                  ; FREEZE INPUT
		Sleep 100
		WinGetActiveTitle, tmpWT      ; Get window title for check loop
		actWT:=tmpWT
		MouseClick, , (rEmuDrive == 1 ? 11 : 36), emuWinH-11  ; Icon X-pos for A:=11, B:=36
		Send {E}                      ; "Existing image" menu option
		While (actWT = tmpWT) {       ; wait for file open dialog to activate
			Sleep 10
			WinGetActiveTitle, actWT
		}
	}  
  ; --- Common (we should be in open file dialog now) ---
	activeWinPID:=0
	Loop, 40 {
		WinGet, activeWinPID, PID, A ; get process ID of (hopefully) file open dialog	
		if (activeWinPID = emuPID)   ; compare it to the emu PID we saved before
			Break
		Sleep, 50
	}
  if (activeWinPID != emuPID) {  ; still no go? something's wrong
  	errAbort("Process interrupted")
  	Return
	}			

	Control, EditPaste, %tempImage%, Edit1, A
	Send {Enter}                   ; try to open our temporary image
	Sleep 100                      ; ensures ENTER keystroke is sent
	if (rEmu=2) { ;86box again
		Send {BS}{BS}{BS}{Pause}     ; UNFREEZE INPUT
		MouseMove, origX, origY      ; restore mouse position
	}
	
	;Step 5: Copy files in emulator
	
	switch rDosAction {
		case 1: ; Do Nothing
			Gosub justAbortSuccess
			Return
		case 2: ; COPY
			dosCmd := "copy " . emuDrive . "`\*.* /y"
		case 3: ; XCOPY
			dosCmd := "xcopy " . emuDrive . "`\*.* . /e /y" 
		default:
	}

	if (Debug) {
		tempDebugOutput = %tempDebugOutput%EMULATOR: Running command "%dosCmd%"`n
		GuiControl, Text, DebugBox, %tempDebugOutput%
	}
	GuiControl, Text, GoButton, Guest: Copying...	
	WinActivate, ahk_pid %emuPID%
	Sleep 100                      ; same here
	Send %dosCmd%{Enter}
	
;Done? - finish up

justAbortSuccess:
	if (Debug) {
		tempDebugOutput = %tempDebugOutput%DONE!
		GuiControl, Text, DebugBox, %tempDebugOutput%
	}
justAbort:
	GuiControl, Enable, Debug
	GuiControl, Enable, GoButton
	GuiControl, Text, GoButton, Inject file(s)
	Return

;++++++++++++++++++++++++++++++++++++++++
errAbort(msg)   ; un-DoIt
{
	MsgBox, 16, Error, %msg%
	GuiControl, Enable, Debug	
	GuiControl, Enable, GoButton
	GuiControl, Text, GoButton, Inject file(s)
}

;++++++++++++++++++++++++++++++++++++++++
SetDebugBox:   ; Show/hide debug box
	
	Gui, Submit, NoHide
	if (Debug) {
		GuiControl, Show, DebugBox
		Gui, Show, h452 w440,
	}
	else {
		GuiControl, Hide, DebugBox
		Gui, Show, h280 w440,
	}
	Return

;++++++++++++++++++++++++++++++++++++++++
GuiDropFiles(GuiHwnd, TempArray, CtrlHwnd, X, Y)    ; File drop event handler
{
	global                                 ; allow global access
	FileArray := []                        ; clear global array
	FileList  := ""                        ; ...and file list too
	sortArray(TempArray)
	for i, file in TempArray {
		FileArray.Push(file)
		if (i<ListLen) or (TempArray.MaxIndex()=ListLen) {
		  SplitPath file, , , ext, name
		  StringUpper, name, name
		  StringUpper, ext, ext
		  FileGetAttrib, Attrs, %file%
		  if InStr(Attrs, "D")
		     SingleSize := "<DIR>"
		  else           
		     FileGetSize, SingleSize, %file%
		  if StrLen(name) > 8
		  	FileList .= Format("{:-6}",SubStr(name, 1, 6)) "..."
		  else
		    FileList .= Format("{:-8}",SubStr(name, 1, 8)) " "
		  FileList .= Format("{:-3}",SubStr(ext, 1, 3))
		  FileList .= Format("{: 10}",SingleSize) "|"
		}
	}
	Sort, FileList, CL D|                  ; sort with "|" as delimiter
	if TempArray.MaxIndex() > ListLen
	   FileList .= "|[ +" FileArray.Length()-(ListLen-1) " more ]"
	GuiControl, Text, FileListbox, |%FileList%   
	GuiControl, Enable, GoButton
}

;++++++++++++++++++++++++++++++++++++++++
SelectFiles:     ; File selector button

	FileSelectFile, SelFiles, M, , Select file(s) to copy
	if (SelFiles = "")
    Return
	TempArray := []                        ; create new temp array
	FileArray := []                        ; clear global array
	FileList  := ""                        ; ...and file list too
	dir := ""
	file := ""
	Loop, parse, SelFiles, `n
	{
		if (A_Index = 1) {
			dir := A_LoopField
			if (SubStr(dir, StrLen(A_LoopField), 1)!="\") ; doesn't end with backslash?
				dir .= "\"
		}
		else
		{
			file := dir . A_LoopField
			TempArray.Push(file)
		}
	}
	for i, file in TempArray {
    FileArray.Push(file)
    if (i<ListLen) or (TempArray.MaxIndex()=ListLen) {
      SplitPath file, , , ext, name
      StringUpper, name, name
      StringUpper, ext, ext
      FileGetAttrib, Attrs, %file%
      if InStr(Attrs, "D")
         SingleSize := "<DIR>"
      else           
         FileGetSize, SingleSize, %file%
      if StrLen(name) > 8
      	FileList .= Format("{:-6}",SubStr(name, 1, 6)) "..."
      else
        FileList .= Format("{:-8}",SubStr(name, 1, 8)) " "
      FileList .= Format("{:-3}",SubStr(ext, 1, 3))
      FileList .= Format("{: 10}",SingleSize) "|"
    }
	}
	if TempArray.MaxIndex() > ListLen
	   FileList .= "|[ +" FileArray.Length()-(ListLen-1) " more ]"
	GuiControl, Text, FileListbox, |%FileList%   
	GuiControl, Enable, GoButton
	TempArray := []                        ; clear memory?
	Return

;++++++++++++++++++++++++++++++++++++++++
sortArray(arr,options="")  ; specify "Flip" in the options to reverse 
{
	if	!IsObject(arr)
		return	0
	new :=	[]
	if	(options="Flip") {
		While	(i :=	arr.MaxIndex()-A_Index+1)
			new.Insert(arr[i])
		return	new
	}
	For each, item in arr
		list .=	item "`n"
	list :=	Trim(list,"`n")
	Sort, list, %options%
	Loop, parse, list, `n, `r
		new.Insert(A_LoopField)
	return	new
}

;++++++++++++++++++++++++++++++++++++++++
RunWaitLogged(command)  ; Using a logfile instead of exec.StdErr.ReadAll(), since that takes AGES for some reason
{
	global
	
  logFileSpec := tempFolder . "\___INJE.TMP.LOG"
  FileDelete, %logFileSpec%
  redirCommand := """(" . command . " > """ . logFileSpec . """ 2>&1)"""      ; Ensure temp path is spaced
  	
  shell := ComObjCreate("WScript.Shell")                                      ; WshShell object: http://msdn.microsoft.com/en-us/library/aew9yb99
  exitCode := shell.Run(ComSpec " /C " redirCommand, 0, true)                 ; Execute a single command via cmd.exe - 0=hide window, true=bWaitOnReturn
                                                                              ;    (don't use .Exec() method because you can't hide the window)
	logFile:=FileOpen(logFileSpec,"r-wd")                                       ; Try to open logfile for reading and lock it
	While !IsObject(logFile) {                                                 
		Sleep 50                                                                  ; Can't? - wait and try again
		logFile:=FileOpen(logFileSpec,"r-wd")                                     ;    (output redirection hasn't finished!)
	}                                                                          
	logContents:=logFile.Read()                                                 ; Succeeded?  Get & close
	logFile.Close()                                                             ; Release share locks
	FileDelete, %logFileSpec%
	
  Return logContents
}


;++++++++++++++++++++++++++++++++++++++++
GetClientSize(hwnd, ByRef w, ByRef h)  ; Find size of window client area (More precise)
{
    VarSetCapacity(rc, 16)
    DllCall("GetClientRect", "uint", hwnd, "uint", &rc)
    w := NumGet(rc, 8, "int")
    h := NumGet(rc, 12, "int")
}

