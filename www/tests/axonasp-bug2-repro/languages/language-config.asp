<%
' MOD     : Multi-language support for MegaBBS v2.x
' Author  : Indrek Haav (aka karmic)
' Contact : karmic@hot.ee
' Status  : Finished

dim Language
set Language = new MegaBBSLanguage

CLASS MegaBBSLanguage

public hasExecuted
private sLanguage

sub SetLanguage ()

  on error resume next
  if hasExecuted = 1 then exit sub
  hasExecuted = 1
  err.clear

  ' Declare a few variables
  dim vUserInfo, rsInfo, iLanguageID, oFSO, sContents, sLanguageFile, SQL
  set rsInfo = server.CreateObject("ADODB.Recordset")
  vUserInfo = BBS.GetUserInfoById(iBBSMemberID)

  ' If we're a registered user then draw the user's language ID and get the respective language file identifier
  if vUserInfo(UI_MemberID) <> -1 then

    if vUserInfo(UI_LanguageID) > 0 then
      sLanguage = GetLanguageInfo(vUserInfo(UI_LanguageID))(LNG_LanguageShortName)
    else
      sLanguage = GetLanguageInfo(GetDefaultLanguage)(LNG_LanguageShortName)
    end if

  else

    ' Apparently we're a guest so we'll check the cookie
    if BBS.ValidateNumeric(request.cookies(sBBSCookieRoot & "guestlanguage")) > 0 then
      sLanguage = GetLanguageInfo(BBS.ValidateNumeric(request.cookies(sBBSCookieRoot & "guestlanguage")))(LNG_LanguageShortName)
    else
      sLanguage = GetLanguageInfo(GetDefaultLanguage)(LNG_LanguageShortName)
    end if

  end if

  ' Was there an error so far?
  if sLanguage = "" then sLanguage = BBS.ValidateField(GetLanguageInfo(GetDefaultLanguage))
  if (err.Number <> 0 or bEmergencyMode = 1 or sLanguage = "") then sLanguage = "us"


  Filesystem.UnicodeInclude(server.mappath(sBBSForumRoot & "/languages/language-" & sLanguage & ".asp"))
  on error goto 0

  ' make the language preference globally available for later use
  dictEnvironment("USER-LANGUAGE") = sLanguage
  set rsInfo = Nothing

end sub

function GetCalendarLanguage()
  ' Returns the path to a language file for the calendar. If one is not provided for this users language, the
  ' default forum one is used. If that is not provided, the us one is used.

  if hasExecuted = 0 then SetLanguage
  if Filesystem.FileExists(Server.MapPath(sBBSForumRoot & "/languages/calendar-" & sLanguage & ".js")) then
    GetCalendarLanguage = sBBSForumRoot & "/languages/calendar-" & sLanguage & ".js"
  else
    sLanguage = GetLanguageInfo(GetDefaultLanguage)(LNG_LanguageShortName)
    if Filesystem.FileExists(Server.MapPath(sBBSForumRoot & "/languages/calendar-" & sLanguage & ".js")) then
      GetCalendarLanguage = sBBSForumRoot & "/languages/calendar-" & sLanguage & ".js"
    else
      GetCalendarLanguage = sBBSForumRoot & "/languages/calendar-us.js"
    end if
  end if
end function

function GetLanguageInfoStruct()
  dim vResult(3)
  GetLanguageInfoStruct = vResult
end function

function GetLanguageInfo(byval iLanguageID)
  dim SQL, rsInfo, vResult, sKey

  sKey = "LANG-" & iLanguageID
  vResult = BBS.Cache(sKey)

  'if not(IsEmpty(vResult)) then
  '  GetLanguageInfo = vResult
  '  iBBSCachedHits = iBBSCachedHits + 1
  '  exit function
  'end if

  set rsInfo = server.Createobject("ADODB.Recordset")
  vResult = GetLanguageInfoStruct()

  if clng(iLanguageID) = 0 then
    SQL = "select id, longname, shortname, isdefault from languages where isdefault=1"
  else
    SQL = "select id, longname, shortname, isdefault from languages where id=" & BBS.ValidateNumeric(iLanguageID)
  end if

  rsInfo.open SQL, dbConnection, adOpenForwardOnly, adLockReadOnly
  BBS.AddQuery(SQL)

  if not(rsInfo.EOF) then
    vResult(LNG_LanguageID)        = rsInfo.fields("id").value
    vResult(LNG_LanguageName)      = rsInfo.fields("longname").value
    vResult(LNG_LanguageShortName) = rsInfo.fields("shortname").value
    vResult(LNG_IsDefault)         = rsInfo.fields("isdefault").value
  else
    vResult(LNG_LanguageID) = -1
    vResult(LNG_LanguageName)      = ""
    vResult(LNG_LanguageShortName) = ""
    vResult(LNG_IsDefault)         = 0
  end if

  BBS.CacheAdd sKey, vResult

  rsInfo.Close
  set rsInfo = Nothing
  GetLanguageInfo = vResult
end function

function GetDefaultLanguage()
  dim iResult
  rsMaster.open "select id from languages where isdefault=1", dbconnection, adOpenForwardOnly, adLockReadOnly
  if not(rsMaster.EOF) then
    iResult = rsMaster.fields("id").value
  else
    iResult = -1
  end if
  rsMaster.close
  GetDefaultLanguage = iResult
end function

function DeleteLanguage(iLanguageID)
  dim SQL, vLanguageInfo
  vLanguageInfo = GetLanguageInfo(iLanguageID)
  if vLanguageInfo(LNG_IsDefault) = 0 then
    SQL = "delete from languages where id=" & BBS.ValidateNumeric(languageid)
    dbconnection.execute  SQL,, adTextNoRecords
    BBS.AddQuery(SQL)
    SQL = "update members set languageid=" & GetDefaultLanguage() & " where languageid=" & BBS.ValidateNumeric(languageid)
    dbconnection.execute  SQL,, adTextNoRecords
    BBS.AddQuery(SQL)
  end if
end function

function SetDefault(iLanguageID)
  dim SQL, vLanguageInfo
  vLanguageInfo = GetLanguageInfo(iLanguageID)
  if vLanguageInfo(LNG_LanguageID) > 0 then
    SQL = "update languages set isdefault=0"
    dbConnection.execute SQL,, adTextNoRecords
    BBS.AddQuery(SQL)
    SQL = "update languages set isdefault=1 where id=" & BBS.ValidateNumeric(iLanguageID)
    dbConnection.execute SQL,, adTextNoRecords
    BBS.AddQuery(SQL)
  end if
end function

' Bye-bye
end class
%>