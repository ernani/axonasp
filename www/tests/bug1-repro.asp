<%@ CodePage=65001 Language="VBScript"%>
<% Option Explicit %>
<%
' Minimal reproduction extracted from MegaBBS Forum Software
' (includes/include-filesystem.asp, class MegaBBSFilesystemAPI, sub CopyFile)
'
' On real IIS / Microsoft VBScript (verified on Windows Server 2022, IIS 10.0),
' this compiles and runs without error, even though "sDest" is never
' explicitly Dim'd anywhere and Option Explicit is in effect for the whole
' compiled unit.
'
' On AxonASP this raises a compile-time error instead of executing:
'   VBScript compilation error error '800A01F4'
'   Variable not defined: 'sDest'

dim Filesystem
set Filesystem = new MegaBBSFilesystemAPI

CLASS MegaBBSFilesystemAPI

  private fsoBBS

  Private Sub Class_Initialize
    set fsoBBS = Server.CreateObject("Scripting.FileSystemObject")
  End Sub

  sub CopyFile(byval sSource, byval sDestination, byval sFileName, byval sNewFileName)
    ' NOTE: sDest is used below without ever being declared with Dim.
    sDest        = sDestination & sFileName
    sSource      = sSource & sFileName
    sNewFileName = sFileName

    do until not(fsoBBS.FileExists(sDest))
      sNewFileName = "_" & sNewFileName
      sDest   = sDestination & sNewFileName
    loop

    fsoBBS.CopyFile sSource, sDest
  end sub

end CLASS

response.write "Compiled and reached this point without a 'Variable not defined' error."
%>
