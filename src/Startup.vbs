' CampusNetworkSwitch managed launcher
Option Explicit
Dim shell, fso, file, configPath, entry, book, dialCommand, phoneCommand, result, dryRun
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

Sub Notice(kind, currentAttempt, totalAttempts, failureCode)
    Dim command
    command = Chr(34) & shell.ExpandEnvironmentStrings("%SystemRoot%") & "\System32\wscript.exe" & Chr(34) & " " & Chr(34) & WScript.ScriptFullName & Chr(34) & " /notice " & kind & " " & currentAttempt & " " & totalAttempts & " " & failureCode
    On Error Resume Next
    shell.Run command, 0, False
    On Error GoTo 0
End Sub
Sub LogLine(message)
    Dim logFile, logPath
    On Error Resume Next
    logPath = fso.BuildPath(shell.SpecialFolders("MyDocuments"), "Codex\CampusNetworkSwitch\last_dial.log")
    Set logFile = fso.OpenTextFile(logPath, 8, True, 0)
    logFile.WriteLine Now & " " & message
    logFile.Close
    On Error GoTo 0
End Sub
If WScript.Arguments.Count > 0 Then
    If LCase(WScript.Arguments(0)) = "/notice" Then
        If WScript.Arguments.Count < 5 Then WScript.Quit 1
        Dim noticeText, noticeTime, kind, num, total, code
        kind = WScript.Arguments(1)
        num = WScript.Arguments(2)
        total = WScript.Arguments(3)
        code = WScript.Arguments(4)
        noticeTime = 4
        Select Case kind
            Case "attempt"
                noticeText = "正在自动拨号，第 " & num & "/" & total & " 次。"
                noticeTime = 3
            Case "success"
                noticeText = "自动拨号成功，校园网已连接。"
                noticeTime = 5
            Case "retry"
                noticeText = "本次拨号未成功，将按设置自动重试。"
                noticeTime = 4
            Case "missing"
                noticeText = "自动拨号组件暂时无法启动，将按设置重试。"
                noticeTime = 5
            Case "failed"
                noticeText = "自动拨号未成功（代码 " & code & "），将打开 Windows 拨号窗口。"
                noticeTime = 8
            Case "missingfinal"
                noticeText = "拨号组件无法启动，请检查安全软件或联系支持。将打开 Windows 拨号窗口。"
                noticeTime = 8
            Case "config"
                noticeText = "自动拨号配置不可用，请打开校园网自动连接工具检查设置。"
                noticeTime = 8
            Case "fallback"
                noticeText = "无法打开 Windows 拨号窗口，请在 Windows 网络设置中手动连接。"
                noticeTime = 8
            Case "test"
                noticeText = "这是一条测试提醒：自动拨号进度和结果会在这里显示。"
                noticeTime = 4
            Case Else
                WScript.Quit 1
        End Select
        shell.Popup noticeText, noticeTime, "校园网自动连接", 64
        WScript.Quit 0
    End If
End If

dryRun = False
If WScript.Arguments.Count > 0 Then
    If LCase(WScript.Arguments(0)) = "/dryrun" Then dryRun = True
End If
Dim delayPath, delayFile, delayText, seconds
seconds = 3
delayPath = fso.BuildPath(shell.SpecialFolders("MyDocuments"), "Codex\CampusNetworkSwitch\delay.txt")
If fso.FileExists(delayPath) Then
    On Error Resume Next
    Set delayFile = fso.OpenTextFile(delayPath, 1, False, 0)
    delayText = Trim(delayFile.ReadAll)
    delayFile.Close
    If Err.Number = 0 Then
        If IsNumeric(delayText) Then
            If CDbl(delayText) >= 0 And CDbl(delayText) <= 300 And CDbl(delayText) = Fix(CDbl(delayText)) Then seconds = CLng(delayText)
        End If
    End If
    Err.Clear
    On Error GoTo 0
End If
If Not dryRun Then WScript.Sleep seconds * 1000
configPath = fso.BuildPath(shell.SpecialFolders("MyDocuments"), "Codex\CampusNetworkSwitch\connection.txt")
If Not fso.FileExists(configPath) Then
    If Not dryRun Then Notice "config", 0, 0, 0
    WScript.Quit 2
End If
On Error Resume Next
Set file = fso.OpenTextFile(configPath, 1, False, -1)
entry = file.ReadLine
book = file.ReadLine
file.Close
If Err.Number <> 0 Then
    If Not dryRun Then Notice "config", 0, 0, 0
    WScript.Quit 2
End If
On Error GoTo 0
If Len(entry) = 0 Or Len(book) = 0 Or InStr(entry, Chr(34)) > 0 Or InStr(book, Chr(34)) > 0 Then
    If Not dryRun Then Notice "config", 0, 0, 0
    WScript.Quit 2
End If
dialCommand = Chr(34) & fso.BuildPath(shell.SpecialFolders("MyDocuments"), "Codex\CampusNetworkSwitch\CampusDialer.exe") & Chr(34)
phoneCommand = Chr(34) & shell.ExpandEnvironmentStrings("%SystemRoot%") & "\System32\rasphone.exe" & Chr(34) & " -f " & Chr(34) & book & Chr(34) & " -d " & Chr(34) & entry & Chr(34)
Dim retryPath, retryFile, retryText, retryParts, maxAttempts, retrySeconds
maxAttempts = 3
retrySeconds = 5
retryPath = fso.BuildPath(shell.SpecialFolders("MyDocuments"), "Codex\CampusNetworkSwitch\retry.txt")
If fso.FileExists(retryPath) Then
    On Error Resume Next
    Set retryFile = fso.OpenTextFile(retryPath, 1, False, 0)
    retryText = Trim(retryFile.ReadAll)
    retryFile.Close
    If Err.Number = 0 Then
        retryParts = Split(retryText, ",")
        If UBound(retryParts) = 1 Then
            If IsNumeric(retryParts(0)) And IsNumeric(retryParts(1)) Then
                If CDbl(retryParts(0)) >= 1 And CDbl(retryParts(0)) <= 10 And CDbl(retryParts(0)) = Fix(CDbl(retryParts(0))) And CDbl(retryParts(1)) >= 1 And CDbl(retryParts(1)) <= 300 And CDbl(retryParts(1)) = Fix(CDbl(retryParts(1))) Then
                    maxAttempts = CLng(retryParts(0))
                    retrySeconds = CLng(retryParts(1))
                End If
            End If
        End If
    End If
    Err.Clear
    On Error GoTo 0
End If
If dryRun Then
    WScript.Echo "ATTEMPTS=" & maxAttempts
    WScript.Echo "RETRY_SECONDS=" & retrySeconds
    WScript.Echo "DELAY=" & seconds
    WScript.Echo "DIAL=" & dialCommand
    WScript.Echo "FALLBACK=" & phoneCommand
    WScript.Quit 0
End If
Dim attempt, startError, fallbackError
attempt = 0
LogLine "start max_attempts=" & maxAttempts & " interval=" & retrySeconds
LogLine "component_exists=" & fso.FileExists(fso.BuildPath(shell.SpecialFolders("MyDocuments"), "Codex\CampusNetworkSwitch\CampusDialer.exe"))
Do
    attempt = attempt + 1
    Notice "attempt", attempt, maxAttempts, 0
    LogLine "attempt=" & attempt
    result = 10010
    On Error Resume Next
    Err.Clear
    result = shell.Run(dialCommand, 0, True)
    startError = Err.Number
    On Error GoTo 0
    If startError <> 0 Then result = 10010
    LogLine "result=" & result & " start_error=" & startError
    If result = 0 Then Exit Do
    Select Case result
        Case 633, 638, 650, 651, 676, 678, 680, 797, 10010
            If attempt < maxAttempts Then
                If result = 10010 Then
                    Notice "missing", attempt, maxAttempts, result
                Else
                    Notice "retry", attempt, maxAttempts, result
                End If
                WScript.Sleep retrySeconds * 1000
            Else
                Exit Do
            End If
        Case Else
            Exit Do
    End Select
Loop
If result = 0 Then
    Notice "success", attempt, maxAttempts, 0
    LogLine "connected"
Else
    If result = 10010 Then
        Notice "missingfinal", attempt, maxAttempts, result
    Else
        Notice "failed", attempt, maxAttempts, result
    End If
    On Error Resume Next
    Err.Clear
    shell.Run phoneCommand, 1, False
    fallbackError = Err.Number
    On Error GoTo 0
    LogLine "fallback_error=" & fallbackError
    If fallbackError <> 0 Then Notice "fallback", attempt, maxAttempts, result
End If
