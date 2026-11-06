$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$build = Join-Path $root 'build'
$dist = Join-Path $root 'dist'
& (Join-Path $root 'install.ps1') -PrepareOnly
New-Item -ItemType Directory -Path $dist -Force | Out-Null
$app = Join-Path $dist '校园网自动连接.exe'
$dialer = Join-Path $dist 'CampusDialer.exe'
Copy-Item -LiteralPath (Join-Path $build 'CampusNetwork.exe') -Destination $app -Force
Copy-Item -LiteralPath (Join-Path $build 'CampusDialer.exe') -Destination $dialer -Force
$stage = Join-Path $build ('release-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $stage 'dist'),(Join-Path $stage 'src') -Force | Out-Null
Copy-Item -LiteralPath $app -Destination (Join-Path $stage 'dist\校园网自动连接.exe')
Copy-Item -LiteralPath $dialer -Destination (Join-Path $stage 'dist\CampusDialer.exe')
Copy-Item -LiteralPath (Join-Path $root 'install.ps1') -Destination (Join-Path $stage 'install.ps1')
Copy-Item -LiteralPath (Join-Path $root 'src\Startup.vbs') -Destination (Join-Path $stage 'src\Startup.vbs')
Copy-Item -LiteralPath (Join-Path $root 'install.cmd') -Destination (Join-Path $stage 'install.cmd')
$readme = @'
校园网自动连接 0.1.3

安装：
1. 将压缩包完整解压到一个文件夹。
2. 双击 install.cmd，等待显示安装完成。
3. 通过桌面“校园网自动连接”快捷方式打开工具，选择已有拨号连接并保存，再点击“开启”。

此程序包包含管理窗口、拨号组件和启动脚本。不要只复制单个 EXE 到另一台电脑；它需要配套文件和安装步骤。
安装使用当前用户的文档目录和启动文件夹，并保留已有配置与开关状态。账号密码由 Windows 管理。

卸载：打开桌面程序，点击右上角“卸载”，阅读提示并确认。卸载会移除本工具及其设置，不会删除 Windows 拨号连接和密码；手动下载的程序包会保留。

程序未数字签名，安全软件可能提示；请确认来源后自行判断。此版本尚未在所有电脑上验证重启后的完整拨号。
'@
[IO.File]::WriteAllText((Join-Path $stage '使用说明.txt'),$readme,(New-Object Text.UTF8Encoding $true))
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zipTemp = Join-Path $build ('package-' + [Guid]::NewGuid().ToString('N') + '.zip')
[IO.Compression.ZipFile]::CreateFromDirectory($stage,$zipTemp,[IO.Compression.CompressionLevel]::Optimal,$false)
$zip = Join-Path $dist 'CampusNetwork-v0.1.3-Windows.zip'
Move-Item -LiteralPath $zipTemp -Destination $zip -Force
$oldArchives = @(Get-ChildItem -LiteralPath $dist -Filter 'CampusNetwork-v*.zip' -File | Where-Object { $_.Name -ne [IO.Path]::GetFileName($zip) })
if ($oldArchives.Count -gt 0) { throw 'dist 中还有旧版本压缩包；请先确认历史链接可用，并从当前分支移除旧包。' }
$hashes = foreach($item in @($app,$dialer,$zip)) { (Get-FileHash -LiteralPath $item -Algorithm SHA256).Hash.ToLowerInvariant() + '  ' + [IO.Path]::GetFileName($item) }
[IO.File]::WriteAllLines((Join-Path $dist 'SHA256SUMS.txt'),$hashes,[Text.Encoding]::UTF8)
Write-Output 'Windows 程序包已生成。'
