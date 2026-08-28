# Project Development Governance / 项目开发治理规范

> 本文是 **codex-usage-sidebar** 的项目级执行规范。每一次功能开发、Bug 修复、文档更新、
> GitHub 推送和正式发版都必须先遵循本文；用户在当前任务中给出的更具体指令优先。

## Scope and precedence / 适用范围与优先级

1. 用户当前指令、平台安全要求和仓库中的 `AGENTS.md` 优先于本文。
2. 本文定义开发交付的统一流程；[VERSIONING.md](../VERSIONING.md) 是版本与分支的专项细则，
   [RELEASES.md](RELEASES.md) 是发布操作细则，
   [`platform-release-catalog.json`](../releases/platform-release-catalog.json) 是平台版本和资产名称的唯一数据源。
3. 不为临时便利绕过版本、测试、签名、校验和、PROVENANCE 或历史发布保护。

## Required workflow / 必须遵循的开发流程

1. **确定范围**：明确是功能、修复、文档、调研还是发布；确认影响 macOS、Windows 或两者。
2. **隔离开发**：从最新 `main` 创建短生命周期 `codex/feat-*`、`codex/fix-*`、
   `codex/docs-*` 或 `codex/spike-*` 分支；保护用户已有的未提交改动。
3. **先验证再修改**：对 Bug 先复现并定位根因；对功能或修复先增加会失败的针对性测试，
   再实现最小改动。
4. **同步文档**：用户可见行为、兼容性、安装方式、截图或已知限制变化时，同步更新 README、
   `CHANGELOG.md` 和相关专题文档。
5. **运行质量门槛**：完成平台对应单元测试、静态/清单校验、安装器校验和真实运行验证；
   不以“本地看起来正常”替代验证证据。
6. **提交与整合**：提交应小而可追溯；合并前保持 `main` 可构建、可测试。功能、修复和临时发布分支
   在合并或发布后删除，标签与 Release 保留为历史证据。

## Version management / 版本管理

采用 `MAJOR.MINOR.PATCH`：

| 变更 | 版本动作 |
| --- | --- |
| 新增用户可感知能力、明显重做数据或交互 | 升 `MINOR`，如 `0.4.0` |
| Bug、布局、性能、语言、兼容性、安装可靠性修复 | 升 `PATCH`，如 `0.3.6` |
| 仅文档、截图、发布说明 | 不升产品版本 |
| 重新签名/重新打包且逻辑不变 | 不升版本；发布重建说明 |
| 破坏安装、配置、数据或功能兼容性 | `0.y.z` 升 `MINOR`；`1.0.0` 后升 `MAJOR` |

- 预发布仅用 `-beta.N` 或 `-rc.N`；已发布版本、校验和和 PROVENANCE 不可改写。
- 版本徽章、应用包元数据、插件清单、安装包名、PROVENANCE 与 Git 标签必须相同。
  `+codex.*` 仅为缓存构建元数据，不能代替产品版本。
- 版本分类或分支命名有疑义时，先按 [VERSIONING.md](../VERSIONING.md) 判定并记录在 CHANGELOG。

## Platform delivery / 跨平台交付

- macOS 与 Windows 允许独立维护补丁：使用 `macos-vX.Y.Z` 和 `windows-vX.Y.Z`。
- 只有共享功能在两端实现、验证和体验对齐后，才发布统一 `vX.Y.Z`，并在同一个 GitHub Release 提供两端资产。
- README 的平台矩阵只展示每个平台最新**已发布**版本；候选版本必须标注为未发布，不能冒充最新下载项。
- 每个 Release 必须说明：目标平台、版本、系统/Codex 支持范围、另一平台的功能差异、升级方式与已知限制。

## Before pushing to GitHub / 推送 GitHub 前

- 检查工作树，仅包含本次范围内的改动；不覆盖或回退无关用户改动。
- 更新 `CHANGELOG.md` 的 `Unreleased` 分类（Added、Changed、Fixed、Removed、Security）。
- 核对平台版本目录、插件清单、应用元数据与文档是否一致。
- 运行受影响平台的测试，以及发布契约校验：

  ```bash
  python3 scripts/validate-platform-release.py \
    --catalog releases/platform-release-catalog.json --target <macos|windows>
  ```

- 在提交前执行 `git diff --check`；提交信息准确描述行为变化。推送前再次确认目标分支与提交范围。

## Before publishing a release / 正式发版前

1. 从通过全部质量门槛的精确提交构建，并让该提交接收最终标签。
2. 从 CI 构建目标平台安装包，不上传未验证的临时本地产物。
3. 生成并校验安装包、`SHA256SUMS.txt` 与 PROVENANCE；三者必须来自同一源提交。
4. 创建 GitHub Release，标题和资产名称采用发布目录定义的规则；上传安装器、校验和与 PROVENANCE。
5. 在干净环境验证首次安装、覆盖升级、首次打开、弹窗定位、数据刷新和卸载/重装。
6. 发布后若发现缺陷，发新的 PATCH 版本。**Do not rewrite published releases**，也不替换已发布资产。

## Hotfixes and rollback / 热修复与回滚

- 从受影响标签创建 `codex/hotfix-<platform>-vX.Y.Z`，修复、测试后合回 `main`，再发布新的 PATCH。
- 如需停止传播有问题版本，可在 Release 说明中标记弃用并指向替代版本；不得改写历史标签或资产。
- 安装或数据迁移的兼容性风险必须先给出回滚路径、用户提示和验证计划。

## Operational checklist / 执行清单

| 场景 | 最低要求 |
| --- | --- |
| 普通开发 | 分支、针对性测试、受影响文档、完整相关测试、清晰提交 |
| Bug 修复 | 根因复现、回归测试、最小修复、跨主题/语言/布局验证（如适用） |
| 仅文档 | 不升版本；检查链接、截图、安装说明和 README 平台矩阵 |
| 平台补丁 | PATCH、平台前缀标签、同源资产/校验和/PROVENANCE、干净环境验证 |
| 共享功能 | MINOR、双平台体验与验证对齐、统一标签和双平台资产 |
| 紧急修复 | 从标签开热修复分支、回合 `main`、新 PATCH，不回改旧 Release |

## Related documents / 关联文档

- [版本与分支专项规范](../VERSIONING.md)
- [发布操作说明](RELEASES.md)
- [平台发布目录](../releases/platform-release-catalog.json)
- [变更日志](../CHANGELOG.md)
