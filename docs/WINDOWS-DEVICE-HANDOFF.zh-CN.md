# Windows 实机诊断交接手册

本手册用于 `v0.3.0-beta.1` 后续 Windows 实机验证阶段。当前产物只是诊断候选物，不是安装器。
请使用已登录 Codex 的普通桌面用户运行，不要使用管理员身份，也不要公开任何报告或截图。

## 1. 准备无敏感信息的 Codex 任务

1. 使用已安装并登录当前 Codex 桌面客户端的 Windows 11 x64 电脑。
2. 关闭包含隐私内容的会话。
3. 新建一个只包含无敏感占位文字的临时任务。
4. 每次采集时保持 Codex 窗口可见。

默认探针不会保存 UI Automation 原始名称或程序路径。每份报告都会生成独立的随机 HMAC
密钥，只写入报告内可关联的令牌和文字长度，随后丢弃密钥。除非维护者先检查默认报告并明确
要求补充，否则不要使用 `--include-text`。

## 2. 验证诊断候选物

从成功的 **Windows beta diagnostic candidate** GitHub Actions 运行中下载名为
`codex-usage-sidebar-v0.3.0-beta.1-windows-x64-diagnostic` 的产物。将 ZIP、校验文件和
provenance 文件放在同一目录，然后在该目录打开 PowerShell：

```powershell
$ErrorActionPreference = 'Stop'
$line = Get-Content -LiteralPath .\WINDOWS-BETA-SHA256SUMS.txt
$expected, $archiveName = $line -split '  ', 2
$actual = (Get-FileHash -LiteralPath ".\$archiveName" -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actual -ne $expected) { throw '诊断 ZIP 的 SHA-256 不匹配。' }

$provenance = Get-Content -Raw -LiteralPath .\WINDOWS-BETA-PROVENANCE.json | ConvertFrom-Json
if ($provenance.version -ne '0.3.0-beta.1' -or
    $provenance.architecture -ne 'x64' -or
    $provenance.status -ne 'diagnostic-candidate' -or
    $provenance.realDeviceValidated -ne $false -or
    $provenance.publishableInstaller -ne $false) {
    throw '诊断 provenance 不符合预期。'
}

Expand-Archive -LiteralPath ".\$archiveName" -DestinationPath .\diagnostic -Force
```

任一验证失败都应立即停止。不能把诊断候选物当成安装程序或可用的 Windows 正式版本。

## 3. 采集窗口布局

先创建输出目录，再按下表逐项切换 Codex 状态并运行默认探针。必须使用规定文件名，确保报告
和截图能够一一对应：

```powershell
New-Item -ItemType Directory -Force C:\Temp\codex-usage-sidebar-probes | Out-Null
Set-Location .\diagnostic
.\CodexUsageSidebar.Control.exe probe C:\Temp\codex-usage-sidebar-probes\01-restored-collapsed.json
```

| 文件名前缀 | 需要采集的 Codex 状态 |
| --- | --- |
| `01-restored-collapsed` | 还原窗口，左、右、下侧栏全部收起 |
| `02-left-expanded` | 展开左侧栏 |
| `03-right-expanded` | 右侧栏保持默认宽度展开 |
| `04-right-wide` | 将右侧栏向左拖到较宽位置 |
| `05-left-right-expanded` | 左右侧栏同时展开 |
| `06-bottom-expanded` | 展开底部面板 |
| `07-narrow-window` | 缩到实际可用的最窄还原窗口 |
| `08-maximized` | 最大化窗口 |
| `09-fullscreen` | 全屏窗口 |
| `10-second-monitor` | 如有第二块显示器，将窗口移过去 |

每个状态还要保存一张使用相同前缀命名的 PNG 截图。截图中只能显示临时任务，不得包含系统
通知、账号名称、其他窗口或真实任务标题。

## 4. 采集主题、语言和缩放组合

对 `01-restored-collapsed`、`04-right-wide` 和 `05-left-right-expanded` 重复以下组合：

- 浅色、深色和跟随系统主题；
- 简体中文、繁体中文和英文；
- 硬件支持时覆盖 100%、125%、150% 和 200% 显示缩放。

文件名使用 `<基础场景>-<主题>-<语言>-<缩放>.json`，例如：

```text
04-right-wide-dark-zh-CN-150.json
```

若切换设置后界面没有立即更新，请重启 Codex 再采集。

## 5. 在本机打包交接资料

最后检查一次截图是否含隐私内容，然后在本机压缩并计算 SHA-256：

```powershell
$root = 'C:\Temp\codex-usage-sidebar-probes'
$bundle = 'C:\Temp\codex-usage-sidebar-probes.zip'
Compress-Archive -Path "$root\*" -DestinationPath $bundle -Force
Get-FileHash -LiteralPath $bundle -Algorithm SHA256 | Format-List
```

仅通过与维护者约定的私密渠道发送 ZIP 和 SHA-256。维护者确认文件可打开且摘要一致前，请保留
原始报告。

## 6. 后续开发边界

这些报告将用于绑定语义化 UIA 选择器和几何测试夹具。首次真正显示浮层的 Windows 构建还必须
在同一源码与 provenance 链上完成定位、悬浮/固定、焦点、DPI、语言、主题、睡眠恢复、Codex
重启/升级、安装、修复和卸载测试。在证据齐备前，未知 Codex UIA 树必须隐藏浮层，也不能发布
Windows setup 资产。
