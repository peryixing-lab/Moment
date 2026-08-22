# Moment（此刻）

> 信息不必寻找，它会在合适的时候出现。

Moment 是一款面向 HarmonyOS 的场景化信息应用。它会结合时间、课程、地点、Wi-Fi 和用户选择，在当下呈现最相关的课程、任务与专注信息，并通过桌面卡片提供无需打开应用的快捷操作。

## 功能亮点

- **场景推荐**：支持图书馆、上课、会议和通勤等场景，并按手动选择、地点/Wi-Fi、课程、时间规则和默认场景进行优先级决策。
- **信息排序**：综合课程状态、任务截止时间与优先级、当前专注进度，优先展示此刻最值得关注的信息。
- **课程管理**：支持课程增删改、系统日历导入以及 VCS/ICS 文件导入。
- **任务与专注**：支持场景化任务、优先级、截止时间，以及 25 分钟、45 分钟和自定义专注时长。
- **自动场景规则**：可按照星期、时间段、地点或 Wi-Fi 自动切换场景，也可以临时或持续锁定手动场景。
- **桌面卡片**：提供 2×2、2×4、4×4 三种规格，支持完成任务、开始/结束专注、恢复自动场景和切换场景等操作。
- **本地优先**：课程、任务、规则、专注记录和设置保存在设备本地。

## 桌面卡片

| 2×2 | 2×4 | 4×4 |
| --- | --- | --- |
| ![2×2 桌面卡片](exports/widgets/moment-scene-widget-2x2.png) | ![2×4 桌面卡片](exports/widgets/moment-scene-widget-2x4.png) | ![4×4 桌面卡片](exports/widgets/moment-scene-widget-4x4.png) |

## 技术栈

- HarmonyOS Stage 模型
- ArkTS 与 ArkUI
- Dynamic Form 桌面卡片
- ArkData Preferences 本地存储
- HarmonyOS SDK API 26
- Hypium / Hamock 测试依赖

## 2in1（PC）适配

应用支持在 2in1 设备上以自由窗口运行，遵循华为官方《PC 窗口适配开发实践》：

- `deviceTypes` 声明 `2in1`，支持自由窗口、二分屏与最大化。
- 通过 `ohos.ability.window.*` metadata 配置首次启动的默认窗口大小（720×1080vp）并居中显示，避免代码 resize 造成窗口跳变。
- 开启窗口记忆（`setWindowRectAutoSave(true)`），重启后恢复用户上次的窗口大小和位置。
- 按设计规范将窗口最小尺寸限制为 360×240vp，保证二分屏正常使用。
- 保留系统标题栏三键，页面内容布局不变。

## 项目结构

```text
Moment/
├── AppScope/                         # 应用级配置与资源
├── entry/
│   └── src/main/
│       ├── ets/
│       │   ├── common/              # 颜色、排版、尺寸与通用工具
│       │   ├── components/          # ArkUI 组件
│       │   ├── database/            # 本地数据版本与迁移
│       │   ├── form/                # 桌面卡片与数据适配
│       │   ├── model/               # 课程、任务、场景等数据模型
│       │   ├── pages/               # 首页及各管理页面
│       │   ├── repository/          # 本地数据访问层
│       │   └── service/             # 场景决策、排序与业务服务
│       └── resources/               # 字符串、颜色与卡片配置
├── exports/widgets/                 # 桌面卡片展示图
├── qa/                              # 视觉验收截图
└── design-qa.md                     # 桌面卡片视觉与交互 QA 记录
```

## 开始使用

### 环境要求

- DevEco Studio
- HarmonyOS SDK API 26
- HarmonyOS 手机、模拟器或 Previewer

### 运行项目

1. 克隆仓库：

   ```bash
   git clone https://github.com/peryixing-lab/Moment.git
   ```

2. 使用 DevEco Studio 打开项目根目录。
3. 等待项目同步并安装 `oh-package.json5` 中的依赖。
4. 在 DevEco Studio 中为本机配置调试签名。签名证书、密钥和本机路径不会提交到仓库。
5. 选择 `entry` 模块和目标设备，运行应用。

## 权限说明

应用会根据启用的功能申请以下权限：

- **日历读取**：从系统日历中选择并导入课程。
- **大致/精确位置**：判断是否进入用户设置的地点场景。
- **Wi-Fi 与网络信息**：匹配用户设置的 Wi-Fi 场景规则。
- **网络访问**：满足 HarmonyOS 网络能力声明要求。

位置、Wi-Fi 与日历能力均由相应功能触发；本地课程、任务、规则和专注记录不会提交到本仓库。

## 测试与质量记录

- 单元测试位于 `entry/src/test/`。
- 桌面卡片已覆盖 2×2、2×4、4×4 的最小、默认和最大 Previewer 尺寸。
- 详细视觉与交互验收记录见 [`design-qa.md`](design-qa.md)。

## 安全说明

仓库通过 `.gitignore` 排除本机配置、构建产物、IDE 缓存、签名证书、私钥和环境文件。请始终通过 DevEco Studio 或本机安全配置管理签名材料，不要将口令或证书提交到版本控制。
