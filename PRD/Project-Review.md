# 项目全面评估（SDE/PM，基于PRD对齐版）

本文依据三份PRD（统计分析PRD、Mood Task PRD、Petview PRD）与现有代码进行系统性评估，给出对齐状态、差距与落地建议。测试相关暂不覆盖。

## 1. 执行摘要（Executive Summary）

- 核心价值
  - 通过“时间段 × 天气 × 任务 × 情绪反馈 × 宠物养成 × 商店装扮”的闭环，帮助用户建立积极的生活节律，并可视化情绪与行为趋势。
  - 产品潜力
  - 任务生成具备固定/随机两种模式，并引入天气窗口加权，带来更强的环境相关性与可玩性。
  - 情绪记录（App打开强制、完成任务后强制）与分时段聚合指标，为“趋势/洞察/AI建议”提供数据基础。
  - 宠物羁绊/经验与商店装扮构成可持续激励体系。
- 关键差距
  - 部分规则在代码与PRD不一致（任务完成判定、宠物羁绊下限与惩罚、商店中“食物”是否可购买等）。
  - 指标口径存在双轨（本地计数 vs 聚合服务），不利于后续分析与验证。
- 重点建议
  - 统一“策略中心”（任务Buffer、奖励、掉落、天气权重）、“指标中心”（聚合口径与上传）与“事件分析”（Analytics）。
  - 收敛任务状态机与生成/刷新/归档边界，严格按PRD落地。
  - 推进本地化与数据导出/上传能力，支撑“统计/洞察/AI建议”。

### 更新记录（最新）
- 任务刷新不再直接删除未完成记录，新增归档标记，保证历史可导出。
- 任务状态机限制仅 `.ready` 可完成，并通过天气适配过滤任务类别，雨天禁户外、晴天优先非室内数字/宠物护理。
- 宠物羁绊最小值提升至 15，0 完成惩罚维持 -2，下限与惩罚口径统一。
- 商店入口隐藏可食用类的购买入口，保留通过任务掉落补给的策略，后续继续集中奖励逻辑到 RewardEngine。
- RewardEngine 统一计算任务能量奖励与随机掉落，完成后先展示奖励再进入情绪反馈；掉落的 snack 成为唯一补给来源。
- DataAggregationService 输出 {published, completed, moodDeltaSum} 三元组并使用“生成时天气”口径；新增 EnergyEvent 流（delta>0 + relatedTaskId）并持久化。
- 启动本地化迁移：TaskCategory.localizedTitle 改为字符串表读取，为后续多语言做准备。

---

## 2. PRD要点与代码对齐情况

### 2.1 时间段与任务生成
- PRD要点
  - 时间段：
    - 早上 06:00–12:00
    - 下午 12:00–17:00
    - 傍晚 17:00–22:00
    - 夜间 22:00–06:00（不生成任务，弹睡眠提醒）
  - 固定模式：在时间段开始时生成任务。
  - 随机模式：在时间段开始时确定一个“本段内的随机生成时刻”，并结合未来数小时天气窗口进行加权；到达该时刻生成任务并发送推送。
  - 上一时间段任务保留到下一段生成时刻；新任务生成后，上一段任务归档到历史。
  - 每个时间段可刷新一次任务。
- 代码现状
  - 存在 `TaskGeneratorService` 与 `AppViewModel` 的时段调度、定时触发与刷新限制（每段一次）逻辑，整体框架吻合。
  - 夜间不生成任务与睡眠提醒已实现（`SleepReminderService`）。
  - 生成触发与保留/清理：当前实现会在新段生成前删除当日“未完成任务”（`refreshTasks` 会调用 `storage.deleteTasks`），与“归档到历史”的语义不一致。
  - 天气加权：`TaskGeneratorService` 固定生成 3 条任务并依赖 `categoryWeights` 加权，但未结合 `TaskCategory` 的天气适配
- 需要对齐的点
  - 引入“归档”状态或历史标记，避免直接删除未完成任务记录。
  - 在 `TaskGeneratorService` 中使用“固定/随机模式”与“天气窗口加权”的明确配置；并在时间段开始时确定随机生成时刻。

### 2.2 任务生命周期与完成判定
- PRD要点
  - 用户必须先“开始”，再等待“Buffer倒计时”，倒计时结束方可“完成”。
- 代码现状
  - 当前 `TaskStatus.isCompletable` 仍允许 `.pending` 完成，`AppViewModel.completeTask` 也以此作为入口，导致未到 Buffer 也能在某些边界下被判定可完成。
  - `AppViewModel.startTask` 设置 `canCompleteAfter` 并在 Buffer 后自动转为 `ready`，但与上述可完成条件存在冲突，需要收敛单一入口与判定标准。
- 需要对齐的点
  - 保持单一入口推进状态，避免 `updateTaskStatus` 与 `start/complete` 双轨导致边界不一致。

### 2.3 天气 × 任务类型适配
- PRD要点
    - 任务重复生成/刷新策略的PRD边界（保留/清理、惩罚/奖励）。
  - `energyReward` 硬编码在 `TaskCategory`，但 `RewardEngine` 也在计算奖励，存在潜在重复口径。
- 需要对齐的点
  - 采用“单一状态机 + 单一入口”：
      • 对外仅暴露 startTask(_:) 与 completeTask(_:)；updateTaskStatus 改为内部私有/删除 UI 层调用。
      • 明确状态机：pending -> started -> ready -> completed，并在 PRD 固化“只有 ready 才能完成”。
      • 倒计时触发仅保留 VM 层（startTask 内部 Task.sleep）或 UI 层其一，建议全部由 VM 控（UI 仅显示状态）。
  - 删除“保留一个任务”的机制和刷新机制

### 2.4 奖励与掉落
- PRD要点
  - 各任务类型对应固定能量奖励：
    - outdoor +15，indoorDigital +5，indoorActivity +10，physical +15，socials +10，petCare +5。
  - 完成任务后弹奖励提示，再弹“强制情绪反馈”弹窗；户外/社交任务有概率掉落“纪念品/玫瑰”。
  - 食物（food）不可购买，只能通过完成任务获得。
- 代码现状
  - `TaskCategory.energyReward` 与 `RewardEngine` 并存，口径重复，且完成逻辑会用分类默认值覆盖已有奖励。
  - 已有“随机Snack奖励”逻辑；商店入口 `ItemType.allCases` 包含 snack，`ShopView` 允许直接购买食物，与“只能掉落”不符。
  - RewardEngine 现已成为统一入口：能量取决于 TaskCategory，完成时集中计算能量/掉落并触发奖励弹窗；ShopView 仅展示可装扮类目，snack 仅能通过掉落获得。
- 需要对齐的点
  - 将奖励/掉落集中到 `TaskCategory` ，删除`tasks.json`和其引用函数的不必要字段。
  - 商店中屏蔽“食物/snack”购买入口，仅通过任务掉落增加库存。
  - 能量时间序列在 PRD 要求为“delta + related_task_id”，代码目前仅记录 totalEnergy 快照（EnergyHistoryEntry）且不含 delta 与任务关联。

### 2.5 情绪记录与反馈
- PRD要点
  - 打开App强制弹出情绪评分（0–100，步长10，0不可选），不可手动关闭；完成任务后强制反馈（-10/-5/0/+5/+10）。
  - 分时段聚合与趋势/洞察/AI建议。
- 代码现状
  - `checkAndShowMoodCapture` 与 `submitMoodFeedback` 已覆盖强制/反馈主流程。
  - 情绪模型 `MoodEntry` 支持 `delta` 与任务/天气关联。
- 需要对齐的点
  - UI层面确保“强制不可关闭”的交互一致性；评分步长与最小值校验。

### 2.6 宠物羁绊与经验
- PRD要点
  - 每天0点若前一天无任务完成，关系值下降2；关系值下限为15。
  - 购买装扮 +10 关系值 +10 XP；喂食 +2 关系值 +2 XP；完成任务 +1 XP。
- 代码现状
  - 购买/喂食/完成任务的加成与PRD不一致。
  
  
### 2.7 指标、聚合与上传
- PRD要点
  - 本地持有完整事件日志（情绪、任务、天气、宠物、商店），支持导出/导入。
  - 分时段聚合：在每个时间段开始时对上一时间段进行聚合，记录
    - user_id
    - date（本地时区）
    - day_length（日出到日落）
    - time_slot
    - timeslot_weather（任务生成时的天气）
    - avg_mood（该时段情绪均值）
    - task_feedback：按任务类型聚合 [发布数、完成数、情绪反馈总和]
  - 每天0点上传当日summary，失败留存重试。
  - “能量增长”仅关注 delta > 0（反映任务完成）。
- 代码现状
  - `DataAggregationService` 产出 `UserTimeslotSummary` 时 `tasksSummary` 仅 [completed, total] 且未包含情绪反馈总和，且 `timeslotWeather` 来源于完成/情绪记录而非“生成时天气”。
  - 聚合结果已调整为 {published, completed, moodDeltaSum} 并记录任务生成时天气；能量增长事件新增 EnergyEvent 结构，按 delta>0 + relatedTaskId 持久化。
  - `DailyActivityMetrics` 以 UserDefaults 计数的方式维护部分日级指标，与聚合服务口径不完全一致。
  - 能量数据仅有每日总量快照（`EnergyHistoryEntry`），缺少“delta>0 + related_task_id”的事件流结构。
- 需要对齐的点
  - 统一以 `DataAggregationService` 为指标中心：扩展结构以覆盖 `task_feedback` 的三元组与“生成时天气”。
  - 新增“能量事件流（delta>0 + related_task_id）”的数据结构与持久化；总量快照仅用于展示。
  - 实现“0点上传当日summary”的持久化重试机制与上传成功后清理策略。

---

## 3. 重复/不一致项（修复清单）

- 任务状态推进双轨
  - 收敛到单一入口；`isCompletable` 需改为仅 `.ready`，并移除允许 `.pending` 完成的入口。
- 奖励口径重复
  - 将能量/掉落/加成统一在 `RewardEngine`；`TaskCategory` 仅提供默认值与语义。
- 指标双轨
  - 统一到 `DataAggregationService`；`DailyActivityMetrics` 作为前端展示缓存，明确来源与口径。
- 商店“食物”购买与PRD不一致
  - 屏蔽 `ItemType.snack` 的购买入口，仅允许任务掉落或背包消耗。
- 任务历史归档缺失
    - 避免直接删除未完成任务，改为“过期/归档”状态，保留完整行为日志。
  - 能量事件缺失
    - 新增“能量增长事件流”结构，记录 delta>0 与关联任务，配合总量快照展示。
- 本地化
  - `TaskCategory.title` 等文案迁移到本地化资源；使用 `localizedTitle`。
  - 已以字符串表托管 TaskCategory.localizedTitle，作为本地化迁移起点。
- 同功能多命名/未用代码段
  - `TaskGeneratorService.taskCount(for:)` 与固定生成 3 条任务的实现并行存在，前者未被调用，导致“按天气数量调整”与实际逻辑脱节。
  - 宠物每日惩罚在 `PetEngine.applyDailyDecay` 与 `AppViewModel.applyDailyBondingDecayIfNeeded` 中双轨存在，前者未接入流程且惩罚值/触发条件不清晰，容易与后者的轻惩罚实现产生混淆。
  - `InventoryEntry.quantity` 与别名 `count` 并存，`UserStats.TotalDays`/`Onboard` 采用不同命名风格，与其余小写属性混用，建议统一命名与入口以减少歧义。

---

## 4. 架构与数据一致性建议

- 策略中心
  - 配置化任务Buffer、奖励、掉落概率、天气权重、固定/随机模式；支持A/B与远程配置。
- 指标中心
  - 以 `DataAggregationService` 为统一出口；定义分时段聚合口径与上传策略；实现导出/导入全量日志。
- 状态机
  - 任务状态机统一在 `AppViewModel`（或独立TaskEngine）中推进，定义清晰的触发器与副作用（奖励、通知、埋点）。
- 数据层规范
  - SwiftData模型统一“原始值 + 类型包装”模式；DAO层提供只读访问，避免直接操作原始字段。

---

## 5. 优先级路线图（对齐PRD）

- P0
  - 修正任务完成判定（已完成）；收敛任务状态推进单入口。
  - 商店屏蔽“食物”购买；将奖励/掉落统一到 `RewardEngine`。
  - 宠物惩罚与下限对齐（-2、min 15）。
  - 扩展 `DataAggregationService` 结构：`task_feedback` 三元组、`timeslot_weather` 使用“生成时天气”。

- P1
  - `TaskGeneratorService`：实现固定/随机模式切换、时间段开始时确定随机生成时刻、天气窗口加权、通知调度。
  - 历史归档：替代删除为归档标记；实现历史浏览与导出。
  - 能量事件流：新增 `EnergyEvent`（delta>0 + related_task_id）持久化与查询；总量快照用于展示。
  - 本地化迁移：采用 `String Catalog`，统一 `TaskCategory.localizedTitle` 、天气文案等迁移到本地化资源等。
  - 指标中心化：将 `DailyActivityMetrics` 与 `DataAggregationService` 逻辑统一


---

## 6. 与PRD对齐的代码变更建议（指令级）

  - UserTask/TaskCategory
    - 补充：实现 `TaskCategory.isEligible(for:)` 与 `localizedTitle`（当前缺失）；`TaskStatus.isCompletable` 收紧为仅 `.ready`。
    - 后续：在生成算法中实际调用 `isEligible(for:)`；文案改为本地化键。
- AppViewModel/TaskGeneratorService
  - 在时间段开始时生成“随机生成时刻”，并根据天气窗口加权；到时触发生成与通知。
  - 新任务生成前，将前段任务标记为“归档/过期”，不删除未完成任务记录。
- RewardEngine/ShopView
  - 将能量/掉落/加成集中到 `RewardEngine`；`ShopView` 中禁止 `snack` 购买，仅展示数量与使用。
- DataAggregationService
  - `tasksSummary` 扩展为 { category: [published, completed, moodDeltaSum] }，并记录“生成时天气”。
- Energy 数据结构
  - 新增 `EnergyEvent`（id, date, delta>0, related_task_id），作为“能量增长事件流”；总量快照仅用于展示。
- 上传与导出
  - 每日0点上传 summary（失败重试）；提供本地导出/导入全量历史数据。

---

## 7. 风险与依赖

- WeatherKit 授权/配额与回退策略；夜间与极端天气的兜底。
- 指标一致性：双轨口径合并与历史数据迁移风险。
- 权限与登录：失败/取消/二次授权的UX需按PRD补齐。

---


## 8. 结语

项目具备“健康行为激励 + 轻量养成 + 数据洞察”的良好潜力。建议优先完成策略/指标/状态机三大统一，对齐PRD的关键规则（任务生成与完成判定、奖励与掉落、宠物边界与惩罚、分时段聚合与上传），再逐步推进洞察与AI建议能力，以支撑产品验证与增长。

## 9. 附录 A：任务状态机

• 状态与触发
   • pending：初始；用户点击“Start”→ 进入 started
   • started：记录 startedAt；计算 canCompleteAfter = startedAt + buffer；倒计时结束→ ready
   • ready：可完成；点击“Done!”→ completed，记录 completedAt
   • completed：发放奖励（能量/XP/羁绊/掉落）、写入记录、触发情绪反馈
• 约束
   • 同一时间仅允许一个 started（DEBUG除外）
   • 仅 ready 可完成

⸻

10. 附录 B：Analytics 事件词典

• 通用属性：app_version、build、platform、locale
• 任务
   • tasks_generated_slot：slot、count、weather
   • task_started：title、category、buffer
   • task_ready：title、category、elapsed
   • task_completed：title、category、energy、completedAt、slot
• 情绪
   • mood_entry_added：id、date、source、value
   • mood_feedback_after_task：id、date、source、value、delta、category、weather、relatedTaskId
• 宠物
   • pet_pat：count
   • pet_feed：sku
   • bonding_penalty：reason(no_tasks_completed_yesterday)
• 系统
   • onboarding_done：region、gender
   • 通知授权：notifications_granted/denied/requires_settings

⸻

11. 附录 C：关键字段对齐

• 任务（UserTask）
   • 新增：timeslot
   • 删除：moodEntryId
   • 完成口径：以 completedAt 为准。
• 能量（EnergyEvent）
   • 新增：delta、relatedTaskId
• 情绪
   • 新增：relatedTaskId?

