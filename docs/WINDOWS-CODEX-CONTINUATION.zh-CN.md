# 在 Codex 中继续 Windows 维护工作

## 权威状态

- 分支为 `main`；跨电脑接力以 Git 提交 SHA 和提交历史为源码依据。
- v0.3.3 是已发布的 Windows 11 AMD64/x64 版本。不得移动 `v0.3.3` 标签、覆盖 Release
  资产，也不得修改官方 Codex 安装包。
- 发布证据：已发布安装包绑定 `docs/validation/windows-v0.3.3.json` 中完整的 85 项实机记录；
  未知 UIA 结构仍保持失败隐藏。
- 兼容性：安装包支持使用签名 HTTPS 兼容包更新选择器。用户不需要手动编辑 `selectors.json`；
  如果遇到未知结构，请按诊断手册提交报告。

## 安全同步代码

```powershell
git clone https://github.com/JaceHwang/codex-usage-sidebar.git
Set-Location .\codex-usage-sidebar
git fetch origin --prune
git switch --track origin/main
git pull --ff-only
git status --short --branch
git rev-parse HEAD
```

已有仓库时先执行 `git status --short`，不要用 `reset --hard` 或丢弃其他开发者的文件；随后
执行 `git fetch origin --prune`、`git switch main` 和 `git pull --ff-only`。

## Windows 开发环境

- Windows 11 AMD64/x64 与已登录 Codex 桌面客户端；
- Git for Windows、.NET 8 SDK、Visual Studio 2022 或包含“.NET 桌面开发”工作负载的 Build Tools；
- 可选 GitHub CLI，用于查询 Actions 和 Release 资产。

不要以管理员身份运行 Codex、PowerShell 或安装器。v0.3.3 安装包暂不支持 Windows ARM64。

## 在 Codex 中开始

打开仓库根目录后，使用下面的首条任务：

```text
从 main 继续 Codex Usage Sidebar Windows 维护。先阅读 docs/releases/v0.3.3.md、
docs/WINDOWS-BETA.md、docs/WINDOWS-DEVICE-HANDOFF.zh-CN.md 和 docs/ARCHITECTURE.md。确认已发布的
v0.3.3 Release 并运行文档中的 .NET 构建/测试。如果排查浮窗消失，只从无敏感信息的 Codex
临时任务采集脱敏 UIA 报告。未知或不安全的 UIA 结构必须隐藏浮窗，不得猜测坐标、手动修改
selectors.json 或覆盖 Release 资产。修改选择器或安装器行为前，先记录可复现的诊断证据。
```

## 基线命令

```powershell
$ErrorActionPreference = 'Stop'
dotnet restore .\plugins\codex-usage-sidebar\windows\CodexUsageSidebar.Windows.sln
dotnet build .\plugins\codex-usage-sidebar\windows\CodexUsageSidebar.Windows.sln --configuration Release --no-restore --nologo
dotnet test .\plugins\codex-usage-sidebar\windows\CodexUsageSidebar.Windows.sln --configuration Release --no-build --nologo
```

发布后的兼容性诊断请按 [Windows 实机诊断交接手册](WINDOWS-DEVICE-HANDOFF.zh-CN.md) 执行。源码修改
先提交到功能分支；发布与兼容性检查通过后，再合并到 `main`。
