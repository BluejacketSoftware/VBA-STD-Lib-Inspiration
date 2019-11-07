VERSION 5.00
Begin VB.Form frmExample 
   Caption         =   "Form1"
   ClientHeight    =   2925
   ClientLeft      =   60
   ClientTop       =   450
   ClientWidth     =   4665
   LinkTopic       =   "Form1"
   ScaleHeight     =   2925
   ScaleWidth      =   4665
   StartUpPosition =   3  'Windows Default
   Begin VB.CommandButton Command3 
      Caption         =   "������� ��������� ������ (Callback)"
      Height          =   480
      Left            =   120
      TabIndex        =   3
      Top             =   2160
      Width           =   4395
   End
   Begin VB.CommandButton Command2 
      Caption         =   "���� � ����������� �� �����. ���������"
      Height          =   480
      Left            =   120
      TabIndex        =   2
      Top             =   1410
      Width           =   4395
   End
   Begin VB.CommandButton Command1 
      Caption         =   "����� ������ ������ ����� �������� ���������."
      Height          =   480
      Left            =   120
      TabIndex        =   1
      Top             =   765
      Width           =   4395
   End
   Begin VB.CommandButton cmdAppletTest 
      Caption         =   "���� � ���������"
      Height          =   480
      Left            =   120
      TabIndex        =   0
      Top             =   165
      Width           =   4395
   End
End
Attribute VB_Name = "frmExample"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Private some_object As CTestClass

Private Declare Sub GetMem4 Lib "msvbvm60" (ByVal pFrom As Long, ByRef pTo As Long)

Private Declare Sub PointerToMethodOfObj Lib "*" (ByVal pMe As CTestClass, ByVal v As Long)
Private Declare Function MathOperator Lib "*" (ByVal a As Long, ByVal b As Long) As Long

Private Sub cmdAppletTest_Click()
    frmApplets.Show vbModal, Me
End Sub

Private Sub Command1_Click()
    Call PointerToMethodOfObj(some_object, 2011)
End Sub

Private Sub Command2_Click()
    Dim xxx As Long
    Dim yyy As Long
    
    Dim addrOpAdd As Long
    Dim addrOpSub As Long
    
    addrOpAdd = L_(AddressOf DoAdd)
    addrOpSub = L_(AddressOf DoSub)
    
    xxx = 5
    yyy = 2
    
    FuncPointer("MathOperator") = addrOpAdd
    MsgBox "��������� MathOparator �������� ����� ������� DoAdd." + vbNewLine + _
            "��������: " + CStr(xxx) + " � " + CStr(yyy) + "." + vbNewLine + _
           "��������� ������: " + CStr(MathOperator(xxx, yyy)), vbExclamation
           
    FuncPointer("MathOperator") = addrOpSub
    MsgBox "��������� MathOparator �������� ����� ������� DoSub." + vbNewLine + _
           "��������: " + CStr(xxx) + " � " + CStr(yyy) + "." + vbNewLine + _
           "��������� ������: " + CStr(MathOperator(xxx, yyy)), vbExclamation
           
End Sub

Private Sub Command3_Click()
    OurProgram
End Sub

Private Sub Form_Load()
    Set some_object = New CTestClass
    MagicPointersOnOff True
    
    Dim l As Long
    GetMem4 ObjPtr(some_object), l
    GetMem4 l + 28, l ' 28 -- ������� ������ � Vtable
    
    FuncPointer("PointerToMethodOfObj") = l
    
End Sub

Private Sub Form_QueryUnload(Cancel As Integer, UnloadMode As Integer)
    MagicPointersOnOff False
    Set some_object = Nothing
End Sub
