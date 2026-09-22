<%@ Language=VBScript %>
<%
' Regression cover for If block resolution at ASP tag boundaries.
'
' Single-line If, branch chains (ElseIf/Else) and block If heads must stay distinct:
' a single-line If is complete when a tag boundary terminates its branch body, while a
' branch chain keeps its block open and is closed by the End If in the next script block.
Dim c, t, s, warn

Response.Write "BLOCK_RES_START<br>"

c = 2
t = ""
s = "abc?x=1"
warn = True
%>
<% If c = 1 Then Response.Write "one" ElseIf c = 2 Then Response.Write "two" %><% End If %><br>
<% If c = 1 Then %><% ElseIf c = 2 Then Response.Write "two" %><% End If %><br>
<% If c = 0 Then Response.Write "yes" Else Response.Write "no" %><% End If %><br>
<% If c = 0 Then Response.Write "yes" %><% Else %><% Response.Write "no" %><% End If %><br>
<% If True Then %><% If True Then t = t & "I" %><% t = t & "B" %><% End If %><% Response.Write t %><br>
<% t = "" : If True Then %><% If False Then t = t & "I" %><% t = t & "B" %><% End If %><% Response.Write t %><br>
<% If InStr(s, "?") > 0 Then s = Left(s, InStr(s, "?") - 1) : End If : Response.Write s %><br>
<% If warn Then Response.Write "tail-ok" %>TAIL
<%
Response.Write "<br>BLOCK_RES_END"
%>