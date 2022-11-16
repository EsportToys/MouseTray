#NoTrayIcon

_Singleton ( 'MouseTray' )

Global Const $PATH_TO_CONFIG_INI = 'options.ini'
Global Const $DEFAULT_PROFILE_NAME = 'Default Mouse Profile'
Global Const $user32dll = DllOpen('user32.dll')

TraySetIcon( GetPtrAccel() ? 'accOn.ico' : '%windir%\Cursors\aero_arrow_xl.cur' )
Opt('GUIOnEventMode', 1)
Opt('TrayOnEventMode', 1)
Opt('TrayMenuMode', 3) ; no default, and don't autocheck
Opt('TrayAutoPause', 0)
Opt('TrayIconHide', 0)
TraySetClick ( 16 )
TraySetOnEvent ( -7 , OnTrayMB1Down )
TraySetOnEvent ( -11, OnTrayHover )

SingletonTray()
SingletonProfiles('initialize')

GUIRegisterMsg(0x00FF, WM_INPUT)
GUIRegisterMsg(0x0006, WM_ACTIVATE)
GUIRegisterMsg(0x0114, WM_HSCROLL)
GUIRegisterMsg(0x020A, WM_MOUSEWHEEL)

Main()

Func Main()
    While Sleep(1000)
    WEnd
EndFunc

Func LostFocus($hWnd)
    SingletonPopup($hWnd,0x0006,0) ; WM_ACTIVATE
EndFunc

Func ShowPreferences()
    SingletonOptions('open')
EndFunc

Func OnTrayMB1Down()
     SingletonPopup()
EndFunc

Func OnTrayHover()
    TraySetToolTip( 'x' & CalculateMultiplier() & ( GetPtrAccel() ? ' - Accel' : ' - Linear' ) )
EndFunc

Func SingletonProfiles($cmd,$arg=Null)
     Local Const $tagProfile = 'uint speed;uint accel;uint thresh1;uint thresh2'
     Local Static $currentProfile, $aProfiles ; save per-profile temporary state in array, first row should load current
     Switch $cmd
       Case 'initialize' ; only called once on application startup. No window so no need to populate dropdown
            Local $aIni = IniReadSection ( $PATH_TO_CONFIG_INI , 'Profiles' )
            If @error Then ; load hardcoded default profile if no ini file found
               Local $a = [[$DEFAULT_PROFILE_NAME,DllStructCreate($tagProfile),DllStructCreate($tagProfile)]]
               DllStructSetData( $a[0][1], 'speed'  , 10 )
               DllStructSetData( $a[0][1], 'accel'  , 0  )
               DllStructSetData( $a[0][1], 'thresh1', 0  )
               DllStructSetData( $a[0][1], 'thresh2', 0  )
            ElseIf $aIni[0][0]>0 Then
               Local $a[ 1+$aIni[0][0] ][ 3 ]
               For $i=0 to $aIni[0][0]
                   $a[$i][0] = $aIni[$i][0] ; element 0,0 is a number but will overwrite later so it's ok
                   Local $s = StringSplit( $aIni[$i][1] , ',' , 2 )
                   If Not (UBound($s)=4) Then 
                      Local $s = [10,0,0,0]
                   EndIf
                   For $j = 1 to 2
                       $a[$i][$j] = DllStructCreate($tagProfile)
                       DllStructSetData( $a[$i][$j], 'speed'  , Number($s[0]) )
                       DllStructSetData( $a[$i][$j], 'accel'  , Number($s[1]) )
                       DllStructSetData( $a[$i][$j], 'thresh1', Number($s[2]) )
                       DllStructSetData( $a[$i][$j], 'thresh2', Number($s[3]) )
                   Next
               Next
               $a[0][0] = $DEFAULT_PROFILE_NAME ; remember to overwrite the loop entry
            Endif
            $aProfiles = $a
            Local $a = [$aProfiles[0][0],$aProfiles[0][1],$aProfiles[0][2]]
            $currentProfile = $a
            Local $spd = GetPtrSpeed(), $acc = GetPtrAccel(True), $lastProf = IniRead( $PATH_TO_CONFIG_INI , 'Cache' , 'selectedProfile' , 'default')
            If not ($lastProf = 'default') Then
               For $i=0 to UBound($aProfiles)-1
                   If $lastProf = $aProfiles[$i][0] Then
                      Local $_ = $aProfiles[$i][1]
                      if $spd = $_.speed and ((0=$acc[0])=(0=$_.accel)) then SingletonProfiles('select',$lastProf)
                   EndIf
               Next 
            EndIf
            DllStructSetData( $currentProfile[2], 'speed'  , $spd    )
            DllStructSetData( $currentProfile[2], 'accel'  , $acc[0] )
            DllStructSetData( $currentProfile[2], 'thresh1', $acc[1] )
            DllStructSetData( $currentProfile[2], 'thresh2', $acc[2] )
       Case 'populate' ; read from static memory rather than reloading ini every time
            If $arg Then
               Local $str = ''
               For $i=0 to UBound($aProfiles)-1
                   $str = $str & "|" & $aProfiles[$i][0]
               Next
               if $str then GUICtrlSetData($arg,$str,$currentProfile[0])
            EndIf
       Case 'select'
            If $arg Then
               For $i=0 to UBound($aProfiles)-1
                   If $arg = $aProfiles[$i][0] Then
                      Local $a = [$aProfiles[$i][0],$aProfiles[$i][1],$aProfiles[$i][2]]
                      $currentProfile = $a
                      Local $_ = $a[2]
                      SetPtrSpeed($_.speed)
                      SetPtrAccel($_.accel,$_.thresh1,$_.thresh2)
                      Refresh()
                      IniWrite( $PATH_TO_CONFIG_INI , 'Cache' , 'selectedProfile' , $arg=$DEFAULT_PROFILE_NAME?'default':$arg )
                      Return ; early return if selection found, otherwise default profile outside loop
                   EndIf
               Next
               Local $a = [$aProfiles[0][0],$aProfiles[0][1],$aProfiles[0][2]]
               $currentProfile = $a
               Local $_ = $a[2]
               SetPtrSpeed($_.speed)
               SetPtrAccel($_.accel,$_.thresh1,$_.thresh2)
               Refresh()
               IniWrite($PATH_TO_CONFIG_INI,'Cache','selectedProfile','default')
            EndIf
       Case 'refresh'
            Local $a = GetPtrAccel(True)
            DllStructSetData( $currentProfile[2], 'speed',   GetPtrSpeed() )
            DllStructSetData( $currentProfile[2], 'accel',   $a[0]         )
            DllStructSetData( $currentProfile[2], 'thresh1', $a[1]         )
            DllStructSetData( $currentProfile[2], 'thresh2', $a[2]         )
       Case 'recenter' ; user shortcut, reset to current profile's default
            Local $_ = $currentProfile[1]
            SetPtrSpeed($_.speed)
            SetPtrAccel($_.accel,$_.thresh1,$_.thresh2)
            Refresh()
       Case 'push'
            If IsArray($arg) and UBound($arg,0)=2 and UBound($arg,1)>0 and UBound($arg,2)=3 Then
               $aProfiles = $arg
               SingletonProfiles('select',$currentProfile[0])
               Local $a=$aProfiles
               ReDim $a[UBound($a)][2]
               For $i=0 to UBound($a)-1
                   Local $_ = $a[$i][1]
                   $a[$i][1] = $_.speed & ',' & $_.accel & ',' & $_.thresh1 & ',' & $_.thresh2
               Next
               IniWriteSection($PATH_TO_CONFIG_INI,"Profiles",$a)
            EndIf
       Case 'query'
            Return $aProfiles
     EndSwitch
EndFunc

Func SingletonOptions($cmd, $arg=Null)
     Local Static $hWnd, $hInput, $hSlider, $hChkBox, $hListView, $hDelete, $aProfiles, $aDevices
     Local Static $lastIndex = 0, $lastString = ''
     Switch $cmd
       Case 'open'
            If IsHwnd($hWnd) Then
               GUISetState(@SW_RESTORE,$hWnd) 
               Local $pos = WinGetPos($hWnd)
               WinMove($hWnd,'',(@DesktopWidth-$pos[2])/2,(@DesktopHeight-$pos[3])/2)
               Return 
            EndIf
            Local $w = 400, $h = 424
            $aProfiles = SingletonProfiles('query')
            ReDim $aProfiles[UBound($aProfiles)][4]

            ; don't make it a taskbar child as it covers up other dialogs.
            $hWnd = GUICreate('Preferences',$w,$h,-1,-1,0x00C00000,0x00000080) ; WS_CAPTION and WS_EX_TOOLWINDOW
            GUICtrlCreateTab ( 8, 8, $w-16+2, $h-44 )
            GUICtrlCreateTabItem('Profiles')

            GUICtrlCreateButton('Save',$w-82,$h-30,75,23)
            GUICtrlSetOnEvent(-1,onEventListApply)
            GUICtrlCreateButton('Cancel',$w-82-81,$h-30,75,23)
            GUICtrlSetOnEvent(-1,CLOSEButton)
            $hDelete = GUICtrlCreateButton('Delete',$w-163-81,$h-30,75,23)
            GUICtrlSetOnEvent(-1,onEventDeleteProfile)
            GUICtrlCreateButton('New',$w-244-81,$h-30,75,23)
            GUICtrlSetOnEvent(-1,onEventCreateProfile)

GUICtrlCreateGroup ( 'Default value for', 21, 40, 357, 99, 0x50000007, 0x00000004 )
GUICtrlCreateLabel ( 'Slow',73,89,26,15,0x50020002,0x00000004 )
GUICtrlCreateLabel ( 'Fast',225,89,24,15,0x50020000,0x00000004 )
GUICtrlCreateIcon ( 'accOn.ico', 1, 30, 61)
$hInput = GUICtrlCreateInput ( $DEFAULT_PROFILE_NAME , 70,58,184,19)
$hChkBox = GUICtrlCreateCheckbox('&Enable pointer acceleration',73,116,227,16)
$hSlider = GUICtrlCreateSlider(102,82,120,26,0x0500) ; TBS_TOOLTIPS+TBS_DOWNISLEFT
GUICtrlSetBkColor($hSlider,0xFFFFFF)
GUICtrlSetLimit($hSlider, 20, 1)
GUICtrlSetData($hSlider, 10)
PopulateTicks($hSlider)

GUICtrlSetState($hInput, 128)  ; $GUI_DISABLE
GUICtrlSetState($hSlider, 128) ; $GUI_DISABLE
GUICtrlSetState($hChkBox, 128) ; $GUI_DISABLE
GUICtrlSetState($hDelete, 128) ; $GUI_DISABLE


            GUICtrlSetOnEvent($hInput,onEventRenameProfile)
            GUICtrlSetOnEvent($hSlider,onEventUpdateProfile)
            GUICtrlSetOnEvent($hChkBox,onEventUpdateProfile)


            $hListView = GUICtrlCreateListView('Name|Speed|Accel|Factor',21,150,357,224,0x800C)
            For $i = 0 to UBound($aProfiles)-1
                Local $_ = $aProfiles[$i][1]
                $aProfiles[$i][3] = GUICtrlCreateListViewItem( $aProfiles[$i][0] & '|' & $_.speed & '|' & $_.accel & '|' & CalculateMultiplier($_.speed,$_.accel) , $hListView )
                GUICtrlSetOnEvent($aProfiles[$i][3],onEventListSelect)
            Next
            GUICtrlSendMsg($hListView, 4126, 0, 192)
            GUICtrlSendMsg($hListView, 4126, 1, 48)
            GUICtrlSendMsg($hListView, 4126, 2, 48)
            GUICtrlSendMsg($hListView, 4126, 3, 48)
;            GUICtrlSendMsg($hListView, 4126, 0, 336)
;            GUICtrlSendMsg($hListView, 4126, 1, 0)
            GUICtrlSetState($aProfiles[0][3],256) ; $GUI_FOCUS
            GUICtrlSetState($hListView,256)       ; $GUI_FOCUS

            GUICtrlCreateTabItem('')
            GUISetState()
            Local $stub = GUICtrlCreateDummy()
            Local $arr = [ ['{UP}',$stub],['{DOWN}',$stub],['{PGUP}',$stub],['{PGDN}',$stub] ]
            GUISetAccelerators ( $arr )
       Case 'detect'
            Local $newIndex = UBound($aDevices)
            ReDim $aDevices[$newIndex+1][2]
            $aDevices[$newIndex][0] = $arg ; handle? or name?
            $aDevices[$newIndex][1] = 'default'
       Case 'create'
            Local $newIndex = UBound($aProfiles)
            Local $newNum = $newIndex
            Local $i = 0
            While $i < $newIndex
               $i += 1
               If $aProfiles[$i-1][0] = 'New Profile ' & $newNum Then 
                  $newNum += 1
                  $i = 0
               EndIf
            WEnd
            Local $newName = 'New Profile ' & $newNum
            ReDim $aProfiles[$newIndex+1][4]
            $aProfiles[$newIndex][0] = $newName
            $aProfiles[$newIndex][1] = DllStructCreate('uint speed;uint accel;uint thresh1;uint thresh2')
            $aProfiles[$newIndex][2] = DllStructCreate('uint speed;uint accel;uint thresh1;uint thresh2')
            For $i=1 to 2
                DllStructSetData($aProfiles[$newIndex][$i], 'speed', 10)
                DllStructSetData($aProfiles[$newIndex][$i], 'accel', 0)
                DllStructSetData($aProfiles[$newIndex][$i], 'thresh1', 0)
                DllStructSetData($aProfiles[$newIndex][$i], 'thresh2', 0)
            Next
            $aProfiles[$newIndex][3] = GUICtrlCreateListViewItem($newName & '|10|0|1',$hListView)
            GUICtrlSetOnEvent($aProfiles[$newIndex][3],onEventListSelect)
            GUICtrlSetState($aProfiles[$newIndex][3],256) ; $GUI_FOCUS
            SingletonOptions('select',$aProfiles[$newIndex][3])
       Case 'delete'
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
               GUICtrlSetState($aProfiles[$index-1][3],256) ; $GUI_FOCUS
               SingletonOptions('select',$aProfiles[$index-1][3])
            Else
               GUICtrlSetState($aProfiles[$index][3],256) ; $GUI_FOCUS
               SingletonOptions('select',$aProfiles[$index][3])
            EndIf
       Case 'rename'
            Local $index = $lastIndex, $str = GUICtrlRead($hInput)
            if $index = 0 then return
            if $str = 'default' or $str = 'default mouse profile' then return GUICtrlSetData($hInput,$lastString)
            $lastString = $str
            For $i=0 to UBound($aProfiles)-1
                If $aProfiles[$i][0]=$str and $i<>$index Then
                   GUICtrlSetState($aProfiles[$i][3],256) ; $GUI_FOCUS
                   SingletonOptions('select',$aProfiles[$i][3])
                   Return
                EndIf
            Next
            $aProfiles[$index][0] = $str
            Local $_ = $aProfiles[$index][1]
            GUICtrlSetData($aProfiles[$index][3],$aProfiles[$index][0] & '|' & $_.speed & '|' & $_.accel & '|' & CalculateMultiplier($_.speed,$_.accel))
       Case 'update'
            Local $index = $lastIndex, $spd = GUICtrlRead($hSlider), $acc = GUICtrlRead($hChkBox)
            if $index = 0 then return
            DllStructSetData( $aProfiles[$index][1], 'speed',   $spd            )
            DllStructSetData( $aProfiles[$index][1], 'accel',   $acc=1 ?  1 : 0 )
            DllStructSetData( $aProfiles[$index][1], 'thresh1', $acc=1 ?  6 : 0 )
            DllStructSetData( $aProfiles[$index][1], 'thresh2', $acc=1 ? 10 : 0 )
            Local $_ = $aProfiles[$index][1]
            GUICtrlSetData($aProfiles[$index][3],$aProfiles[$index][0] & '|' & $_.speed & '|' & $_.accel & '|' & CalculateMultiplier($_.speed,$_.accel))
            DllStructSetData( $aProfiles[$index][2], 'speed',   $spd                       )
            DllStructSetData( $aProfiles[$index][2], 'accel',   $acc=1 ?  1 : 0 )
            DllStructSetData( $aProfiles[$index][2], 'thresh1', $acc=1 ?  6 : 0 )
            DllStructSetData( $aProfiles[$index][2], 'thresh2', $acc=1 ? 10 : 0 )
       Case 'select'
            Local $index = SingletonOptions('queryindex',$arg)
            GUICtrlSetData( $hInput , $aProfiles[$index][0])
            GUICtrlSetData( $hSlider,DllStructGetData($aProfiles[$index][1],'speed'))
            GUICtrlSetState($hChkBox,DllStructGetData($aProfiles[$index][1],'accel')?1:4)
            If $index = 0 Then
               GUICtrlSetState($hInput,  128) ; $GUI_DISABLE
               GUICtrlSetState($hDelete, 128) ; $GUI_DISABLE
               GUICtrlSetState($hChkBox, 128) ; $GUI_DISABLE
               GUICtrlSetState($hSlider, 128) ; $GUI_DISABLE
            Else
               GUICtrlSetState($hInput,  64) ; $GUI_ENABLE
               GUICtrlSetState($hDelete, 64) ; $GUI_ENABLE
               GUICtrlSetState($hChkBox, 64) ; $GUI_ENABLE
               GUICtrlSetState($hSlider, 64) ; $GUI_ENABLE
            EndIf
            $lastIndex = $index
            $lastString = $aProfiles[$index][0]
       Case 'apply'
            Local $a = $aProfiles
            ReDim $a[UBound($aProfiles)][3]
            SingletonProfiles('push',$a)
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
        TrayCreateItem ( 'Enable wheel shortcuts' ), _
        TrayCreateItem ( 'Preferences...' ), _
        TrayCreateItem ( '' ), _
        TrayCreateMenu ( 'Control Panel' ), _
        TrayCreateMenu ( 'Settings App' ), _
        TrayCreateItem ( '' ), _
        TrayCreateItem ( 'Exit' ) _
    ]
    If $init Then
       $init = False
       $n = UBound($tray)
       TrayItemSetOnEvent ($tray[0], ToggleShortcuts )
       TrayItemSetOnEvent ($tray[1], OpenToolPrefs )
       TrayItemSetOnEvent (TrayCreateItem('Mouse',$tray[$n-4]), OpenCplMouse )
       TrayItemSetOnEvent (TrayCreateItem('Mouse',$tray[$n-3]), OpenUwpMouse )
       TrayItemSetOnEvent (TrayCreateItem('Keyboard',$tray[$n-4]), OpenCplKeyboard )
       TrayItemSetOnEvent (TrayCreateItem('Touchpad',$tray[$n-3]), OpenUwpTouchpad )
       TrayItemSetOnEvent ($tray[$n-1], ExitApp )
    EndIf
#cs
    If $msg Then
        Switch $msg
          Case Else
        EndSwitch
    EndIf
#ce
EndFunc

Func SingletonPopup($hWnd=Null, $iMsg=Null, $iwParam=Null, $ilParam=Null)
  Local Static $hDropdn = Null, $hNum = Null, $hAccIco = Null, $hSlider = Null, $hPopup = Null
  Switch $iMsg
    Case 0x0006 ; WM_ACTIVATE
      if $iwParam==0 and $hWnd=$hPopup then GUIDelete($hWnd)
    Case Null
      If $hWnd==Null Then
        if IsHwnd($hPopup) then return GUISetState(@SW_RESTORE,$hPopup)
        Local $l, $t, $w = 360, $h = 100
        Local $hSysTray = WinGetHandle('[Class:Shell_TrayWnd]')
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
        $hPopup = GUICreate('',$w,$h,$l,$t,0x80000000,0x00000008,$hSysTray) ; WS_POPUP and WS_EX_TOPMOST
        WinSetTrans ( $hPopup, '', 240 )
        GUISetAccelerators ( PopupAccelerators() )
        $hNum = GUICtrlCreateLabel(CalculateMultiplier(),($w-248)/2+250,$h-46,50,40,0x1) ; $SS_CENTER
        GUICtrlSetFont($hNum, 18, 0, 0, 'Segoe UI')
        GUICtrlSetColor($hNum, 0xFFFFFF)
        GUISetBkColor(0x1f1f1f)

        $hAccIco = GUICtrlCreateIcon ( GetPtrAccel()?'accOn.ico':'accOff.ico' , 1 , 19 , $h-44)
        $hDropdn = GUICtrlCreateCombo($DEFAULT_PROFILE_NAME,7,8,$w-14,-1, 0x00200000+0x3) ; WS_VSCROLL + CBS_DROPDOWNLIST
        GUICtrlSetFont($hDropdn, 11.5, 0, 0, 'Segoe UI')
        GUICtrlSetBkColor($hDropdn,0x1f1f1f)
        SingletonProfiles('populate',$hDropdn)

        $hSlider = GUICtrlCreateSlider(($w-248)/2,$h-49,250,42,0x0508) ; TBS_TOOLTIPS+TBS_DOWNISLEFT+TBS_BOTH
        GUICtrlSetBkColor($hSlider, 0x1f1f1f)
        GUICtrlSetLimit($hSlider, 20, 1)
        GUICtrlSetData($hSlider, 10)
        PopulateTicks($hSlider)
        GUICtrlSetState($hDropDn, 256) 
        GUICtrlSetOnEvent($hAccIco,onAccIcoEvent)
        GUICtrlSetOnEvent($hDropdn,onDropdnEvent)
        GUISetState()
      EndIf
      SingletonProfiles('refresh')
      Local $acc = GetPtrAccel()
      TraySetIcon($acc?'accOn.ico':'%windir%\Cursors\aero_arrow_xl.cur')
      if not IsHWnd($hPopup) then return
      if $hWnd then return GUISetState(@SW_RESTORE,$hPopup)
      GUICtrlSetData($hSlider, GetPtrSpeed())
      GUICtrlSetData($hNum, CalculateMultiplier())
      GUICtrlSetImage($hAccIco,$acc?'accOn.ico':'accOff.ico',1)
      GUICtrlSetTip( $hAccIco, GetPtrAccel()?'Acceleration ON':'No Acceleration' )
      Local $ret = [$hPopup, $hDropdn, $hAccIco, $hSlider, $hNum]
      Return $ret
    Case 0x0114 ; WM_HSCROLL
      if not ($hPopup and $hWnd = $hPopup) then return
      Local $hw = BitShift($iWParam, 16), $lw = BitAND($iWParam, 0xFFFF)
      if $lw = 5 or $lw = 4 then GUICtrlSetData($hNum, CalculateMultiplier($hw))
      if $lw = 8 or $lw = 4 then SetPtrSpeed(GUICtrlRead($hSlider))
      if $lw = 8 then Refresh()
    Case 0x020A ; WM_MOUSEWHEEL received when scrolling with cursor over window but not slider itself
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

Func SingletonRawInput($cmd, $arg=Null)
     Local Static $hWnd = GUICreate('')
     Local $struct = DllStructCreate('struct;ushort UsagePage;ushort Usage;dword Flags;hwnd Target;endstruct')
     $struct.UsagePage = 0x01 ; Generic Desktop Controls
     $struct.Usage     = 0x02 ; Mouse
     Switch $cmd
       Case 'enable'
            GUIRegisterMsg(0x00FF,WM_INPUT)
            $struct.Flags = 0x00000100+0x00002000 ; RIDEV_INPUTSINK+RIDEV_DEVNOTIFY
            $struct.Target = $hWnd
            If Not DllCall($user32dll, 'bool', 'RegisterRawInputDevices', 'struct*', $struct, 'uint', 1, 'uint', DllStructGetSize($struct))[0] Then Exit
       Case 'disable'
            $struct.Flags = 0x00000001 ; RIDEV_REMOVE
            $struct.Target = Null
            If Not DllCall($user32dll, 'bool', 'RegisterRawInputDevices', 'struct*', $struct, 'uint', 1, 'uint', DllStructGetSize($struct))[0] Then Exit
            GUIRegisterMsg(0x00FF,'')
     EndSwitch
EndFunc

Func WM_INPUT($hWnd, $iMsg, $iwParam, $ilParam)
     Local Static $tRIM = 'struct;dword Type;dword Size;handle hDevice;wparam wParam;endstruct;ushort Flags;ushort Alignment;ushort ButtonFlags;short ButtonData;ulong RawButtons;long LastX;long LastY;ulong ExtraInformation;'
     Local Static $RIMSize = DllStructGetSize(DllStructCreate($tRIM))
     Local Static $RIHeaderSize = DllStructGetSize(DllStructCreate('struct;dword Type;dword Size;handle hDevice;wparam wParam;endstruct'))
     Local $_ = DllCall($user32dll, 'uint', 'GetRawInputData', 'handle', $ilParam, 'uint', 0x10000003, 'struct*', DllStructCreate($tRIM), 'uint*', $RIMSize, 'uint', $RIHeaderSize)[3]
     If $_.ButtonFlags Then
        If BitAND(0x8000,DllCall($user32dll, 'short', 'GetAsyncKeyState', 'int', 0x14)[0]) then
           If BitAnd(16,$_.ButtonFlags) Then            ; or BitAnd(32,$_.ButtonFlags) Then
              AcceleratorCallbacks( BitAND(0x8000,DllCall($user32dll, 'short', 'GetAsyncKeyState', 'int', 0x10)[0]) ? '+{HOME}' : '{HOME}' )
           ElseIf $_.ButtonData = 120 Then
              AcceleratorCallbacks( '=' )
           ElseIf $_.ButtonData = -120 Then
              AcceleratorCallbacks( '-' )
           Endif
        Endif
     EndIf
     If $iwParam Then Return 0    
EndFunc

Func WM_ACTIVATE($hWnd, $iMsg, $iwParam, $ilParam)
    if Not $iwParam then LostFocus($hWnd)
    Return 'GUI_RUNDEFMSG'
EndFunc

Func WM_HSCROLL($hWnd, $iMsg, $iwParam, $ilParam)
    SingletonPopup($hWnd, $iMsg, $iwParam, $ilParam)
    Return 'GUI_RUNDEFMSG'
EndFunc

Func WM_MOUSEWHEEL($hWnd, $iMsg, $iwParam, $ilParam)
    SingletonPopup($hWnd, $iMsg, $iwParam, $ilParam)
    Return 'GUI_RUNDEFMSG'
EndFunc

Func CloseButton()
    GUIDelete( @GUI_WinHandle )
EndFunc

Func ExitApp()
     Exit
EndFunc

Func ToggleShortcuts()
     Local $state = TrayItemGetState(@TRAY_ID)
     If BitAnd(1,$state) Then ; currently checked
        TrayItemSetState( @TRAY_ID , 4 ) ; uncheck it
        SingletonRawInput('disable')
     Else 
        TrayItemSetState( @TRAY_ID , 1 ) ; check it
        SingletonRawInput('enable')
     EndIf
EndFunc

Func OpenCplMouse()
    ShellExecute ( 'main.cpl' )
EndFunc

Func OpenCplKeyboard()
    ShellExecute ( 'main.cpl' , 'keyboard' )
EndFunc

Func OpenUwpMouse()
    ShellExecute ( 'ms-settings:mousetouchpad' )
EndFunc

Func OpenUwpTouchpad()
    ShellExecute ( 'ms-settings:devices-touchpad' )
EndFunc

Func OpenToolPrefs()
    ShowPreferences()
EndFunc

Func Refresh()
    SingletonPopup(False)
EndFunc

Func ReFocus()
    SingletonPopup(True)
EndFunc

Func onDropdnEvent()
    SingletonProfiles('select',GUICtrlRead(@GUI_CtrlID))
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
    SingletonOptions('select',@GUI_CtrlId)
EndFunc

Func onEventListApply()
    SingletonOptions('apply',@GUI_CtrlId)
EndFunc

Func onEventCreateProfile()
    SingletonOptions('create')
EndFunc

Func onEventDeleteProfile()
    SingletonOptions('delete')
EndFunc

Func onEventRenameProfile()
    SingletonOptions('rename')
EndFunc

Func onEventUpdateProfile()
    SingletonOptions('update')
EndFunc

Func IncrementPointerSpeed()
    AcceleratorCallbacks('=')
EndFunc

Func DecrementPointerSpeed()
    AcceleratorCallbacks('-')
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
     Return DllCall($user32dll, 'bool', 'SystemParametersInfoW', 'uint', 0x0070, 'uint', 0, 'uint*', 0, 'uint', 0)[3]
EndFunc

Func SetPtrSpeed($val, $flag=1)
     DllCall($user32dll, 'bool', 'SystemParametersInfoW', 'uint', 0x0071, 'uint', 0, 'uint', $val, 'uint', $flag)
EndFunc

Func GetPtrAccel($advanced=False)
     Local $retval, $struct = DllCall($user32dll, 'bool', 'SystemParametersInfoW', 'uint', 0x0003, 'uint', 0, 'struct*', DllStructCreate('uint thresh1;uint thresh2;uint accel'), 'uint', 0)[3]
     If $advanced Then 
        Local $arr = [$struct.accel,$struct.thresh1,$struct.thresh2]
        Return $arr
     Else
        Return $struct.accel
     EndIf
EndFunc

Func SetPtrAccel($accel,$thresh1,$thresh2,$flag=1)
     Local $struct = DllStructCreate('uint thresh1;uint thresh2;uint accel')
     $struct.thresh1 = $thresh1
     $struct.thresh2 = $thresh2
     $struct.accel   = $accel
     DllCall($user32dll, 'bool', 'SystemParametersInfoW', 'uint', 0x0004, 'uint', 0, 'struct*', $struct, 'uint', $flag)
EndFunc

Func CalculateMultiplier($speed=GetPtrSpeed(),$accel=GetPtrAccel())
    if $accel    then return ( $speed=10 ? '1.0' : $speed/10 )
    if $speed<3  then return '1/' & 32/$speed
    if $speed<10 then return $speed-2 & '/8'
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

Func PopulateTicks($hSlider)
     DllCall($user32dll, "lresult", "SendMessage", "hwnd", GUICtrlGetHandle($hSlider), "uint", 0x404, "wparam", 0, "lparam", 2)
     DllCall($user32dll, "lresult", "SendMessage", "hwnd", GUICtrlGetHandle($hSlider), "uint", 0x404, "wparam", 0, "lparam", 4)
     DllCall($user32dll, "lresult", "SendMessage", "hwnd", GUICtrlGetHandle($hSlider), "uint", 0x404, "wparam", 0, "lparam", 6)
     DllCall($user32dll, "lresult", "SendMessage", "hwnd", GUICtrlGetHandle($hSlider), "uint", 0x404, "wparam", 0, "lparam", 8)
     DllCall($user32dll, "lresult", "SendMessage", "hwnd", GUICtrlGetHandle($hSlider), "uint", 0x404, "wparam", 0, "lparam", 10)
     DllCall($user32dll, "lresult", "SendMessage", "hwnd", GUICtrlGetHandle($hSlider), "uint", 0x404, "wparam", 0, "lparam", 12)
     DllCall($user32dll, "lresult", "SendMessage", "hwnd", GUICtrlGetHandle($hSlider), "uint", 0x404, "wparam", 0, "lparam", 14)
     DllCall($user32dll, "lresult", "SendMessage", "hwnd", GUICtrlGetHandle($hSlider), "uint", 0x404, "wparam", 0, "lparam", 16)
     DllCall($user32dll, "lresult", "SendMessage", "hwnd", GUICtrlGetHandle($hSlider), "uint", 0x404, "wparam", 0, "lparam", 18)
EndFunc

; #FUNCTION# ====================================================================================================================
; Author ........: Valik
; Modified.......:
; ===============================================================================================================================
Func _Singleton($sOccurrenceName, $iFlag = 0)
	Local Const $ERROR_ALREADY_EXISTS = 183
	Local Const $SECURITY_DESCRIPTOR_REVISION = 1
	Local $tSecurityAttributes = 0

	If BitAND($iFlag, 2) Then
		; The size of SECURITY_DESCRIPTOR is 20 bytes.  We just
		; need a block of memory the right size, we aren't going to
		; access any members directly so it's not important what
		; the members are, just that the total size is correct.
		Local $tSecurityDescriptor = DllStructCreate("byte;byte;word;ptr[4]")
		; Initialize the security descriptor.
		Local $aCall = DllCall("advapi32.dll", "bool", "InitializeSecurityDescriptor", _
				"struct*", $tSecurityDescriptor, "dword", $SECURITY_DESCRIPTOR_REVISION)
		If @error Then Return SetError(@error, @extended, 0)
		If $aCall[0] Then
			; Add the NULL DACL specifying access to everybody.
			$aCall = DllCall("advapi32.dll", "bool", "SetSecurityDescriptorDacl", _
					"struct*", $tSecurityDescriptor, "bool", 1, "ptr", 0, "bool", 0)
			If @error Then Return SetError(@error, @extended, 0)
			If $aCall[0] Then
				; Create a SECURITY_ATTRIBUTES structure.
				$tSecurityAttributes = DllStructCreate($tagSECURITY_ATTRIBUTES)
				; Assign the members.
				DllStructSetData($tSecurityAttributes, 1, DllStructGetSize($tSecurityAttributes))
				DllStructSetData($tSecurityAttributes, 2, DllStructGetPtr($tSecurityDescriptor))
				DllStructSetData($tSecurityAttributes, 3, 0)
			EndIf
		EndIf
	EndIf

	Local $aHandle = DllCall("kernel32.dll", "handle", "CreateMutexW", "struct*", $tSecurityAttributes, "bool", 1, "wstr", $sOccurrenceName)
	If @error Then Return SetError(@error, @extended, 0)
	Local $aLastError = DllCall("kernel32.dll", "dword", "GetLastError")
	If @error Then Return SetError(@error, @extended, 0)
	If $aLastError[0] = $ERROR_ALREADY_EXISTS Then
		If BitAND($iFlag, 1) Then
			DllCall("kernel32.dll", "bool", "CloseHandle", "handle", $aHandle[0])
			If @error Then Return SetError(@error, @extended, 0)
			Return SetError($aLastError[0], $aLastError[0], 0)
		Else
			Exit -1
		EndIf
	EndIf
	Return $aHandle[0]
EndFunc   ;==>_Singleton
