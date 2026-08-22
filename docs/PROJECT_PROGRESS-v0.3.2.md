# Codex Usage Sidebar v0.3.2 工作进展看板

> 该文档是 `v0.3.2` 分支的可读交接看板；Git 提交历史仍是源码和变更边界的最终依据。

## 当前状态

| 项目 | 状态 |
| --- | --- |
| 分支 | `v0.3.2` |
| 分支来源 | 当前最新 Windows parity 提交 `ba70631` |
| macOS 功能基线 | v0.3.1 可见功能（原生额度卡、Token、账号、主题图标、GitHub 入口） |
| Windows 功能基线 | v0.3.1 parity 源码与自动化门禁已完成 |
| Tibo X 入口 | macOS 保留；Windows 按既定范围不显示 |
| 发布资产 | 尚未在本分支生成新的 macOS DMG 或 Windows setup |
| 总体状态 | 进行中：等待 Windows 实机与安装资产门禁 |

## 已纳入的功能

- 实时剩余百分比、重置时间、Credits、Bank 可用次数及各条 Bank 到期信息。
- 当前额度周期内的七日 Token 使用量和周期总量；数据不可用时显示安全降级状态。
- 简体中文、繁体中文、英文，以及 Codex 自动语言的最终显示结果匹配。
- 浅色/深色主题自适应额度图标、进度颜色和原生风格浮窗。
- 账号身份从 Codex `account/read` 获取；缺少昵称或头像时使用邮箱/首字母安全回退。
- GitHub 底部链接按钮；点击打开项目仓库，悬浮时显示轻量阴影。
- 标题栏碰撞感知定位：中间标题栏空间不足时切换到右侧安全回退位，避免与原生控件重叠。
- Windows 使用官方 app-server `account/usage/read`、`account/read` 数据源，不读取浏览器 Cookie、OAuth 私密文件或 X 数据。

## 本次分支动作

1. 从最新代码 `ba70631` 创建 `v0.3.2` 分支。
2. 将本看板文档纳入仓库，记录当前功能边界、验证证据和未完成门禁。
3. 保留 v0.3.1 的产品版本元数据和历史发布资产，避免在没有新安装包和实机验证时制造虚假的 v0.3.2 发布声明。
4. 将分支推送到远端，供 Windows 设备继续完成实机验证和安装资产构建。
5. 在 Windows 11 x64 上完成本地源码基线、非发布 device-test 载荷和默认脱敏 UIA 探针检查；未生成 setup 或 GitHub Release。

## 验证证据

最近一次基线验证（来源提交 `ba70631`）：

- Windows Core 测试：`51/51` 通过。
- Windows solution 构建：0 warnings、0 errors。
- Windows HostCoordinator Token/账户集成焦点测试：`1/1` 通过。
- Windows parity workflow shell 检查：通过。
- 插件 manifest validator：通过。
- 公共仓库 validator：通过。
- `git diff --check`：通过。

2026-08-22 本地 Windows 继续执行检查（源提交 `cc6976c`）：

- Windows 11 build `26200` / `x64`；solution restore：通过。
- Windows solution 测试：`51 + 57 + 80 = 188/188` 通过，0 失败。
- Windows Host 构建：0 warnings、0 errors。
- Windows-only source boundary：通过；payload manifest 负向/正向检查在 WSL 中通过。Git for Windows 因当前设备未启用 symlink 创建权限，未能执行该负向分支，未修改测试或生产代码。
- 本地 device-test payload：通过 manifest 和嵌入管理器自检；`status=device-test`、`realDeviceValidated=false`、`publishableInstaller=false`；payload manifest SHA-256 为 `92462f22319c258724807818d6c39c9b4766aae923c81d6441d34b14d2ca9e6b`。
- 当前 Codex 客户端默认脱敏 UIA 探针：通过；报告保存在系统临时目录 `codex-usage-sidebar-v0.3.2-probes\01-current-default.json`，`IncludesText=false`，未采集原始 UIA 文本。
- 以上证据只是单次本地检查，不替代完整的 130 项实机矩阵；Windows 实机与安装资产门禁仍未完成。

2026-08-22 本地安装修复与刷新（源提交 `6efda99`）：

- 修复 device-test 安装流程的版本漂移：安装器要求 `0.3.1`，旧脚本却生成 `0.3.0`，导致原子安装静默返回退出码 `70`。
- 版本对齐回归测试先失败后通过；manifest、payload 计划和 device-test 测试均通过。
- 已删除旧 `%LOCALAPPDATA%\CodexUsageSidebar\Current` 载荷并安装当前分支载荷；当前状态为 `runtime=running version=0.3.1`。
- 当前安装 payload 的 `sourceCommit` 为 `6efda99fff4361bb931c14d4405ae2f414952d7c`，manifest SHA-256 为 `02679fc3477cdc2f9988af22016c84af40f3e48d29c47d3f4bcb1f8bc6d65e47`。

2026-08-22 中间页签窄宽度定位修复（源提交 `67bdf4b`）：

- 根因：当前 Codex build `151.0.7922.170` 的右侧 pane 工具栏位于 pane 深度 `+4`，selector 只接受旧的 `+3`，因此右侧回退位置无法解析。
- 新增回归测试覆盖 `+4` 深度；修复后 Windows solution 测试为 `51 + 58 + 80 = 189/189` 通过。
- 已重新安装当前载荷；默认脱敏探针确认 `TitlebarResolved=true`、右侧工具栏 `x=2378..2856`、右侧障碍数 `1`，不再因 selector 失败而隐藏浮层。

2026-08-22 分享按钮重叠修复（源提交 `0ecc7c7`、安装门禁修复提交 `acc672d`）：

- 根因：selector 将“打开方式”按钮硬编码为中间页标题栏右锚点，无法避让其左侧新增的分享按钮。
- 现在从标题区域右侧、同一按钮层级和对齐带中选择最靠左的合规按钮作为锚点，并将后续 composer 按钮全部纳入障碍列表；新增回归测试覆盖分享按钮位于“打开方式”之前的场景。
- Windows solution 测试：`51 + 59 + 80 = 190/190` 通过，0 失败。
- 安装脚本启动版本校验同步修复为 `0.3.1`，避免已成功启动的当前载荷被旧 `0.3.0` 检查误报失败；相关 device-test 版本回归检查通过。
- 已安装当前载荷：`runtime=running pid=412 version=0.3.1`，`sourceCommit=acc672d`，manifest SHA-256 为 `072174471b4cdaf7f6f14b5fbed7bfbe363212dd5199afa58dfb2a68dd763833`。
- 最新默认脱敏探针：`04-current-anchor-after-fix.json`，Codex build `151.0.7922.170`，`IncludesText=false`，`TitlebarResolved=true`；右侧第一个按钮/新锚点左边界 `x=1393`，原“打开方式”按钮左边界 `x=1461`，障碍列表从 `x=1393` 开始。

2026-08-22 标题栏间距调整（源提交 `68966af`）：

- 将插件按钮与右侧第一个标题栏按钮的间距从 `8` 个逻辑像素调整为 `4` 个逻辑像素；在 200% DPI 下由 `16` 个物理像素缩小为 `8` 个物理像素。
- coordinator 几何回归测试先失败后通过；Windows solution 测试保持 `51 + 59 + 80 = 190/190` 通过。
- 已安装当前载荷：`runtime=running pid=18204 version=0.3.1`，`sourceCommit=68966af`，manifest SHA-256 为 `6a67ddd5f82715c67e18b30f673d926a327587ec082733e648b99ba7d0f6ad02`。
- 最新默认脱敏探针：`05-current-gap-after-fix.json`，`IncludesText=false`、`TitlebarResolved=true`，当前实际右侧锚点为 `x=2552`。

2026-08-22 右侧默认位置未展示的根因修复（源提交 `cd7c894`）：

- 根因：右侧工具栏 selector 仍限制在 pane 深度 `+3/+4`；窄页签布局新增两层 UIA 包装时，selector 返回空，coordinator 无法进入右侧回退位置，因此此前间距调整也不会体现在该分支上。
- 改为使用右侧 pane 内唯一的工具栏结构类名、边界包含关系和右侧障碍按钮进行识别，不再依赖固定 UIA 深度；新增 `+5` 深度回归测试，旧实现先失败、修复后通过。
- Windows solution 测试：`51 + 60 + 80 = 191/191` 通过。
- 已安装当前载荷：`runtime=running pid=17160 version=0.3.1`，`sourceCommit=cd7c894`，manifest SHA-256 为 `b20e62e3735a069aa0e27681b1e27af0b94275e52e4561c67731c1ebed718b9c`。
- 最新默认脱敏探针：`06-structure-fix.json`，`IncludesText=false`、`TitlebarResolved=true`、`RightToolbarBounds=x=2378..2856`；4 个逻辑像素间距仍由 `WindowsHostCoordinator` 生效。

2026-08-22 按钮边缘紧凑化与右侧障碍修复（源提交 `7deaf6e`）：

- 根据实机截图撤回“删除 `%` 与日期之间分隔空格”的错误调整，恢复为 `76% · 8月2日 08:00`；真正的紧凑化改为将 WPF 按钮表面左右内边距从 `8` 缩小为 `4` 个逻辑像素，并将表面右对齐，使文字首尾贴近按钮边缘。
- 右侧工具栏 selector 不再因对齐按钮数量超过一个而整棵结构判定失败；所有对齐的右侧按钮都会进入回退障碍列表，窄页签仍使用右侧默认回退位。
- 新增格式、视觉指标和多右侧按钮回归测试；Windows solution 测试：`52 + 61 + 80 = 193/193` 通过，Release Host 构建 0 warnings、0 errors。
- 已安装当前载荷：`runtime=running pid=4280 version=0.3.1`，`sourceCommit=7deaf6e0240acad30f32d3e6cd151fcaca2457fd`；默认脱敏探针 `08-edge-padding-right-obstacles.json` 通过，Codex build `151.0.7922.170`、`TitlebarResolved=true`、`RightToolbarBounds=x=1865..2856`、`RightObstacles=1`，未采集原始 UIA 文本。

2026-08-22 右侧默认位置最终修复（源提交 `b719628`、`2010779`）：

- 根因一：新版 Codex 的右侧 pane 比旧结构多了一层包装；运行时扫描器按固定父级深度取错容器。现在按 `relative z-[41] ... shrink-0 overflow-visible` 结构标记向上查找真实右侧 pane。
- 根因二：当前 Codex build `151.0.7922.170` 下，Win32 `GetWindowRect` 返回逻辑像素，而 UI Automation 返回物理像素；主窗口边界被缩小一半，导致 selector 将完整右侧结构判定为越界。现在按窗口 DPI 将定位边界转换到 UIA 的物理坐标系。
- Windows solution 测试：`53 + 63 + 80 = 196/196` 通过；Release Host 构建 0 warnings、0 errors。
- 已安装当前载荷：`runtime=running pid=17580 version=0.3.1`，`sourceCommit=20107794ad1e1aeb1819dbb857cf9bbc40518455`，manifest SHA-256 为 `9ff578941939e8214bfc6be678f865b8f140c61655beff70adf8589e4aaf5f90`。
- 运行时扫描确认：`RightToolbarBounds=x=1923..2856`、右侧障碍 `x=2856..2912`；实际浮层窗口已位于 `x=2520..2848`，即右侧默认位置并保留 8 个物理像素间隔。探针：`%TEMP%\codex-usage-sidebar-v0.3.2-probes\13-runtime-right-slot.json`。

2026-08-22 中间页签优先、右侧页溢出回退（源提交 `49a3c74`）：

- 修正定位优先级：先尝试中间页签标题栏；只有中间空间不足、与标题或原生按钮碰撞时，才使用右侧页默认锚点。
- 新增回归测试覆盖“右侧 pane 存在但中间空间足够时仍留在中间页签”的场景；窄页签回退测试继续通过。
- 已重新安装当前载荷：`runtime=running pid=24820 version=0.3.1`，`sourceCommit=49a3c74447feefc6fc33975b03528b62f13b03ac`。
- 实际运行探针确认当前宽度使用中间位置：浮层 `x=1586..1914`；探针：`%TEMP%\codex-usage-sidebar-v0.3.2-probes\14-runtime-middle-first.json`。

2026-08-22 缩小中间页签浮层冗余宽度（源提交 `9f3c37f`）：

- 将 indicator 固定宽度从 `164` 调整为 `132` 个逻辑像素；在当前 200% DPI 下，物理宽度从 `328` 缩小为 `264`，空间判断同步收紧。
- 保持文字右侧 4 个逻辑像素内边距和原有文字内容不变，实际左侧冗余空白由约 `80` 个物理像素降至约 `16` 个物理像素。
- Windows solution 测试：`53 + 63 + 80 = 196/196` 通过。
- 已安装当前载荷：`runtime=running pid=24220 version=0.3.1`，`sourceCommit=9f3c37f24c29ad4629271eef848cabd8d5131262`；探针：`%TEMP%\codex-usage-sidebar-v0.3.2-probes\16-indicator-compact.json`。

2026-08-22 将左侧透明余量压缩至约 1 个物理像素（源提交 `5cbdce7`）：

- 将 indicator 固定宽度从 `132` 调整为 `124.5` 个逻辑像素；在当前 200% DPI 下，物理宽度从 `264` 缩小为 `249`。
- 保留文字两侧各 `4` 个逻辑像素的内部边距；实时探针确认浮层宽度为 `249`、文字区域宽度约 `232`，文字区域加左右各约 `8` 个物理像素内边距后为 `248`，因此左侧透明余量约 `1` 个物理像素。
- Windows solution 测试：`53 + 63 + 80 = 196/196` 通过；Release x64 构建 `0` 警告、`0` 错误。
- 已安装当前载荷：`runtime=running pid=24680 version=0.3.1`，`sourceCommit=5cbdce7359b3c6a442c2a92466d3e1ad397f6ef2`；探针：`%TEMP%\codex-usage-sidebar-v0.3.2-probes\17-indicator-one-left.json`。

## 未完成门禁与下一步

### Windows 实机门禁（未完成）

需要在 Windows 11 AMD64/x64 的真实 Codex 客户端上完成：

- 安装、修复、升级、卸载和当前用户自启动流程。
- UI Automation 结构、DPI 缩放、浅色/深色主题和三语言切换。
- 左右侧栏、窄标题栏、中间编辑内容滚入标题栏时的碰撞定位。
- Codex 生命周期重启、app-server 延迟/拒绝/降级和账号数据缺失场景。
- 生成 Windows x64 setup、计算 SHA-256，并核对安装后载荷摘要。

### 下一步

在 Windows 设备完成上述矩阵后，再决定是否将产品元数据、安装资产和 GitHub Release 提升为正式
`v0.3.2`；在此之前，`v0.3.2` 分支作为最新源码交接分支，产品运行版本仍显示为 `0.3.1`。

## 变更范围

本次新增的文档文件：

- `docs/PROJECT_PROGRESS-v0.3.2.md`
- `docs/superpowers/plans/2026-08-22-v0.3.2-windows-device-gate.md`

本次分支不修改既有 macOS 业务逻辑，不重写历史 v0.3.1 发布记录，也不提交本机生成的签名
载荷或临时构建输出；Windows 仅提交标题栏定位与 device-test 安装门禁修复。
