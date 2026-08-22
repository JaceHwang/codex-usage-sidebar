# Windows v0.3.2 实机验证交接手册

本手册用于在真实 Windows 11 AMD64/x64 电脑上验证已发布的 v0.3.2 Windows 安装包。它是验证流程，不授权绕过 Windows 安全对话框或发布新资产。

## 1. 安全准备

使用已登录 Codex 的普通 Windows 桌面用户，不要用管理员身份。新建一个不含隐私内容的 Codex 临时任务。除非维护者明确要求受控采集，否则不得保存账号信息、其他窗口、真实任务标题、通知或带 `--include-text` 的 UIA 输出。

## 2. 下载并校验精确 Release 资产

从 [v0.3.2 Release](https://github.com/JaceHwang/codex-usage-sidebar/releases/tag/v0.3.2) 下载 `codex-usage-sidebar-v0.3.2-windows-x64-setup.exe`、`WINDOWS-V032-SHA256SUMS.txt` 和 `WINDOWS-V032-PROVENANCE.json`。在 PowerShell 中执行：

```powershell
$ErrorActionPreference = 'Stop'
$asset = 'codex-usage-sidebar-v0.3.2-windows-x64-setup.exe'
$actual = (Get-FileHash -LiteralPath ".\\$asset" -Algorithm SHA256).Hash.ToLowerInvariant()
$line = Get-Content .\WINDOWS-V032-SHA256SUMS.txt | Where-Object { $_ -match [regex]::Escape($asset) } | Select-Object -First 1
if ([string]::IsNullOrWhiteSpace($line)) { throw '校验文件中缺少安装包条目。' }
$expected = ($line -split '\s+', 2)[0].ToLowerInvariant()
if ($actual -ne $expected) { throw "SHA-256 不匹配：$actual" }
$provenance = Get-Content -Raw .\WINDOWS-V032-PROVENANCE.json | ConvertFrom-Json
if ($provenance.version -ne '0.3.2' -or $provenance.architecture -ne 'x64') { throw 'v0.3.2 provenance 不符合预期。' }
```

仅在摘要一致后，用户才可以针对预期的未签名发布者提示选择 **更多信息** 和 **仍要运行**。不得关闭或绕过 Defender、SmartScreen、杀毒软件或系统策略。

## 3. 验证运行与安装状态

安装后确认 `%LOCALAPPDATA%\CodexUsageSidebar\Current` 和当前用户 Run 键中的 `CodexUsageSidebar` 值存在。只有得到用户明确授权时才测试 `--repair` 与 `--uninstall`。确认安装、修复和卸载都不会修改官方 Codex 安装包。

## 4. 采集可见实机矩阵

每个状态都从临时任务采集脱敏 status/probe 与裁剪后的标题栏截图：

| 类别 | 必测状态 |
| --- | --- |
| 侧栏/窗口 | 左右下侧栏收起与展开；窄窗、还原、最大化、全屏 |
| 视觉 | 浅色、深色、跟随系统；硬件支持时 100%、125%、150%、200% DPI |
| 语言 | 简体中文、繁体中文、英文、任一不受支持语言 |
| 交互 | 悬浮、单击固定、再次单击收回、不抢焦点、空间不足时回退 |
| 生命周期 | Codex 重启/升级、睡眠恢复、app-server 恢复、修复、卸载 |

未知或不完整的 UIA 结构必须让浮层保持隐藏，不能认可坐标猜测。最终仅通过约定的私密渠道发送脱敏证据包及 SHA-256。
