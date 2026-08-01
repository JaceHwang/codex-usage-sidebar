<p align="center">
  <img src="docs/images/hero.svg" alt="Codex Usage Sidebar 展开与收起状态" width="900">
</p>

<h1 align="center">Codex Usage Sidebar</h1>

<p align="center">在 Codex 桌面端实时显示剩余额度、重置时间、Credits 与 Bank 明细。</p>

<p align="center">
  <a href="README.md">English</a> ·
  <a href="docs/INSTALL.md">人工安装</a> ·
  <a href="docs/INSTALL_FOR_AGENTS.md">交给 Agent 安装</a> ·
  <a href="docs/TROUBLESHOOTING.md">故障排查</a>
</p>

> [!NOTE]
> 这是独立社区项目，与 OpenAI 无隶属或官方背书关系。

## 功能效果

Codex Usage Sidebar 会在 Codex 官方应用包之外安装一个轻量原生伴随程序。它从 Codex
本地 `app-server` 数据流读取额度，跟随白天/黑夜主题，并按当前页面自动调整位置。

| 状态 | 表现 |
| --- | --- |
| 左侧栏展开 | 独立额度按钮与用户、帮助按钮并列，不互相覆盖。 |
| 左侧栏收起 | `剩余百分比 · 重置时间` 自动移动到标题栏右侧原生图标组前。 |
| 鼠标悬浮 | 展示套餐、额度周期、Credits、全部 Bank 次数、状态与过期时间。 |
| 设置页或其他非主页 | 完整识别页面后自动隐藏，不留下孤立按钮。 |

<p align="center">
  <img src="docs/images/placement.svg" alt="展开、收起和设置页三种状态" width="900">
</p>

## 两条命令安装

要求：macOS 14+、Apple Silicon、Codex 桌面版与 `codex` CLI。

```bash
codex plugin marketplace add Byctor/codex-usage-sidebar
codex plugin add codex-usage-sidebar@codex-usage-sidebar
```

安装后请新建一个 **Codex 任务**，`SessionStart` hook 会自动安装并启动伴随程序。

完整的预期输出、权限、升级与卸载步骤请看 [人工安装教程](docs/INSTALL.md)。希望由 Codex
或其他编程 Agent 全程操作时，请使用 [Agent 安装教程](docs/INSTALL_FOR_AGENTS.md)。

## macOS 权限

没有“辅助功能”权限时，插件仍可依靠同步状态显示；要精确识别主页/设置页和语义位置，需开启：

`系统设置 → 隐私与安全性 → 辅助功能 → Codex Usage Sidebar`

这是 macOS 系统安全权限，项目不会绕过授权，也不会修改、注入或重签
`/Applications/ChatGPT.app`。

Codex 官方应用升级通常不会影响此授权。当前公开版采用临时签名，因此未来若插件更新替换了
伴随程序，可能需要重新开启“辅助功能”权限；在完成 Developer ID 签名和公证前，本项目不把
该授权描述为永久一次性。

## 为什么 Codex 升级后仍能用

- 伴随程序安装在 `~/Library/Application Support/CodexUsageSidebar/`。
- 用户级 LaunchAgent 负责常驻和自动重启。
- 每次会话都会重新发现正在运行的 Codex 与当前 `codex app-server`。
- 插件更新使用原子替换；Codex 官方升级不会覆盖插件目录。
- 如需修复，只需一个命令：

```bash
"$HOME/Library/Application Support/CodexUsageSidebar/sidebar-control.sh" repair
```

## 隐私与安全

- 仅从本机 Codex `app-server` 读取额度快照。
- 不抓网页、不读取账号令牌、不上传遥测或额度数据。
- 辅助功能权限只用于 Codex 窗口语义与定位。
- 运行数据只保存在本机。

详见 [隐私说明](docs/PRIVACY.md)、[架构说明](docs/ARCHITECTURE.md) 和
[安全策略](SECURITY.md)。

## 开发验证

```bash
cd plugins/codex-usage-sidebar
bash scripts/build-companion.sh
bash tests/test-sidebar-control.sh
bash tests/live-app-server-probe.sh   # 需要 Codex 桌面版正在运行
```

构建脚本会运行完整 Swift 测试、生成 arm64 Release、进行临时签名并严格校验签名。提交 PR
前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 许可证

[MIT](LICENSE) © 2026 Jace (Byctor)
