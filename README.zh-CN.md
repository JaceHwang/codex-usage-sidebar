<p align="center">
  <img src="docs/images/hero.svg" alt="自适应放置在 Codex 标题栏中的剩余额度" width="900">
</p>

<h1 align="center">Codex Usage Sidebar</h1>

<p align="center">在 Codex 标题栏实时显示剩余额度、重置时间、Credits 与 Bank 明细。</p>

<p align="center">
  <a href="README.md">English</a> ·
  <a href="docs/INSTALL.md">安装运维</a> ·
  <a href="docs/INSTALL_FOR_AGENTS.md">交给 Agent 安装</a> ·
  <a href="docs/TROUBLESHOOTING.md">故障排查</a>
</p>

> [!NOTE]
> 这是独立社区项目，与 OpenAI 无隶属关系，也不代表 OpenAI 官方背书。

## 平台状态

| 平台 | 状态 | 分发方式 |
| --- | --- | --- |
| macOS 14+ Apple Silicon | 正式版 v0.2.3 | 已签名伴随程序与 v0.2.3 DMG |
| Windows 11 AMD64（`x64`） | `v0.3.1` 功能对齐 | 未签名 `x64` 安装程序待实机门禁；Windows ARM64 不在本版本范围内 |

Windows `v0.3.1` 是面向 Windows 11 AMD64/x64 的 macOS 可见功能对齐版本，包含 Token 使用量、账号身份、主题图标、重置倒计时、Credits、Bank 明细和 GitHub 底部入口，但不显示 Tibo X 行。共享额度契约、.NET 核心、Win32 窗口边界、默认脱敏的 UI Automation 探针、用户级安装器后端、载荷摘要校验与 Windows CI 均不会改变稳定的 macOS 载荷。130 个 Windows 人工用例矩阵尚未完成；源码已通过自动化门禁，最终安装包仍需 Windows 实机门禁。现在选择器不再因为 Codex 文件版本变化而直接拒绝；只要标题栏仍提供安全的语义 UI Automation 结构即可工作，结构未知或不安全时仍会隐藏浮层，不会猜测坐标。开发和验证细节见 [Windows Beta 开发说明](docs/WINDOWS-BETA.md)。
后续测试电脑的完整操作步骤见 [Windows 实机诊断交接手册](docs/WINDOWS-DEVICE-HANDOFF.zh-CN.md)。
准备在 Windows Codex 中继续开发时，请从
[Windows Codex 开发接力手册](docs/WINDOWS-CODEX-CONTINUATION.zh-CN.md)开始；Git 分支和经过
验证的提交历史是跨电脑接力的唯一源码依据。
完整功能矩阵见 [Windows v0.3.1 功能对齐说明](docs/WINDOWS-V031-PARITY.md)。

## 当前 v0.3.1 实际效果

<p align="center">
  <img src="docs/images/quota-popover-v0.3.1-zh-light.png" alt="Codex Usage Sidebar v0.3.1 浅色主题额度浮窗，包含 Token 使用量、主题图标和 GitHub 底部链接" width="48%">
  <img src="docs/images/quota-popover-v0.3.1-zh-dark.png" alt="Codex Usage Sidebar v0.3.1 深色主题额度浮窗，包含 Token 使用量、主题图标和 GitHub 底部链接" width="48%">
</p>

<p align="center"><em>当前浅色主题 · 当前深色主题</em></p>

这些 v0.3.1 截图由当前原生 AppKit 浮窗和安装包内的主题图标生成，展示了 Codex 账号身份、七日
Token 使用量图表、醒目的重置倒计时、主题自适应额度图标、无边框紧凑 GitHub 链接，以及
浅色/深色主题下的分隔线和阴影材质。

## 自适应标题栏定位

<p align="center">
  <img src="docs/images/adaptive-titlebar-nearby-dark.png" alt="额度按钮移动到打开位置左侧最近的无碰撞空位" width="96%">
</p>

<p align="center"><em>空间足够：使用最近的无碰撞空位，并与原生控件保持 8pt 间隔。</em></p>

<p align="center">
  <img src="docs/images/adaptive-titlebar-fallback-dark.png" alt="额度按钮移动到右侧标题栏安全回退位置" width="96%">
</p>

<p align="center"><em>空间不足：立即切换到标题栏右侧预留位置；中间页签继续缩窄时仍保持显示。</em></p>

## 功能效果

Codex Usage Sidebar 会在 Codex 官方应用包之外安装一个轻量原生伴随程序。它从本机
`app-server` 读取额度更新，跟随白天/黑夜主题，并把额度按钮放进最近的安全标题栏空位。

| 场景 | 表现 |
| --- | --- |
| 打开或关闭左、右、下侧栏 | 优先跟随原生“打开位置”，遇到占用控件时向左寻找最近空位；本地空间不足才切换到右侧预留位置。 |
| 移动或缩放窗口 | 每 `0.1 秒`重新核对可用标题栏空间，避免覆盖原生按钮和页签标题；没有可靠中间锚点时固定回退到右侧停靠位。 |
| 鼠标悬浮 | 展示同步的插件版本、账号身份、主题图标、套餐、额度周期、每日与总 Token 使用量、Credits、全部 Bank 次数、状态与过期时间。 |
| 鼠标点击 | 浮窗保持常驻，再次点击收回；原有悬浮查看方式继续保留。 |
| 底部 GitHub 按钮 | 打开 [github.com/JaceHwang/codex-usage-sidebar](https://github.com/JaceHwang/codex-usage-sidebar)。默认态融入底部背景，悬浮时仅显示柔和圆角阴影。 |
| 剩余额度变化 | 百分比严格按 100% 绿、49% 橙、10% 红连续过渡，已填充进度显示对应光谱。 |
| Codex 语言变化 | 按 Codex 最终显示语言在 1 秒内切换简体中文、繁体中文或英文。 |

旧版左侧栏底部副本以及所有侧栏状态同步代码均已删除，现在只有顶部这一个额度按钮。

<p align="center">
  <img src="docs/images/placement.svg" alt="侧栏与窗口变化时自动避让原生控件" width="900">
</p>

## 快速安装

请按平台选择安装路径。Windows 仅支持 Windows 11 AMD64/x64，不支持 Windows ARM64。Windows
`v0.3.1` 安装程序在 Windows 实机门禁完成后发布，并保留明确的未签名安装防护说明。

### Windows 11 AMD64/x64

要求：Windows 11 AMD64/x64、已安装并登录的 Codex Windows 桌面客户端，以及 PowerShell。没有固定的
Codex 文件最低版本；新版本只要提供已验证的安全标题栏语义结构即可使用。结构未知或不安全时，
插件会保持隐藏，直到完成验证。

#### 人工安装

1. Windows 门禁完成并发布后，打开 [v0.3.1 GitHub Release](https://github.com/JaceHwang/codex-usage-sidebar/releases/tag/v0.3.1)，只下载
   `codex-usage-sidebar-v0.3.1-windows-x64-setup.exe` 与 `WINDOWS-V031-SHA256SUMS.txt`。
2. 启动安装程序前，先校验 SHA-256：

   ```powershell
   Get-FileHash .\codex-usage-sidebar-v0.3.1-windows-x64-setup.exe -Algorithm SHA256 | Select-Object -ExpandProperty Hash
   ```

   将结果与 `WINDOWS-V031-SHA256SUMS.txt` 中对应条目比较；大小写不影响判断。
3. 摘要匹配后，为当前用户启动安装：

   ```powershell
   Start-Process .\codex-usage-sidebar-v0.3.1-windows-x64-setup.exe
   ```

4. 该安装程序有意保持未签名（`NotSigned`），Windows 可能显示“未知发布者”。只有在 SHA-256
   匹配后，才选择“更多信息”，再选择“仍要运行”。
5. 绝不要关闭 Defender、SmartScreen、杀毒软件或系统策略。摘要不匹配时请删除文件，并从发行页重新下载。
   伴随程序会安装到 `%LOCALAPPDATA%\CodexUsageSidebar\Current`，并通过当前用户的 Run 项自动启动。

如果 Codex 暴露的是不受支持的 UI Automation 结构，Windows 浮层会保持隐藏，而不是猜测坐标。
`--repair`、`--uninstall`、状态输出和验证边界见[安装运维说明](docs/INSTALL.md)。

#### Agent 自动安装

可以把下面这段任务交给 Windows 电脑上的 Agent：

```text
从 GitHub Release 安装 Codex Usage Sidebar v0.3.1。当前电脑必须是 Windows 11 AMD64/x64。
只下载 codex-usage-sidebar-v0.3.1-windows-x64-setup.exe 和 WINDOWS-V031-SHA256SUMS.txt，先验证
安装程序 SHA-256 与发行页对应条目一致，只有摘要匹配时才运行安装程序，并回报安装路径和运行状态。不要关闭或绕过
Defender、SmartScreen、杀毒软件或系统策略。如果出现安装器、SmartScreen、卸载或 Windows 安全对话框，
先停下来让我即时确认，再点击任何按钮。
```

Agent 可以自动完成下载、摘要比对和启动安装器；但不能绕过 Windows 信任界面，也不能在没有实际完成本机
验证时声称 setup 安装/卸载生命周期已经通过。确定性流程见[Agent 安装流程](docs/INSTALL_FOR_AGENTS.md)。

### macOS 14+ Apple Silicon

要求：macOS 14+、Apple Silicon、Codex 桌面版与支持插件的 `codex` CLI。安装器不绑定某个 Codex
版本，会同时搜索标准安装路径和当前 `PATH`；只要 CLI 提供安装器使用的 `plugin marketplace` 与
`plugin add` 命令即可兼容。

#### 下载图形安装器

1. 从 v0.2.3 Release 的 **Assets** 下载 [`codex-usage-sidebar-v0.2.3-macos-arm64.dmg`](https://github.com/JaceHwang/codex-usage-sidebar/releases/download/v0.2.3/codex-usage-sidebar-v0.2.3-macos-arm64.dmg)。
2. 打开 DMG，再打开 **Codex Usage Sidebar Installer**。
3. 这是未经公证的原始下载；如果 macOS 阻止打开，请在 Finder 中右键点击安装器并选择“打开”。
4. 点击 **安装**，按引导完成 Codex 登录，并在 macOS 提示时为 **Codex Usage Sidebar** 开启“辅助功能”。
5. 点击安装器中的 **验证**，确认受管理的伴随程序正在运行。

安装器会把文件放在 Codex 应用包之外，也绝不会复制普通 `~/.codex` 凭据。修复、更新和卸载行为请见
[安装运维说明](docs/INSTALL.md)。

### 高级：手动 Marketplace 安装

```bash
codex plugin marketplace add JaceHwang/codex-usage-sidebar
codex plugin add codex-usage-sidebar@codex-usage-sidebar
```

安装后请新建一个 **Codex 任务**。Codex 会在任务开始时加载插件，`SessionStart` hook 随后
自动安装并启动伴随程序；这与[官方 Codex 插件流程](https://developers.openai.com/learn/developers-codex-plugin/)
描述的任务边界一致。

插件使用独立 CodexHome，不会复制普通 `~/.codex` 中的凭据。首次安装需单独授权一次：

```bash
env CODEX_HOME="$HOME/Library/Application Support/CodexUsageSidebar/CodexHome" codex login
```

之后按 macOS 提示，为 **Codex Usage Sidebar** 开启“辅助功能”。完整状态检查、更新、修复与
卸载步骤见[安装运维说明](docs/INSTALL.md)。

## 防碰撞定位原理

伴随程序扫描会影响标题栏定位的辅助功能分支，只读取合格按钮和静态标题的标签与几何信息；
相关区域内的结构组只读取几何信息，用于识别面板边界。之后按以下规则定位：

```text
1. 优先：额度按钮.maxX = 打开位置按钮.minX - 8pt
2. 若候选框碰到其他标题栏元素，向左移动到最近的完整空位
3. 若标题前已无完整空位，立即使用右侧预留回退位置
```

标题栏元素扫描横向覆盖 164pt 额度按钮的完整可能范围，并排除 46pt 标题栏以外的元素。结构组
只作为面板边界几何使用，不读取其标签或文字，因此不会读取聊天正文。
全屏时被裁切到窗口顶端、仅剩 1px 高的退化正文元素会被忽略，不会误判成可见标题。程序会在
读取标签前先做几何过滤，每个 0.1 秒定位周期都会重新扫描合格标题栏几何，即使语义锚点本身
没有移动。主动回退会立即替换已过期的保留锚点；短暂扫描不完整时最多保留最后一次有效位置
0.75 秒。整个过程不会修改 Codex 内部代码。

## 实时额度明细

- 紧凑按钮始终展示剩余百分比和下次重置时间。
- `Codex 剩余额度` 后方的小型蓝色描边徽标直接读取 App Bundle 版本，方便不打开终端就
  判断当前实际运行代码。
- 悬浮卡片展示套餐、额度周期、Credits、Bank 可用次数、每一条 Bank 额度、状态和过期时间。
- 按钮百分比和悬浮百分比共用连续状态色：`100%` 绿色、`49%` 橙色、`10%` 红色。
- 已填充进度条从固定的红→橙→绿光谱中按实时额度裁切，未填充部分保持主题自适应灰色。
- 本地通知到达后立即更新，并带有有界刷新、重置检查与数据流恢复机制。

## 语言自动匹配

v0.3.1 直接跟随 Codex **最终实际显示的语言**。Codex 明确选择的语言优先；设为“自动”时，
插件跟随运行中的 Codex 渲染进程语言。Codex 偏好设置与 macOS 首选语言仅作为启动阶段的安全回退。

| Codex 最终语言 | 插件显示 |
| --- | --- |
| 简体中文（`zh-Hans`、`zh-CN`、`zh-SG`） | 简体中文 |
| 繁体中文（`zh-Hant`、`zh-TW`、`zh-HK`、`zh-MO`） | 繁體中文 |
| 英文（`en-*`） | English |
| 其他语言 | English |

插件不再提供一套独立语言设置，避免与 Codex 不一致。伴随程序每秒检查一次有效语言；已显示或
点击固定的浮窗也会原地更新，无需重新安装插件。

## 为什么 Codex 升级后仍能用

- 伴随程序位于 `~/Library/Application Support/CodexUsageSidebar/`，不在官方应用包中。
- 用户级 LaunchAgent 负责常驻与自动重启。
- 每次运行都会重新发现当前 `com.openai.codex` 和对应的 `codex app-server`。
- 插件更新先校验载荷指纹再原子替换，Codex 官方升级不会覆盖它。
- 安装器会优先使用稳定的本地签名身份重新签署复制后的载荷，使插件重装前后的“辅助功能”
  代码身份保持稳定。
- 修复仍然只需一个命令：

```bash
"$HOME/Library/Application Support/CodexUsageSidebar/sidebar-control.sh" repair
```

“辅助功能”的最终授权始终由 macOS 决定；系统安全策略或签名发生变化时仍可能要求再次确认。

## 隐私与安全

- 只通过 stdio 从本机 Codex `app-server` 读取额度快照。
- 使用隔离的 `CodexHome`，凭据仅由官方 `codex login` 流程创建。
- 不抓网页、不注入 Codex、不读取聊天正文、不上传遥测。
- 只在内存中读取 Codex 渲染进程的语言参数用于匹配；原始进程参数不会写入诊断或日志。
- 只读取合格标题栏控件和静态标题的标签与几何信息；相关区域内的结构组只读取几何信息，
  用于识别面板边界。
- 运行文件只保存在用户的 Application Support 目录。

详见[隐私说明](docs/PRIVACY.md)、[架构说明](docs/ARCHITECTURE.md)和[安全策略](SECURITY.md)。

## 状态诊断

```bash
"$HOME/Library/Application Support/CodexUsageSidebar/sidebar-control.sh" status
```

精确定位正常时会返回常驻 LaunchAgent 进程的真实状态：

```text
pid=12345 version=0.3.1 runtime=shown placement=content-header anchor=labeledControl
language=simplifiedChinese language_source=process
indicator=654,1003,164,46 ... cached:false,source:labeledControl,edge:826
installed and loaded: .../Codex Usage Sidebar.app
```

当锚点为 `openLocation`、`labeledControl` 或 `rightPaneBoundary` 时，额度按钮右边缘应等于
`edge - 8`。带有效边缘的 `fallback` 表示主动切换到右侧安全位置，并非故障；状态版本号还应
与悬浮卡片徽标一致。

## 构建来源证明

Marketplace 分发的伴随程序来自 GitHub Actions 的精确产物。
[`assets/PROVENANCE.json`](plugins/codex-usage-sidebar/assets/PROVENANCE.json) 记录源码提交、工作流、
Artifact 摘要、压缩包摘要、可执行文件 SHA-256 与代码目录哈希。CI 会先验证固定产物，再独立
重建并运行测试。

## 开发验证

```bash
cd plugins/codex-usage-sidebar
bash scripts/build-companion.sh
bash tests/test-sidebar-control.sh
bash tests/test-signing-identity.sh
bash tests/live-app-server-probe.sh   # 需要先登录隔离 CodexHome

cd ../..
CUS_ALLOW_SOURCE_AHEAD=1 bash scripts/validate-public-repo.sh
```

完整 Swift 测试、arm64 Release 构建、签名选择与严格签名校验均由构建脚本执行。提交 PR 前请
阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 文档索引

- [安装与运维](docs/INSTALL.md)
- [Agent 安装流程](docs/INSTALL_FOR_AGENTS.md)
- [架构](docs/ARCHITECTURE.md)
- [Windows Beta 开发说明](docs/WINDOWS-BETA.md)
- [Windows 实机诊断交接手册](docs/WINDOWS-DEVICE-HANDOFF.zh-CN.md)
- [故障排查](docs/TROUBLESHOOTING.md)
- [隐私](docs/PRIVACY.md)
- [支持](SUPPORT.md)
- [更新记录](CHANGELOG.md)

## 许可证

[MIT](LICENSE) © 2026 Jace
