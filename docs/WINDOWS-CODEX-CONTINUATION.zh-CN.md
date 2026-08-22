# 在 Codex 中继续 v0.3.2 Windows 开发

## 权威状态

- 分支为 `v0.3.2`；跨电脑接力以 Git 提交 SHA 和提交历史为唯一源码依据。
- `v0.3.2` 已发布 macOS arm64 与 Windows 11 AMD64/x64 安装资产。不得移动 `v0.3.2` 标签、覆盖 Release 资产，也不得修改官方 Codex 应用。
- 当前缺口是 Windows 11 实机 UIA、DPI、生命周期与安装矩阵；便携式 .NET 源码验证已完成，但不能替代实机证据。
- Windows 已对齐额度、Token 使用量、账号身份、三语言、主题图标、倒计时强调、Credits、Bank 与 GitHub 页脚；当前 v0.3.2 卡片不渲染 Tibo X 行。

## 安全同步代码

```powershell
git clone https://github.com/JaceHwang/codex-usage-sidebar.git
Set-Location .\codex-usage-sidebar
git fetch origin --prune
git switch --track origin/v0.3.2
git pull --ff-only
git status --short --branch
git rev-parse HEAD
```

已有仓库时先执行 `git status --short`，不要用 `reset --hard` 或丢弃其他开发者的文件；随后执行 `git fetch origin --prune`、`git switch v0.3.2` 和 `git pull --ff-only`。

## Windows 开发环境

- Windows 11 AMD64/x64 与已登录 Codex 桌面客户端；
- Git for Windows、.NET 8 SDK、Visual Studio 2022 或包含“.NET 桌面开发”工作负载的 Build Tools；
- 可选 GitHub CLI，用于查询 Actions 和 Release 资产。

不要以管理员身份运行 Codex、PowerShell 或安装器。Windows ARM64 不在支持范围内。

## 在 Codex 中开始

打开仓库根目录后，使用下面的首条任务：

```text
继续 Codex Usage Sidebar v0.3.2 Windows 实机验证。先阅读 docs/WINDOWS-BETA.md、
docs/WINDOWS-DEVICE-HANDOFF.zh-CN.md、docs/WINDOWS-V031-PARITY.md 和 docs/ARCHITECTURE.md。
先确认 v0.3.2 Git HEAD，再运行 .NET 构建/测试；只从无敏感信息的 Codex 临时任务采集脱敏 UIA
报告。未知或不安全的 UIA 结构必须隐藏浮层，不得猜测坐标，也不得发布或覆盖 Release 资产。修改
选择器、安装器行为或兼容性声明前，先记录 Windows 实机证据。
```

## 基线命令

```powershell
$ErrorActionPreference = 'Stop'
dotnet restore .\plugins\codex-usage-sidebar\windows\CodexUsageSidebar.Windows.sln
dotnet build .\plugins\codex-usage-sidebar\windows\CodexUsageSidebar.Windows.sln --configuration Release --no-restore --nologo
dotnet test .\plugins\codex-usage-sidebar\windows\CodexUsageSidebar.Windows.sln --configuration Release --no-build --nologo
```

基线通过后，按 [Windows 实机诊断交接手册](WINDOWS-DEVICE-HANDOFF.zh-CN.md) 执行实机矩阵。每个可验证的小阶段都提交到功能分支并推送；回到 macOS 后用 `git fetch origin` 和 `git pull --ff-only` 继续。
