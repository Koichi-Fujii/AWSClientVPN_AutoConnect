
On Error Resume Next

'===========================================================
' オブジェクト初期化
'===========================================================
Set objShell = WScript.CreateObject("WScript.Shell")

For Each strArg In WScript.Arguments
	strArgs = strArgs & Chr(34) & strArg & Chr(34) & Chr(32)
Next

objShell.Run strArgs, vbHide, True

WScript.Quit
