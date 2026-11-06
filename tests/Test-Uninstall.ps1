$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$build = Join-Path $root 'build\tests'
New-Item -ItemType Directory -Path $build -Force | Out-Null
$fixture = Join-Path $build ('uninstall-' + [Guid]::NewGuid().ToString('N'))
$docs = Join-Path $fixture 'Documents'
$startup = Join-Path $fixture 'Startup'
$desktop = Join-Path $fixture 'Desktop'
$install = Join-Path $docs 'Codex\CampusNetworkSwitch'
foreach($dir in @($docs,$startup,$desktop,$install)){New-Item -ItemType Directory -Path $dir -Force | Out-Null}
$src = [IO.File]::ReadAllText((Join-Path $root 'src\Uninstall.vbs'),[Text.Encoding]::UTF8)
$src = $src.Replace('shell.SpecialFolders("MyDocuments")','shell.ExpandEnvironmentStrings("%CAMPUS_TEST_DOCUMENTS%")')
$src = $src.Replace('shell.SpecialFolders("Startup")','shell.ExpandEnvironmentStrings("%CAMPUS_TEST_STARTUP%")')
$src = $src.Replace('shell.SpecialFolders("Desktop")','shell.ExpandEnvironmentStrings("%CAMPUS_TEST_DESKTOP%")')
$src = $src.Replace('WScript.Sleep 800','WScript.Sleep 1').Replace('WScript.Sleep 500','WScript.Sleep 5')
$src = $src.Replace('fso.DeleteFile WScript.ScriptFullName, True',"' test helper retained")
$resultSub = @'
Sub ShowResult(errors, skipped)
    Dim outFile
    Set outFile = fso.OpenTextFile(fso.BuildPath(shell.ExpandEnvironmentStrings("%CAMPUS_TEST_ROOT%"), "result.txt"), 2, True, 0)
    outFile.WriteLine errors & ":" & skipped
    outFile.Close
End Sub
'@
$src = [regex]::Replace($src,'(?s)Sub ShowResult\(errors, skipped\).*?End Sub',$resultSub)
$testScript = Join-Path $fixture 'uninstall-test.vbs'
[IO.File]::WriteAllText($testScript,$src,[Text.Encoding]::Unicode)
$env:CAMPUS_TEST_DOCUMENTS=$docs
$env:CAMPUS_TEST_STARTUP=$startup
$env:CAMPUS_TEST_DESKTOP=$desktop
$env:CAMPUS_TEST_ROOT=$fixture
$shell=New-Object -ComObject WScript.Shell
$on=Join-Path $startup 'Campus Network Auto Connect.vbs'
$link=Join-Path $desktop '校园网自动连接.lnk'
$owned=@('CampusNetwork.exe','CampusDialer.exe','connection.txt','delay.txt','retry.txt','last_dial.log','startup-before-migration.vbs','desktop-before-migration.lnk')
try {
 foreach($scenario in @('clean','legacy','foreign','locked')) {
  New-Item -ItemType Directory -Path $install -Force | Out-Null
  foreach($name in $owned){[IO.File]::WriteAllText((Join-Path $install $name),'owned')}
  $backup=Join-Path $install 'backup-20261106-123456-789'
  New-Item -ItemType Directory -Path $backup -Force | Out-Null
  foreach($name in @('CampusNetwork.exe','CampusDialer.exe','Campus Network Auto Connect.vbs')){[IO.File]::WriteAllText((Join-Path $backup $name),'backup')}
  if($scenario -eq 'foreign') {
   [IO.File]::WriteAllText((Join-Path $install 'user-notes.txt'),'keep me')
   [IO.File]::WriteAllText($on,'unrelated user script',[Text.Encoding]::Unicode)
  } elseif($scenario -eq 'legacy') { $legacy=[IO.File]::ReadAllText((Join-Path $root 'src\Startup.vbs'),[Text.Encoding]::UTF8) -replace '^\x27 CampusNetworkSwitch managed launcher\r?\n',''; [IO.File]::WriteAllText($on,$legacy,[Text.Encoding]::Unicode) } else { [IO.File]::WriteAllText($on,"' CampusNetworkSwitch managed launcher",[Text.Encoding]::Unicode) }
  $shortcut=$shell.CreateShortcut($link)
  $shortcut.TargetPath=if($scenario -eq 'foreign'){Join-Path $fixture 'different.exe'}else{Join-Path $install 'CampusNetwork.exe'}
  $shortcut.Save()
  $lock=$null
  if($scenario -eq 'locked'){$lock=[IO.File]::Open((Join-Path $install 'CampusNetwork.exe'),[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::None)}
  try {& (Join-Path $env:WINDIR 'System32\cscript.exe') //nologo $testScript;if($LASTEXITCODE -ne 0){throw "卸载测试脚本失败：$scenario"}} finally {if($lock){$lock.Dispose()}}
  $result=[IO.File]::ReadAllText((Join-Path $fixture 'result.txt')).Trim()
  if($scenario -eq 'clean' -or $scenario -eq 'legacy') {
   if($result -ne '0:0' -or (Test-Path -LiteralPath $on) -or (Test-Path -LiteralPath $link) -or (Test-Path -LiteralPath $install)){throw "完整卸载失败：$result"}
  } elseif($scenario -eq 'foreign') {
   if($result -ne '0:3' -or -not(Test-Path -LiteralPath $on) -or -not(Test-Path -LiteralPath $link) -or -not(Test-Path -LiteralPath (Join-Path $install 'user-notes.txt'))){throw "非本工具文件保护失败：$result"}
   Remove-Item -LiteralPath $on,$link,(Join-Path $install 'user-notes.txt') -Force
  } else {
   if(-not $result.StartsWith('1:') -or -not(Test-Path -LiteralPath (Join-Path $install 'CampusNetwork.exe'))){throw "占用文件提示失败：$result"}
   Remove-Item -LiteralPath (Join-Path $install 'CampusNetwork.exe') -Force
  }
  Write-Output "通过卸载场景：$scenario（$result）"
 }
 $selfDeleteScript=Join-Path $fixture 'uninstall-self-delete.vbs'
 $selfDeleteSource=$src.Replace("' test helper retained",'fso.DeleteFile WScript.ScriptFullName, True')
 [IO.File]::WriteAllText($selfDeleteScript,$selfDeleteSource,[Text.Encoding]::Unicode)
 & (Join-Path $env:WINDIR 'System32\cscript.exe') //nologo $selfDeleteScript
 if($LASTEXITCODE -ne 0 -or (Test-Path -LiteralPath $selfDeleteScript)){throw '卸载临时程序未能自行清理。'}
 Write-Output '通过临时卸载程序自清理测试。'
} finally {
 foreach($name in @('CAMPUS_TEST_DOCUMENTS','CAMPUS_TEST_STARTUP','CAMPUS_TEST_DESKTOP','CAMPUS_TEST_ROOT')){Remove-Item ("Env:"+$name) -ErrorAction SilentlyContinue}
}
Write-Output '卸载模拟测试全部通过，未更改真实拨号设置。'
