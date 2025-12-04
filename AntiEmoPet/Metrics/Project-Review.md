# 项目全面评估（SDE/PM）

本文基于当前代码库进行“从代码反推PRD”的系统性分析。仓库中未检索到“3份PRD文档”，因此以下评估以已实现的功能与接口为依据，同时指出PRD缺失处需要补齐的条目。

## 1. 执行摘要（Executive Summary）

- 核心价值：项目旨在通过“日常任务 × 天气/时段 × 虚拟宠物反馈”形成一套轻量行为激励系统，辅以情绪记录与商店奖励，驱动用户持续参与。
- 产品潜力：
  - 结合天气/时段生成动态任务、完成后奖励能量与宠物羁绊/等级，具备“情绪健康 + 游戏化”的差异化空间。
  - 入门（Onboarding）引导、情绪捕获提醒、轻商城与装扮，具备进一步增长与留存的潜力。
- 主要风险：
  - PRD缺失导致“需求边界、指标口径、异常流程”不清晰，易产生实现分歧与重复逻辑。
  - 分析口径分散（UserDefaults计数 vs DataAggregationService指标），后续数据一致性与可验证性存在风险。
- 关键建议：
  1) 统一“任务/心情/天气/指标”的数据口径与事件命名（Analytics 词典）。
  2) 明确任务生命周期（pending/started/ready/completed）与Buffer规则的PRD，避免前后端/前后台边界不一致。
  3) 指标体系统一到单一聚合服务（或数据层），替代多处计数。
  4) 将“奖励策略（energy/xp/bonding/掉落）”数据化/配置化，避免硬编码。

---

## 2. 功能地图（从代码反推）

- 任务系统
  - `UserTask`（SwiftData @Model）：`TaskCategory`、`TaskStatus`、Buffer机制（`bufferDuration`）与奖励（`energyReward`）。
  - 生成与调度：`TaskGeneratorService`（未展开但被广泛调用）、`AppViewModel`管理按`TimeSlot`生成、刷新、过期清理与通知。
  - 状态推进与完成奖励：`AppViewModel.startTask / completeTask / updateTaskStatus`。

- 宠物系统
  - `PetEngine`：处理 `pat / feed / penalty`，XP升级（`XPProgression`），羁绊值边界与每日衰减、任务完成奖励。
  - `PetViewModel`：UI状态（背景、时间段、天气文案、宠物贴图）。

- 情绪系统
  - `MoodEntry`（SwiftData）：`MoodSource`、`delta`、与任务/天气的关联；`AppViewModel`负责“强制/引导记录”逻辑。

- 天气与时段
  - `WeatherService`：WeatherKit拉取、缓存、回退策略、日出日落（`SunTimes`）、`WeatherReport`。
  - `TimeSlot`（未见文件但广泛使用）：`morning/afternoon/evening/night`；调度与触发。

- 商店与道具
  - `Item`（SwiftData）、`ItemLoader`（JSON版本化种子）、`ShopView` + `ShopViewModel`、入手/装备/背包（`InventoryEntry`）。

- 入门流程（Onboarding）
  - 多步骤视图与`OnboardingViewModel`（第三方登录、权限、资料采集）、完成后一次性生成引导任务。

- 通知与分析
  - `NotificationService`（未展开）按任务安排提醒；`AnalyticsService`（未展开）记录关键事件。

- 指标与数据聚合
  - `DailyActivityMetrics`（轻量日级指标）由 `AppViewModel.makeDailyActivityMetrics` 生成（依赖UserDefaults计数）。
  - `DataAggregationService` 输出 `UserTimeslotSummary`（包含情绪、能量、任务统计等）。

---

## 3. PRD 完整度评估与建议

以下维度按“现状 -> 缺口 -> 建议”给出。

### 3.1 任务系统（TaskCategory/TaskStatus/Buffer/奖励）
- 现状
  - `TaskCategory` 定义了展示名称（`title`）、`bufferDuration` 和 `energyReward`。
  - `TaskStatus` 包含 `pending/started/ready/completed`，`isCompletable` = `.ready || .pending`。
  - `AppViewModel` 中存在两套状态推进：`startTask/completeTask` 与 `updateTaskStatus`（包含定时器推送 `ready`）。
- 缺口
  - PRD 未明确：
    - 为什么 `pending` 状态可被视为 “completable”？与 Buffer 机制存在冲突（未等到 `ready` 也能完成？）。
    - Buffer 超时后如何处理后台、跨时段、跨日？
    - 任务重复生成/刷新策略的PRD边界（保留/清理、惩罚/奖励）。
  - `energyReward` 硬编码在 `TaskCategory`，但 `RewardEngine` 也在计算奖励，存在潜在重复口径。
- 建议
  - PRD补齐：
    - 明确任务生命周期图（含状态变迁触发条件、超时/取消/失败分支）。
    - 明确 Buffer 规则（前后台、重启、跨日、异常）与“可完成”的判定。
    - 定义“刷新任务”的触发规则、冷却、惩罚、例外（Onboarding）。
  - 技术方案：
    - 统一任务状态推进入口（保留 `startTask/completeTask`，移除/收敛 `updateTaskStatus` 的重复逻辑或将其限定为内部API）。
    - 将 `energyReward` 与掉落策略改为“策略中心/配置中心”，由 `RewardEngine` 统一输出（`TaskCategory` 中仅保留展示文案与分类语义）。

### 3.2 宠物系统（羁绊/XP/衰减）
- 现状
  - `PetEngine` 统一处理加减羁绊、XP升级（`XPProgression`），并在任务完成/购买/抚摸时触发。
- 缺口
  - PRD未明确：
    - 羁绊衰减的触发条件、频率、边界（`applyDailyDecay` vs `applyDailyBondingDecayIfNeeded`）。
    - 宠物状态（`PetBonding`）与UI表现的映射规则，是否与心情/任务完成关联。
- 建议
  - 将“每日衰减/未完成任务惩罚”的规则收敛到一个“日批评估点”，与时区/跨日一致。
  - 数据化 XP/羁绊规则，便于A/B测试与版本演进。

### 3.3 情绪系统（MoodEntry + 捕获逻辑）
- 现状
  - `MoodEntry` 采用 String 存储 + 计算属性包装，支持 `delta` 与任务/天气关联。
  - `AppViewModel` 通过 `checkAndShowMoodCapture/refreshMoodLoggingState` 控制时段内是否需要记录。
- 缺口
  - PRD未明确：
    - “强制/引导记录”的触发条件、豁免（夜间已做处理但其余异常？）。
    - 情绪值口径（0-100）与阈值（`MoodLevel`）对产品功能的影响。
- 建议
  - 明确“情绪记录”在任务完成与普通时段的引导策略、频率限制、过度打扰控制。
  - 将情绪与奖励/任务推荐形成闭环：例如低情绪时优先推荐“简单/舒缓”任务。

### 3.4 天气与时段（Weather/TimeSlot）
- 现状
  - `WeatherService` 具备完整的授权、缓存、回退与持久化策略；`sunEvents` 与 `windows` 已实现。
  - `AppViewModel` 基于 `TimeSlot` 进行任务生成与触发。
- 缺口
  - PRD未明确：天气/时段对任务生成的具体权重与兜底策略（无天气、夜间是否生成等）。
- 建议
  - 将“任务生成权重矩阵（天气×时段×用户偏好）”配置化；明确夜间/极端天气策略。

### 3.5 商店与道具（Shop/Inventory）
- 现状
  - `ItemLoader` 支持 JSON 版本化种子，`ShopView`/`AppViewModel` 支持购买/装备/消耗。
- 缺口
  - PRD未明确：
    - 道具掉落（`randomSnackReward`）的概率与产出上限。
    - 价格、折扣、限时、货币化（如有）。
- 建议
  - 统一“奖励策略中心”定义掉落概率、能量价格、购买返利与活动。

### 3.6 通知与分析（Notification/Analytics）
- 现状
  - 任务提醒、每日提醒（睡眠提醒）已接入；分析事件分散在 `AppViewModel`。
- 缺口
  - PRD未明确：事件词典、埋点一致性、关键指标（留存、完成率、情绪改善、LTV）。
- 建议
  - 制定 Analytics 事件词典（事件名、属性、触发时机），统一接入点，增加版本/实验ID。

### 3.7 指标与聚合（DailyActivityMetrics vs DataAggregationService）
- 现状
  - `DailyActivityMetrics` 由 `AppViewModel` 基于 UserDefaults 快速累计；
  - `DataAggregationService` 计算更完整的分时段指标（情绪均值、能量、任务完成/创建）。
- 缺口
  - 指标口径不统一（双轨并行），易出现看数不一致。
- 建议
  - 统一指标来源：以 `DataAggregationService` 为主（或合并逻辑），`DailyActivityMetrics` 作为派生/缓存层。
  - 将“任务创建/完成”口径在PRD中固定（以`completedAt`为准，或分开统计）。

### 3.8 国际化与可用性
- 现状
  - 存在中文注释与英文文案混用；`TaskCategory.title` 为英文固定文案。
- 缺口
  - PRD未明确：语言覆盖、文案风格、地区特性。
- 建议
  - 采用 `LocalizedStringKey`/`StringCatalog` 管理文案，`TaskCategory` 提供 `localizedTitle`。

---

## 4. 重复/不一致项清单（需修复）

1) 任务状态推进逻辑重复
- 位置：`AppViewModel.startTask/completeTask` 与 `updateTaskStatus` 都在做“启动→定时→ready→完成”的工作。
- 风险：边界条件不一致（例如 `isCompletable` 允许 `pending` 完成 与 Buffer 检查冲突）。
- 处理：收敛到单一入口；`isCompletable` 改为仅 `.ready`（或PRD明确例外）。

2) 奖励口径重复
- 位置：`TaskCategory.energyReward` 与 `RewardEngine.applyTaskReward`。
- 风险：能量值口径不一致；后续活动/配置难以统一。
- 处理：将奖励计算集中在 `RewardEngine`，`TaskCategory` 仅作为“推荐/默认值”。

3) 指标双轨
- 位置：`DailyActivityMetrics`（UserDefaults计数） vs `DataAggregationService`（聚合计算）。
- 风险：看数不一致、调试困难。
- 处理：统一指标来源并定义口径；将历史数据迁移或兼容。

4) 字段类型与存储不一致
- 位置：`MoodEntry` 使用 String 存储 + 计算属性；`UserTask` 直接存枚举。
- 风险：多种模式混用易造成误用（直接读 `source` vs 读 `moodSource`）。
- 处理：在 DAO 层统一访问方式，避免直接访问原始字段；或统一为“原始值+包装器”的一致模式。

5) 文案与本地化
- 位置：`TaskCategory.title`、`PetViewModel.weatherDescription` 等。
- 风险：无法多语言扩展，测试环境与生产文案不同步。
- 处理：统一用本地化资源管理。

---

## 5. 架构与数据一致性建议

- 统一“策略中心”：
  - 奖励（能量、XP、羁绊、掉落）、Buffer 时长、任务生成权重。
  - 支持 A/B 测试与远程配置（如 Remote Config/自建配置）。

- 统一“指标中心”：
  - 以 `DataAggregationService` 为核心，定义指标口径与聚合周期。
  - `DailyActivityMetrics` 作为前端缓存/展示层，来源明确且只读。

- 状态机与边界：
  - 采用清晰的任务状态机（State Machine），明确状态切换的触发器与副作用（奖励/通知/埋点）。

- 数据层与访问规范：
  - SwiftData模型统一“原始值+类型包装”模式；提供只读访问接口，避免直接写原始字段。

---

## 6. 优先级路线图（建议）

- P0（本周）
  - 收敛任务状态推进逻辑，修正 `isCompletable` 判定；
  - 定义并冻结“任务完成口径”（以 `completedAt` 为准）；
  - 统一奖励口径到 `RewardEngine`；
  - 输出 Analytics 事件词典（事件名、属性、触发时机）。

- P1（两周内）
  - 指标中心化：将 `DailyActivityMetrics` 与 `DataAggregationService` 逻辑统一；
  - 本地化改造：将 `TaskCategory.title`、天气文案等迁移到本地化资源；
  - 策略中心化：Buffer、掉落、能量价格配置化。

- P2（四周内）
  - 任务生成权重（天气×时段×用户偏好）配置化，加入A/B；
  - 情绪-任务闭环（低情绪推荐舒缓任务、完成后正反馈）。

---

## 7. 风险与依赖

- WeatherKit 授权与配额：需要PRD明确“无授权/失败”的体验与任务生成兜底。
- UserDefaults 作为指标缓存：跨设备/跨版本迁移风险；建议转为统一数据层。
- 第三方登录：需要PRD定义“登录失败/取消/二次授权”的用户体验与恢复路径。

---

## 8. 针对 `TaskCategory` 的专项建议

- 现状：
  - `bufferDuration` 与 `energyReward` 在枚举内硬编码；`title` 为英文固定文案。
- 建议：
  - 将 `title` 替换为 `localizedTitle`（本地化资源驱动）。
  - 将 `bufferDuration` 与 `energyReward` 迁移到“策略中心”，允许远程配置和实验；`TaskCategory` 保留默认值作为兜底。
  - 对 `petCare` 15秒Buffer属测试值的概率较高，PRD需明确真实体验（是否允许“秒完任务”）。

---

## 9. 附：待补齐的PRD条目清单（示例）

- 任务生命周期与异常流程
  - 启动/中断/超时/取消/跨日；Buffer判定与后台策略。
- 奖励策略与掉落
  - base奖励、加成、上限、冷却、概率与保底；活动期配置。
- 任务生成矩阵
  - 天气×时段×用户偏好；夜间/极端天气策略；刷新/重投规则。
- 情绪记录策略
  - 强制/引导条件、频率、免打扰；与任务/奖励的联动。
- 指标口径与数据地图
  - 事件词典、日/周/月口径；端上缓存与后端聚合的一致性。
- 国际化与可用性
  - 语言覆盖、文案风格、地区特性；可访问性（字体、对比度、动态类型）。

---

## 10. 结语

项目具备“健康行为激励 + 轻量养成”的良好产品潜力。建议尽快补齐PRD并统一策略/指标中心，收敛重复逻辑，推进本地化与实验能力，以支撑持续的产品验证与增长。
