#NoTrayIcon
#include <ListBoxConstants.au3>
#include <ComboConstants.au3> 
#include <ButtonConstants.au3>
#include <WinAPISys.au3>
#include <SendMessage.au3>
#include <SliderConstants.au3>
#include <EditConstants.au3>
#include <TrayConstants.au3>
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <StaticConstants.au3>
#include <Misc.au3>

_Singleton ( "MouseTray" )
TraySetIcon(GetPtrAccel()?"accOn.ico":"%windir%\Cursors\aero_arrow_xl.cur")
Opt("GUIOnEventMode", 1)
Opt("TrayOnEventMode", 1)
Opt("TrayMenuMode", 1)
Opt("TrayAutoPause", 0)
Opt("TrayIconHide", 0)
; Opt("TrayIconDebug", 1)
TraySetClick ( 16 )
TraySetOnEvent ( -7 , OnTrayMB1Down )
TraySetOnEvent ( -11, OnTrayHover )

Global Const $PATH_TO_CONFIG_INI = "options.ini"
Global Const $DEFAULT_PROFILE_NAME = "Default Mouse Profile"
Global Const $user32dll = DllOpen("user32.dll")
Global Const $RIHeaderSize = DllStructGetSize(DllStructCreate('struct;dword Type;dword Size;handle hDevice;wparam wParam;endstruct'))
Global Const $tRIM = 'struct;dword Type;dword Size;handle hDevice;wparam wParam;endstruct;ushort Flags;ushort Alignment;ushort ButtonFlags;short ButtonData;ulong RawButtons;long LastX;long LastY;ulong ExtraInformation;'
Global Const $RIMSize = DllStructGetSize(DllStructCreate($tRIM))

BuildTray()
SingletonProfiles("initialize")
GUIRegisterMsg($WM_ACTIVATE,   WM_ACTIVATE)
GUIRegisterMsg($WM_HSCROLL,    WM_HSCROLL)
GUIRegisterMsg($WM_MOUSEWHEEL, WM_MOUSEWHEEL)

Main()

Func Main()
    While Sleep(1000)
    WEnd
EndFunc

Func ShowPopup()
    SingletonPopup()
EndFunc

Func LostFocus($hWnd)
    SingletonPopup($hWnd,$WM_ACTIVATE,0)
EndFunc

Func BuildTray()
    SingletonTray()
Endfunc

Func ShowPreferences()
    SingletonOptions("open")
EndFunc

Func OnTrayMB1Down()
    ShowPopup()
EndFunc

Func OnTrayHover()
    TraySetToolTip( "x" & CalculateMultiplier() & (GetPtrAccel()?" - Accel":" - Linear") )
EndFunc

Func SingletonProfiles($cmd,$arg=Null)
     Local Const $tagProfile = "uint speed;uint accel;uint thresh1;uint thresh2"
     Local Static $currentProfile, $aProfiles ; save per-profile temporary state in array, first row should load current
     Switch $cmd
       Case "initialize" ; only called once on application startup. No window so no need to populate dropdown
            Local $aIni = IniReadSection ( $PATH_TO_CONFIG_INI, "Profiles" )
            If @error Then ; load hardcoded default profile if no ini file found
               Local $a = [[$DEFAULT_PROFILE_NAME,DllStructCreate($tagProfile),DllStructCreate($tagProfile)]]
                With $a[0][1]
                    .speed   = 10
                    .accel   = 0
                    .thresh1 = 0
                    .thresh2 = 0
                EndWith
            ElseIf $aIni[0][0]>0 Then
               Local $a[ 1+$aIni[0][0] ][ 3 ]
               For $i=0 to $aIni[0][0]
                   $a[$i][0] = $aIni[$i][0] ; element 0,0 is a number but will overwrite later so it's ok
                   Local $s = StringSplit($aIni[$i][1],",",2)
                   If Not (UBound($s)=4) Then 
                      Local $s = [10,0,0,0]
                   EndIf
                   For $j = 1 to 2
                       $a[$i][$j] = DllStructCreate($tagProfile)
                       With $a[$i][$j]
                        .speed   = Number($s[0])
                        .accel   = Number($s[1])
                        .thresh1 = Number($s[2])
                        .thresh2 = Number($s[3])
                       EndWith
                   Next
               Next
               $a[0][0] = $DEFAULT_PROFILE_NAME ; remember to overwrite the loop entry
            Endif
            $aProfiles = $a
            Local $a = [$aProfiles[0][0],$aProfiles[0][1],$aProfiles[0][2]]
            $currentProfile = $a
            With $currentProfile[2]
                 Local $a = GetPtrAccel(True)
                 .speed   = GetPtrSpeed()
                 .accel   = $a[0]
                 .thresh1 = $a[1]
                 .thresh2 = $a[2]
            EndWith
       Case "populate" ; read from static memory rather than reloading ini every time
            If $arg Then
               Local $str = ""
               For $i=0 to UBound($aProfiles)-1
                   $str = $str & "|" & $aProfiles[$i][0]
               Next
               if $str then GUICtrlSetData($arg,$str,$currentProfile[0])
            EndIf
       Case "select"
            If $arg Then
               For $i=0 to UBound($aProfiles)-1
                   If $arg = $aProfiles[$i][0] Then
                      Local $a = [$aProfiles[$i][0],$aProfiles[$i][1],$aProfiles[$i][2]]
                      $currentProfile = $a
                      With $a[2]
                           SetPtrSpeed(.speed)
                           SetPtrAccel(.accel,.thresh1,.thresh2)
                      EndWith
                      Refresh()
                      Return ; early return if selection found, otherwise default profile outside loop
                   EndIf
               Next
               Local $a = [$aProfiles[0][0],$aProfiles[0][1],$aProfiles[0][2]]
               $currentProfile = $a
               With $a[2]
                    SetPtrSpeed(.speed)
                    SetPtrAccel(.accel,.thresh1,.thresh2)
               EndWith
               Refresh()
            EndIf
       Case "refresh"
            With $currentProfile[2]
                 Local $a = GetPtrAccel(True)
                 .speed   = GetPtrSpeed()
                 .accel   = $a[0]
                 .thresh1 = $a[1]
                 .thresh2 = $a[2]
            EndWith
       Case "recenter" ; user shortcut, reset to current profile's default
            With $currentProfile[1]
                 SetPtrSpeed(.speed)
                 SetPtrAccel(.accel,.thresh1,.thresh2)
                 Refresh()
            EndWith
       Case "push"
            If IsArray($arg) and UBound($arg,0)=2 and UBound($arg,1)>0 and UBound($arg,2)=3 Then
               $aProfiles = $arg
               SingletonProfiles("select",$currentProfile[0])
               Local $a=$aProfiles
               ReDim $a[UBound($a)][2]
               For $i=0 to UBound($a)-1
                   With $a[$i][1]
                        $a[$i][1] = .speed & "," & .accel & "," & .thresh1 & "," & .thresh2
                   EndWith
               Next
               IniWriteSection($PATH_TO_CONFIG_INI,"Profiles",$a)
            EndIf
       Case "query"
            Return $aProfiles
     EndSwitch
EndFunc

Func SingletonOptions($cmd, $arg=Null)
     Local Static $hWnd, $hInput, $hSlider, $hChkBox, $hListView, $hDelete, $aProfiles
     Local Static $lastIndex = 0
     Switch $cmd
       Case "open"
;            if IsHwnd($hWnd) then GUIDelete($hWnd)
            If IsHwnd($hWnd) Then
               GUISetState(@SW_RESTORE,$hWnd) 
               Local $pos = WinGetPos($hWnd)
               WinMove($hWnd,"",(@DesktopWidth-$pos[2])/2,(@DesktopHeight-$pos[3])/2)
               Return 
            EndIf
            Local $w = 400, $h = 424
            $aProfiles = SingletonProfiles("query")
            ReDim $aProfiles[UBound($aProfiles)][4]
            $hWnd = GUICreate("Preferences",$w,$h,-1,-1,$WS_CAPTION,$WS_EX_TOOLWINDOW)
            GUISetOnEvent($GUI_EVENT_CLOSE,CloseButton)
            GUICtrlCreateTab ( 8, 8, $w-16+2, $h-44 )
            GUICtrlCreateTabItem("Profiles")

            GUICtrlCreateButton("Save",$w-82,$h-30,75,23)
            GUICtrlSetOnEvent(-1,onEventListApply)
            GUICtrlCreateButton("Cancel",$w-82-81,$h-30,75,23)
            GUICtrlSetOnEvent(-1,CLOSEButton)
            $hDelete = GUICtrlCreateButton("Delete",$w-163-81,$h-30,75,23)
            GUICtrlSetOnEvent(-1,onEventDeleteProfile)
            GUICtrlCreateButton("New",$w-244-81,$h-30,75,23)
            GUICtrlSetOnEvent(-1,onEventCreateProfile)

GUICtrlCreateGroup ( "Default value for", 21, 40, 357, 99, 0x50000007, 0x00000004 )
;GUICtrlCreateLabel ( "Sele&ct a pointer speed:",73,61,180,13 )
GUICtrlCreateLabel ( "Slow",73,89,26,15,0x50020002,0x00000004 )
GUICtrlCreateLabel ( "Fast",225,89,24,15,0x50020000,0x00000004 )
GUICtrlCreateIcon ( "accOn.ico", 1, 30, 61)
;$hInput = GUICtrlCreateInput ( $DEFAULT_PROFILE_NAME , 70,58,259,19)
$hInput = GUICtrlCreateInput ( $DEFAULT_PROFILE_NAME , 70,58,184,19)
$hChkBox = GUICtrlCreateCheckbox("&Enable pointer acceleration",73,116,227,16)
$hSlider = GUICtrlCreateSlider(102,82,120,26,$TBS_TOOLTIPS+$TBS_DOWNISLEFT)
GUICtrlSetBkColor(-1,0xFFFFFF)
GUICtrlSetLimit(-1, 20, 1)
GUICtrlSetData(-1, 10)
_SendMessage(GUICtrlGetHandle($hSlider), $TBM_SETTIC, 0, 2)
_SendMessage(GUICtrlGetHandle($hSlider), $TBM_SETTIC, 0, 4)
_SendMessage(GUICtrlGetHandle($hSlider), $TBM_SETTIC, 0, 6)
_SendMessage(GUICtrlGetHandle($hSlider), $TBM_SETTIC, 0, 8)
_SendMessage(GUICtrlGetHandle($hSlider), $TBM_SETTIC, 0, 10)
_SendMessage(GUICtrlGetHandle($hSlider), $TBM_SETTIC, 0, 12)
_SendMessage(GUICtrlGetHandle($hSlider), $TBM_SETTIC, 0, 14)
_SendMessage(GUICtrlGetHandle($hSlider), $TBM_SETTIC, 0, 16)
_SendMessage(GUICtrlGetHandle($hSlider), $TBM_SETTIC, 0, 18)
GUICtrlSetState($hInput, $GUI_DISABLE)
GUICtrlSetState($hSlider, $GUI_DISABLE)
GUICtrlSetState($hChkBox, $GUI_DISABLE)
GUICtrlSetState($hDelete, $GUI_DISABLE)


            GUICtrlSetOnEvent($hInput,onEventRenameProfile)
            GUICtrlSetOnEvent($hSlider,onEventUpdateProfile)
            GUICtrlSetOnEvent($hChkBox,onEventUpdateProfile)


            $hListView = GUICtrlCreateListView("Name|Speed|Accel|Factor",21,150,357,224,0x800C)
            For $i = 0 to UBound($aProfiles)-1
                With $aProfiles[$i][1]
;                     $aProfiles[$i][3] = GUICtrlCreateListViewItem($aProfiles[$i][0]&"|"&.speed&","&.accel&","&.thresh1&","&.thresh2,$hListView)
                     $aProfiles[$i][3] = GUICtrlCreateListViewItem($aProfiles[$i][0] & "|" & .speed & "|" & .accel & "|" & CalculateMultiplier(.speed,.accel),$hListView)
                     GUICtrlSetOnEvent($aProfiles[$i][3],onEventListSelect)
                EndWith
            Next
            GUICtrlSendMsg($hListView, 4126, 0, 192)
            GUICtrlSendMsg($hListView, 4126, 1, 48)
            GUICtrlSendMsg($hListView, 4126, 2, 48)
            GUICtrlSendMsg($hListView, 4126, 3, 48)
;            GUICtrlSendMsg($hListView, 4126, 0, 336)
;            GUICtrlSendMsg($hListView, 4126, 1, 0)
            GUICtrlSetState($aProfiles[0][3],$GUI_FOCUS) 
            GUICtrlSetState($hListView,$GUI_FOCUS) 
            GUICtrlCreateTabItem("")
            GUISetState()
            Local $stub = GUICtrlCreateDummy()
            Local $arr = [ ["{UP}",$stub],["{DOWN}",$stub],["{PGUP}",$stub],["{PGDN}",$stub] ]
            GUISetAccelerators ( $arr )
       Case "create"
            Local $newIndex = UBound($aProfiles)
            Local $newNum = $newIndex
            Local $i = 0
            While $i < $newIndex
               $i += 1
               If $aProfiles[$i-1][0] = "New Profile " & $newNum Then 
                  $newNum += 1
                  $i = 0
               EndIf
            WEnd
            Local $newName = "New Profile " & $newNum
            ReDim $aProfiles[$newIndex+1][4]
            $aProfiles[$newIndex][0] = $newName
            $aProfiles[$newIndex][1] = DllStructCreate("uint speed;uint accel;uint thresh1;uint thresh2")
            $aProfiles[$newIndex][2] = DllStructCreate("uint speed;uint accel;uint thresh1;uint thresh2")
            For $i=1 to 2
                With $aProfiles[$newIndex][$i]
                     .speed = 10
                     .accel = 0
                     .thresh1 = 0
                     .thresh2 = 0
                Endwith
            Next
;            $aProfiles[$newIndex][3] = GUICtrlCreateListViewItem($newName&"|"&"10,0,0,0",$hListView)
            $aProfiles[$newIndex][3] = GUICtrlCreateListViewItem($newName & "|10|0|1",$hListView)
            GUICtrlSetOnEvent($aProfiles[$newIndex][3],onEventListSelect)
            GUICtrlSetState($aProfiles[$newIndex][3],$GUI_FOCUS) 
            SingletonOptions("select",$aProfiles[$newIndex][3])
       Case "delete"
            Local $index = $lastIndex
            if $index = 0 then return
            GUICtrlDelete($aProfiles[$index][3])
            Local $a[UBound($aProfiles)-1][4], $offset = 0
            For $i=0 to UBound($aProfiles)-1
                If $i=$index Then
                   $offset += 1
                   ContinueLoop
                EndIf
                $a[$i-$offset][0] = $aProfiles[$i][0]
                $a[$i-$offset][1] = $aProfiles[$i][1]
                $a[$i-$offset][2] = $aProfiles[$i][2]
                $a[$i-$offset][3] = $aProfiles[$i][3]
            Next
            $aProfiles = $a
            If UBound($aProfiles)-1 < $index Then
               GUICtrlSetState($aProfiles[$index-1][3],$GUI_FOCUS) 
               SingletonOptions("select",$aProfiles[$index-1][3])
            Else
               GUICtrlSetState($aProfiles[$index][3],$GUI_FOCUS) 
               SingletonOptions("select",$aProfiles[$index][3])
            EndIf
       Case "rename"
            Local $index = $lastIndex, $str = GUICtrlRead($hInput)
            if $index = 0 then return
            For $i=0 to UBound($aProfiles)-1
                If $aProfiles[$i][0]=$str and $i<>$index Then
                   GUICtrlSetState($aProfiles[$i][3],$GUI_FOCUS) 
                   SingletonOptions("select",$aProfiles[$i][3])
                   Return
                EndIf
            Next
            $aProfiles[$index][0] = $str
            With $aProfiles[$index][1]
;                 GUICtrlSetData($aProfiles[$index][3],$aProfiles[$index][0]&"|"&.speed&","&.accel&","&.thresh1&","&.thresh2)
                 GUICtrlSetData($aProfiles[$index][3],$aProfiles[$index][0] & "|" & .speed & "|" & .accel & "|" & CalculateMultiplier(.speed,.accel))
            EndWith
       Case "update"
            Local $index = $lastIndex, $spd = GUICtrlRead($hSlider), $acc = GUICtrlRead($hChkBox)
            if $index = 0 then return
            With $aProfiles[$index][1]
                 .speed   = $spd
                 .accel   = $acc=$GUI_CHECKED ?  1 : 0
                 .thresh1 = $acc=$GUI_CHECKED ?  6 : 0
                 .thresh2 = $acc=$GUI_CHECKED ? 10 : 0
;                 GUICtrlSetData($aProfiles[$index][3],$aProfiles[$index][0]&"|"&.speed&","&.accel&","&.thresh1&","&.thresh2)
                 GUICtrlSetData($aProfiles[$index][3],$aProfiles[$index][0] & "|" & .speed & "|" & .accel & "|" & CalculateMultiplier(.speed,.accel))
            EndWith
            With $aProfiles[$index][2]
                 .speed   = $spd
                 .accel   = $acc=$GUI_CHECKED ?  1 : 0
                 .thresh1 = $acc=$GUI_CHECKED ?  6 : 0
                 .thresh2 = $acc=$GUI_CHECKED ? 10 : 0
            EndWith
       Case "select"
            Local $index = SingletonOptions("queryindex",$arg)
            GUICtrlSetData( $hInput , $aProfiles[$index][0])
            GUICtrlSetData( $hSlider,DllStructGetData($aProfiles[$index][1],"speed"))
            GUICtrlSetState($hChkBox,DllStructGetData($aProfiles[$index][1],"accel")?$GUI_CHECKED:$GUI_UNCHECKED)
            If $index = 0 Then
               GUICtrlSetState($hInput,  $GUI_DISABLE)
               GUICtrlSetState($hDelete, $GUI_DISABLE)
               GUICtrlSetState($hChkBox, $GUI_DISABLE)
               GUICtrlSetState($hSlider, $GUI_DISABLE)
            Else
               GUICtrlSetState($hInput,  $GUI_ENABLE)
               GUICtrlSetState($hDelete, $GUI_ENABLE)
               GUICtrlSetState($hChkBox, $GUI_ENABLE)
               GUICtrlSetState($hSlider, $GUI_ENABLE)
            EndIf
            $lastIndex = $index
       Case "apply"
            Local $a = $aProfiles
            ReDim $a[UBound($aProfiles)][3]
            SingletonProfiles("push",$a)
            GUIDelete($hWnd)
       Case "queryindex"
            Local $handle = $arg ? $arg : GUICtrlRead($hListView)
            For $i=0 to UBound($aProfiles)-1
                If $aProfiles[$i][3] = $handle Then
                   Return $i
                EndIf
            Next
            Return 0
     EndSwitch
EndFunc

Func SingletonTray($msg=Null)
    Local Static $init = True
    Local Static $tray = [ _
        TrayCreateItem ( "Enable wheel shortcuts" ), _
        TrayCreateItem ( "Preferences..." ), _
        TrayCreateItem ( "" ), _
        TrayCreateMenu ( "Control Panel" ), _
        TrayCreateMenu ( "Settings App" ), _
        TrayCreateItem ( "" ), _
        TrayCreateItem ( "Exit" ) _
    ]
    If $init Then
       $init = False
       $n = UBound($tray)
       TrayItemSetOnEvent ($tray[0], ToggleShortcuts )
       TrayItemSetOnEvent ($tray[1], OpenToolPrefs )
       TrayItemSetOnEvent (TrayCreateItem("Mouse",$tray[$n-4]), OpenCplMouse )
       TrayItemSetOnEvent (TrayCreateItem("Mouse",$tray[$n-3]), OpenUwpMouse )
       TrayItemSetOnEvent (TrayCreateItem("Keyboard",$tray[$n-4]), OpenCplKeyboard )
       TrayItemSetOnEvent (TrayCreateItem("Touchpad",$tray[$n-3]), OpenUwpTouchpad )
       TrayItemSetOnEvent ($tray[$n-1], ExitApp )
    EndIf
    If $msg Then
        Switch $msg
          Case Else
        EndSwitch
    EndIf
EndFunc

Func SingletonPopup($hWnd=Null, $iMsg=Null, $iwParam=Null, $ilParam=Null)
  Local Static $hDropdn = Null, $hNum = Null, $hAccIco = Null, $hSlider = Null, $hPopup = Null
  Switch $iMsg
    Case $WM_ACTIVATE 
      if $iwParam==0 and $hWnd=$hPopup then GUIDelete($hWnd)
    Case Null
      If $hWnd==Null Then
        if IsHwnd($hPopup) then return GUISetState(@SW_RESTORE,$hPopup)
        Local $l, $t, $w = 360, $h = 100
        Local $hSysTray = WinGetHandle("[Class:Shell_TrayWnd]")
        Local $a = WinGetPos( $hSysTray ) ; [left, top, width, height]
        If Not UBound($a) = 4 Then Return
        If $a[1] Then ; bot
           $l = @DesktopWidth  - $w
           $t = @DesktopHeight - $h - $a[3]
        ElseIf $a[0] Then ; right
           $l = @DesktopWidth  - $w - $a[2]
           $t = @DesktopHeight - $h
        ElseIf $a[2]>$a[3] Then ; top
           $l = @DesktopWidth  - $w
           $t = $a[3]
        Else ; left
           $l = $a[2]
           $t = @DesktopHeight - $h
        EndIf
        $hPopup = GUICreate("",$w,$h,$l,$t,$WS_POPUP,$WS_EX_TOPMOST,$hSysTray)
        GUISetOnEvent($GUI_EVENT_CLOSE,CloseButton)
        WinSetTrans ( $hPopup, "", 240 )
        GUISetAccelerators ( PopupAccelerators() )
        $hNum = GUICtrlCreateLabel(CalculateMultiplier(),($w-248)/2+250,$h-46,50,40,$SS_CENTER)
        GUICtrlSetFont($hNum, 18, 0, 0, "Segoe UI")
        GUICtrlSetColor($hNum, 0xFFFFFF)
        GUISetBkColor(0x1f1f1f)

        $hAccIco = GUICtrlCreateIcon ( GetPtrAccel()?"accOn.ico":"accOff.ico", 1, 19, $h-44)
        $hDropdn = GUICtrlCreateCombo($DEFAULT_PROFILE_NAME,7,8,$w-14,-1, $WS_VSCROLL+$CBS_DROPDOWNLIST)
        GUICtrlSetFont($hDropdn, 11.5, 0, 0, "Segoe UI")
        GUICtrlSetBkColor($hDropdn,0x1f1f1f)
        SingletonProfiles("populate",$hDropdn)

        $hSlider = GUICtrlCreateSlider(($w-248)/2,$h-49,250,42,$TBS_TOOLTIPS+$TBS_DOWNISLEFT+$TBS_BOTH)
        GUICtrlSetBkColor($hSlider, 0x1f1f1f)
        GUICtrlSetLimit($hSlider, 20, 1)
        GUICtrlSetData($hSlider, 10)
        _SendMessage(GUICtrlGetHandle($hSlider), $TBM_SETTIC, 0, 2)
        _SendMessage(GUICtrlGetHandle($hSlider), $TBM_SETTIC, 0, 4)
        _SendMessage(GUICtrlGetHandle($hSlider), $TBM_SETTIC, 0, 6)
        _SendMessage(GUICtrlGetHandle($hSlider), $TBM_SETTIC, 0, 8)
        _SendMessage(GUICtrlGetHandle($hSlider), $TBM_SETTIC, 0, 10)
        _SendMessage(GUICtrlGetHandle($hSlider), $TBM_SETTIC, 0, 12)
        _SendMessage(GUICtrlGetHandle($hSlider), $TBM_SETTIC, 0, 14)
        _SendMessage(GUICtrlGetHandle($hSlider), $TBM_SETTIC, 0, 16)
        _SendMessage(GUICtrlGetHandle($hSlider), $TBM_SETTIC, 0, 18)
        GUICtrlSetState($hDropDn, $GUI_FOCUS) 
        GUICtrlSetOnEvent($hAccIco,onAccIcoEvent)
        GUICtrlSetOnEvent($hDropdn,onDropdnEvent)
        GUISetState()
      EndIf
      SingletonProfiles("refresh")
      Local $acc = GetPtrAccel()
      TraySetIcon($acc?"accOn.ico":"%windir%\Cursors\aero_arrow_xl.cur")
      if not IsHWnd($hPopup) then return
      if $hWnd then return GUISetState(@SW_RESTORE,$hPopup)
      GUICtrlSetData($hSlider, GetPtrSpeed())
      GUICtrlSetData($hNum, CalculateMultiplier())
      GUICtrlSetImage($hAccIco,$acc?"accOn.ico":"accOff.ico",1)
      GUICtrlSetTip( $hAccIco, GetPtrAccel()?"Acceleration ON":"No Acceleration" )
      Local $ret = [$hPopup, $hDropdn, $hAccIco, $hSlider, $hNum]
      Return $ret
    Case $WM_HSCROLL
      if not ($hPopup and $hWnd = $hPopup) then return
      Local $hw = BitShift($iWParam, 16), $lw = BitAND($iWParam, 0xFFFF)
      if $lw = 5 or $lw = 4 then GUICtrlSetData($hNum, CalculateMultiplier($hw))
      if $lw = 8 or $lw = 4 then SetPtrSpeed(GUICtrlRead($hSlider))
      if $lw = 8 then Refresh()
    Case $WM_MOUSEWHEEL ; received when scrolling with cursor over window but not slider itself
      if not ($hPopup and $hWnd = $hPopup) then return
      Local $hw = BitShift($iWParam, 16)
      If $hw >= 120 Then
        Local $spd=GetPtrSpeed()+1
        if $spd>20 then $spd=20
        SetPtrSpeed($spd)
        Refresh()
      ElseIf $hw <= -120 Then
        Local $spd=GetPtrSpeed()-1
        if $spd<1 then $spd=1
        SetPtrSpeed($spd)
        Refresh()
      EndIf
  EndSwitch
EndFunc

; WM_HSCROLL low word
; Drag: only 5
; Release: 4 and 8
; Scroll: only 4
; Click/PgUp/PgDn: 2/3 and 8
; Arrow: 0/1 and 8
; Home/End: 6/7 and 8
; It seems that AutoIt's slider event only detects 8
; 0,1: SB_LINELEFT/SB_LINERIGHT
; 2,3: SB_PAGELEFT/SB_PAGERIGHT
; 4:   SB_THUMBPOSITION
; 5:   SB_THUMBTRACK
; 6,7: SB_LEFT/SB_RIGHT
; 8:   SB_ENDSCROLL

Func RegisterRawmouse($hWnd, $flags)
     Local $tRID = DllStructCreate($tagRAWINPUTDEVICE)
     $tRID.UsagePage = 0x01 ; Generic Desktop Controls
     $tRID.Usage = 0x02     ; Mouse
     $tRID.Flags = $flags
     $tRID.hTarget = $hWnd
     If Not _WinAPI_RegisterRawInputDevices($tRID) Then Exit
EndFunc

Func WM_INPUT($hWnd, $iMsg, $iwParam, $ilParam)
  Local $a = DllCall($user32dll, 'uint', 'GetRawInputData', 'handle', $ilParam, 'uint', 0x10000003, 'struct*', DllStructCreate($tRIM), 'uint*', $RIMSize, 'uint', $RIHeaderSize)
  With $a[3]
    If .ButtonFlags Then
       If _isPressed(14) then
          If BitAnd(16,.ButtonFlags) Then; or BitAnd(32,.ButtonFlags) Then
             AcceleratorCallbacks(_isPressed(10)?"+{HOME}":"{HOME}")
          ElseIf .ButtonData = 120 Then
             AcceleratorCallbacks("=")
          ElseIf .ButtonData = -120 Then
             AcceleratorCallbacks("-")
          Endif
       Endif
    EndIf
  EndWith
  Return 0    
EndFunc

Func WM_ACTIVATE($hWnd, $iMsg, $iwParam, $ilParam)
    if Not $iwParam then LostFocus($hWnd)
    Return $GUI_RUNDEFMSG
EndFunc

Func WM_HSCROLL($hWnd, $iMsg, $iwParam, $ilParam)
    SingletonPopup($hWnd, $iMsg, $iwParam, $ilParam)
    Return $GUI_RUNDEFMSG
EndFunc

Func WM_MOUSEWHEEL($hWnd, $iMsg, $iwParam, $ilParam)
    SingletonPopup($hWnd, $iMsg, $iwParam, $ilParam)
    Return $GUI_RUNDEFMSG
EndFunc

Func CloseButton()
    GUIDelete( @GUI_WinHandle )
EndFunc

Func ExitApp()
     Exit
EndFunc

Func ToggleShortcuts()
    Local Static $hWnd = GUICreate("")
    If BitAnd($TRAY_CHECKED,TrayItemGetState(@TRAY_ID)) Then
       GUIRegisterMsg($WM_INPUT,WM_INPUT)
       RegisterRawmouse($hWnd, $RIDEV_INPUTSINK)
    Else 
       RegisterRawmouse(Null, $RIDEV_REMOVE)
       GUIRegisterMsg($WM_INPUT,"")
    EndIf
EndFunc

Func OpenCplMouse()
    TrayItemSetState( @TRAY_ID , $TRAY_UNCHECKED )
    ShellExecute ( "main.cpl" )
EndFunc

Func OpenCplKeyboard()
    TrayItemSetState( @TRAY_ID , $TRAY_UNCHECKED )
    ShellExecute ( "main.cpl" , "keyboard" )
EndFunc

Func OpenUwpMouse()
    TrayItemSetState( @TRAY_ID , $TRAY_UNCHECKED )
    ShellExecute ( "ms-settings:mousetouchpad" )
EndFunc

Func OpenUwpTouchpad()
    TrayItemSetState( @TRAY_ID , $TRAY_UNCHECKED )
    ShellExecute ( "ms-settings:devices-touchpad" )
EndFunc

Func OpenToolPrefs()
    TrayItemSetState( @TRAY_ID , $TRAY_UNCHECKED )
    ShowPreferences()
EndFunc

Func Refresh()
    SingletonPopup(False)
EndFunc

Func ReFocus()
    SingletonPopup(True)
EndFunc

Func onDropdnEvent()
    SingletonProfiles("select",GUICtrlRead(@GUI_CtrlID))
EndFunc

Func onAccIcoEvent()
    Local $enable = not GetPtrAccel()
    If $enable Then
        EnablePointerAccel()
    Else
        DisablePointerAccel()
    EndIf
EndFunc

Func onEventAccelerator()
    AcceleratorCallbacks(GUICtrlRead(@GUI_CtrlId))
EndFunc

Func onEventListSelect()
    SingletonOptions("select",@GUI_CtrlId)
EndFunc

Func onEventListApply()
    SingletonOptions("apply",@GUI_CtrlId)
EndFunc

Func onEventCreateProfile()
    SingletonOptions("create")
EndFunc

Func onEventDeleteProfile()
    SingletonOptions("delete")
EndFunc

Func onEventRenameProfile()
    SingletonOptions("rename")
EndFunc

Func onEventUpdateProfile()
    SingletonOptions("update")
EndFunc

Func IncrementPointerSpeed()
    AcceleratorCallbacks("=")
EndFunc

Func DecrementPointerSpeed()
    AcceleratorCallbacks("-")
EndFunc

Func EnablePointerAccel()
    SetPtrAccel(1,6,10)
    Refresh()
EndFunc

Func DisablePointerAccel()
    SetPtrAccel(0,0,0)
    Refresh()
EndFunc

Func GetPtrSpeed()
    Local $struct = DllStructCreate("uint speed")   
    _WinAPI_SystemParametersInfo ( 0x0070, 0, DllStructGetPtr($struct), 0 )
    Return $struct.speed
EndFunc

Func SetPtrSpeed($val, $flag=1)
    _WinAPI_SystemParametersInfo ( 0x0071, 0, $val, $flag)
EndFunc

Func GetPtrAccel($advanced=False)
    Local $retval, $struct = DllStructCreate("uint thresh1;uint thresh2;uint accel")
    _WinAPI_SystemParametersInfo ( 0x0003, 0, DllStructGetPtr($struct), 0 )
    If $advanced Then 
       Local $arr = [$struct.accel,$struct.thresh1,$struct.thresh2]
       Return $arr
    Else
       Return $struct.accel
    EndIf
EndFunc

Func SetPtrAccel($accel,$thresh1,$thresh2,$flag=1)
    Local $struct = DllStructCreate("uint thresh1;uint thresh2;uint accel")
    $struct.thresh1 = $thresh1
    $struct.thresh2 = $thresh2
    $struct.accel   = $accel
    _WinAPI_SystemParametersInfo ( 0x0004, 0, $struct, $flag)
EndFunc

Func CalculateMultiplier($speed=GetPtrSpeed(),$accel=GetPtrAccel())
    if $accel    then return ($speed=10?"1.0":$speed/10)
    if $speed<3  then return "1/" & 32/$speed
    if $speed<10 then return $speed-2 & "/8"
    return $speed/4 - 1.5
EndFunc

Func PopupAccelerators()
    Local $arr = [ _
        ["`",      GUICtrlCreateDummy()], _
        ["1",      GUICtrlCreateDummy()], _
        ["2",      GUICtrlCreateDummy()], _
        ["3",      GUICtrlCreateDummy()], _
        ["4",      GUICtrlCreateDummy()], _
        ["5",      GUICtrlCreateDummy()], _
        ["6",      GUICtrlCreateDummy()], _
        ["7",      GUICtrlCreateDummy()], _
        ["8",      GUICtrlCreateDummy()], _
        ["9",      GUICtrlCreateDummy()], _
        ["0",      GUICtrlCreateDummy()], _
        ["-",      GUICtrlCreateDummy()], _
        ["=",      GUICtrlCreateDummy()], _
        ["{BS}",   GUICtrlCreateDummy()], _
        ["{UP}",   GUICtrlCreateDummy()], _
        ["{DOWN}", GUICtrlCreateDummy()], _
        ["{LEFT}", GUICtrlCreateDummy()], _
        ["{RIGHT}",GUICtrlCreateDummy()], _
        ["{PGUP}", GUICtrlCreateDummy()], _
        ["{PGDN}", GUICtrlCreateDummy()], _
        ["{HOME}", GUICtrlCreateDummy()], _
        ["{END}",  GUICtrlCreateDummy()], _
        ["{DEL}",  GUICtrlCreateDummy()], _
        ["+{PGUP}",GUICtrlCreateDummy()], _
        ["+{PGDN}",GUICtrlCreateDummy()], _
        ["+{HOME}",GUICtrlCreateDummy()], _
        ["+{END}" ,GUICtrlCreateDummy()], _
        ["+{DEL}", GUICtrlCreateDummy()]  _
    ]
    For $i=0 to UBound($arr)-1
        GUICtrlSetData($arr[$i][1],$arr[$i][0])
        GUICtrlSetOnEvent($arr[$i][1],onEventAccelerator)
    Next
    Return $arr
EndFunc

Func AcceleratorCallbacks($str)
    Switch $str
        Case "`"
            SetPtrSpeed(1)
            Refresh()
        Case "1"
            SetPtrSpeed(2)
            Refresh()
        Case "2"
            SetPtrSpeed(4)
            Refresh()
        Case "3"
            SetPtrSpeed(6)
            Refresh()
        Case "4"
            SetPtrSpeed(8)
            Refresh()
        Case "5"
            SetPtrSpeed(10)
            Refresh()
        Case "6"
            SetPtrSpeed(12)
            Refresh()
        Case "7"
            SetPtrSpeed(14)
            Refresh()
        Case "8"
            SetPtrSpeed(16)
            Refresh()
        Case "9"
            SetPtrSpeed(18)
            Refresh()
        Case "0"
            SetPtrSpeed(20)
            Refresh()
        Case "-","{LEFT}","{DOWN}"
            Local $spd=GetPtrSpeed()-1
            if $spd<1 then $spd=1
            SetPtrSpeed($spd)
            Refresh()
        Case "=","{RIGHT}","{UP}"
            Local $spd=GetPtrSpeed()+1
            if $spd>20 then $spd=20
            SetPtrSpeed($spd)
            Refresh()
        Case "{BS}"
            Local $acc=GetPtrAccel()
            If $acc Then
                DisablePointerAccel()
            Else
                EnablePointerAccel()
            EndIf
        Case "{PGUP}"
            Local $spd=GetPtrSpeed()+1
            if $spd>20 then $spd=20
            SetPtrSpeed($spd)
            SetPtrAccel(0,0,0)
            Refresh()
        Case "{PGDN}"
            Local $spd=GetPtrSpeed()-1
            if $spd<1 then $spd=1
            SetPtrSpeed($spd)
            SetPtrAccel(0,0,0)
            Refresh()
        Case "+{PGUP}"
            Local $spd=GetPtrSpeed()+1
            if $spd>20 then $spd=20
            SetPtrSpeed($spd)
            SetPtrAccel(1,6,10)
            Refresh()
        Case "+{PGDN}"
            Local $spd=GetPtrSpeed()-1
            if $spd<1 then $spd=1
            SetPtrSpeed($spd)
            SetPtrAccel(1,6,10)
            Refresh()
        Case "{DEL}"
            SetPtrAccel(0,0,0)
            Refresh()
        Case "+{DEL}"
            SetPtrAccel(1,6,10)
            Refresh()
        Case "{END}"
            SetPtrSpeed(10)
            SetPtrAccel(0,0,0)
            Refresh()
        Case "+{END}"
            SetPtrSpeed(10)
            SetPtrAccel(1,6,10)
            Refresh()
        Case "{HOME}"
            SingletonProfiles("recenter")
        Case "+{HOME}"
            Local $a = SingletonPopup(False)
            SingletonProfiles("select",$DEFAULT_PROFILE_NAME)
            SingletonProfiles("recenter")
            if UBound($a)>1 then SingletonProfiles("populate",$a[1])
    EndSwitch
EndFunc