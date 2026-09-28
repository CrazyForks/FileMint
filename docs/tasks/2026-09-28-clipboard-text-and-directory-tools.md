# Task: 从剪贴板新建与在当前目录打开工具

Status: in-progress
Next action: 等待用户提供 iTerm2/Ghostty、macOS 13 环境并配合确认终端窗口/标签数量；用户本轮明确暂不替换已安装 App，当前源码的 Finder 安装态验收继续待定。

## Objective and scope

对应[路线图](../ROADMAP.md)中的两个条目，交付一个任务、两个可独立验收的功能：

1. **从剪贴板新建…**：主动读取一次纯文本，预填现有创建面板，用户确认后保存。
2. **在当前目录打开工具**：将 Finder 捕获的目录交给用户配置的终端或编辑器。

本记录保存设计、实现及验收状态。产品代码已经接入；完整原生验收未完成，因此尚不能宣称已发布或所有终端都已验证。验收后再更新路线图状态。

首期范围：纯文本；Finder、主应用和菜单栏的文本创建入口；扩展现有“使用 App 打开”支持背景目录；Terminal、iTerm2、Ghostty、Warp 的终端能力白名单；应用设置页重设计与更大的设置窗口；沿用中英文原生界面。

范围外：剪贴板监控/历史、HTML/RTF 转换、从文件引用复制正文、图片入口合并、自动保存或创建后打开、自定义 Shell 命令、远程目录、批量打开多个目录、自动发现/安装应用、发布。

## Selected context

| 行为 | Owning contract / 相关约束 |
| --- | --- |
| 剪贴板快照、草稿、创建和请求凭据 | [Creation](../../specs/domains/creation.md) |
| 文本模板切换和默认格式 | [Templates](../../specs/domains/templates.md) |
| Finder 目标、授权、已捕获目录 | [Finder and permissions](../../specs/domains/finder-permissions.md) |
| 应用配置、打开请求和菜单布局 | [Open with App](../../specs/domains/open-with.md) |
| 偏好兼容、冷启动和窗口所有权 | [Startup](../../specs/domains/startup.md) |
| 设置页、双语和原生外观 | [Presentation](../../specs/domains/presentation.md) |

已核对 [File tools](../../specs/domains/file-tools.md)：其现有选择工具保持独立；目录工具不挂在该模块开关下，也不扩展移动/删除流程。

工作流依据 [AI Playbook](../AI_PLAYBOOK.md)。验证依据 [HARNESS](../../specs/HARNESS.md)、[Core checks](../../specs/verification/core.md) 和 [Finder/native checks](../../specs/verification/finder.md)。已加载 [Distribution](../../specs/domains/distribution.md) 评估终端集成的权限边界；首选原生 Services / URL，暂不规划新增依赖或 Automation 权限。若实际适配必须改变 entitlements，先更新该域并记录理由。

## 当前代码与缺口

| 当前入口 | 可复用能力 | 本任务要补的部分 |
| --- | --- | --- |
| [PreferencesModel](../../App/FileMint/PreferencesModel.swift) 的 `presentClipboardImage` | 主应用读取剪贴板、单面板保护、busy/restart 计数 | 纯文本快照、文本入口与共用的创建准备状态 |
| [CustomFileSavePanelController](../../SharedUI/CustomFileSavePanelController.swift) | 原生文本编辑、目录选择、授权重试、碰撞确认、后台创建 | 显式 `initialText` 输入，初始化时标记为用户内容 |
| [CustomFileDraft](../../CorePackage/Sources/FileMintCore/CustomFileDraft.swift) | `updateContent` 设置 `hasEditedContent`；已编辑内容不随格式切换重置 | 验证预填内容始终走 `.verbatim` 写入 |
| [QuickCreationTicket](../../CorePackage/Sources/FileMintCore/QuickCreationTicket.swift) | 私有文件、60 秒有效期、单次消费、目录范围校验 | 区分模板快建、图片草稿、文本草稿 |
| [FinderSync](../../FinderSyncExtension/FileMintFinderSync/FinderSync.swift) | 菜单快照、主/子菜单布局、主应用转发 | 文本动作和独立的目录目标规则 |
| [OpenWithApplication](../../CorePackage/Sources/FileMintCore/OpenWithApplication.swift) | 应用身份、书签、排序、去重、菜单位置 | 终端打开方式与能力识别；保持一份配置和菜单 |
| [OpenWithApplicationAccess](../../App/FileMint/OpenWithApplicationAccess.swift) | 有界 bundle 验证、书签解析、指定 App 的原生打开 | 小型、按应用身份选择的目录适配器 |
| [FileOperationCoordinator](../../App/FileMint/FileOperationCoordinator.swift) | 请求串行化、授权、重校验、访问生命周期 | 目录请求分支与终端打开方式分派 |
| [OpenWithSettingsView](../../App/FileMint/OpenWithSettingsView.swift) | 原生 App 图标、位置选择、拖动排序、失败回滚 | 简化行操作、按能力呈现终端选项和设置摘要 |
| [SettingsWindowController](../../App/FileMint/SettingsWindowController.swift) / [ContentView](../../App/FileMint/ContentView.swift) | 单独设置窗口、SwiftUI 最小尺寸 | 统一尺寸策略与屏幕可用区域适配 |

现有“使用 App 打开”只接受 item 菜单中的完整选中项，不能通过简单传空 selection 支持背景目录。现有 `FileMenuDestination` 服务新建文件；新工具单独定义目录规则，避免改变已有创建行为。

## A. 从剪贴板新建

### 用户流程

1. Finder 的“新建文件”中增加 **从剪贴板新建… / New File from Clipboard…**，位于“新建文件…”之后、“图片粘贴为文件”之前；跟随已有新建菜单位置设置，只出现一次。
2. 主应用创建操作区、File 菜单和菜单栏增加同名入口，不新增全局快捷键。
3. 有现存草稿时，只聚焦原面板，保留名称、目录、格式、内容和选择状态，**不读取剪贴板**。已有目录选择 sheet 或创建写入也不另起一份草稿。
4. 无草稿时，在主应用接收并处理这次显式动作时读取一次剪贴板；Finder 构建菜单及扩展进程不读取正文。冷启动读取的是主应用开始处理时的内容，不声称是 Finder 点击瞬间的快照。
5. Finder 入口使用菜单捕获的目标目录。主应用/菜单栏没有 Finder 目录上下文，先捕获文本，再走 `newFile()` 的原生目录选择；取消即丢弃快照。等待选目录期间剪贴板变化不影响这份文本。
6. 面板初始格式为 `txt`，允许改名称、文本后缀、目录及正文。内容从预填时就算“用户编辑”，不展开模板变量。按 Create 才写文件；取消没有输出。

### 类型与保存规则

- 首期接受一个剪贴板 item 的纯文本表示；富文本若同时提供纯文本表示，只取纯文本。不自行解析 HTML/RTF。
- 图片、文件 URL 引用、多个 item、无文本或空字符串给出明确提示；保留只有空白/换行的非空文本，不 trim。文件引用即使带字符串表示也拒绝，避免把拷贝文件误当正文。
- 首期文本上限拟定为 UTF-8 编码后 **8 MiB**；超限提示，不截断、不保存。读取后立即检查，不能声称此上限约束第三方剪贴板 provider 的响应时间。
- 多行、Unicode、前后空格、CRLF 和 `{{fileName}}` 等字面文本原样写为 UTF-8。纯文本 URL 也只是正文，不解析或访问其目标。
- 即使 txt 模板被禁用/删除，也可使用临时 txt 草稿；不恢复用户删除的模板，不更改模板设置。其他文本格式切换保留正文，二进制文档模板沿用已有已编辑正文保护。
- 同名处理沿用自定义创建面板：显式确认替换、取消为默认；不静默覆盖。授权失败保留草稿并沿用目录授权重试。

### 实现切分

- **Core**：新增纯值 `ClipboardTextPolicy`，校验类型摘要、文本是否存在及大小；正文读写仍属于原生 adapter。扩展 `QuickCreationTicket` 的 intent 为 `template(id)` / `clipboardImage` / `clipboardText`，兼容当前旧字段解码；未知或矛盾 intent 拒绝。文本不放入 ticket 或 URL，旧裸草稿链接不能请求读剪贴板。
- **App**：新增 `ClipboardTextReader`，可注入独立 `NSPasteboard` 用于验证；只在动作处理函数读取。增加 `newFileFromClipboard` 与 `presentClipboardText`，使用统一的创建准备 guard，覆盖选目录、文本准备和既有图片解码。所有新建入口在 guard 持有期间拒绝重入或聚焦现有 UI；在每个异步返回点重新检查单面板状态。
- **SharedUI**：`present` 增加 `initialText: String?`，禁止与 `imageData` / 二进制模板同时初始化。先建立 txt 草稿，再调用 `draft.updateContent(initialText)`，最后建立控件；复用既有 `.verbatim` 创建路径。保留原有无初始文本调用行为。
- **Finder / App 入口**：加入菜单动作、ticket 分派和双语字符串。修改 [FileMintApp](../../App/FileMint/FileMintApp.swift)、[ContentView](../../App/FileMint/ContentView.swift) 中对应创建入口；不另建窗口控制器。

## B. 在当前目录打开工具

### 统一入口与目录语义

直接复用“使用 App 打开”的应用列表、排序、一级/二级位置及 Finder 菜单，**不新增独立工具组、设置页或目录动作开关**。扩展的是同一个入口的背景目录上下文。

| Finder 上下文 | 传给 App 的内容 | 终端的窗口/标签页选项 |
| --- | --- | --- |
| 文件夹/桌面空白处 | 捕获的 container URL | 生效 |
| 单选普通目录 | 该目录 | 生效 |
| 单选文件、package、符号链接、Finder alias | 保持既有选中项打开行为 | 不生效；不自动改成父目录或执行目录启动命令 |
| 多个选中项 | 按 Finder 顺序传完整 selection，保持原行为 | 不生效；不悄悄合并成一个目录 |
| toolbar、sidebar、缺失目标 | 无新增入口，不复用旧 selection | 不生效 |

`OpenWithTargetPolicy` 在 Core 区分 `selection([URL])` 与 `directory(URL)`；原生层提供 ordinary directory / package / symlink 的类型信息。背景 container 不因为 metadata 不可读而改用父目录；不扫描目录内容。普通 App 的目录是否受支持交给它自身处理，FileMint 不虚构所有 App 都能打开文件夹。

菜单构建时捕获 App identity、target 与打开方式。点击及授权后重校验完整选择或目录的范围、存在性、类型、当前配置；目录经 symlink 父路径进入范围外、被替换为文件或已经删除则拒绝。请求执行时不再读取 Finder 当前窗口。

### 终端能力白名单

白名单是随 FileMint 发布的 adapter catalog，不预先往用户应用列表添加条目。用户通过现有“添加 App”选择应用后，基于 bundle identifier、有效 bundle 和对应能力识别终端；不能按显示名称包含 Terminal 猜测。

首批目标如下，**均需在发布前通过签名沙盒 App 的实际验收**；“存在公开接口”不等于当前 FileMint 已支持：

| 终端 | 身份 | 首选适配 | 已核实依据与剩余门槛 |
| --- | --- | --- | --- |
| 原生 Terminal | `com.apple.Terminal` | `New Terminal at Folder` / `New Terminal Tab at Folder` 系统 Services | 本机 Terminal 2.15 的 Info.plist 明确注册两项；需验证 macOS 13 与当前系统中的 service 调用、注册与目录传递 |
| iTerm2 Stable | `com.googlecode.iterm2` | `New iTerm2 Window Here` / `New iTerm2 Tab Here` Services | 官方 release plist 明确注册两项；需验证实际发行版与服务路由 |
| Ghostty | `com.mitchellh.ghostty` | 对应 New Window Here / New Tab Here Services | 官方 macOS plist 明确注册两项；需核对正式 bundle 身份、发行版及其支持的 OS，不提高 FileMint 的 macOS 13 下限 |
| Warp Stable | `dev.warp.Warp-Stable` | 官方 `warp://action/new_window` / `new_tab`，`path` query 为目录 | 官方 URI 文档和本机 Warp bundle 已核实；需测试 URL 编码与冷/热启动 |

WezTerm、kitty 放入后续候选：其官方 CLI 有窗口/标签页与 cwd 参数，但外部 CLI 的进程、socket、sandbox 和用户配置依赖需要单独适配；首期不展示为已支持。Preview/Nightly 也不靠名称自动复用 Stable 的 scheme/服务。

每条 catalog 提供 `kind`、`supportedModes`、adapter 及经验证的版本条件。运行时只检查已配置 App 的有界元数据、版本与服务声明，不枚举 Applications、不启动 App 做能力探测。系统注册/权限导致的执行错误在实际动作后显示，不因 metadata 存在就标注“连接成功”。

### 打开方式与默认值

- 识别为受支持终端后，自动显示与菜单位置同级的原生下拉框：**跟随终端 / 新标签页 / 新窗口**，无需先开启“高级功能”。后两项用户要求的明确模式由实际验证的 adapter 支持。
- 新添加且完成适配的终端默认 **新标签页**；旧配置缺字段或值无效时默认 **跟随终端**，保留原 NSWorkspace 行为。普通 App 不显示终端专属控件。
- 新标签页：在该终端可用窗口中新建标签；无窗口时创建窗口及首个标签。多窗口时使用 adapter 已验证的“最近活动的普通窗口”规则，不复用现有 tab 执行 `cd`，也不向已有会话发送输入。
- 新窗口：明确请求独立窗口。若终端偏好、系统状态或实现使该语义无法保证，就不能将该模式标为支持；不静默退回另一个模式。
- 跟随终端：将目录交给该 App 自行决定，不承诺新 tab/window。模式仅应用于实际目录 target；文件/多选继续按现有方式打开。
- 保存即时生效。变更前已打开的 Finder 菜单保留原快照；若与最新模式不一致，拒绝旧动作并提示重新打开菜单，避免标签与实际行为不同。
- Finder 中仍只保留每个 App 一项：目录场景的终端项附“（新标签页）”或“（新窗口）”；不拆成双行，也不增加第三级菜单。配置位置和原排序仍然生效。

### 数据与执行设计

1. `OpenWithApplication` 仅新增 `terminalOpenMode`（`applicationDefault` / `newTab` / `newWindow`），保留既有 `placement`。adapter 身份由 catalog 推导，不持久化自称支持的能力。重加/修复书签保留原模式、ID、排序和位置。
2. `FileMenuAction` 保留 target 和 mode；[FileOperationRequest](../../CorePackage/Sources/FileMintCore/FileOperationTicket.swift) 为目录增加 `openDirectory(application:directory:mode:)`。沿用私有单次、60 秒 ticket、现有 URL 路由和串行 coordinator，不接收外部任意命令或 scheme。
3. 主应用解析保存的应用书签、验证身份；目录请求按需授权目标目录本身，selection 请求沿用现有父目录访问。授权不扩大 Finder 范围。再次核对 identity、mode、adapter 能力、目录类型及 resolved scope 后调用。
4. 普通 App / `applicationDefault` 复用 `OpenWithApplicationAccess.open([directory], with: savedAppURL)`。编辑器无需第二份白名单；至少用 VS Code 验证目录确实成为工作区。必要的专用公开 URL 只能在其 adapter 内构造。
5. Terminal / iTerm2 / Ghostty 首选公开 `NSPerformService`，使用 `NSPasteboard.withUniqueName()` 传递目录；按各服务声明写入文件列表/URL或纯文本，不触碰 `.general`。native Services 返回后释放私有 pasteboard 和访问权限；对换行、引号等路径验证 provider 是否准确接收，不能“转义一下”就当通过。
6. Services 按服务名路由，API 不提供 `withApplicationAt`：实现阶段必须核对系统登记的规范 App URL 与用户书签一致，并验证重复安装、服务名称冲突及本地化行为。无法可靠绑定选中副本时停止并提示重新选择，不悄悄打开另一份 App。该项是优先验证的真实风险，不用动态反射或私有 API 绕过。
7. Warp 使用 `URLComponents` / `URLQueryItem` 编码目录，通过指定 savedAppURL 的 NSWorkspace 投递；不全局调用默认 scheme handler。未知字段和模式拒绝，路径绝不拼入 shell。URL callback 表示交付成功，不证明终端的实际 cwd。
8. 首期不添加 AppleScript、模拟按键、改终端配置文件、用户脚本安装、CLI PATH 依赖、额外网络服务或 Automation 权限。Service/URL 失败保留设置、提示原因，防止自动重试产生双窗口；状态明确未知时不自动换另一种方式。
9. 保持 busy/restart guard 和 security scope 到 adapter 完成；短暂调用期禁用重复提交。终端启动后终端自己的权限和会话归终端管理，FileMint 不持续查询、读取终端内容或监控目录。

### 官方接口证据

2026-09-28 查阅；原生 service metadata 是静态证据，还未执行这些服务：

- [Apple Services 调用指南](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/SysServices/Articles/using.html)：`NSPerformService` 接收服务名与指定 pasteboard，允许由程序发起系统服务。
- [Terminal 用户指南](https://support.apple.com/guide/terminal/open-new-terminal-windows-and-tabs-trmlb20c7888/mac)：支持在目录中新建窗口或标签。另已只读检查本机 `/System/Applications/Utilities/Terminal.app/Contents/Info.plist`。
- [iTerm2 官方 release plist](https://raw.githubusercontent.com/gnachman/iTerm2/master/plists/release-iTerm2.plist)：声明新标签和新窗口服务及 `com.googlecode.iterm2` 身份。
- [Ghostty 官方 macOS plist](https://raw.githubusercontent.com/ghostty-org/ghostty/main/macos/Ghostty-Info.plist)：声明对应两种服务。它也有 AppleScript，但本方案不依赖该路径。
- [Warp 官方 URI](https://docs.warp.dev/terminal/more-features/uri-scheme)：提供两种 action 与目录参数；本机 `/Applications/Warp.app/Contents/Info.plist` 的 Stable 身份已只读核实。
- 后续候选依据：[WezTerm spawn](https://wezterm.org/cli/cli/spawn.html)、[kitty launch](https://sw.kovidgoyal.net/kitty/generated/launch/)。

## C. 设置页与窗口设计

### 推荐方案：紧凑应用行，同级下拉配置

保留现有全局侧栏、页面标题“使用 App 打开”和一个应用列表，延续原生图标、暖白/石墨背景、低对比边界和薄荷色焦点。新增空间用于对齐和留白，不放大所有字和按钮。

- 页头一句话解释“选中文件时打开文件；在文件夹空白处打开当前文件夹”。右上保留一个 **添加 App…**，继续使用原生应用选择器，不先给用户一个重复的品牌选择步骤。
- 列表采用同一轻边界分组，常规行约 76 pt：拖动柄、32 pt 真实 App 图标、名称、次级类型/模式摘要，右侧为带可访问标签的菜单位置选择和“更多”按钮。路径移入“更多 → 应用信息/在 Finder 中显示”，仅修复时重点展示；不让长路径挤占主操作。
- 按用户反馈，受支持终端在应用行内与“菜单位置”同级显示“打开目录时”原生下拉框；普通编辑器不显示此控件，不留空白位置。
- 下拉项为“跟随终端 / 新标签页 / 新窗口”；每行独立保存，不设全局默认去覆盖已有选择。次级摘要同步更新，辅助说明只有一句“没有窗口时将新建窗口”。
- 拖动柄保留明显的插入线；“更多”提供上移、下移、重新选择、在 Finder 中显示和移除。键盘用户通过菜单完成排序，不需要同时常驻两枚箭头和删除按钮。移除只改列表；不删除 App，保留现有无需重复确认的轻量交互。
- 行内错误取代整页泛化红字：缺失应用显示“找不到应用 · 重新选择…”，服务不可用显示具体修复建议；模式选择保持可读。保存失败回滚并说明未保存，不显示假成功 toast。新增 App 后滚动到该行并短暂高亮，重加则定位旧行，避免用户以为添加失败。
- 列表下方可提供“支持哪些终端？”展开白名单说明；生产列表不预置未安装的品牌卡片，也不把开发中 adapter 展示为占位工具。
- 空列表保留单一添加按钮和说明；长列表在当前页面滚动，页头与底部的全局布局保持既有行为。白名单识别、图标/元数据刷新仍在有界后台任务中完成。
- 中文/英文、VoiceOver、Tab/方向键、Reduce Motion、高对比焦点均沿用原生控件语义。控件有完整可访问名称，不仅依赖图标或 hover；长 App 名按中间截断并提供完整信息。

备选布局是“左列表 + 右详情”，适合未来每个 App 有许多设置。本期只有菜单位置与终端方式，推荐内联方案，避免用户逐个点进去才发现选项。对话内草案提供这两种布局的交互比较；草案中的应用是示例，不代表用户真实配置或适配验收。

### 设置窗口尺寸

| 尺寸 | 当前 | 计划 |
| --- | --- | --- |
| 最小内容尺寸 | 840 × 600 pt | **960 × 680 pt** |
| 初始内容尺寸 | 900 × 650 pt | **1040 × 720 pt** |

侧栏从 202 pt 小幅调整到约 212 pt；内容区保持约 30 pt 边距。正常最小宽度下内容宽约 688 pt，足够容纳 App 身份、位置选择和完整的三段控件；普通行不会被终端控件强迫撑高。

在 App 层抽出一个 `SettingsWindowMetrics`，同时供 `NSWindow.contentMinSize`、初始 contentRect 与 SwiftUI 约束使用，避免两处硬编码不一致。显示前和屏幕变化时，使用 `NSScreen.visibleFrame` 扣除标题栏后的可用内容区域夹取尺寸；保存的/当前较大尺寸不应在普通重开时被缩小。屏幕可用区域小于标准最小尺寸时，动态降低有效 min 并允许页面纵向滚动；不能留下 SwiftUI 的固定 960 宽约束阻止适配。

仅改变设置窗口；创建面板保持紧凑，资源工具窗口不自动继承。把新值写入 Presentation SPEC，检查各设置页在新最小尺寸和小屏兜底下无裁切，不新增设置入口让用户配置窗口最小值。

## 实施顺序与完成条件

| 阶段 | 实施内容 | 完成条件 |
| --- | --- | --- |
| 0. 契约与可行性 | 更新 creation / open-with / startup / finder / presentation；用独立临时目录验证四种终端的服务或 URL | 目录矩阵、模式、窗口尺寸与迁移写入 SPEC；每个 adapter 有实际证据，未通过的不能标为支持 |
| 1. 文本草稿 | 文本 reader/policy、ticket intent 兼容、单面板 guard、initialText、所有入口和本地化 | 文本动作从 Finder / App / 菜单栏到实际文件闭环；不覆盖旧草稿 |
| 2. 目录工具和界面 | Core 目标规则、白名单、模式迁移、应用行/设置窗口、Finder 布局、ticket 和 launcher | 单一菜单复用；终端模式按能力出现；指定工具打开正确目录；新窗口尺寸与全部设置页相容 |
| 3. 验收与收尾 | Core/原生证据、错误路径、文档状态 | 下列验收通过；未完成项明确记账，再将 task 改为 complete |

产品实现期间按 HARNESS 执行 `make verify`、`CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO make build`。若阶段中独立验证后又修改逻辑，重跑受影响检查；规划阶段不运行这些检查。

### 验收清单

- [ ] 文本的多行、CRLF、Unicode、纯空白和字面模板符号按预期 UTF-8 字节保存；txt 模板禁用/删除仍可预填；改后缀不覆盖正文。
- [ ] 空剪贴板、纯图片、文件引用、多 item、超限文本均给出相应提示且零文件输出；8 MiB 边界不截断。
- [ ] 已有文本/图片/Office 草稿、目录 sheet、图片解码、连续点击和写入期间不替换草稿、不重复读取/创建；取消选择目录和取消创建均无输出。
- [ ] 用命名的测试 pasteboard 验证显式动作读取次数；测试不读写用户真实剪贴板。预填后改变剪贴板不改变草稿。
- [ ] ticket 兼容旧模板/图片请求，文本 intent、未知 intent、矛盾字段、超时、重放、裸链接和范围变化有回归覆盖。
- [ ] 目录矩阵、Desktop 无 metadata、包/链接、非本地 URL、范围外/移除的目录、symlink 父路径逃逸及目录类型变化有 Core 回归。
- [ ] 旧偏好模式为 applicationDefault，新添支持终端为 newTab；普通 App 不显示终端控件；未知模式安全回退；增加/重选/删除、单一位置、排序、损坏条目和空菜单符合规则。
- [ ] 菜单构建后切换 Finder 选择仍操作原目录；菜单打开后改模式/删应用/改授权时旧请求拒绝；取消授权不启动工具。
- [ ] 空格、单双引号、中文、emoji、`#`、`%`、`?`、冒号、换行、前导连字符及 shell 特殊字符的目录传递正确，路径从不成为命令。
- [ ] 复用/扩展现有 sandbox open-with harness 的接收 App 验证准确 URL、访问释放、busy guard 和单次执行；fake receiver 成功不算真实 Terminal / VS Code 成功。
- [ ] 四种终端各自验证新 tab / 新 window 的数量变化和实际 cwd；覆盖无进程、已启动无窗口、单窗口、多窗口、全屏/最小化、恢复会话、改变终端默认偏好。错误/超时不能自动重试造成重复窗口。
- [ ] macOS Services 在禁用/未注册服务、中英文、本机同一 App 多副本下能明确成功或失败；指向正确 App。私有 pasteboard 不改变 `.general`，未获授权不执行。
- [ ] 至少以 VS Code 验证普通编辑器的工作区根路径；文件与多选仍传递选中项，终端模式不把文件当成命令或目录。
- [ ] 中英文、浅/深色、VoiceOver、键盘排序、长名称和保存失败回滚完成原生检查；Finder 请求不打开设置窗口。
- [ ] 初始 1040×720、最小 960×680、1280×800 屏幕、较小 visibleFrame、多屏移动均无按钮裁切。AppKit / SwiftUI 有效约束一致，所有设置页受检；创建面板尺寸不变。

Core 回归放入现有 `FocusedCreationTests`、`OpenWithTests`、`StartupPreferencesTests` 等相关 suite，按规模拆出新测试文件。正文 `.verbatim` 和错误用例使用 Swift tests，不扩展现有 JSON Harness schema 来伪装原生能力。

## Decisions and progress

- 已完成：当前源码和 domain 对照、需求边界、目录语义、草稿冲突规则、复用点、工具适配器方案、迁移和验收设计。
- 按后续讨论改为一份应用身份、一项菜单入口，自动区分 selection / directory；移除前稿中独立目录工具组、双开关与双位置。
- 新增四终端白名单、三种打开方式、内联行设计和更大的设置窗口；本机只读核实 Terminal / Warp 元数据，官方源码核实 iTerm2 / Ghostty 服务声明。
- 已实现文本快照、旧凭据兼容、Finder/App/菜单栏入口、原文草稿；目录目标策略、终端偏好和 Services/Warp launcher；同级下拉框、菜单预览、设置窗口尺寸与屏幕夹取。
- 已更新 owning SPEC；代码构建和自动检查通过。签名沙盒夹具确认普通文件/目录交付及独立剪贴板。Terminal 与 Warp 的 New Tab / New Window 请求返回成功，且只读进程检查确认各请求的实际 cwd，包括特殊字符与换行；窗口/标签数量仍无观察证据。
- 用户纠正了视觉交互：打开方式与菜单位置同级使用下拉框；产品代码与交互草案已调整。
- QA 发现设置窗口在语言切换后从 960×680 被 SwiftUI 撑至 960×1253；在产品 `NSHostingView` 禁用隐式尺寸建议，隔离夹具的自动回归确认语言和外观切换后尺寸保持 960×680。
- 已准备本地 Developer ID 签名 QA DMG；用户选择暂不替换 `/Applications/FileMint.app`，并表示将提供其余终端/macOS 13 环境、配合观察窗口/标签数量。本轮不安装、不改系统扩展或偏好。

## Evidence

Tested base commit/worktree: `c23ffc6` + 本任务未提交改动；原工作区仅有此任务文档。
Environment: macOS 27.2 / Apple silicon；2026-09-28。最终日志保存在 `build/qa-2026-09-28/`（本地忽略文件）。

| Check / command | Status | Observed result / evidence link |
| --- | --- | --- |
| SPEC、入口源码与官方接口文档检查 | passed | 复用点与接口证据见上文；静态设计证据 |
| `make verify-context` | passed | 21 documents / 113 local links；入口 6992/7000 UTF-8 bytes；这是文档检查 |
| 任务文档本地链接 | passed | 本次更新后检查 27 个本地链接，全部存在 |
| 设置页交互草案静态检查 | passed | 26 KB HTML fragment；`node --check` 通过；包含内联/列表详情两种布局、模式/位置/菜单预览/示例添加/排序交互；不算原生产品验收 |
| 草案浏览器视觉与交互验收 | blocked | 本地预览服务器受 sandbox 限制；浏览器 URL 策略拒绝 `file://`。未绕过策略，未取得截图或实际交互通过证据 |
| `make verify` | passed | Swift 168 tests / 20 suites、图像 14 tests、JSON Harness 5/5、CLI 10 项和其余离线检查，见 `build/qa-2026-09-28/filemint-qa-verify-final-20260928.log` |
| `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO make build` | passed | 最终 Release app + Finder 扩展 unsigned build 通过，见 `build/qa-2026-09-28/filemint-qa-build-final-20260928.log`；不是签名运行证据 |
| `git diff --check` | passed | 当前未提交工作区无空白错误 |
| `APPLE_TEAM_ID=8S66M2ZLD5 ... make package` | passed | 本地 Developer ID 签名 QA DMG 的嵌套签名、entitlements、arm64 bundle、checksum 与 `hdiutil verify` 通过；`build/qa-2026-09-28/FileMint-0.6.1.dmg` 的 SHA-256 为 `e1bb5d6a9895b5566bafde35621eb58ff663338939e2c38b248d38bc8409259a`。未公证、安装或发布 |
| 签名 sandbox open-with / clipboard smoke | passed | 生产 coordinator 向接收 App 交付 selection 和目录；命名 pasteboard 原文/文件引用规则、Warp 特殊字符 URL、单次凭据、文件和通用剪贴板保持通过，见 `build/qa-2026-09-28/filemint-qa-open-with-final-20260928.log` |
| 剪贴板原生创建面板 | passed | 隔离 UI 夹具用命名 pasteboard 预填后改变剪贴板，面板仍显示原文；创建文件与预期 29 个 UTF-8 字节完全一致，第二次取消无输出；未读取用户通用剪贴板 |
| Terminal / Warp cwd | passed | 两款已安装终端的 New Tab / New Window 请求均返回成功，`lsof` 只读核实各自 shell cwd；另核实引号、中文、emoji、标点和换行均原样到达。日志见 `build/qa-2026-09-28/filemint-qa-{terminal,warp}-*.log`；**不证明窗口/标签数量** |
| VS Code 实际工作区 | passed | 生产 coordinator 打开临时目录，VS Code 原生资源管理器显示同一个目录为根；见 `build/qa-2026-09-28/filemint-qa-code-20260928.log` 和本轮原生 UI 观察 |
| 设置页和尺寸回归 | passed | 原生夹具观察同级终端模式/菜单位置、预览更新、普通 App 无终端控件；修复语言切换后窗口异常增高，`--check-window-size` 自动断言 960×680 在英语与深色切换后保持，见 `build/qa-2026-09-28/filemint-qa-window-size-20260928.log` |
| 当前源码的已安装 Finder 回调、四终端窗口/标签数量、iTerm2/Ghostty、macOS 13 | not-run | `/Applications/FileMint.app` 与工作区构建的可执行文件 SHA-256 不同；终端类 App 的电脑操作被安全限制拒绝；iTerm2/Ghostty 与 macOS 13 环境不可用。未替换安装版或修改系统扩展权限 |
| QA 后扩展注册检查 | passed | `pluginkit -m -A -D -v -i io.github.daigua.filemint.findersync` 只显示 `/Applications/FileMint.app/Contents/PlugIns/FileMintFinderSync.appex` 一项；安装版可执行文件 SHA-256 保持 `f64225d284ad30a6664677862d362305b4b599296989432dec5dc9f93f48b860` |

## Handoff

- Remaining work: 用户提供 iTerm2/Ghostty 与 macOS 13 环境后，核对终端新标签/新窗口数量、禁用或重复 Services；小屏/多屏、VoiceOver 仍待检查。当前源码的 Finder 菜单、冷启动和剪贴板入口需将来另行授权安装 QA 候选后才能验收；本轮用户已明确暂不替换安装版。完成这些项目后再改为 complete。
- Files currently changed: 对应 Core、App、Finder、SharedUI、Harness、domain SPEC 及本任务文档；均未提交。
- Conversation design: 交互草案保存在本对话可写的 visualization 目录，文件名 `open-with-terminal-design.html`；它是讨论界面，不作为 SwiftUI 代码或已验证截图交付。
- Known limitations: Terminal / Warp 的实际 cwd 已核实，但 tab/window 数不能从 shell cwd 推断；终端 App 的 UI 读取受工具安全限制。iTerm2/Ghostty 未安装，macOS 13 无环境，当前安装的 FileMint 与工作区构建不同。浏览器本地草案 preview 仍受 URL 策略限制。
- Cleanup: 隔离 QA App 与 VS Code 的临时工作区窗口已关闭；只读检查仍见 3 个以 `filemint-terminal-qa-*` 为 cwd 的 Terminal/Warp 测试 shell。终端 UI 工具拒绝操作，未通过其他方式强制关闭；用户可手动关闭这些临时会话。
- Next action and minimum context: 读取本 task、当前 diff、相关 domain 和 Harness；使用可用的原生验收环境确认实际行为，不将静态服务声明或派发回执当成 cwd 验收。
