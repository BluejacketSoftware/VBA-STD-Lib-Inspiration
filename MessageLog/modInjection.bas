Attribute VB_Name = "modInjection"
Option Explicit

' ������ ��� ��������� � ����� ������� � ������� ������� ���������, � ����� �������� ��� ��������� ����������� ����
' � ������� �������� ����������� (The trick), 2014


' ******                  ******* **                                         *            **
'  *    *                 *  *  *  *                        *                              *
'  *    *                    *     *                        *                              *
'  *    * *** ***            *     * **    *****           ****   *** **   ***     *****   *  **
'  *****   *   *             *     **  *  *     *           *       **  *    *    *     *  *  *
'  *    *  *   *             *     *   *  *******           *       *        *    *        * *
'  *    *   * *              *     *   *  *                 *       *        *    *        ***
'  *    *   * *              *     *   *  *     *           *  *    *        *    *     *  *  *
' ******     *              ***   *** ***  *****             **   *****    *****   *****  **   **
'            *
'          **

Private Type MessageInfo                    ' ��� ��������� �������� � �������� ��������� ������ ����
    Msg As Long
    wParam As Long
    lParam As Long
End Type
Private Type TrickThreadData
    SrcWnd As Long                          ' ����� ���������������� ����
    DesthWnd As Long                        ' ����� ���� frmSpy
    EventHandle As Long                     ' ����� �������, ����������� �� ���������� ������
    AddrWindowProc As Long                  ' ����� ������� WindowProc � ����� ��������
    AddrStructure As Long                   ' ����� ���� ���������
    Msg As MessageInfo                      ' ��� �������� ��������� COPYDATASTRUCT
End Type
Private Type COPYDATASTRUCT
    dwData As Long
    cbData As Long
    lpData As Long
End Type

Private Declare Function SetWindowLong Lib "user32" Alias "SetWindowLongA" (ByVal hwnd As Long, ByVal nIndex As Long, ByVal dwNewLong As Long) As Long
Private Declare Function VirtualAllocEx Lib "kernel32.dll" (ByVal hProcess As Long, lpAddress As Any, ByVal dwSize As Long, ByVal flAllocationType As Long, ByVal flProtect As Long) As Long
Private Declare Function VirtualFreeEx Lib "kernel32.dll" (ByVal hProcess As Long, lpAddress As Any, ByVal dwSize As Long, ByVal dwFreeType As Long) As Long
Private Declare Function WriteProcessMemory Lib "kernel32" (ByVal hProcess As Long, ByVal lpBaseAddress As Long, lpBuffer As Any, ByVal nSize As Long, lpNumberOfBytesWritten As Long) As Long
Private Declare Function CreateRemoteThread Lib "kernel32" (ByVal hProcess As Long, lpThreadAttributes As Any, ByVal dwStackSize As Long, ByVal lpStartAddress As Long, lpParameter As Any, ByVal dwCreationFlags As Long, lpThreadId As Long) As Long
Private Declare Function GetMem4 Lib "msvbvm60" (src As Any, dst As Any) As Long
Private Declare Function CloseHandle Lib "kernel32" (ByVal hObject As Long) As Long
Private Declare Function GetWindowThreadProcessId Lib "user32" (ByVal hwnd As Long, lpdwProcessId As Long) As Long
Private Declare Function OpenProcess Lib "kernel32" (ByVal dwDesiredAccess As Long, ByVal bInheritHandle As Long, ByVal dwProcessId As Long) As Long
Private Declare Function CreateEvent Lib "kernel32" Alias "CreateEventA" (lpEventAttributes As Any, ByVal bManualReset As Long, ByVal bInitialState As Long, lpName As Any) As Long
Private Declare Function PulseEvent Lib "kernel32" (ByVal hEvent As Long) As Long
Private Declare Function DuplicateHandle Lib "kernel32" (ByVal hSourceProcessHandle As Long, ByVal hSourceHandle As Long, ByVal hTargetProcessHandle As Long, lpTargetHandle As Long, ByVal dwDesiredAccess As Long, ByVal bInheritHandle As Long, ByVal dwOptions As Long) As Long
Private Declare Function GetCurrentProcess Lib "kernel32" () As Long
Private Declare Function GetModuleHandle Lib "kernel32" Alias "GetModuleHandleA" (ByVal lpModuleName As String) As Long
Private Declare Function GetProcAddress Lib "kernel32" (ByVal hModule As Long, ByVal lpProcName As String) As Long
Private Declare Sub CopyMemory Lib "kernel32" Alias "RtlMoveMemory" (Destination As Any, Source As Any, ByVal Length As Long)
Private Declare Function WaitForSingleObject Lib "kernel32" (ByVal hHandle As Long, ByVal dwMilliseconds As Long) As Long
Private Declare Function CallWindowProc Lib "user32" Alias "CallWindowProcA" (ByVal lpPrevWndFunc As Long, ByVal hwnd As Long, ByVal Msg As Long, ByVal wParam As Long, lParam As Any) As Long

Private Const WM_COPYDATA = &H4A
Private Const GWL_WNDPROC = (-4)
Private Const DUPLICATE_SAME_ACCESS = &H2
Private Const PROCESS_ALL_ACCESS = &H1F0FFF
Private Const MEM_COMMIT = &H1000&
Private Const MEM_RESERVE = &H2000&
Private Const MEM_RELEASE = &H8000&
Private Const PAGE_EXECUTE_READWRITE = &H40&
Private Const INFINITE = -1&

Private Const Prop As String = "pInject"                    ' 7 �������� + \0, ����� 8 ����, ������ ���������� � ���������� ���� Currency
Private Const PropCur As Currency = 3276038452689.5472@     ' ������ Prop � ���� Currecy �����

Public hProcess As Long                                     ' ����� ��������, � ������� ����������
Public hThread As Long                                      ' ����� ������, ������� �� �������� � ����� ��������
Public TID As Long                                          ' ������������� ����� ������
Public lpProc As Long                                       ' ����� ������� InjectionProc
Public Size As Long                                         ' ������ ������ � ����, ����������� � �������
Public hEvent As Long                                       ' ��������� ������� � ����� ��������

Dim lpPrevWndProc As Long                                   ' ����� ������� ��������� frmSpy (�����������)

' ������� �������� ��� � ����� �������
Public Function Hook(hwnd As Long) As Boolean
    Dim Buf() As Byte, ret As Long, PID As Long, DupHandle As Long, nearWndProc As Long, _
        FuncOf() As Long, FuncAddr() As Long, hMod As Long, lpFunc As Long, i As Long, lpData As Long
        
    If hProcess Then Clear                   ' ���� �������� ���, �� �������
    GetWindowThreadProcessId hwnd, PID
    
    ' ������������� �������
    If modListView.Dic Is Nothing Then modListView.DicInit
    
    If PID Then hProcess = OpenProcess(PROCESS_ALL_ACCESS, False, PID) Else Exit Function

    ' ������� ������� ��� ���������� �������
    hEvent = CreateEvent(ByVal 0, 1, 0, ByVal 0)

    If hEvent = 0 Then Clear: Exit Function
    ' ������� �������� ��������� ������� ��� ��������
    If DuplicateHandle(GetCurrentProcess(), hEvent, hProcess, DupHandle, 0, False, DUPLICATE_SAME_ACCESS) = 0 Then Clear: Exit Function

    ' ���������� ������ ��� ����������� ����
    lpData = AddrOf(AddressOf AddrOf) - AddrOf(AddressOf InjectionProc)
    ' ���������� ������������� �������� ������� WindowProc �� ������
    nearWndProc = AddrOf(AddressOf AddrOf) - AddrOf(AddressOf WindowProc)
    ' ���������� ������ ������ � ����
    Size = lpData + 32

    ' �������� ������ � ����� ��������
    lpProc = VirtualAllocEx(hProcess, ByVal 0, Size, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If lpProc = 0 Then MsgBox "Error allocate memory", vbCritical: Clear: Exit Function

    ' ���������� �������� ��� ������������� API ������������ ������ ������
    ReDim FuncOf(9)
    FuncOf(0) = AddrOf(AddressOf myCopyMemory) - AddrOf(AddressOf InjectionProc)
    FuncOf(1) = AddrOf(AddressOf myCopyMemory2) - AddrOf(AddressOf InjectionProc)
    FuncOf(2) = AddrOf(AddressOf myCloseHandle) - AddrOf(AddressOf InjectionProc)
    FuncOf(3) = AddrOf(AddressOf myWaitForSingleObject) - AddrOf(AddressOf InjectionProc)
    FuncOf(4) = AddrOf(AddressOf mySetProp) - AddrOf(AddressOf InjectionProc)
    FuncOf(5) = AddrOf(AddressOf myGetProp) - AddrOf(AddressOf InjectionProc)
    FuncOf(6) = AddrOf(AddressOf myRemoveProp) - AddrOf(AddressOf InjectionProc)
    FuncOf(7) = AddrOf(AddressOf mySetWindowLong) - AddrOf(AddressOf InjectionProc)
    FuncOf(8) = AddrOf(AddressOf mySendMessage) - AddrOf(AddressOf InjectionProc)
    FuncOf(9) = AddrOf(AddressOf myCallWindowProc) - AddrOf(AddressOf InjectionProc)

    ' ���������� ������ API �������, ��� ��������� ��������� �� ������ ������������� �� ������ � ������ ������ ��� � � ���
    ReDim FuncAddr(9)
    hMod = GetModuleHandle("kernel32")
    FuncAddr(0) = GetProcAddress(hMod, "RtlMoveMemory")
    FuncAddr(1) = FuncAddr(0)
    FuncAddr(2) = GetProcAddress(hMod, "CloseHandle")
    FuncAddr(3) = GetProcAddress(hMod, "WaitForSingleObject")
    hMod = GetModuleHandle("user32")
    FuncAddr(4) = GetProcAddress(hMod, "SetPropA")
    FuncAddr(5) = GetProcAddress(hMod, "GetPropA")
    FuncAddr(6) = GetProcAddress(hMod, "RemovePropA")
    FuncAddr(7) = GetProcAddress(hMod, "SetWindowLongA")
    FuncAddr(8) = GetProcAddress(hMod, "SendMessageA")
    FuncAddr(9) = GetProcAddress(hMod, "CallWindowProcA")

    ' �������� ���
    ReDim Buf(Size - 1)
    CopyMemory Buf(0), ByVal AddrOf(AddressOf InjectionProc), lpData

    ' ������������ ��� ��� ������ API ������ ����� ��������
    For i = 0 To UBound(FuncOf)
        Buf(FuncOf(i)) = &HE9                                                   ' JMP
        GetMem4 (FuncAddr(i) - FuncOf(i) - lpProc) - 5, Buf(FuncOf(i) + 1)      ' near (������������� ������ �� API �������)
    Next

    ' �������� ������
    GetMem4 hwnd, Buf(lpData)                                                   ' ����� ���������������� ����
    GetMem4 frmSpy.hwnd, Buf(lpData + 4)                                        ' ����� ����-���������
    GetMem4 DupHandle, Buf(lpData + 8)                                          ' ����� �������
    GetMem4 lpProc + lpData - nearWndProc, Buf(lpData + 12)                     ' ����� WindowProc � ����� ��������
    GetMem4 lpProc + lpData, Buf(lpData + 16)                                   ' ����� ���� ��������� � ����� ��������
    
    ' ������ ��������
    If WriteProcessMemory(hProcess, lpProc, Buf(0), Size, ret) Then
        If ret <> Size Then MsgBox "Error write process", vbCritical: Clear: Exit Function
        ' ��������� ��� ��������
        hThread = CreateRemoteThread(hProcess, ByVal 0, 0, lpProc, ByVal lpProc + Size - 32, 0, TID)
        If hThread = 0 Then MsgBox "Error create thread", vbCritical: Clear: Exit Function
    End If
    
    lpPrevWndProc = SetWindowLong(frmSpy.hwnd, GWL_WNDPROC, AddressOf SpyWindowProc)     ' ���������� ���� ����
    
    Hook = True
End Function

' ������� ��������
Public Sub Clear()
    If lpPrevWndProc Then
        SetWindowLong frmSpy.hwnd, GWL_WNDPROC, lpPrevWndProc       ' ������� �����������
        lpPrevWndProc = 0
    End If
    If hThread Then
        PulseEvent hEvent                                           ' ��������� ���������� ������
        WaitForSingleObject hThread, INFINITE                       ' ���� ���������� ������ (��������������)
        CloseHandle hThread                                         ' ��������� ��������� ������
        hThread = 0
    End If
    If lpProc Then
        Call VirtualFreeEx(hProcess, ByVal lpProc, 0, MEM_RELEASE)  ' ����������� ���������� ������
    End If
    If hProcess Then
        CloseHandle hProcess                                        ' ��������� ��������� ��������
        hProcess = 0
    End If
    If hEvent Then
        CloseHandle hEvent                                          ' ��������� ��������� ������� (������ ���� ��������)
        hEvent = 0
    End If
End Sub
' ������� ��������� ��� ������������ ��������� �� ������ ��������
Private Function SpyWindowProc(ByVal hwnd As Long, ByVal Msg As Long, ByVal wParam As Long, ByVal lParam As Long) As Long
    Dim CDS As COPYDATASTRUCT, Info As MessageInfo
    
    If Msg = WM_COPYDATA Then
        ' �������� ��������� �� ���� ��������!!!
        CopyMemory CDS, ByVal lParam, Len(CDS)
        CopyMemory Info, ByVal CDS.lpData, CDS.cbData
        ItemAdd modListView.GetMessageName(Info.Msg), Info.wParam, Info.lParam
    End If
    
    ' ������������ ��� � ������
    SpyWindowProc = CallWindowProc(lpPrevWndProc, hwnd, Msg, wParam, ByVal lParam)
End Function

' ������ ��� ����������� � �� ������ ��������, ������� �� �� ����� ������� �� � ����� ���������� ��� ��������� ����������
' ������ ����� ������, ������������ ������� ������ � ������� �� ����� �������� ����������� ��� ���������� �� ���������
' TrickThreadData, ������� � ����������� ����������� � �������� ���� 'pInject'. ����� ����� �������, ����� � ��������������
' � ��������������� API ��������. ����� ����������� ���, ������� ������ �� ���������� �������. ��� ������������� �������
' �������� (������ � �������� ������� �� ������� ������������� ��������� ������), ����� ��� �������������� ���������, �����
' LoadLibrary() � �������� ������ ������� ����� GetProcAddress(). ��� ���������� ����� � ����������, ����� ������� �
' � ���������� ��� ����� �������������� ������. ��� ��� ��������� � ����� ���������� ���������� ��� ���������
' (������ s$="VB6 best language") ����� ������� ������ �������

' \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
' ���������, ����������� � ����� ��������, �������� �� ��������� �� ������
Private Sub InjectionProc(Dat As TrickThreadData)
    Dim lpOldProc As Long
    ' �� � ����� �������� ))
    mySetProp Dat.SrcWnd, PropCur, Dat.AddrStructure                         ' ������������� ���� �������� � ���������� �� ������
    lpOldProc = mySetWindowLong(Dat.SrcWnd, GWL_WNDPROC, Dat.AddrWindowProc) ' ������������� ���� ����� ������� ����������
    ' ������ ������ ������ ��������� ����� ������
    Dat.AddrWindowProc = lpOldProc
    ' ������������ �����
    myWaitForSingleObject Dat.EventHandle, INFINITE
    ' ����� ����������, ������ ���� ���������� ��� �� �����
    mySetWindowLong Dat.SrcWnd, GWL_WNDPROC, Dat.AddrWindowProc
    myRemoveProp Dat.SrcWnd, PropCur
    ' ��������� ��������� �������
    myCloseHandle Dat.EventHandle
    ' ��� ����� ��������, ������ Clear ������������ � ������� ���������� ������
End Sub

' �������� ������ ��������������� API c ������� ����������
Private Function myCopyMemory(dst As TrickThreadData, ByVal src As Long, ByVal Length As Long) As Long
    myCopyMemory = -1
End Function
Private Function myCopyMemory2(ByVal dst As Long, src As TrickThreadData, ByVal Length As Long) As Long
    myCopyMemory2 = -2
End Function
Private Function mySetProp(ByVal hwnd As Long, ByRef Name As Currency, ByVal Value As Long) As Long
    mySetProp = -3
End Function
Private Function myGetProp(ByVal hwnd As Long, ByRef Name As Currency) As Long
    myGetProp = -4
End Function
Private Function myRemoveProp(ByVal hwnd As Long, ByRef Name As Currency) As Long
    myRemoveProp = -5
End Function
Private Function mySetWindowLong(ByVal hwnd As Long, ByVal Index As Long, ByVal Data As Long) As Long
    mySetWindowLong = -6
End Function
Private Function myWaitForSingleObject(ByVal hEvent As Long, ByVal Millisecond As Long) As Long
    myWaitForSingleObject = -7
End Function
Private Function mySendMessage(ByVal hwnd As Long, ByVal Msg As Long, ByVal wParam As Long, lParam As COPYDATASTRUCT) As Long
    mySendMessage = -8
End Function
Private Function myCallWindowProc(ByVal addr As Long, ByVal hwnd As Long, ByVal Msg As Long, ByVal wParam As Long, ByVal lParam As Long) As Long
    myCallWindowProc = -9
End Function
Private Function myCloseHandle(ByVal Handle As Long) As Long
    myCloseHandle = -10
End Function
' ������� �������, ������� ����� �������� � ����� ��������
Private Function WindowProc(ByVal hwnd As Long, ByVal uMsg As Long, ByVal wParam As Long, ByVal lParam As Long) As Long
    Dim lpDat As Long, Dat As TrickThreadData, CDS As COPYDATASTRUCT
    
    lpDat = myGetProp(hwnd, PropCur)

    myCopyMemory Dat, lpDat, Len(Dat)                   ' �������� ���������
    
    ' ������������� ��������� ���������
    Dat.Msg.Msg = uMsg
    Dat.Msg.wParam = wParam
    Dat.Msg.lParam = lParam
    
    myCopyMemory2 lpDat, Dat, Len(Dat)                  ' �������� ��������� �������
    
    CDS.cbData = Len(Dat.Msg)
    CDS.lpData = lpDat + 20                             ' �������� ��������� MessageInfo, ������������ ������
    
    ' ���������� ������ ���� �����������
    mySendMessage Dat.DesthWnd, WM_COPYDATA, hwnd, CDS
    
    ' �������� ��������� �� ���������
    WindowProc = myCallWindowProc(Dat.AddrWindowProc, hwnd, uMsg, wParam, lParam)
End Function
' \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
' ��� ������� ����� ������ �������� ����� ������� � � ������� �� ����������
Private Function AddrOf(Value As Long) As Long
    AddrOf = Value
End Function
