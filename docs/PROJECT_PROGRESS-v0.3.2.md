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

本次分支不修改既有 macOS/Windows 业务逻辑，不重写历史 v0.3.1 发布记录，也不提交本机生成的签名
载荷或临时构建输出。
