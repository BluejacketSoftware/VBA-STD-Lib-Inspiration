Attribute VB_Name = "modEnumWindow"
Option Explicit

' ������ ��� ��������� ���� ��� �������� (� ������ Z-�������)
' � ������� �������� ����������� (The trick), 2014

Private Type Point
    x As Long
    y As Long
End Type

Public Type RECT
    Left As Long
    Top As Long
    Right As Long
    Bottom As Long
End Type

Private Declare Function WindowFromPoint Lib "user32" (ByVal x As Long, ByVal y As Long) As Long
Private Declare Function GetCursorPos Lib "user32" (lpPoint As Any) As Long
Private Declare Function DeleteObject Lib "gdi32" (ByVal hObject As Long) As Long
Private Declare Function GetWindowRect Lib "user32" (ByVal hwnd As Long, lpRect As RECT) As Long
Private Declare Function GetWindowThreadProcessId Lib "user32" (ByVal hwnd As Long, lpdwProcessId As Long) As Long
Private Declare Function GetCurrentProcessId Lib "kernel32" () As Long
Private Declare Function PtInRect Lib "user32" (lpRect As RECT, ByVal ptx As Long, ByVal pty As Long) As Long
Private Declare Function PtInRegion Lib "gdi32" (ByVal hRgn As Long, ByVal x As Long, ByVal y As Long) As Long
Private Declare Function CreateRectRgn Lib "gdi32" (ByVal X1 As Long, ByVal Y1 As Long, ByVal X2 As Long, ByVal Y2 As Long) As Long
Private Declare Function GetWindow Lib "user32" (ByVal hwnd As Long, ByVal wCmd As Long) As Long
Private Declare Function IsWindowVisible Lib "user32" (ByVal hwnd As Long) As Long
Private Declare Function GetWindowRgn Lib "user32" (ByVal hwnd As Long, ByVal hRgn As Long) As Long
Private Declare Function GetWindowLong Lib "user32" Alias "GetWindowLongA" (ByVal hwnd As Long, ByVal nIndex As Long) As Long

Private Const WS_EX_MDICHILD As Long = &H40&
Private Const WS_CHILD As Long = &H40000000
Private Const GWL_STYLE As Long = (-16)
Private Const GWL_EXSTYLE As Long = (-20)
Private Const GW_CHILD As Long = 5
Private Const GW_HWNDPREV As Long = 3
Private Const GW_HWNDLAST As Long = 1

' �������� ����� ���� ������ �� ������� �������
Public Function GetWindowFromCursorPos() As Long
    Dim pt As Point, PID As Long, TID As Long, hwnd As Long, hWndParent As Long
    
    GetCursorPos pt
    hWndParent = WindowFromPoint(pt.x, pt.y)

    TID = GetWindowThreadProcessId(hWndParent, PID)
    If App.ThreadID = TID And GetCurrentProcessId() = PID Then Exit Function        ' ���������� ���� ������ ����������

    hwnd = EnumWindowZOrder(hWndParent, pt, True)                                   ' ���������� ��� �������� ����
    
    Do While hWndParent <> hwnd And hwnd
        DoEvents
        hWndParent = EnumWindowZOrder(hwnd, pt, False)                              ' ���������� ��� ����������� ����
        hwnd = EnumWindowZOrder(hWndParent, pt, True)                               ' ���� � ���� ���� ����
    Loop

    If (GetWindowLong(hWndParent, GWL_STYLE) And WS_CHILD) Then                     ' ���������� ���� ���� ��������
        GetWindowFromCursorPos = hWndParent
    ElseIf (GetWindowLong(hWndParent, GWL_EXSTYLE) And WS_EX_MDICHILD) = 0 Then
        GetWindowFromCursorPos = hWndParent
    Else
        GetWindowFromCursorPos = EnumWindowZOrder(hWndParent, pt, False)
    End If

End Function
' ����� ������ ����
Private Function PtInWindow(hwnd As Long, x As Long, y As Long) As Boolean
    Dim RC As RECT
    GetWindowRect hwnd, RC
    PtInWindow = PtInRect(RC, x, y)
End Function
' ������������ ���� � ������� ���� �� �����������
Private Function EnumWindowZOrder(ByVal hwnd As Long, pt As Point, Optional IsParent As Boolean) As Long
    Dim hRgn As Long
    
    hRgn = CreateRectRgn(0, 0, 0, 0)
    
    If IsParent Then hwnd = GetWindow(hwnd, GW_CHILD)

    hwnd = GetWindow(hwnd, GW_HWNDLAST)
    
    Do While hwnd
        DoEvents
        If IsWindowVisible(hwnd) And PtInWindow(hwnd, pt.x, pt.y) Then
            If GetWindowRgn(hwnd, hRgn) = 0 Then Exit Do
            If PtInRegion(hRgn, pt.x, pt.y) Then Exit Do
        End If
        hwnd = GetWindow(hwnd, GW_HWNDPREV)
    Loop
    
    DeleteObject hRgn
    EnumWindowZOrder = hwnd
End Function

