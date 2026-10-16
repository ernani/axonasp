<!-- #include file="database/constants.asp"-->
<!-- #include file="includes/include-filesystem.asp"-->
<!-- #include file="includes/include-constants.asp"-->
<!-- #include file="languages/language-config.asp"-->
<%

' ASP Forum : Master include file : Version 2.2 Beta 2
' Copyright PD9 Software
' Please refer to the license agreement for more information on reuse

' Depends on : constants.asp, include-constants.asp, include-filesystem.asp

dim BBS
set BBS = new MegaBBSAPI

CLASS MegaBBSAPI

  sub SetupBBS
    ' DESCRIPTION : Runs the initialization routines

    ' Temporarily force the cache to be application.  dictConfiguration isn't populated yet
    ' and clearing out the cache only makes sense with an application cache anyway.
    dictConfiguration("sCACHE") = "APPLICATION"
    sBBSCachePrefix = sBBSForumRoot
    if trim(sBBSForumRoot) = "" then sBBSCachePrefix = "_mb"
    if cdate(BBS.Cache("FLUSHDATE")) < now then
      BBS.CacheDeleteAll
      BBS.CacheAdd "FLUSHDATE", dateadd("n", 15, now)
    end if
    dictConfiguration("sCACHE") = ""
    GetConfigVariables
    SetupDatabase
  end sub

  Sub GetConfigVariables
    ' DESCRIPTION : Sets up complex global variables used by various MegaBBS functions

    iBBSCachedHits = 0

    ' Capture any information that may be provided by cookies
    iBBSCookieID       = request.cookies(sBBSCookieRoot & "bbsmid")
    sBBSPassword       = request.cookies(sBBSCookieRoot & "password")

    sBBSForumViewMode  = request.cookies(sBBSCookieRoot & "ForumViewMode")
    sBBSThreadViewMode = request.cookies(sBBSCookieRoot & "ThreadViewMode")
    iBBSGuestID        = request.cookies(sBBSCookieRoot & "guestID")

    ' Get the name of the current file (from the last forward or backslash to the end of the string)
    sBBSPageName = replace(request.servervariables("SCRIPT_NAME"), "\", "/")
    sBBSPageName = mid(sBBSPageName, instrrev(sBBSPageName , "/")+1)

    ' The path to the script, ex "/megaBBS/index.asp"
    sBBScurrentURLPath = request.Servervariables("PATH_INFO")

    ' The complete list of querystrings, ex "reply=true&name=bobsmith"
    sBBSCurrentQueryString = request.Servervariables("QUERY_STRING")

    ' The complete URL and script name, including querystrings, ex "/megabbs/hi.asp?&reply=true&name=bobsmith"
    sBBSCompleteURL = sBBScurrentURLPath & "?" & sBBSCurrentQueryString

    ' The base portion of the URL, minus the path or script name, ex "http://www.mydomain.com"
    if ucase(left(sBBSPreferredDomain,7)) = "HTTP://" or ucase(left(sBBSPreferredDomain,7)) = "HTTP:\\" then
      sBBSBaseURL = sBBSPreferredDomain
    elseif ucase(left(sBBSPreferredDomain,8)) = "HTTPS://" or ucase(left(sBBSPreferredDomain,8)) = "HTTPS:\\" then
      sBBSBaseURL = sBBSPreferredDomain
    else
      sBBSBaseURL = "http://" & sBBSPreferredDomain
    end if

    ' The referring URL
    sBBSReferer = request.ServerVariables("HTTP_REFERER")

    ' http://www.yourdomain.com/megabbs (html encoded)
    sBBSValidatedBaseURL = BBS.ValidateField(sBBSBaseURL & sBBSForumRoot)

    ' http://www.yourdomain.com/megabbs (html encoded)
    sBBSUnvalidatedBaseURL = sBBSBaseURL & sBBSForumRoot

    ' Look for a catlock
    if len(Trim(request.querystring("catlock"))) > 0 then
      iBBSCatLock = BBS.ValidateNumeric(request.querystring("catlock"))
      response.cookies(sBBSCookieRoot & "catlock") = BBS.ValidateNumeric(iBBSCatLock)
    elseif len(trim(request.cookies(sBBSCookieRoot & "catlock"))) > 0 then
      iBBSCatLock = BBS.ValidateNumeric(request.cookies(sBBSCookieRoot & "catlock"))
    else
      iBBSCatLock = -1
    end if

    ' Check if first run for installation
    if bNoSetup = 1 and sBBSPageName = "category-view.asp" then
      response.redirect "admin/bbs-start.asp"
    elseif bNoSetup = True and not sBBSPageName = "category-view.asp" then
      response.write "BBS has not yet been configured. Please run BBS configuration to generate a valid constant file."
      response.end
    end if

  end Sub

  Sub SetupDatabase()
    ' DESCRIPTION : Creates the database connection and a default recordset
    dim index, iUpperBound, sHostAddr, vImpersonateInfo, iDatabaseVersion, vUserInfo

    ' Initialize database connections
    err.clear

    on error resume next
    set dbConnection = server.createobject("ADODB.Connection")
    set rsMaster     = server.createobject("ADODB.Recordset")
    dbConnection.CursorLocation   = adUseServer
    dbConnection.ConnectionString = sConnString
    dbConnection.ConnectionTimeout = 30
    dbConnection.Open
    rsMaster.cachesize = 25

    if err.Number <> 0 then
      response.redirect sBBSForumRoot & "/closed.asp"
    end if
    on error goto 0

    if ucase(sBBSDatabaseType) = "MSSQL" and ucase(sBBSSQLFormat) = "ISO" then
      dbConnection.execute "set dateformat ymd"
    elseif ucase(sBBSDatabaseType) = "MSSQL" and ucase(sBBSSQLFormat) = "EUR" then
      dbConnection.execute "set dateformat dmy"
    elseif ucase(sBBSDatabaseType) = "MSSQL" and ucase(sBBSSQLFormat) = "US" then
      dbConnection.execute "set dateformat mdy"
    end if

    iDatabaseVersion = GetDBVersion
    if iDatabaseVersion < 2.2 and instr(sBBSPageName, "database-upgrade.asp") = 0 and instr(sBBSPageName, "bbs-setup.asp") = 0 and instr(sBBSPageName, "setup.asp") = 0 then response.redirect sBBSForumRoot & "/closed.asp"

    if dbConnection.State <> 0 then
      ' Get values from BBS configuration table
      GetBBSConfigVariables
      GetGlobalVariables

      ' Get the user logon type and global variables
      if sBBSUsername = "12345678901234567890logoff" or iBBSCookieID = -100 then
        iBBSLogonType = US_NotRegistered
        sBBSUsername  = ""
        sBBSPassword  = ""
      else
        iBBSLogonType = CheckUsernameByID (iBBSCookieID, sBBSPassword)
      end if

      ' Now set by CheckUsernameByID
      'if iBBSLogonType = US_Registered then
      '  iBBSMemberID = GetMemberID(sBBSUsername)
      'else
      '  iBBSMemberID = -1
      '  sBBSUsername  = ""
      '  sBBSPassword  = ""
      'end if

      iBBSUserLevel = GetUserLevel(MODULE_BBS, -1)

      dim bImpersonateCookieSet, bIsGlobalAdmin
      bImpersonateCookieSet = (len(request.cookies(sBBSCookieRoot & "impersonate")) > 0)
      bIsGlobalAdmin        = (iBBSUserLevel = USERLEVEL_GlobalAdministrator)
      if (bImpersonateCookieSet AND bIsGlobalAdmin) then
        vImpersonateInfo = BBS.GetUserInfobyID(request.cookies(sBBSCookieRoot & "impersonate"))
        if vImpersonateInfo(UI_MemberID) > 0 then
          ChangeSecurityContext vImpersonateInfo(UI_Username), vImpersonateInfo(UI_Password)
          dictEnvironment("C-IMPERSONATION-ACTIVE") = 1
          dictEnvironment("U-IMPERSONATION-END") = sBBSForumRoot & "/admin/impersonate.asp?action=end&redirect=" & server.urlencode(sBBSForumRoot & "/admin/user-maintenance.asp")
        else
          response.cookies(sBBSCookieRoot & "impersonate") = ""
        end if
      end if
    end if
  end sub
end CLASS
%>
<%response.write "reached end of repro7"%>
