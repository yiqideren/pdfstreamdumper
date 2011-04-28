VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
  Persistable = 0  'NotPersistable
  DataBindingBehavior = 0  'vbNone
  DataSourceBehavior  = 0  'vbNone
  MTSTransactionMode  = 0  'NotAnMTSObject
END
Attribute VB_Name = "CSharpFilters"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
Private Declare Sub CopyFromMem Lib "kernel32" Alias "RtlMoveMemory" (Destination As Any, ByVal Source As Long, ByVal Length As Long)

Dim iTextFilters As Object
Dim wsh As New WshShell
    
Public Initilized As Boolean
Public ErrorMessage As String
Public DecodedBuffer As String

'Enum Decoders 'these align to the values used in the Csharp enum so we can pass directly
'    RunLengthDecode = 0
'    FlateDecode = 1
'    ASCIIHexDecode = 2
'    ASCII85Decode = 3
'    LzwDecode = 4
'    DecodePredictor = 5
'End Enum

Private Sub Class_Initialize()
    
    On Error Resume Next
    Dim iText As String
    
    If Not DetectDotNet() Then
        ErrorMessage = ".Net v2.0 Not found on this machine"
        Exit Sub
    End If
    
    iText = wsh.RegRead("HKCR\iTextFilters.MemDecoder\")
    If Len(iText) = 0 Then
        ErrorMessage = "iTextFilters is not registered on this machine"
        Exit Sub
    End If
        
    Set iTextFilters = CreateObject("iTextFilters.MemDecoder")
    
    If Err.Number <> 0 Or iTextFilters Is Nothing Then
        ErrorMessage = "Could not create CreateObject(iText_Filters.StringDecoder) " & vbCrLf & Err.Description
        Exit Sub
    End If
    
    Initilized = True
    
End Sub

Public Function DetectDotNet() As Boolean

    On Error GoTo hell
    
    Dim folders() As String, f, installroot As String
   
    installroot = wsh.RegRead("HKLM\SOFTWARE\Microsoft\.NETFramework\InstallRoot")
    
    If Not FolderExists(installroot) Then GoTo hell
    
    folders = GetSubFolders(installroot)
    
    For Each f In folders
        If VBA.Left(f, 2) = "v2" Then
            DetectDotNet = True
            Exit Function
        End If
    Next
    
    Exit Function
hell: ErrorMessage = Err.Description
End Function

'public interface ICDecoder
'{
'        string ErrorMessage { get; }
'        bool Debug { get; set; }
'        void ReleaseMem();
'        bool Decode(ref int address, ref int bufSize, mDecoders method);
'        bool Decrypt(string infile, string outfile);
'        void SetPredictorParams(int predictor, int columns, int colorss, int bitspercomponent);
'}
    
Function SetPredictorParams(predictor As Integer, Optional columns = 1, Optional colors = 1, Optional bitspercomponent = 8)
    On Error GoTo hell
    If Not Initilized Then Exit Function
    iTextFilters.SetPredictorParams CInt(predictor), CInt(columns), CInt(colorss), CInt(bitspercomponent)
hell:
End Function

Function decode(Data As String, decoder As Decoders, Optional surpressErrorMsg As Boolean = True, Optional dbugMode As Boolean = False) As Boolean
    
    On Error GoTo hell
        
    If Not Initilized Then
        If Not surpressErrorMsg Then MsgBox ErrorMessage, vbInformation
        Exit Function
    End If
    
    Dim b() As Byte
    Dim addr As Long
    Dim bufsize As Long
    
    b() = StrConv(Data, vbFromUnicode, LANG_US)
    addr = VarPtr(b(0))
    bufsize = UBound(b)
    
    iTextFilters.Debug = dbugMode
    
    If iTextFilters.decode(addr, bufsize, decoder) Then
        ReDim b(bufsize - 1) 'addr, bufsize - these were set byref in csharp to describe response buffer
        CopyFromMem b(0), addr, bufsize
        DecodedBuffer = StrConv(b(), vbUnicode, LANG_US)
        decode = True
    Else
        ErrorMessage = iTextFilters.ErrorMessage
        Exit Function
    End If
    
    iTextFilters.ReleaseMem
    
    Exit Function
    'hell is only for vb errors, .net errors get caught with output
hell:   ErrorMessage = "Error in " & method & " : " & Err.Description
        If Not surpressErrorMsg Then MsgBox ErrorMessage, vbInformation
End Function


Function Decrypt(infile As String, retString As String, Optional startMsg As String = "PDF is encrypted try to decrypt it?") As Boolean
        
    On Error Resume Next
    
    Dim outfile As String
    Dim ret As String
    
    outfile = fso.GetParentFolder(infile) & "\" & fso.GetBaseName(infile) & ".decrypted.pdf"
    
    If Len(startMsg) > 0 Then If MsgBox(startMsg, vbYesNo) = vbNo Then Exit Function
    
    If Not Me.Initilized Then
        MsgBox "Decrypt Error: " & ErrorMessage
        Exit Function
    End If
    
    If fso.FileExists(outfile) Then Kill outfile
    
    If Not iTextFilters.Decrypt(infile, outfile) Then
        retString = iTextFilters.ErrorMessage
    Else
    
         If FileLen(outfile) = 0 Then
             retString = "Decryption failed file probably has user password set?"
             Kill outfile
             Exit Function
         End If
         
         retString = outfile
         Decrypt = True
    
    End If
           
End Function



Private Function GetSubFolders(folder) As String()
    Dim fnames() As String
    
    If Not FolderExists(folder) Then
        'returns empty array if fails
        GetSubFolders = fnames()
        Exit Function
    End If
    
   If Right(folder, 1) <> "\" Then folder = folder & "\"

   fd = Dir(folder, vbDirectory)
   While fd <> ""
     If Left(fd, 1) <> "." Then
        If (GetAttr(folder & fd) And vbDirectory) = vbDirectory Then
           push fnames(), fd
        End If
     End If
     fd = Dir()
   Wend
   
   GetSubFolders = fnames()
End Function

Private Function FolderExists(path) As Boolean
  If Len(path) = 0 Then Exit Function
  If Dir(path, vbDirectory) <> "" Then FolderExists = True _
  Else FolderExists = False
End Function

Private Sub push(ary, Value) 'this modifies parent ary object
    On Error GoTo init
    x = UBound(ary) '<-throws Error If Not initalized
    ReDim Preserve ary(UBound(ary) + 1)
    ary(UBound(ary)) = Value
    Exit Sub
init: ReDim ary(0): ary(0) = Value
End Sub
