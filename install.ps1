[CmdletBinding()]
param([switch]$PrepareOnly, [switch]$UsePrebuilt)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$build = Join-Path $root 'build'
$src = Join-Path $root 'src'
$icon = Join-Path $root 'assets\app.ico'
$assembly = Join-Path $src 'AssemblyInfo.cs'
New-Item -ItemType Directory -Path $build -Force | Out-Null
$appBuild = Join-Path $build 'CampusNetwork.exe'
$dialBuild = Join-Path $build 'CampusDialer.exe'
if ($UsePrebuilt) {
  $dist = Join-Path $root 'dist'
  $prebuiltApp = Join-Path $dist '校园网自动连接.exe'
  $prebuiltDialer = Join-Path $dist 'CampusDialer.exe'
  if (-not (Test-Path -LiteralPath $prebuiltApp) -or -not (Test-Path -LiteralPath $prebuiltDialer)) { throw '找不到程序包中的可执行文件，请重新完整解压程序包。' }
  Copy-Item -LiteralPath $prebuiltApp -Destination $appBuild -Force
  Copy-Item -LiteralPath $prebuiltDialer -Destination $dialBuild -Force
} else {
  $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
  if (-not (Test-Path -LiteralPath $csc)) { $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }
  if (-not (Test-Path -LiteralPath $csc)) { throw '找不到 .NET Framework C# 编译器。' }
  $uninstallSource = Join-Path $src 'Uninstall.vbs'
  if (-not (Test-Path -LiteralPath $uninstallSource)) { throw '找不到卸载组件源码。' }
  & $csc /nologo /target:winexe /codepage:65001 /reference:System.Windows.Forms.dll /reference:System.Drawing.dll "/win32icon:$icon" "/resource:$uninstallSource,CampusNetwork.Uninstall.vbs" "/out:$appBuild" (Join-Path $src 'Dashboard.cs') $assembly
  if ($LASTEXITCODE -ne 0) { throw '管理窗口编译失败。' }
  & $csc /nologo /target:exe /codepage:65001 "/out:$dialBuild" (Join-Path $src 'Dialer.cs') $assembly
  if ($LASTEXITCODE -ne 0) { throw '拨号程序编译失败。' }
}
$launcherText = [IO.File]::ReadAllText((Join-Path $src 'Startup.vbs'), [Text.Encoding]::UTF8)
$buildLauncher = Join-Path $build 'Campus Network Auto Connect.vbs'
[IO.File]::WriteAllText($buildLauncher, $launcherText, [Text.Encoding]::Unicode)
if ($PrepareOnly) { Write-Output '构建完成，未安装或更改开机设置。'; return }
$installDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Codex\CampusNetworkSwitch'
$startupDir = [Environment]::GetFolderPath('Startup')
$desktopDir = [Environment]::GetFolderPath('Desktop')
$enabled = Join-Path $startupDir 'Campus Network Auto Connect.vbs'
$disabled = $enabled + '.disabled'
$link = Join-Path $desktopDir '校园网自动连接.lnk'
$enabledExists = Test-Path -LiteralPath $enabled
$disabledExists = Test-Path -LiteralPath $disabled
if ($enabledExists -and $disabledExists) { throw '同时存在启用和关闭的启动文件，请先检查启动文件夹。' }
$startup = if ($enabledExists) { $enabled } else { $disabled }
if (Test-Path -LiteralPath $startup) {
  $current = [IO.File]::ReadAllText($startup)
  $marker = "' CampusNetworkSwitch managed launcher"
  $legacy = ($launcherText -replace '^\x27 CampusNetworkSwitch managed launcher\r?\n','')
  $normalCurrent = $current.Replace([string][char]13,'').Trim()
  $normalLegacy = $legacy.Replace([string][char]13,'').Trim()
  if (-not $current.StartsWith($marker) -and $normalCurrent -ne $normalLegacy) { throw '启动文件不是本工具管理的版本，已停止以避免覆盖。' }
}
$shell = New-Object -ComObject WScript.Shell
if (Test-Path -LiteralPath $link) {
  $existing = $shell.CreateShortcut($link)
  if (-not $existing.TargetPath.EndsWith('\CampusNetworkSwitch\CampusNetwork.exe',[StringComparison]::OrdinalIgnoreCase)) { throw '桌面已有同名快捷方式且指向其他程序，已停止以避免覆盖。' }
}
$running = @(Get-Process -Name 'CampusNetwork' -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq (Join-Path $installDir 'CampusNetwork.exe') })
if ($running.Count -gt 0) { throw '请先关闭校园网自动连接窗口，再运行安装程序。' }
New-Item -ItemType Directory -Path $installDir -Force | Out-Null
$backupDir = Join-Path $installDir ('backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
$existingFiles = @((Join-Path $installDir 'CampusNetwork.exe'),(Join-Path $installDir 'CampusDialer.exe'),$startup,$link)
$hadExisting = @{}
foreach ($file in $existingFiles) { $hadExisting[$file] = Test-Path -LiteralPath $file }
New-Item -ItemType Directory -Path $backupDir | Out-Null
foreach ($file in $existingFiles) { if ($hadExisting[$file]) { Copy-Item -LiteralPath $file -Destination (Join-Path $backupDir ([IO.Path]::GetFileName($file))) } }
try {
  Copy-Item -LiteralPath $appBuild -Destination (Join-Path $installDir 'CampusNetwork.exe') -Force
  Copy-Item -LiteralPath $dialBuild -Destination (Join-Path $installDir 'CampusDialer.exe') -Force
  Copy-Item -LiteralPath $buildLauncher -Destination $startup -Force
  $shortcut = $shell.CreateShortcut($link)
  $shortcut.TargetPath = Join-Path $installDir 'CampusNetwork.exe'
  $shortcut.WorkingDirectory = $installDir
  $shortcut.IconLocation = (Join-Path $installDir 'CampusNetwork.exe') + ',0'
  $shortcut.Arguments = ''
  $shortcut.Description = '查看并切换校园网开机自动连接'
  $shortcut.Save()
  $check = $shell.CreateShortcut($link)
  if ($check.TargetPath -ne (Join-Path $installDir 'CampusNetwork.exe')) { throw '桌面快捷方式验证失败。' }
  Write-Output '安装完成。请通过桌面快捷方式打开工具。'
  if (-not $enabledExists -and -not $disabledExists) { Write-Output '首次安装默认关闭自动拨号；请选择连接并手动开启。' }
} catch {
  foreach ($file in $existingFiles) {
    $backup = Join-Path $backupDir ([IO.Path]::GetFileName($file))
    if ($hadExisting[$file] -and (Test-Path -LiteralPath $backup)) { Copy-Item -LiteralPath $backup -Destination $file -Force -ErrorAction Continue }
    elseif (-not $hadExisting[$file] -and (Test-Path -LiteralPath $file)) { Remove-Item -LiteralPath $file -Force -ErrorAction Continue }
  }
  throw
}
