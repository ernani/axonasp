<%
'Please copy this and update your /database/constants.asp file
' ---
dim bEmergencyMode, sBBSSQLFormat, sBBSForumRoot, sBBSCookieRoot, sBBSPreferredDomain, sBBSDatabaseType, sMSAccessFilePath, sConnString, sDateDelimiter, bNoSetup

' ************************************************************************
' *** EITHER REMOVE THIS LINE OR SET IT TO ZERO AFTER THE BBS IS SETUP ***
' ************************************************************************
bEmergencyMode = 0
bNoSetup       = 1

sBBSForumRoot         =""
sBBSPreferredDomain   = Request.ServerVariables("SERVER_NAME")
sBBSSQLFormat         ="iso"
sBBSDatabaseType      ="MYSQL"
sMSAccessFilePath     =""
sConnString           ="Driver={MySQL}; Server=mariadb; Option=16834; Port=3306; Database=megabbs; Uid=megabbs; Pwd=megabbspw;"
sDateDelimiter        ="'"
sBBSCookieRoot        =""
%>