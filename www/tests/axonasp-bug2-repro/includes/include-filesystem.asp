<%

  ' MegaBBS filesystem API
  ' Copyright PD9 Software
  ' Please refer to the license agreement for more information on reuse

  ' Depends on : includes.asp

dim Filesystem
set Filesystem = new MegaBBSFilesystemAPI

CLASS MegaBBSFilesystemAPI

  ' SHARED FILESYSTEM OBJECT
  private fsoBBS
  private fsoTXT

  Private Sub Class_Initialize   ' Setup Initialize event.
    set fsoBBS = Server.CreateObject("Scripting.FileSystemObject")
  End Sub

  Function FileExists (byval sFileName)
    ' DESCRIPTION : Given a file name, returns whether the file exists or not
    ' INPUTS      : A path to a file name
    ' RETURNS     : True or false

    FileExists = fsoBBS.FileExists(sFileName)
  end Function

  function FolderExists (byval sFolderName)
    ' DESCRIPTION : Given a file name, returns whether the file exists or not
    ' INPUTS      : A path to a file name
    ' RETURNS     : True or false

    FolderExists = fsoBBS.FolderExists(sFolderName)
  end function

  Sub DeleteFile (sFileName)
    ' DESCRIPTION : Given a file name, this file is deleted
    ' INPUTS      : A path to a file name

    if fsoBBS.FileExists(sFileName) then fsoBBS.DeleteFile (sFileName)
  end Sub

  sub CopyFile(byval sSource, byval sDestination, byval sFileName, byval sNewFileName)
    ' DESCRIPTION : Copies a file from one location to another. Does not overwrite files.
    ' INPUTS      : sSource - source path
    '               sDestination - destination path
    '               sFileName - source filename
    '               sNewFileName - destination file name
    ' RETURNS     : The new filename.

    dim sDest

    ' Get the full name of the destination file
    sDest        = sDestination & sFileName
    sSource      = sSource & sFileName
    sNewFileName = sFileName

    ' Get a good name for the new file
    do until not(fsoBBS.FileExists(sDest))
      sNewFileName = "_" & sNewFileName
      sDest   = sDestination & sNewFileName
    loop

    ' Copy the filename
    fsoBBS.CopyFile sSource, sDest
  end sub

  function InlineExecute(sFileName)
    ' DESCRIPTION : Executes the code provided in sFileName
    ' RETURNS     : Nothing
    if FileExists(server.mappath(sFileName)) then
      ExoticInclude(server.mappath(sFileName))
    end if
  end function

  function ExecuteTemplateConfig()
    dim sTemplateFileName, sDefaultFileName, sOriginalFileName

    sTemplateFileName = server.mappath(sBBSTemplateRoot & "/template-config.asp")
    sDefaultFileName  = server.mappath(sBBSDefaultRoot & "/template-config.asp")
    sOriginalFileName = server.mappath(sBBSOriginalRoot & "/template-config.asp")

    if FileExists(sTemplateFileName) then
      ExoticInclude(sTemplateFileName)
    elseif FileExists(sDefaultFileName) then
      ExoticInclude(sDefaultFileName)
    elseif FileExists(sOriginalFileName) then
      ExoticInclude(sOriginalFileName)
    else
      response.write "Fatal template error: Cannot find " & sBBSTemplateRoot & "/template-config.asp" & "<br/>"
    end if
  end function

  function ExecuteBBSTemplate(byref sFileName)
    ' DESCRIPTION : Executes the template code provided in sFileName
    ' RETURNS     : Nothing

    dim sTemplateFileName, sDefaultFileName, sOriginalFileName
    if left(sFileName, 1) <> "/" then sTemplateFileName= "/" & sFileName

    sTemplateFileName= server.mappath(sBBSTemplateRoot & "/bbs" & sFileName)
    sDefaultFileName = server.mappath(sBBSDefaultRoot & "/bbs" & sFileName)
    sOriginalFileName = server.mappath(sBBSOriginalRoot & "/bbs" & sFileName)

    if FileExists(sTemplateFileName) then
      ExoticInclude(sTemplateFileName)
    elseif FileExists(sDefaultFileName) then
      ExoticInclude(sDefaultFileName)
    elseif FileExists(sOriginalFileName) then
      ExoticInclude(sOriginalFileName)
    else
      response.write "Fatal template error: Cannot find " & sBBSTemplateRoot & "/bbs" & sFileName & "<br/>"
    end if
  end function

  function ExecuteFragmentTemplate(byref sFileName)
    ' DESCRIPTION : Executes the template code provided in sFileName
    ' RETURNS     : Nothing

    dim sTemplateFileName, sDefaultFileName, sOriginalFileName
    if left(sFileName, 1) <> "/" then sTemplateFileName= "/" & sFileName

    sTemplateFileName= server.mappath(sBBSTemplateRoot & "/fragments" & sFileName)
    sDefaultFileName = server.mappath(sBBSDefaultRoot & "/fragments" & sFileName)
    sOriginalFileName = server.mappath(sBBSOriginalRoot & "/fragments" & sFileName)

    'response.write sTemplateFileName & "<br/>"
    'response.write sDefaultFileName & "<br/>"
    'response.write sOriginalFileName & "<br/>"

    if FileExists(sTemplateFileName) then
      ExoticInclude(sTemplateFileName)
    elseif FileExists(sDefaultFileName) then
      ExoticInclude(sDefaultFileName)
    elseif FileExists(sOriginalFileName) then
      ExoticInclude(sOriginalFileName)
    else
      response.write "Fatal template error: Cannot find " & sBBSTemplateRoot & "/fragments" & sFileName & "<br/>"
    end if
  end function

  function ExecuteCustomTemplate(byref sFileName)
    ' DESCRIPTION : Executes the template code provided in sFileName
    ' RETURNS     : Nothing

    dim sTemplateFileName, sDefaultFileName, sOriginalFileName
    if left(sFileName, 1) <> "/" then sTemplateFileName= "/" & sFileName

    sTemplateFileName= server.mappath(sBBSTemplateRoot & "/custom" & sFileName)
    sDefaultFileName = server.mappath(sBBSDefaultRoot & "/custom" & sFileName)
    sOriginalFileName = server.mappath(sBBSOriginalRoot & "/custom" & sFileName)

    if FileExists(sTemplateFileName) then
      ExoticInclude(sTemplateFileName)
    elseif FileExists(sDefaultFileName) then
      ExoticInclude(sDefaultFileName)
    elseif FileExists(sOriginalFileName) then
      ExoticInclude(sOriginalFileName)
    else
      response.write "Fatal template error: Cannot find " & sBBSTemplateRoot & "/custom" & sFileName & "<br/>"
    end if
  end function

  function ExoticInclude(byref sCompletePathName)
    ' DESCRIPTION : Bizarre function
    ' INPUTS      : A full path to a VBS file
    ' RETURNS     : ???
    ' NOTES       : !!!

    dim sVBSPureText

    on error resume next

    Set fsoTXT = fsoBBS.OpenTextFile(sCompletePathName)

    sVBSPureText = fsoTXT.ReadAll()
    fsoTXT.Close
    ExecuteGlobal sVBSPureText

    if err.number <> 0 then
      response.write "<br/>Error encountered in: " & sCompletePathName & "<br/>"
      response.write Err.Source & " - " & Err.description & "<br/>"
      err.Clear
    end if

    on error goto 0
  End Function

  function UnicodeInclude(byref sCompletePathName)
    ' DESCRIPTION : Bizarre function
    ' INPUTS      : A full path to a VBS file
    ' NOTES       : The same function as ExoticInclude except accepts UNICODE encoded files

    dim sVBSPureText

    on error resume next

    Set fsoTXT = fsoBBS.OpenTextFile(sCompletePathName,1, False, -1)

    sVBSPureText = fsoTXT.ReadAll()
    fsoTXT.Close
    ExecuteGlobal sVBSPureText

    if err.number <> 0 then
      response.write "<br/>Error encountered in: " & sCompletePathName & "<br/>"
      response.write Err.Source & " - " & Err.description & "<br/>"
      err.Clear
    end if

    on error goto 0
  End Function

function GetLocalizedTemplateImage(byref sImageName, byref sLanguage)
	' DESCRIPTION	: function to retrieve a path to a localised template image based on the user's language preference
	' INPUTS		: the name of the image and the language identifier
	' RETURNS		: path to the image
	' NOTE			: the function will fall back to the default image if the localized one doesn't exist

	dim sResult
	sResult = sBBSTemplateImagesRoot & "/localized/" & sLanguage & "/" & sImageName
	if not FileExists(server.mappath(sResult)) then sResult = sBBSTemplateImagesRoot & "/localized/" & sImageName
	GetLocalizedTemplateImage = sResult
end function

END CLASS
%>