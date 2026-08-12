# Windows Codex 开发接力手册

这份文档是从 macOS 开发环境切换到 Windows Codex 后的唯一接力入口。代码、设计决策和测试
基线全部通过 Git 同步，不需要复制本机工作区，也不依赖原 Codex 任务的聊天上下文。

## 当前权威状态

- 开发分支：`codex/v0.3.0-beta.1`
- 稳定 macOS 版本：`v0.2.3`，不得改写或重新上传其 Release Assets
- Windows 阶段：跨平台核心、Win32/UIA 诊断边界、安装器后端、完整性校验和诊断 CI 已完成
- 下一个实现任务：在 Windows 实机上绑定当前 Codex UIA 结构，并开发/验证 WPF 浮层与本地化
  安装器界面
- 发布状态：诊断候选物，不是安装器；真实 UI、DPI、生命周期和安装矩阵通过前禁止发布 setup

## 视觉基线

Windows 直接延用当前获准的 macOS v0.2.3 风格和体验，不重新设计：

- 标题栏按钮显示“剩余百分比 + 下次重置”，默认融入背景，悬浮/固定时出现轻微中性色底；
- 百分比、浮窗百分比、进度条和倒计时数字使用同一套 100% 绿、49% 橙、10% 红连续色阶；
- 浮窗保持约 300 逻辑像素宽、12px 圆角、细边框、原生阴影、蓝色小版本徽章和紧凑两列内容；
- 鼠标悬浮显示，再单击固定，再次单击关闭；不抢 Codex 焦点；
- 简体中文、繁体中文、英文和自动语言逻辑保持一致；
- Windows 仅允许使用 Segoe UI、Per-Monitor DPI、原生焦点与高对比度等必要平台适配。

详细参数见
[Windows v0.3.0-beta.1 设计文档](superpowers/specs/2026-08-11-windows-v0.3.0-beta.1-design.md#approved-visual-decision-brief)。

## 1. 在 Windows 同步代码

推荐用 PowerShell 和 Git 新建干净克隆：

```powershell
git clone https://github.com/JaceHwang/codex-usage-sidebar.git
Set-Location .\codex-usage-sidebar
git fetch origin
git switch --track origin/codex/v0.3.0-beta.1
git status --short --branch
git rev-parse HEAD
```

如果电脑上已经有这个仓库，先确认没有未提交修改，不要用 reset 或 checkout 丢弃文件：

```powershell
Set-Location C:\path\to\codex-usage-sidebar
git status --short
git fetch origin
git switch codex/v0.3.0-beta.1
git pull --ff-only
git status --short --branch
git rev-parse HEAD
```

若本地尚未创建该分支，使用：

```powershell
git switch --track origin/codex/v0.3.0-beta.1
```

## 2. 准备 Windows 开发环境

安装以下组件后重新打开 PowerShell：

- Windows 11 x64 和已登录的 Codex 桌面客户端；
- Git for Windows；
- .NET 8 SDK（不是只安装 Runtime）；
- Visual Studio 2022 Build Tools 或 Visual Studio 2022，包含“.NET 桌面开发”工作负载；
- 可选：GitHub CLI，用于下载 Actions 诊断产物。

验证环境：

```powershell
git --version
dotnet --info
dotnet --list-sdks
```

日常开发和诊断都使用普通用户权限，不要以管理员身份启动 Codex、PowerShell 或安装器。

## 3. 在 Windows Codex 打开项目

在 Windows Codex 中打开克隆后的仓库根目录，然后把下面这段作为新任务的第一条消息：

```text
继续开发 Codex Usage Sidebar Windows v0.3.0-beta.1。先完整阅读：
1. docs/WINDOWS-CODEX-CONTINUATION.zh-CN.md
2. docs/superpowers/specs/2026-08-11-windows-v0.3.0-beta.1-design.md
3. docs/superpowers/plans/2026-08-11-windows-v0.3.0-beta.1.md
4. docs/WINDOWS-DEVICE-HANDOFF.zh-CN.md

当前视觉 source of truth 是 macOS v0.2.3，Windows 只做必要平台适配。先验证 Git HEAD 和
运行文档中的基线测试，再在无敏感信息的 Codex 临时任务上采集默认脱敏 UIA 报告。未知 UIA
结构必须隐藏浮层；未经实机验证不要发布或声称 setup 可用。使用 TDD 实现 WPF 浮层、定位和
本地化安装器 UI，并保持 macOS v0.2.3 资产不变。
```

## 4. 运行接力基线

在仓库根目录执行：

```powershell
$ErrorActionPreference = 'Stop'
dotnet restore .\plugins\codex-usage-sidebar\windows\CodexUsageSidebar.Windows.sln
dotnet test .\plugins\codex-usage-sidebar\windows\CodexUsageSidebar.Windows.sln `
  --configuration Release --nologo
dotnet build `
  .\plugins\codex-usage-sidebar\windows\src\CodexUsageSidebar.Windows\CodexUsageSidebar.Windows.csproj `
  --configuration Release --framework net8.0-windows10.0.19041.0 --no-restore --nologo
```

在开始改代码前，基线应保持全部测试通过且无编译警告。若 Git HEAD 与远端分支不同，或测试失败，
先记录完整输出并排查，不要绕过测试。

## 5. 首次实机诊断

1. 在 Codex 新建无敏感信息的临时任务并保持窗口可见。
2. 从成功的 **Windows beta diagnostic candidate** Actions 运行下载诊断产物，按
   [Windows 实机诊断交接手册](WINDOWS-DEVICE-HANDOFF.zh-CN.md)验证摘要和 provenance。
3. 先采集默认脱敏报告；未经明确需要不要添加 `--include-text`：

```powershell
.\CodexUsageSidebar.Control.exe probe C:\Temp\codex-usage-sidebar-probe.json
```

4. 完成左/右/下侧栏、窄窗、最大化、全屏、多显示器、主题、语言和 DPI 矩阵。
5. 将脱敏报告转成版本化 UIA/布局夹具，先写失败测试，再绑定生产选择器和显示浮层。

## 6. Windows 实现顺序

1. 真实 UIA 树与窗口/DPI 证据；
2. 可版本化的语义选择器和布局夹具；
3. 非激活 WPF 紧凑按钮与浮窗，达到 macOS 视觉/交互基线；
4. 主题、三语言、DPI、多显示器、侧栏和窗口状态回归；
5. 本地化 WPF 安装器壳、安装/修复/卸载实测；
6. 签名、provenance、setup 负向验证和 Windows prerelease。

任何未知 Codex 版本或不完整 UIA 结构都应安全隐藏插件，而不是猜测坐标并与原生控件重叠。

## 7. 每次在两台电脑间同步

Windows 完成一个可验证的小阶段后，在当前功能分支提交并推送：

```powershell
git status --short
git add -- <明确的文件列表>
git commit -m "feat: continue Windows beta integration"
git push
```

回到 macOS 时使用 `git fetch origin` 和 `git pull --ff-only` 获取同一分支。不要用聊天记录、压缩包
或网盘作为源码真相；Git 分支、提交 SHA、自动化测试和 provenance 才是接力依据。
