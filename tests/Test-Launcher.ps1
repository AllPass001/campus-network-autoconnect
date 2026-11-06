$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$build = Join-Path $root 'build\tests'
$fixture = Join-Path $build ('launcher 空格-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixture -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $root 'install.cmd') -Destination (Join-Path $fixture 'install.cmd')
$fake = @'
param([switch]$UsePrebuilt)
if(-not $UsePrebuilt){exit 9}
[IO.File]::WriteAllText($env:CAMPUS_LAUNCHER_TEST_RESULT,'ok')
'@
[IO.File]::WriteAllText((Join-Path $fixture 'install.ps1'),$fake,[Text.Encoding]::ASCII)
$result = Join-Path $fixture 'result.txt'
$old = $env:CAMPUS_LAUNCHER_TEST_RESULT
try {
 $env:CAMPUS_LAUNCHER_TEST_RESULT=$result
 $psi=New-Object Diagnostics.ProcessStartInfo
 $psi.FileName=Join-Path $env:WINDIR 'System32\cmd.exe'
 $psi.Arguments='/d /c ""' + (Join-Path $fixture 'install.cmd') + '""'
 $psi.UseShellExecute=$false
 $psi.CreateNoWindow=$true
 $psi.RedirectStandardInput=$true
 $psi.RedirectStandardOutput=$true
 $psi.RedirectStandardError=$true
 $process=[Diagnostics.Process]::Start($psi)
 $process.StandardInput.Close()
 $output=$process.StandardOutput.ReadToEnd()
 $errorOutput=$process.StandardError.ReadToEnd()
 $process.WaitForExit()
 if($process.ExitCode -ne 0 -or -not(Test-Path -LiteralPath $result) -or [IO.File]::ReadAllText($result) -ne 'ok'){throw "安装入口测试失败：$output $errorOutput"}
 Write-Output '根目录 install.cmd 可调用同目录安装脚本和预编译参数。'
} finally {if($null -eq $old){Remove-Item Env:CAMPUS_LAUNCHER_TEST_RESULT -ErrorAction SilentlyContinue}else{$env:CAMPUS_LAUNCHER_TEST_RESULT=$old}}
