Attribute VB_Name = "modNativeInfo"
Option Explicit

' ����������

' ���������� �� �������� ��������
Public Type ExportInfo
    EntryPoint      As Long     ' ����� �����
    Forwarder       As Boolean  ' ���� ���������������
    Ordinal         As Long     ' �������
    Name            As String   ' ���
End Type
' ���������� �� �������� �������
Public Type ImportInfo
    Name            As String   ' ��� ����������
    Count           As Long     ' ���������� ������������� ������� �� ���� ����������
    Func()          As String   ' ������ �������
End Type
' ���������� � DLL
Public Type NativeInfo
    ImportCount     As Long     ' ���������� ��������� �������
    ExportCount     As Long     ' ���������� ��������� ��������
    DelImpCount     As Long     ' ���������� ��������� ����������� �������
    Import()        As ImportInfo
    Export()        As ExportInfo
    DelayImport()   As ImportInfo
End Type
Public Type tagSAFEARRAYBOUND
    cElements As Long
    lLbound As Long
End Type

