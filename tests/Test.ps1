$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$build = Join-Path $root 'build\tests'
New-Item -ItemType Directory -Path $build -Force | Out-Null
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $csc)) { $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }
if (-not (Test-Path -LiteralPath $csc)) { throw '找不到 C# 编译器。' }
$ui = Join-Path $build 'RetryUiTest.exe'
$mock = Join-Path $build 'RetryMock.exe'
& $csc /nologo /target:exe /codepage:65001 /reference:System.Windows.Forms.dll /reference:System.Drawing.dll /main:RetryUiTest "/out:$ui" (Join-Path $root 'src\Dashboard.cs') (Join-Path $PSScriptRoot 'RetryUiTest.cs')
if ($LASTEXITCODE -ne 0) { throw '界面测试编译失败。' }
& $ui
if ($LASTEXITCODE -ne 0) { throw "界面设置测试失败，代码：$LASTEXITCODE" }
& $csc /nologo /target:exe /codepage:65001 "/out:$mock" (Join-Path $PSScriptRoot 'RetryMock.cs')
if ($LASTEXITCODE -ne 0) { throw '模拟拨号器编译失败。' }
$fixture = Join-Path $build 'fixture'
$testAsset = Join-Path $fixture 'Codex\CampusNetworkSwitch'
New-Item -ItemType Directory -Path $testAsset -Force | Out-Null
Copy-Item -LiteralPath $mock -Destination (Join-Path $testAsset 'MockPhone.exe') -Force
[IO.File]::WriteAllText((Join-Path $testAsset 'connection.txt'), ('test' + [Environment]::NewLine + 'C:\Test\phonebook.pbk' + [Environment]::NewLine), [Text.Encoding]::Unicode)
[IO.File]::WriteAllText((Join-Path $testAsset 'delay.txt'), '0', [Text.Encoding]::ASCII)
[IO.File]::WriteAllText((Join-Path $testAsset 'retry.txt'), '3,5', [Text.Encoding]::ASCII)
$script = [IO.File]::ReadAllText((Join-Path $root 'src\Startup.vbs'), [Text.Encoding]::UTF8)
$script = $script.Replace('shell.SpecialFolders("MyDocuments")','shell.ExpandEnvironmentStrings("%CAMPUS_TEST_DOCUMENTS%")')
$notice = @'
Sub Notice(kind, currentAttempt, totalAttempts, failureCode)
    Dim outFile
    Set outFile = fso.OpenTextFile(fso.BuildPath(shell.ExpandEnvironmentStrings("%CAMPUS_TEST_DOCUMENTS%"), "Codex\CampusNetworkSwitch\notices.txt"), 8, True, 0)
    outFile.WriteLine kind & ":" & currentAttempt & ":" & totalAttempts & ":" & failureCode
    outFile.Close
End Sub
'@
$script = [regex]::Replace($script, '(?s)Sub Notice\(kind, currentAttempt, totalAttempts, failureCode\).*?End Sub', $notice)
$script = $script.Replace('WScript.Sleep retrySeconds * 1000','WScript.Sleep 5')
$phone = 'phoneCommand = Chr(34) & fso.BuildPath(shell.ExpandEnvironmentStrings("%CAMPUS_TEST_DOCUMENTS%"), "Codex\CampusNetworkSwitch\MockPhone.exe") & Chr(34)'
$script = [regex]::Replace($script, '(?m)^phoneCommand = .*$', $phone)
$testScript = Join-Path $build 'startup-test.vbs'
[IO.File]::WriteAllText($testScript, $script, [Text.Encoding]::Unicode)
$oldLocal = $env:LOCALAPPDATA
$oldTest = $env:CAMPUS_TEST_DOCUMENTS
try {
 $env:CAMPUS_TEST_DOCUMENTS = $fixture
 $env:LOCALAPPDATA = Join-Path $fixture 'Codex'
 foreach ($case in @(@('0','success',1),@('651,651,0','success',3),@('691','failed',1),@('missing','missingfinal',3))) {
  foreach($name in @('count.txt','fallback.txt','notices.txt','last_dial.log','CampusDialer.exe')) { $p=Join-Path $testAsset $name; if(Test-Path -LiteralPath $p){Remove-Item -LiteralPath $p} }
  if($case[0] -ne 'missing') {
   Copy-Item -LiteralPath $mock -Destination (Join-Path $testAsset 'CampusDialer.exe')
   [IO.File]::WriteAllText((Join-Path $testAsset 'codes.txt'),$case[0],[Text.Encoding]::ASCII)
  }
  & (Join-Path $env:WINDIR 'System32\cscript.exe') //nologo $testScript
  if($LASTEXITCODE -ne 0){throw "启动脚本测试失败：$($case[0])"}
  $events=Get-Content -LiteralPath (Join-Path $testAsset 'notices.txt')
  $attempts=@($events | Where-Object { $_ -match '^attempt:' }).Count
  $final=@($events | Where-Object { $_ -like "$($case[1]):*" }).Count
  if($attempts -ne $case[2] -or $final -ne 1){throw "错误的重试或提示结果：$($case[0])"}
  Write-Output "通过：$($case[0])，尝试 $attempts 次，结果 $($case[1])。"
 }
} finally {
 $env:LOCALAPPDATA=$oldLocal
 if($null -eq $oldTest){Remove-Item Env:CAMPUS_TEST_DOCUMENTS -ErrorAction SilentlyContinue}else{$env:CAMPUS_TEST_DOCUMENTS=$oldTest}
}
Write-Output '所有模拟测试已通过，未拨号或断网。'
