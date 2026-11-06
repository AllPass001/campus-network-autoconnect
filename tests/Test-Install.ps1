param([switch]$UsePrebuilt)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$testRoot = Join-Path (Join-Path $root 'build\tests') ('install-' + [Guid]::NewGuid().ToString('N'))
$docs = Join-Path $testRoot 'Documents'
$startup = Join-Path $testRoot 'Startup'
$desktop = Join-Path $testRoot 'Desktop'
foreach ($dir in @($docs,$startup,$desktop)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
$source = [IO.File]::ReadAllText((Join-Path $root 'install.ps1'),[Text.Encoding]::UTF8)
$source = $source.Replace('$root = $PSScriptRoot','$root = $env:CAMPUS_TEST_PROJECT_ROOT')
$source = $source.Replace("[Environment]::GetFolderPath('MyDocuments')",'$env:CAMPUS_TEST_DOCUMENTS')
$source = $source.Replace("[Environment]::GetFolderPath('Startup')",'$env:CAMPUS_TEST_STARTUP')
$source = $source.Replace("[Environment]::GetFolderPath('Desktop')",'$env:CAMPUS_TEST_DESKTOP')
$fixtureScript=Join-Path $testRoot 'install-fixture.ps1'
[IO.File]::WriteAllText($fixtureScript,$source,(New-Object Text.UTF8Encoding $true))
$env:CAMPUS_TEST_PROJECT_ROOT=$root
$env:CAMPUS_TEST_DOCUMENTS=$docs
$env:CAMPUS_TEST_STARTUP=$startup
$env:CAMPUS_TEST_DESKTOP=$desktop
try {
 & $fixtureScript -UsePrebuilt:$UsePrebuilt
 $install=Join-Path $docs 'Codex\CampusNetworkSwitch'
 $on=Join-Path $startup 'Campus Network Auto Connect.vbs'
 $off=$on+'.disabled'
 $link=Join-Path $desktop '校园网自动连接.lnk'
 if(-not(Test-Path -LiteralPath $off) -or (Test-Path -LiteralPath $on) -or -not(Test-Path -LiteralPath $link)){throw '首次安装验证失败。'}
 $shell=New-Object -ComObject WScript.Shell
 if($shell.CreateShortcut($link).TargetPath -ne (Join-Path $install 'CampusNetwork.exe')){throw '桌面快捷方式验证失败。'}
 $appBytes=[IO.File]::ReadAllBytes((Join-Path $install 'CampusNetwork.exe'))
 $appAssembly=[Reflection.Assembly]::Load($appBytes)
 $resource=$appAssembly.GetManifestResourceStream('CampusNetwork.Uninstall.vbs')
 if($null -eq $resource){throw '安装程序中缺少卸载组件。'}
 try { $reader=New-Object IO.StreamReader($resource,[Text.Encoding]::UTF8); try { $embedded=$reader.ReadToEnd() } finally {$reader.Dispose()} } finally {$resource.Dispose()}
 $expectedPath=Join-Path $root 'src\Uninstall.vbs'
 if(Test-Path -LiteralPath $expectedPath){$expected=[IO.File]::ReadAllText($expectedPath,[Text.Encoding]::UTF8);if($embedded.Replace([string][char]13,'') -ne $expected.Replace([string][char]13,'')){throw '卸载组件内容不匹配。'}}
 elseif(-not $embedded.Contains('Sub RemoveManagedStartup')){throw '卸载组件内容无效。'}

 Move-Item -LiteralPath $off -Destination $on
 [IO.File]::WriteAllText((Join-Path $install 'delay.txt'),'8',[Text.Encoding]::ASCII)
 [IO.File]::WriteAllText((Join-Path $install 'retry.txt'),'4,7',[Text.Encoding]::ASCII)
 & $fixtureScript -UsePrebuilt:$UsePrebuilt
 if(-not(Test-Path -LiteralPath $on) -or (Test-Path -LiteralPath $off)){throw '升级后启用状态没有保留。'}
 if([IO.File]::ReadAllText((Join-Path $install 'delay.txt')) -ne '8' -or [IO.File]::ReadAllText((Join-Path $install 'retry.txt')) -ne '4,7'){throw '升级后用户设置发生变化。'}
 [IO.File]::WriteAllText($on,'unrelated user script',[Text.Encoding]::ASCII)
 $blocked=$false
 try { & $fixtureScript -UsePrebuilt:$UsePrebuilt } catch { $blocked=$true }
 if(-not $blocked -or [IO.File]::ReadAllText($on) -ne 'unrelated user script'){throw '未能保护已有的非本工具启动文件。'}
 Write-Output '首次安装、升级保留设置及同名文件保护均通过。'
} finally {
 foreach($name in @('CAMPUS_TEST_PROJECT_ROOT','CAMPUS_TEST_DOCUMENTS','CAMPUS_TEST_STARTUP','CAMPUS_TEST_DESKTOP')) {Remove-Item ("Env:"+$name) -ErrorAction SilentlyContinue}
}
