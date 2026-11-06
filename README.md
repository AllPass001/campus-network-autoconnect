# 校园网自动连接

Windows 用户登录后自动连接已有的宽带拨号（RAS/PPPoE）连接。通过一个窗口管理开关、拨号连接、首次等待时间和有限重试，并用短暂提示框显示尝试和结果。

## 功能

- 从 Windows 已有拨号连接中选择目标；重命名或添加连接后可刷新列表。
- 自定义首次等待 0–300 秒、总拨号次数 1–10 次（包含首次）和重试间隔 1–300 秒。
- 对部分线路或设备暂时不可用的错误重试；账号或密码等错误不重复尝试，失败后打开 Windows 拨号窗口。
- 使用 Windows 保存的账号密码；程序不把密码写入脚本、配置或日志。
- 保留现有的拨号设置及开关状态。

## 要求

- Windows 10 或 Windows 11，已创建可通过 Windows 拨号的连接。
- Windows 自带的 .NET Framework 4.x 和 Windows Script Host；从源码构建时还需要其 C# 编译器。
- 成功的自动拨号通常需要先在 Windows 中保存对应连接的凭据。

此工具处理的是 Windows RAS 拨号，不包含网页认证；第三方校园网客户端或 Wi-Fi 登录网页可能不适用。

## 下载现成程序包（推荐）

下载 [CampusNetwork-v0.1.2-Windows.zip](dist/CampusNetwork-v0.1.2-Windows.zip)，**完整解压**后双击 `install.cmd`。安装完成后，从桌面的“校园网自动连接”快捷方式打开。

仓库中也单独提供了 [校园网自动连接.exe](dist/校园网自动连接.exe)，方便查看或在已有安装的电脑上运行。首次在另一台电脑使用时，请使用完整程序包：仅复制这个 EXE 不会安装拨号组件或开机启动脚本。程序包中不包含任何个人拨号配置或密码。

安装会保留本工具已有的连接、等待时间和开关状态；首次安装默认关闭自动拨号，请在窗口中选择连接、保存后手动开启。

## 从源码安装或升级

下载或克隆本仓库，在仓库目录打开 PowerShell，运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

脚本只为当前用户安装，编译到本地，并在桌面创建“校园网自动连接”快捷方式。首次安装默认关闭自动拨号：打开工具，选择连接并保存，再点击“开启”。已有安装会保留配置和当前启用状态，并备份要替换的程序和启动脚本。

安装脚本对该次 PowerShell 进程使用 ExecutionPolicy Bypass，以便运行未签名的本地脚本。安装前可先阅读源码和脚本。程序未进行数字签名，安全软件可能提示；请先确认文件来源与提示内容。

## 历史版本

- [0.1.1 Windows 完整安装包](dist/CampusNetwork-v0.1.1-Windows.zip)：上一版，未包含卸载按钮。
- [0.1.0 源码包](dist/CampusNetwork-v0.1.0-source.zip)：初始版本，需从源码构建。

历史版本会保留用于回溯；新安装建议使用当前版本。每个版本的具体改动见 [更新日志](CHANGELOG.md)。

## 卸载

打开“校园网自动连接”，点击右上角“卸载”，阅读提示后确认。工具会移除其启动项、专属快捷方式、程序和本工具保存的设置。Windows 拨号连接及 Windows 保存的凭据不会删除；手动下载的程序包和复制的程序文件会保留。为避免误删，安装目录中的其他文件和不属于本工具的同名启动项或快捷方式会保留。

## 使用与故障排查

1. 双击桌面快捷方式，选择 Windows 中已有的拨号连接，点击“保存连接”。
2. 设置等待时间、总拨号次数和重试间隔，点击“保存设置”。
3. 登录后按设置开始拨号，尝试和结果会显示短暂的提示框。连接成功表示 RAS 拨号成功，不保证校园网网页认证已完成。
4. 连接名称改变后，在工具中刷新、重新选择并保存；账号密码变更时，点击“打开 Windows 拨号设置”进行更新。

运行文件及用户配置位于当前用户的“文档”目录下的 `Codex\CampusNetworkSwitch`；请勿删除该文件夹，否则自动拨号无法工作。启动入口位于当前用户的 Windows 启动文件夹。

如果发生错误，检查工具里的开关状态、已保存连接与 Windows 保存的凭据。可查看运行目录中的 `last_dial.log`（含时间和错误代码）；分享日志前请自行检查其中是否包含个人信息。还可查看安全软件是否拦截未签名程序。

## 构建和测试

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -PrepareOnly
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-Install.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-Uninstall.ps1
```

测试通过模拟拨号程序验证设置、重试和提示逻辑，不连接或断开真实网络。每次实际发布前仍应在目标电脑上验证登录后的完整拨号流程。

## 隐私与版本

个人拨号配置、日志和 Windows 电话簿不应提交到 Git；dist 中仅包含从项目源码构建的程序包。项目变更记录见 [CHANGELOG.md](CHANGELOG.md)；后续版本使用 Git 提交和标签保留历史。
