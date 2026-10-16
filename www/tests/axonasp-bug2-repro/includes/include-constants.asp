<%

  ' ======================================
  ' Global variables
  '
  response.buffer = TRUE
  if instr(request.Servervariables("PATH_INFO"), "get-photo.asp") = 0 and instr(request.Servervariables("PATH_INFO"), "retrieve-image.asp") = 0 and instr(request.Servervariables("PATH_INFO"), "retrieve-scheme.asp") = 0 and instr(request.Servervariables("PATH_INFO"), "get-attachment.asp") = 0 then
    response.expires = -1
  end if
  server.scripttimeout = 30

  ' ADO CONSTANTS
  Const adOpenForwardOnly = 0
  Const adOpenKeyset = 1
  Const adOpenDynamic = 2
  Const adOpenStatic = 3
  Const adLockReadOnly = 1
  Const adLockPessimistic = 2
  Const adLockOptimistic = 3
  Const adLockBatchOptimistic = 4
  Const adUseServer = 2
  Const adUseClient = 3
  Const adCmdUnknown = &H0008
  Const adCmdText = &H0001
  Const adCmdTable = &H0002
  Const adCmdStoredProc = &H0004
  Const adExecuteNoRecords = &H00000080


  ' DATABASE CONNECTIONS
  dim dbConnection, rsMaster, rsReindexer

  ' COOKIE VARIABLES
  dim sBBSUsername, sBBSPassword, sBBSForumViewMode, sBBSThreadViewMode, iBBSGuestID, iBBSCatLock, iBBSUserLevel, sBBSCachePrefix, iBBSCookieID

  ' SESSION CACHE VARIABLES
  dim vBBSEmoticonsArray, vBBSDecodeEmoticonsArray, vBBSDecodeArray, vBBSRankArray, vBBSDecorationArray, vBBSBadWordFilter, dictGeneralCache, dictOnline, vBannedIPs
  set dictGeneralCache = server.createobject("SCRIPTING.DICTIONARY") : dictGeneralCache.Comparemode = 0
  set dictOnline = server.createobject("SCRIPTING.DICTIONARY") : dictOnline.Comparemode = 0

  ' TEMPLATES & LANGUAGES
  dim dictLanguage, dictImages, dictTemplate, dictEnvironment, sBBSTemplateRoot, sBBSTemplateImagesRoot, sBBSOriginalRoot, sBBSDefaultRoot, sBBSLanguage, sBBSTemplateLocalizedImagesRoot, dictComplexVariables, sBBSLangPage, sBBSFragmentOutput
  set dictImages           = server.createobject("SCRIPTING.DICTIONARY") : dictImages.Comparemode = 0
  set dictLanguage         = server.createobject("SCRIPTING.DICTIONARY") : dictLanguage.Comparemode = 0
  set dictEnvironment      = server.createobject("SCRIPTING.DICTIONARY") : dictEnvironment.Comparemode = 0
  set dictTemplate         = server.CreateObject("SCRIPTING.DICTIONARY") : dictTemplate.Comparemode = 0
  set dictComplexVariables = server.CreateObject("SCRIPTING.DICTIONARY") : dictComplexVariables.Comparemode = 0

  ' SHARED REGEX OBJECT
  dim mBBSRegEx
  Set mBBSRegEx = Server.CreateObject("VBScript.RegExp")

  ' PAGE VARIABLES
  dim sBBSPageName, sBBScurrentURLPath, sBBSCurrentQueryString, sBBSCompleteURL, sBBSBaseURL, sBBSReferer, sBBSValidatedBaseURL, sBBSUnvalidatedBaseURL, iBBSLogonType, iBBSMemberID, dBBSDebugTime, iBBSCachedHits, sBBSSQLDebug, iBBSExecutedQueries, iBBSCreatedRecordsets, iBBSCachedRecordsets
  dim sBBSSchemeFile, iBBSTimeOffset, sBBSStyleID, bBBSBadWordFilterOnDisplay, vIgnoreList

  ' CONFIGURATION
  dim dictConfiguration, dBBSLastMaintenance, bFooterUnlocked, bFeaturesUnlocked
  set dictConfiguration = server.createobject("SCRIPTING.DICTIONARY")

  ' Cache engine maintenance
  ' sBBSCachePrefix = "_mb"

  dBBSDebugTime = Timer

  dim quote, CRLF
  Quote = chr(34)
  CRLF  = chr(13) & chr(10)

  dim adTextNoRecords
  adTextNoRecords = adCmdText + adExecuteNoRecords

  ' AlbumInfo constants
  CONST AI_AlbumID = 0
  CONST AI_Name = 1
  CONST AI_Description = 2
  CONST AI_Username = 3
  CONST AI_AllowUserComments = 4
  CONST AI_AllowGuestComments = 5
  CONST AI_DateUpdated = 6
  CONST AI_SortORder = 7
  CONST AI_CommentCount = 8
  CONST AI_PhotoCount = 9

  ' AlertInfo constants
  CONST AL_ArraySize = 7
  CONST AL_AlertID = 0
  CONST AL_Type = 1
  CONST AL_MessageID = 2
  CONST AL_MemberID = 3
  CONST AL_Approved = 4
  CONST AL_Reported = 5
  CONST AL_Message = 6

  'CategoryInfo constants
  CONST CA_ArraySize = 8
  CONST CA_CategoryName = 0
  CONST CA_CategoryURL = 1
  CONST CA_Locked = 2
  CONST CA_SchemeDefault = 3
  CONST CA_ForceScheme = 4
  CONST CA_CategoryID = 5
  CONST CA_SortOrder = 6
  CONST CA_CollapsedByDefault = 7

  'ControlBox constants
  CONST CB_ArraySize = 8
  CONST CB_Registered = 0
  CONST CB_NewMessages = 1
  CONST CB_TotalUsers = 2
  CONST CB_RegisteredUsers = 3
  CONST CB_GuestUsers = 4
  CONST CB_TotalMessages = 5
  CONST CB_OldMessages = 6
  CONST CB_outboxmessages = 7

  'CalendarEvents structure
  CONST CEV_ArraySize = 22
  CONST CEV_Calendareventid = 0
  CONST CEV_Calendarid = 1
  CONST CEV_Owner = 2
  CONST CEV_Shortdesc = 3
  CONST CEV_Longdesc = 4
  CONST CEV_Weekday = 5
  CONST CEV_Day = 6
  CONST CEV_Month = 7
  CONST CEV_Year = 8
  CONST CEV_Recurrence = 9
  CONST CEV_Private= 10
  CONST CEV_SingleDate= 11
  CONST CEV_TimeOfDayHour= 12
  CONST CEV_TimeOfDayMinute= 13
  CONST CEV_TimeOfDayMeridian= 14
  CONST CEV_AllDayEvent = 15
  CONST CEV_HasDateRange= 16
  CONST CEV_StartDateRange = 17
  CONST CEV_EndDateRange = 18
  CONST CEV_AllowSignups  = 19
  CONST CEV_OwnerStatus = 20
  CONST CEV_META_date = 21

  'CalendarInfo structure
  CONST CI_ArraySize = 3
  CONST CI_CalendarID = 0
  CONST CI_CalendarName = 1
  CONST CI_Description = 2

  'DateInfo constants
  CONST DE_ArraySize = 17
  CONST DE_EventID = 0
  CONST DE_shortdesc = 1
  CONST DE_Hyperlink = 2
  CONST DE_Recurring = 3
  CONST DE_Private = 4
  CONST DE_Owner = 5
  CONST DE_Date = 6
  CONST DE_longdesc = 7
  CONST DE_ValidatedHyperlink = 8
  CONST DE_alldayevent = 9
  CONST DE_TimeOfDayHour = 10
  CONST DE_TimeOfDayMinute = 11
  CONST DE_TimeOfDayMeridian = 12
  CONST DE_HasDateRange = 13
  CONST DE_StartDateRange = 14
  CONST DE_EndDateRange = 15
  CONST DE_allowsignups = 16

  ' ForumInfo constants
  CONST FI_ArraySize = 27
  CONST FI_forumid = 0
  CONST FI_CategoryID = 1
  CONST FI_ForumName = 2
  CONST FI_URL = 3
  CONST FI_ForumDescription = 4
  CONST FI_datecreated = 5
  CONST FI_lastactivity = 6
  CONST FI_sortbyactivity = 7
  CONST FI_shownavbars = 8
  CONST FI_forceunregistered = 9
  CONST FI_AnonymousAllowed = 10
  CONST FI_defaultthreadview = 11
  CONST FI_defaultforumview = 12
  CONST FI_showquotes = 13
  CONST FI_hideemaillink = 14
  CONST FI_showprofilepicture = 15
  CONST FI_sortorder = 16
  CONST FI_threadcount = 17
  CONST FI_PostCount = 18
  CONST FI_DisablePrinter = 19
  CONST FI_SortMessagesByActivity=20
  CONST FI_showonline = 21
  CONST FI_ShowRank = 22
  CONST FI_HideReplyButton = 23
  CONST FI_LastActiveThread = 24
  CONST FI_ShowIPs = 25
  CONST FI_Emoticons = 26
  CONST FI_RSS = 27

  ' HeaderInfo constants
  CONST HI_ArraySize = 9
  CONST HI_OwnerLink = 0
  CONST HI_Subject = 1
  CONST HI_ShortDate = 2
  CONST HI_LongDate = 3
  CONST HI_Body = 4
  CONST HI_NumComments = 5
  CONST HI_CommentLink = 6
  CONST HI_MessageBody = 7
  CONST HI_OwnerName = 8

  ' Messageinfo Constants
  CONST MI_ArraySize = 24
  CONST MI_MessageID = 0
  CONST MI_threadid  = 1
  CONST MI_inreplyto = 2
  CONST MI_Subject = 3
  CONST MI_Body = 4
  CONST MI_Anonymous = 5
  CONST MI_HostName = 6
  CONST MI_DatePosted = 7
  CONST MI_MessageIcon = 8
  CONST MI_Emoticons = 9
  CONST MI_ReplyLevel = 10
  CONST MI_ReplyOrder = 11
  CONST MI_Signature = 12
  CONST MI_FilterHTML = 13
  CONST MI_lasteditedname = 14
  CONST MI_lastediteddate = 15
  CONST MI_Edited = 16
  CONST MI_HasAttachment = 17
  CONST MI_IsRegistered = 18
  CONST MI_MemberID = 19
  CONST MI_GuestName = 20
  CONST MI_ForceLineBreaks = 21
  CONST MI_Approved = 22
  CONST MI_HasRevisions = 23

  'OptionInfo constants
  CONST OI_ArraySize = 8
  CONST OI_OptionID = 0
  CONST OI_PollID = 1
  CONST OI_Description = 2
  CONST OI_MemberID = 3
  CONST OI_Registered = 4
  CONST OI_Votes = 5
  CONST OI_GuestName = 6
  CONST OI_Percentage = 7

  ' PhotoInfo constnats
  CONST PI_PhotoID = 0
  CONST PI_AlbumID = 1
  CONST PI_DateUploaded = 2
  CONST PI_Username = 3
  CONST PI_filename = 4
  CONST PI_Description = 5
  CONST PI_Picture = 6
  CONST PI_TimesViewed = 7

  'PollInfo constants
  CONST PI_ArraySize = 9
  CONST PI_pollid = 0
  CONST PI_UnregisteredCanVote = 1
  CONST PI_UnregisteredCanAddOptions = 2
  CONST PI_RegisteredCanAddOptions = 3
  CONST PI_DisplayNames = 4
  CONST PI_Closed = 5
  CONST PI_MultiVoting = 6
  CONST PI_HideResults = 7
  CONST PI_ThreadID = 8




  'Private message constants
  CONST PM_ArraySize = 9
  CONST PM_MessageID = 0
  CONST PM_ToName = 1
  CONST PM_FromName = 2
  CONST PM_Subject = 3
  CONST PM_DateSent = 4
  CONST PM_Body = 5
  CONST PM_MessageRead = 6
  CONST PM_DateRead = 7

  'GenerateTopList constants
  CONST TL_ArraySize = 12
  CONST TL_threadid = 0
  CONST TL_Hyperlink = 1
  CONST TL_threadsubject = 2
  CONST TL_NumReplies = 3
  CONST TL_lastactivity = 4
  CONST TL_datecreated = 5
  CONST TL_Owner = 6
  CONST TL_lastposter = 7
  CONST TL_ValidatedHyperlink = 8
  CONST TL_NumViews = 9
  CONST TL_ThreadOwner = 10
  CONST TL_forumid = 11

  'ThreadInfo structure
  CONST TI_ArraySize = 23
  CONST TI_ThreadID = 0
  CONST TI_ForumID = 1
  CONST TI_TotalPosts = 2
  CONST TI_DateCreated = 3
  CONST TI_LastActivity = 4
  CONST TI_Subject = 5
  CONST TI_Anonymous = 6
  CONST TI_Closed = 7
  CONST TI_TimesViewed = 8
  CONST TI_Sticky = 9
  CONST TI_HasPoll = 10
  CONST TI_PollID = 11
  CONST TI_HasAttachment = 12
  CONST TI_LastPosterAnonymous= 13
  CONST TI_LastPosterMemberID= 14
  CONST TI_LastPosterIsRegistered= 15
  CONST TI_LastPosterGuestName= 16
  CONST TI_MemberID= 17
  CONST TI_IsRegistered = 18
  CONST TI_GuestName = 19
  CONST TI_Seed = 20
  CONST TI_LastPostID = 21
  CONST TI_Approved = 22

  'Template constants
  CONST TMP_ArraySize = 3
  CONST TMP_TemplateID = 0
  CONST TMP_TemplatePath = 1
  CONST TMP_TemplateName = 2
  CONST TMP_IsDefault = 3

  'Language constants
  CONST LNG_ArraySize = 3
  CONST LNG_LanguageID = 0
  CONST LNG_LanguageName = 1
  CONST LNG_LanguageShortName = 2
  CONST LNG_IsDefault = 3

  ' Userinfo constants
  CONST UI_ArraySize = 45
  CONST UI_memberid = 0
  CONST UI_Username = 1
  CONST UI_Password=2
  CONST UI_RealName = 3
  CONST UI_Websiteaddr = 4
  CONST UI_Emailaddr = 5
  CONST UI_ICQNumber = 6
  CONST UI_Active = 7
  CONST UI_Interests = 8
  CONST UI_Signature = 9
  CONST UI_dateregistered = 10
  CONST UI_totalposts = 11
  CONST UI_ShowEmail = 12
  CONST UI_Location = 13
  CONST UI_EmailNotifications = 14
  CONST UI_Invisible = 15
  CONST UI_ProfileURL = 16
  CONST UI_defaultthreadview = 17
  CONST UI_defaultforumview = 18
  CONST UI_userichedit = 19
  CONST UI_Yahoo = 20
  CONST UI_MSN = 21
  CONST UI_AIM = 22
  CONST UI_UseSignature = 23
  CONST UI_ViewSignature = 24
  CONST UI_photourl = 25
  CONST UI_LastLogon = 26
  CONST UI_disablepostcount = 27
  CONST UI_TimeOffset = 28
  CONST UI_LogoffURL = 29
  CONST UI_IsOnline = 30
  CONST UI_Rank = 31
  CONST UI_UseCustomRank = 32
  CONST UI_SendPrivateNotifications = 33
  CONST UI_TemplateID = 34
  CONST UI_LanguagePreference = 35
  CONST UI_IncludeBody = 36
  CONST UI_LanguageID = 37
  CONST UI_OKToPost = 38
  CONST UI_DisallowBroadcasts = 39
  CONST UI_ViewAvatars = 40
  CONST UI_Salt = 41
  CONST UI_VCode = 42
  CONST UI_QuickReplyMode = 43
  CONST UI_IgnoreList = 44

  ' Message Status Constants
  CONST ST_Unregistered = 0   : CONST ST_Registered = 1
  CONST ST_Moderator    = 2   : CONST ST_Administrator = 3

  'Error constants
  CONST ERR_None = 0            :  CONST ERR_UserExists = -1
  CONST ERR_NoUserFound = -2    :  CONST ERR_NoSuchForum = -3
  CONST ERR_NoSuchCalendar = -4 :  CONST ERR_FileNotFound = -5

  'Hook constants
  CONST HK_OnlineAdd = 1     :  CONST HK_OnlineRemove = 2
  CONST HK_UserAdd = 3       :  CONST HK_UserDelete = 4
  CONST HK_UserUpdate = 5

  'Alert constants
  CONST ALERT_BadPost = 1    :  CONST ALERT_NewPost = 2
  CONST ALERT_NewUser = 3

  'Complex variable constants
  CONST CV_NewInbox = 1
  CONST CV_OldInbox = 2
  CONST CV_InboxTotal = 3
  CONST CV_OnlineUsers = 4
  CONST CV_OnlineRegisteredUsers = 5
  CONST CV_OnlineGuestUsers = 6
  CONST CV_OutboxTotal = 7
  CONST CV_SessionsToday = 8
  CONST CV_BadPostAlerts = 9
  CONST CV_NewPostAlerts = 10
  CONST CV_NewUserAlerts = 11

  'Online constants
  CONST ON_RecordID     = 0
  CONST ON_Username     = 1
  CONST ON_Location     = 2
  CONST ON_Logontime    = 3
  CONST ON_Lastactivity = 4
  CONST ON_IP           = 5
  CONST ON_Registered   = 6

  'Permission constants
  ' 0 - 199    : Administrative actions
  ' 200-399    : BBS module functions
  ' 400 - 599  : Forum actions

  ' BELOW 10,000 IS RESERVED FOR BBS USE. FOR CUSTOM PERMISSIONS, USE VALUES >= 10,000

  ' BBS ADMIN LEVEL PERMISSIONS (support admins) 0-199
  CONST PERM_admindbupgrade          = 0         ' Upgrade database                             ' Can assign to support admins
  CONST PERM_admineditmbbscode       = 1         ' Edit MBBS Codes                              ' Can assign to support admins
  CONST PERM_admineditemoticons      = 2         ' Edit Emoticons                               ' Can assign to support admins
  CONST PERM_admineditusers          = 3         ' Edit users                                   ' Can assign to support admins
  CONST PERM_adminedittemplates      = 4         ' Edit templates                               ' Can assign to support admins
  CONST PERM_admineditlanguages      = 5         ' Edit languages                               ' Can assign to support admins
  CONST PERM_admindeleteuser         = 7         ' Delete users                                 ' Can assign to support admins
  CONST PERM_admineditgroups         = 9         ' Edit/delete groups                           ' Can assign to support admins
  CONST PERM_admineditglobaladministrators  = 10 ' Assign global administrators
  CONST PERM_admineditsupportadministrators = 11 ' Assign support administrators                ' Can assign to support admins
  CONST PERM_admineditmoduleadministrators  = 12 ' Assign module administrators                 ' Can assign to support admins
  CONST PERM_adminbbssetup           = 15        ' Run the initial BBS setup                    ' Can assign to support admins
  CONST PERM_adminbbsconfigure       = 16        ' Change global BBS settings                   ' Can assign to support admins
  CONST PERM_adminconfigurepermissions = 17      ' Configure support administrator permissions
  CONST PERM_adminconfiguremodulepermissions = 18' Configure module level permissions           ' Can assign to support admins
  CONST PERM_admineditipbans         = 19        ' Edit IP bans                                 ' Can assign to support admins
  CONST PERM_admineditfilteredwords  = 20        ' Edit Filtered words                          ' Can assign to support admins
  CONST PERM_adminbroadcast          = 23        ' Can broadcast a message                      ' Can assign to support admins
  CONST PERM_adminpurgeitems         = 24        ' Can purge old items                          ' Can assign to support admins
  CONST PERM_admineditmailbans       = 25        ' Can edit email bans                          ' Can assign to support admins


  ' BBS MISCELLANEOUS PERMISSIONS (users) 200-399
  CONST PERM_viewprofile             = 200       ' Can view profiles                            ' Can assign to users, Inactive/guests
  CONST PERM_ViewBBS                 = 201       ' Can view the BBS                             ' Can assign to inactive/guests

  ' FORUM LEVEL PERMISSIONS 400-599
  CONST PERM_forumnewthread          = 400       ' Can create a new thread                      ' Assignable to userlevels (special, users, inactive/banned, guests)
  CONST PERM_forumreplyown           = 401       ' Can reply to thread started by the same user ' Assignable to userlevels (special, users, inactive/banned, guests)
  CONST PERM_forumreplyothers        = 402       ' Can reply to thread started by others        ' Assignable to userlevels (special, users, inactive/banned, guests)
  CONST PERM_forumaccess             = 403       ' Can access the forum                         ' Assignable to userlevels (special, users, inactive/banned, guests)
  CONST PERM_forumview               = 404       ' Can view the forum (invisible?)              ' Assignable to userlevels (special, users, inactive/banned, guests)
  CONST PERM_forumeditown            = 405       ' Can edit own messages                        ' Assignable to userlevels (special, users, inactive/banned, guests)
  CONST PERM_forumeditothers         = 406       ' Can edit other's messages                    ' Assignable to userlevels (special, users, inactive/banned, guests)
  CONST PERM_forumattach             = 407       ' Can attach files                             ' Assignable to userlevels (special, users, inactive/banned, guests)
  CONST PERM_forumattachsize         = 408       ' BBS.Maximum attachment size                  ' Assignable to userlevels (special, users, inactive/banned, guests)
  CONST PERM_forumcreatepoll         = 409       ' Can create a poll                            ' Assignable to userlevels (special, users, inactive/banned, guests)
  CONST PERM_forumvotepoll           = 410       ' Can vote on a poll                           ' Assignable to userlevels (special, users, inactive/banned, guests)
  CONST PERM_forumdeleteown          = 411       ' Can delete own messages                      ' Assignable to userlevels (special, users, inactive/banned, guests)
  CONST PERM_forumdeleteothers       = 412       ' Can delete others messages                   ' Assignable to userlevels (special, users, inactive/banned, guests)
  CONST PERM_forumfreeze             = 413       ' Can freeze a thread                          ' Assignable to userlevels (special, users, inactive/banned, guests)
  CONST PERM_forummove               = 414       ' Can move a thread                            ' Assignable to userlevels (special, users, inactive/banned, guests)
  CONST PERM_forumsticky             = 415       ' Can sticky a thread                          ' Assignable to userlevels (special, users, inactive/banned, guests)
  CONST PERM_forumdeletethread       = 416       ' Can delete a thread                          ' Assignable to userlevels (special, users, inactive/banned, guests)
  CONST PERM_forumposthtml           = 417       ' Can use HTML in a post                       ' Assignable to userlevels (special, users, inactive/banned, guests)
  CONST PERM_modforumedit            = 418       ' Can edit forums                              ' Can assign to forum moderators
  CONST PERM_forumallownotifications = 419       ' Can subscribe to threads                     ' Assignable to userlevels (special, users, inactive/banned, guests)
  CONST PERM_forumhideedittag        = 420       ' Can hide the 'edited by' tag?                ' Assignable to userlevels (special, users, inactive/banned, guests)
  CONST PERM_forummaxedittime        = 421       ' Maximimum time in minutes you can edit a post' Assignable to userlevels (special, users, inactive/banned, guests)
  CONST PERM_modforumpermissions     = 422       ' Can edit forum permissions                   ' Can assign to forum moderators
  CONST PERM_canmasssubscribe        = 423       ' Can mass subscribe to forums                 ' Assignable to userlevels (special, users, inactive/banned, guests)
  CONST PERM_modeditmessagedetails   = 424       ' Can edit database level message details      ' Assignable to forum moderators
  CONST PERM_modmovemessages         = 425       ' Can move messages inside threads             ' Assignable to forum moderators
  CONST PERM_modeditspecialaccess    = 426       ' Can edit special access list                 ' Assignable to forum moderators
  CONST PERM_modeditmoderators       = 427       ' Can edit forum moderators                    ' Assignable to forum moderators
  CONST PERM_forumviewpostrevisions  = 428       ' Can view post revisions                      ' Assignable to userlevels (special, users, inactive/banned, guests)

  ' module admin administrative
  CONST PERM_adminforumcreate        = 500       ' Can create forums/move forums           ' Can assign to module administrators
  CONST PERM_adminforumdelete        = 502       ' Can delete forums                       ' Can assign to module administrators
  CONST PERM_admincategorycreateedit = 504       ' Can create/edit categories              ' Can assign to module administrators
  CONST PERM_admincategorydelete     = 505       ' Can delete categories                   ' Can assign to module administrators
  CONST PERM_admineditranks          = 510       ' Can edit forum ranks                    ' Can assign to module administrators
  CONST PERM_admineditdecorations    = 511       ' Can edit decorations                    ' Can assign to module administrators
  CONST PERM_adminpurgeattachments   = 512       ' Can purge attachments                   ' Can assign to module administrators

  ' RANDOMQUOTES PERMISSIONS 700-799
  CONST PERM_addquotes               = 700       ' Can add a random quote
  CONST PERM_editquotes              = 701       ' Can edit or delete your own random quote ' Assignable to userlevels (special, users, inactive/banned, guests)
  CONST PERM_modeditquotes           = 702       ' Can edit or delete other's random quotes ' Assignable to mods

  ' CALENDAR PERMISSIONS 800-999
  CONST PERM_calendaraddpublicevent  = 800       ' Add a public event
  CONST PERM_calendaraddprivateevent = 801       ' Add a private event
  CONST PERM_calendarposthtml        = 802       ' Post HTML?
  CONST PERM_editownevent            = 803       ' Can edit/delete own event
  CONST PERM_editotherevent          = 804       ' Can edit/delete other's events
  CONST PERM_addrecurring            = 805       ' Add recurring event
  CONST PERM_viewotherprivateevents  = 808       ' View other's private events
  CONST PERM_calendaraccess          = 809       ' Can access calendar
  CONST PERM_calendarview            = 810       ' Can view calendar in calendar-view.asp
  CONST PERM_modcalendaredit         = 852       ' Can edit calendars
  CONST PERM_modcalendarmods         = 853       ' Can edit calendar mods
  CONST PERM_modcalendarspecialaccess= 854       ' Can edit special access list
  CONST PERM_modcalendarpermissions  = 855       ' Can edit calendar permissions
  CONST PERM_modcalendarmoderators   = 856       ' Can edit calendar moderators

  ' administrative
  CONST PERM_admincalendarcreate     = 900       ' Can create calendars
  CONST PERM_admincalendardelete     = 901       ' Can delete calendars

  ' ALBUM PERMISSIONS 1000-1199
  CONST PERM_albumcreate             = 1000      ' Can create photo albums
  CONST PERM_albumview               = 1001      ' Can view photo albums
  CONST PERM_modcreategroupalbums    = 1100      ' Can create / edit group albums
  CONST PERM_moddeletegroupalbums    = 1101      ' Can delete group albums


  CONST MODULE_BBS    = 0
  CONST MODULE_Forums = 1   : CONST MODULE_Calendars = 2
  CONST MODULE_FileBase = 3 : CONST MODULE_Albums = 4
  CONST MODULE_Quotes = 5

  CONST USERLEVEL_MEMBER = -1
  CONST USERLEVEL_GROUP  = -2
  CONST USERLEVEL_Guest = 0
  CONST USERLEVEL_InactiveBanned = 10
  CONST USERLEVEL_User = 20
  CONST USERLEVEL_SpecialAccess = 30
  CONST USERLEVEL_Moderator = 40
  CONST USERLEVEL_ModuleAdministrator = 50
  CONST USERLEVEL_SupportAdministrator = 60
  CONST USERLEVEL_GlobalAdministrator = 70

  'UserStatus constants
  CONST US_IncorrectCode = -4
  CONST US_Undefined = -3
  CONST US_NotRegistered = -2
  CONST US_BadPassword = -1
  CONST US_Inactive = 1
  CONST US_Banned = 2
  CONST US_Registered = 3

  CONST TYPE_TEXT     = 1
  CONST TYPE_DROPDOWN = 2

%>