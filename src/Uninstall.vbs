Option Explicit
Dim fso, shell, appDir, startupDir, desktopDir, enabledPath, shortcutPath
Dim errorCount, skippedCount, folder, subFolder, backupPaths(), count, i, names, filename
Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")
appDir = fso.BuildPath(shell.SpecialFolders("MyDocuments"), "Codex\CampusNetworkSwitch")
startupDir = shell.SpecialFolders("Startup")
desktopDir = shell.SpecialFolders("Desktop")
enabledPath = fso.BuildPath(startupDir, "Campus Network Auto Connect.vbs")
shortcutPath = fso.BuildPath(desktopDir, "校园网自动连接.lnk")
errorCount = 0
skippedCount = 0

Sub RemoveKnownFile(filePath)
    Dim n, lastError
    If Not fso.FileExists(filePath) Then Exit Sub
    For n = 1 To 12
        On Error Resume Next
        Err.Clear
        fso.DeleteFile filePath, True
        lastError = Err.Number
        Err.Clear
        On Error GoTo 0
        If lastError = 0 And Not fso.FileExists(filePath) Then Exit Sub
        WScript.Sleep 500
    Next
    errorCount = errorCount + 1
End Sub

Sub RemoveManagedStartup(filePath)
    Dim stream, content, readError, owned
    If Not fso.FileExists(filePath) Then Exit Sub
    On Error Resume Next
    Err.Clear
    Set stream = fso.OpenTextFile(filePath, 1, False, -1)
    content = stream.ReadAll
    stream.Close
    readError = Err.Number
    Err.Clear
    On Error GoTo 0
    If readError <> 0 Then
        errorCount = errorCount + 1
        Exit Sub
    End If
    owned = (InStr(content, "' CampusNetworkSwitch managed launcher") = 1)
    If InStr(content, "Codex\CampusNetworkSwitch\CampusDialer.exe") > 0 And InStr(content, "Codex\CampusNetworkSwitch\connection.txt") > 0 Then owned = True
    If owned Then
        RemoveKnownFile filePath
    Else
        skippedCount = skippedCount + 1
    End If
End Sub

Sub RemoveOwnedShortcut(filePath)
    Dim shortcut, target, expected, readError
    If Not fso.FileExists(filePath) Then Exit Sub
    On Error Resume Next
    Err.Clear
    Set shortcut = shell.CreateShortcut(filePath)
    target = shortcut.TargetPath
    readError = Err.Number
    Err.Clear
    On Error GoTo 0
    expected = fso.BuildPath(appDir, "CampusNetwork.exe")
    If readError <> 0 Then
        errorCount = errorCount + 1
    ElseIf StrComp(target, expected, 1) = 0 Then
        RemoveKnownFile filePath
    Else
        skippedCount = skippedCount + 1
    End If
End Sub

Sub RemoveEmptyFolder(folderPath)
    Dim current, removeError
    If Not fso.FolderExists(folderPath) Then Exit Sub
    On Error Resume Next
    Err.Clear
    Set current = fso.GetFolder(folderPath)
    If (current.Attributes And 1024) <> 0 Then
        skippedCount = skippedCount + 1
    ElseIf current.Files.Count = 0 And current.SubFolders.Count = 0 Then
        fso.DeleteFolder folderPath, False
        removeError = Err.Number
        If removeError <> 0 Then errorCount = errorCount + 1
    Else
        skippedCount = skippedCount + 1
    End If
    Err.Clear
    On Error GoTo 0
End Sub

Sub ShowResult(errors, skipped)
    Dim text
    If errors > 0 Then
        text = "卸载未完全完成，请关闭所有校园网工具窗口后重试。部分文件可能仍被占用。"
    ElseIf skipped > 0 Then
        text = "校园网自动连接已卸载。为避免误删，不属于本工具的文件或快捷方式已保留。"
    Else
        text = "校园网自动连接已卸载，开机自动拨号已关闭。Windows 拨号连接和密码未删除。"
    End If
    shell.Popup text, 0, "校园网自动连接", 64
End Sub

WScript.Sleep 800
RemoveManagedStartup enabledPath
RemoveManagedStartup enabledPath & ".disabled"
RemoveOwnedShortcut shortcutPath
If fso.FolderExists(appDir) Then
    Set folder = fso.GetFolder(appDir)
    If (folder.Attributes And 1024) <> 0 Then
        skippedCount = skippedCount + 1
    Else
        count = 0
        ReDim backupPaths(0)
        For Each subFolder In folder.SubFolders
            Dim re
            Set re = New RegExp
            re.Pattern = "^backup-[0-9]{8}-[0-9]{6}-[0-9]{3}$"
            re.IgnoreCase = True
            If re.Test(subFolder.Name) Then
                ReDim Preserve backupPaths(count)
                backupPaths(count) = subFolder.Path
                count = count + 1
            End If
        Next
        For i = 0 To count - 1
            Set subFolder = fso.GetFolder(backupPaths(i))
            If (subFolder.Attributes And 1024) <> 0 Then
                skippedCount = skippedCount + 1
            Else
                names = Array("CampusNetwork.exe", "CampusDialer.exe", "Campus Network Auto Connect.vbs", "Campus Network Auto Connect.vbs.disabled", "校园网自动连接.lnk")
                For Each filename In names
                    RemoveKnownFile fso.BuildPath(subFolder.Path, filename)
                Next
                RemoveEmptyFolder subFolder.Path
            End If
        Next
        names = Array("CampusNetwork.exe", "CampusDialer.exe", "connection.txt", "delay.txt", "retry.txt", "last_dial.log", "startup-before-migration.vbs", "desktop-before-migration.lnk")
        For Each filename In names
            RemoveKnownFile fso.BuildPath(appDir, filename)
        Next
        RemoveEmptyFolder appDir
    End If
End If
ShowResult errorCount, skippedCount
On Error Resume Next
fso.DeleteFile WScript.ScriptFullName, True
On Error GoTo 0
