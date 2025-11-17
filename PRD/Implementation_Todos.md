# TO_DO list

---

## 0. 数据模型完整性检查

### 0.1 本地数据存储结构修改
**优先级**: Core  
**状态**: 已完成

**问题**: 
- `MoodEntry` 仍只有 `id/date/value` 字段，缺少 PRD 要求的 `source/delta/related_task_category/related_weather`，导致无法追踪任务后的情绪来源与天气背景。
- `UserTask` 只记录 `status/completedAt`，没有 `startedAt/canCompleteAfter`，无法支持 Buffer 机制。
- WeatherKit 返回的 `SunTimes` 仅存在于 `WeatherReport` 内存对象中，没有持久化存储，后续无法做日照统计。

**具体实施步骤**:
- [x] 按下表补齐缺失字段并更新 SwiftData schema：
  1. **MoodEntry**：保留 `date/value`，新增 `source: MoodSource`（枚举字符串）、`delta: Int?`、`relatedTaskCategory: TaskCategory?`、`relatedWeather: WeatherType?`；提供带默认值的 init 以及迁移方案。
  2. **EnergyHistoryEntry**：保持现状，可作为时间序列参考。
  3. **UserTask**：在模型中新增 `startedAt: Date?`、`canCompleteAfter: Date?`，并把 `TaskStatus` 扩展为 `pending/started/ready/completed`。
  4. **SunTimes**：在 `StorageService` 中持久化最近的 `SunTimes`（可存入 UserDefaults 或 SwiftData 新实体），供统计模块复用。
- [x] 更新 `StorageService.saveMoodEntry()` 与任务读写方法，确保新增字段持久化。
- [x] 评估现有数据的迁移策略：执行一次性迁移脚本或在模型 init 中填充默认值，避免 SwiftData 崩溃。

**相关文件路径**:
- `AntiEmoPet/Functions/MoodEntry.swift`
- `AntiEmoPet/Functions/UserTask.swift`
- `AntiEmoPet/Services/StorageService.swift`
- `AntiEmoPet/Services/WeatherService.swift`
**注意事项**:
- SwiftData 结构体变更需要 bump schema version，并确保已有数据不会因强制 unwrap 而崩溃；迁移前需备份本地存档。

---
### 0.2 上传后端的数据
**优先级**: Optional
**状态**: 未开始（占位符）

**问题**: 目前只有本地 SwiftData 数据，没有实现 PRD 要求的 `user_timeslot_summary` 聚合与上传逻辑，后端无法获取跨用户统计。

**具体实施步骤**:
- [ ] 定义 `UserTimeslotSummary` 结构，字段包含：
  - 用户基础信息：`user_id (accountEmail)`、`country_region`。
  - 聚合指标：`date/day_length/time_slot/timeslot_weather/count_mood/avg_mood/total_energy_gain/mood_delta_after_tasks`。
  - 任务摘要：`tasks_completed_total_by_type`（如 `{ "outdoor": [completed,total] }`），必要时压缩到 JSON。
- [ ] 在本地创建 `DataAggregationService`：
  - 每日或每 6 小时扫描 `MoodEntry`、`UserTask`、`EnergyHistoryEntry`。
  - 通过 `TimeSlot.from(date:)` 分组，计算统计值并写入待上传队列。
  - 引入 `SunTimes` 或日照计算补齐 `day_length`。
- [ ] 创建 `DataUploadService`：
  - 读取聚合结果，构造网络请求（REST/GraphQL TBD），处理重试与失败缓存。
  - 上传成功后持久化上传时间，避免重复。
- [ ] 初始化时在 `AppViewModel.load()` 触发聚合与上传任务，可结合 `background task`。

**相关文件路径**:
- 新建：`AntiEmoPet/Services/DataAggregationService.swift`
- 新建：`AntiEmoPet/Services/DataUploadService.swift`
- `AntiEmoPet/App/AppViewModel.swift`
**注意事项**:
- 聚合需脱敏（不上传情绪原始记录），并尊重 `userStats.shareLocationAndWeather` 开关；上传前提示用户并更新隐私声明。

---

### 0.3 数据上传功能（开发者端分析）
**优先级**: Optional
**状态**: 未开始（占位符）

**问题**: 将聚合的行为数据上传到后端用于全量行为分析。

**具体实施步骤** (占位符 - 当前不做):
- [ ] 设计数据聚合服务：
  - 按日期和时间段聚合情绪和任务数据
  - 生成`user_timeslot_summary`记录
- [ ] 实现数据上传服务：
  - 创建网络请求服务
  - 在每个时间段结束后聚合和批量上传聚合数据
  - 处理上传失败和重试
  - 添加隐私声明
  - 确保数据匿名化

**相关文件路径**:
- 新建：`AntiEmoPet/Services/DataUploadService.swift`
- 新建：`AntiEmoPet/Services/DataAggregationService.swift`
---
**注意事项**:
- 当前只是占位，等 0.2 完成再细化；暂不在代码中引用未使用的服务声明。

## 1. 情绪记录系统 (Mood Entry System)

### 1.1 MoodEntry数据模型扩展
**优先级**: Core  
**状态**: 未开始

**问题**: `MoodEntry` 仅含 `id/date/value`，`AppViewModel.addMoodEntry()` 也只写入数值，无法记录来源、任务绑定与天气，导致 PRD 中“AI 分析”所需的上下文缺失。

**具体实施步骤**:
- [ ] 在 `MoodEntry.swift` 中新增：
  - `source: MoodEntry.Source`（枚举封装 `"app_open"` / `"after_task"`）
  - `delta: Int?`
  - `relatedTaskCategory: TaskCategory?`
  - `relatedWeather: WeatherType?`
  - 更新 `@Model` 初始化方法和 `@Attribute(.unique)` 迁移。
- [ ] 修改 `StorageService.saveMoodEntry(_:)` 与 `AppViewModel.addMoodEntry(...)`/任务完成反馈调用，确保这些字段被赋值。
- [ ] 为 `MoodEntry` 提供 `Codable`/`Sendable` 支持，以便未来上传聚合时直接复用。

**相关文件路径**:
- `AntiEmoPet/Functions/MoodEntry.swift`
- `AntiEmoPet/Services/StorageService.swift`
- `AntiEmoPet/App/AppViewModel.swift`
**注意事项**:
- 该模型受 SwiftData 管理，新增字段必须设置默认值或进行轻量迁移，否则现有用户的本地存档会损坏。

---

### 1.2 应用打开时强制情绪记录弹窗
**优先级**: Core  
**状态**: 已完成

**问题**: 目前 `ContentView` 只有 onboarding 的全屏遮罩，没有"每日首次打开强制记录"逻辑，且 `MoodCaptureOverlayView` 的 Slider 仍允许 0，用户可以绕过记录。

**具体实施步骤**:
- [x] 在 `AppViewModel` 中添加 `hasLoggedMoodToday`（基于 `moodEntries` 与日历分组）以及 `recordMoodOnLaunch()`。
- [x] `MainTabView` or `ContentView` 监听该状态，使用 `.fullScreenCover` 或 `.overlay` 展示 `MoodCaptureOverlayView`，并调用 `.interactiveDismissDisabled(true)`。
- [x] 改造 `MoodCaptureOverlayView`：
  - Slider 改为 `10...100`，`step = 10`，默认值 50。
  - 支持将 `source` 作为参数传给 `onSave` 回调。
- [x] 成功记录后设置 `source = .appOpen` 并立即刷新 `moodEntries` 列表，确保当天不再弹窗；跨日需重置。

**相关文件路径**:
- `AntiEmoPet/App/ContentView.swift` ✅
- `AntiEmoPet/Services/MoodCaptureOverlayView.swift` ✅
- `AntiEmoPet/App/AppViewModel.swift` ✅
**注意事项**:
- 需要和 Onboarding/SleepReminder 的全屏弹层互斥，注意同时上屏时的优先级，以及保证 VoiceOver 用户仍可完成记录。

**注意**: 需要修改`MoodCaptureOverlayView`：
- Slider的step改为10 ✅
- 最小值设为10（不允许0）✅

---

### 1.3 任务完成后强制情绪反馈弹窗
**优先级**: Core  
**状态**: 已完成

**问题**: `AppViewModel.completeTask` 目前只更新能量/奖励，没有触发情绪反馈；`TasksView` 也没有 UI 钩子来展示强制弹窗。

**具体实施步骤**:
- [x] 在`AppViewModel.completeTask()`方法中，任务完成后显示情绪反馈弹窗
- [x] 反馈选项：`worse` (-5), `unchanged` (0), `better` (+5), `much better` (+10)
- [x] 记录情绪时：
  - 设置`source = "after_task"`
  - 设置`delta`为选择的反馈选项的数值
  - 设置`related_task_category`为完成的任务分类
- [x] 使用全屏覆盖层，`.interactiveDismissDisabled(true)`确保不能关闭
- [x] 记录后自动关闭并继续任务完成流程

**相关文件路径**:
- `AntiEmoPet/App/AppViewModel.swift` ✅
- `AntiEmoPet/Features/Pet/Tasks/TasksView.swift` ✅
- `AntiEmoPet/Services/MoodFeedbackOverlayView.swift` ✅ 已创建
**注意事项**:
- 需要确保反馈结果与任务奖励逻辑解耦（避免在同一个 `completeTask` 调用里重复保存任务状态）；同时保证在多任务并发完成时只弹一次。

---

## 2. 任务系统 (Task System)

### 2.1 任务开始/完成Buffer时间机制和能量奖励
**优先级**: Core  
**状态**: 已完成

**问题**: `TasksView` 当前只有「完成」按钮，没有 Start/Buffer 状态；`UserTask`/`TaskStatus` 也没有 `started/ready`，导致无法 enforcing PRD 的等待机制与统一 reward。

**任务类型及要求的buffer时间**:
- outdoor: 5分钟 ✅
- indoorDigital: 3分钟 ✅
- indoorActivity: 3分钟 ✅
- physical: 2分钟 ✅
- socials: 3分钟 ✅
- petCare: 15秒 ✅

**任务类型及获得的能量奖励**:
- outdoor: 15 ✅
- indoorDigital: 5 ✅
- indoorActivity: 10 ✅
- physical: 15 ✅
- socials: 10 ✅
- petCare: 5 ✅

**具体实施步骤**:
- [x] 添加任务状态枚举：
  - `pending` - 未开始
  - `started` - 已开始但未到完成时间
  - `ready` - 可以完成
  - `completed` - 已完成
- [x] 在`TasksView.swift`中：
  - 未开始的任务：显示"开始"按钮
  - 已开始但未到时间：显示倒计时和"等待中"状态
  - 可以完成：显示"完成"按钮
- [x] 实现开始任务逻辑：点击"开始"后设置`startedAt`和`canCompleteAfter`
- [x] 实现倒计时显示：显示剩余等待时间
- [x] 更新`AppViewModel.completeTask()`以检查是否可以完成（检查`canCompleteAfter`）
- [x] 修改任务能量奖励逻辑和数值

**相关文件路径**:
- `AntiEmoPet/Functions/UserTask.swift` ✅
- `AntiEmoPet/Features/Pet/Tasks/TasksView.swift` ✅
- `AntiEmoPet/Features/Pet/Tasks/TasksViewModel.swift`
- `AntiEmoPet/App/AppViewModel.swift` ✅
**注意事项**:
- 需要迁移历史任务记录并为新状态赋默认值；另外 `TaskGeneratorService` 的模板能量奖励需与 PRD 表格同步，以免 UI 与后端不一致。

---

### 2.2 任务完成后随机食物奖励
**优先级**: Core  
**状态**: 未开始

**问题**: 完成任务后，随机获得商店中一种食物（owned amount +1）和经验值+1。

**具体实施步骤**:
- 在`AppViewModel.completeTask()`中添加食物奖励逻辑：
  - 从`shopItems`中筛选出`type == .snack`的食物
  - 随机选择一种食物
  - 调用`incrementInventory(for: item)`增加该食物的拥有数量
- 显示获得食物的提示消息（类似奖励banner）
- 在`AppViewModel.completeTask()`中添加经验值奖励逻辑

**相关文件路径**:
- `AntiEmoPet/App/AppViewModel.swift`
- `AntiEmoPet/Services/RewardEngine.swift`
**注意事项**:
- 需要与未来的“纪念品掉落”逻辑兼容，建议将奖励封装为 `RewardEngine` 的新方法，并处理无 snack 项目时的回退提示。

---

### 2.3 任务刷新按钮限制（每个时间段一次）
**优先级**: Core  
**状态**: 未开始

**问题**: 当前任务全部完成后出现刷新按钮，每个时间段可刷新一次。

**具体实施步骤**:
- 在`TasksView.swift`中：
  - 检查当前时间段是否已经刷新过
  - 只有所有任务都完成且当前时间段未刷新过，才显示刷新按钮
- 实现时间段刷新状态追踪：
  - 使用UserDefaults存储每个时间段的刷新时间戳
  - 检查当前时间段的刷新状态
- 刷新时：
  - 获取当前天气
  - 根据天气生成3个新任务
  - 记录当前时间段的刷新时间戳

**相关文件路径**:
- `AntiEmoPet/Features/Pet/Tasks/TasksView.swift`
- `AntiEmoPet/Features/Pet/Tasks/TasksViewModel.swift`
- `AntiEmoPet/App/AppViewModel.swift`
**注意事项**:
- 时间段计算需复用 `TimeSlot.from(date:)`，避免多处重复；刷新记录应写入 `UserDefaults` 并在跨日时自动清理，防止新一天无法刷新。

---

### 2.4 当前任务生成逻辑检查
**优先级**: Core  
**状态**: 未开始

**问题**: 初始任务全部完成后，刷新没有生成新的任务。在每个时间段开始的时候任务系统没有更新和生成任务。

**具体实施步骤**:
- 根据时间和天气状况，在每个时间段内随机的时刻基于实时天气生成3个任务，并发送推送通知。
    - 时间段：上午6-12、下午12-17、傍晚17-22、晚上22-6
        - 晚上不生成任务，并且如果用户还在app内，在petview界面里弹出窗口提醒用户睡觉。
    - 这个随机时刻的生成时间会在每个时间段的开始时间决定。比如6点决定上午时间段在6-12中的什么时候生成任务。
        - 极大增加在晴天的时候生成的概率，比如在早上6点、阴天的情况下，在上午的天气预报里预计9：20-9：40是晴天，那么任务一定会在这20分钟的窗口里生成。
        - 减少在下雨的时候生成的概率。其他天气随机。
        - 颗粒度根据weatherkit实际可获取的天气预报颗粒度对齐
	- 到任务生成时间，获取用户当前的天气和一小时内的天气预报。当前天气后面需要存入对应的数据流中，所以可以使用一个temp的数值，每个时间段更新任务时更新。
- 根据天气随机在相关任务类型中抽取任务。任务分为6类，
    - 下雨：不包括户外任务
    - 晴天：不包括indoor digital和petcare
    - 其他：包括所有任务类型

**相关文件路径**:
- `AntiEmoPet/Services/TaskGeneratorService.swift`
- `AntiEmoPet/Services/NotificationService.swift`
- `AntiEmoPet/App/AppViewModel.swift`
- `AntiEmoPet/Services/WeatherService.swift`
**注意事项**:
- 现有 `TaskGeneratorService` 已按 `TimeSlot` 生成任务，需要在不破坏当前生成逻辑的情况下加入「时间段内随机触发 + 推送」调度；注意晚上 22-6 不生成但要触发 `SleepReminder`。

---

### 2.5 增加轻惩罚逻辑

**优先级**: Core  
**状态**: 未开始

**问题**: 未完成当前时段全部任务，bonding数值-1

**具体实施步骤**:
- [ ] 在 `AppViewModel` 中新增 `evaluateBondingPenalty(for:)`，在每个 `TimeSlot` 结束或刷新前调用。
- [ ] 若当前时段仍有 `status != .completed` 的任务，则调用 `PetEngine` 新方法减少 1 点 bonding，并记录本时段已处罚。
- [ ] 使用 `UserDefaults` 或 SwiftData 保存处罚日志，防止重复扣减，同时触发 UI 提示。

**相关文件路径**:
- `AntiEmoPet/App/AppViewModel.swift`
- `AntiEmoPet/Services/PetEngine.swift`
- `AntiEmoPet/Functions/UserTask.swift`
**注意事项**:
- 需要与 3.1 的每日衰减叠加时做下限保护；处罚提示要与任务刷新弹窗配合，避免用户无感知扣分。


## 3. 宠物系统 (Pet System)

### 3.1 每天0点关系值下降2
**优先级**: Core  
**状态**: 未开始

**问题**: 每天0点关系值下降2。

**具体实施步骤**:
- 在`AppViewModel.load()`或启动时检查：
  - 获取`userStats.lastActiveDate`
  - 计算自上次活跃日期以来的天数
  - 每天关系值下降2（不能低于10）
- 更新关系值逻辑：
  - 需要实现从bonding value到PetBonding的反向映射
  - 下降后的关系值需要更新对应的`PetBonding`状态
- 建议：创建一个`PetEngine`的新方法`applyDailyDecay(pet: Pet, days: Int)`
- 使用后台任务在每天0点触发检查

**相关文件路径**:
- `AntiEmoPet/Services/PetEngine.swift`
- `AntiEmoPet/App/AppViewModel.swift`
- `AntiEmoPet/Functions/Pet.swift`
**注意事项**:
- `Pet.bonding` 当前为枚举，需要新增可序列化的数值（或映射表）来支持“下降 2 点”计算，同时在冷启动时进行补偿。

---

### 3.2 宠物抚摸手势交互（点击+上下滑动）
**优先级**: Core  
**状态**: 未开始

**问题**: PRD要求点击狐狸并上下滑动可以完成抚摸动作。当前只有`petting()`方法，但没有UI手势交互。

**具体实施步骤**:
- 在`PetView.swift`的`petStage(for:)`中添加手势识别：
  - 使用`DragGesture`或组合`onTapGesture`和`onLongPressGesture`
  - 检测上下滑动手势（大致上下即可）
  - 手势成功后调用`appModel.petting()`
- 添加视觉反馈：
  - 抚摸时显示动画效果（爱心）
- 限制：同一天内限三次（见3.3）

**相关文件路径**:
- `AntiEmoPet/Features/Pet/PetView.swift`
- `AntiEmoPet/App/AppViewModel.swift` (petting方法已存在)
**注意事项**:
- 需确保 DragGesture 不与任务/商店按钮手势冲突，可通过限定手势区域或使用 `simultaneousGesture`；要兼容动画帧率与命中测试。

---

### 3.3 抚摸限制（每天3次）
**优先级**: Core  
**状态**: 未开始

**问题**: PRD要求抚摸动作同一天内限三次。

**具体实施步骤**:
- 在`AppViewModel`中添加每日抚摸次数追踪：
  - 使用UserDefaults存储当前抚摸次数
  - 在`petting()`方法中检查当天是否已达到3次
  - 显示提示消息，例如"今天已经抚摸过1/3次了"
- 如果已达到3次：
  - 不执行抚摸逻辑
- 每天0点重置计数

**相关文件路径**:
- `AntiEmoPet/App/AppViewModel.swift`
- `AntiEmoPet/Features/Pet/PetView.swift`
**注意事项**:
- 同一天下多设备登录需要统一计数，可将计数保存在 `UserStats` 或共享 UserDefaults；提示文案要避免重复弹出。

---

### 3.4 购买装扮后的奖励值调整
**优先级**: Core  
**状态**: 未开始

**问题**: 购买新装扮后bonding数值+10，经验值+20。

**具体实施步骤**:
- 检查`PetEngine.applyPurchaseReward()`方法，确认关系值计算是否正确
- 更新经验值奖励：从+1改为+20
- 更新`AppViewModel.purchase()`方法中的调用

**相关文件路径**:
- `AntiEmoPet/Services/PetEngine.swift`
- `AntiEmoPet/App/AppViewModel.swift`
**注意事项**:
- 需要重新定义 bonding 数值与 `PetBonding` 的映射，避免一次购买直接跨越多个状态；XP 增长要复用 3.6 的新曲线。


---

### 3.5 喂食奖励值确认
**优先级**: Core  
**状态**: 未开始

**问题**: 每次喂食后关系值+2，经验值+2。

**具体实施步骤**:
- 检查`PetEngine.handleAction(.feed(item: Item))`方法：
  - 当前是`bondingBoost / 4`，需要确认是否符合bonding数值+2的要求
  - 需要添加经验值奖励：调用`awardXP(2, to: pet)`
- 更新`AppViewModel.feed(item:)`方法

**相关文件路径**:
- `AntiEmoPet/Services/PetEngine.swift`
- `AntiEmoPet/App/AppViewModel.swift`
**注意事项**:
- 喂食既会改变库存也会触发任务奖励，需确保 XP/Bonding 更新只发生一次；同时校验库存扣减失败时的回滚逻辑。

---

### 3.6 经验值系统调整
**优先级**: Core  
**状态**: 未开始

**问题**: PRD要求1-5级解锁需要数值：10，25，50，75，100。后续每一级为100。当前`PetViewModel.xpRequirement()`的实现可能不完整。

**具体实施步骤**:
- 检查并更新`PetViewModel.xpRequirement(for:)`方法：
  - Level 1: 10 (当前: 0/10)
  - Level 2: 25 (当前: 10/25，升级后应该是0/25)
  - Level 3: 50 (当前: 25/50)
  - Level 4: 75 (当前: 50/75)
  - Level 5: 100 (当前: 75/100)
  - Level 6+: 100 (当前: 100/100)
- 更新`PetEngine.awardXP()`方法：
  - 确保升级逻辑正确
  - 确保经验值超过升级数值后余量继续加到新的等级中（LV1：0/10 +25之后应该是LV2:15/25）

**相关文件路径**:
- `AntiEmoPet/Features/Pet/PetViewModel.swift`
- `AntiEmoPet/Services/PetEngine.swift`
**注意事项**:
- 需要把 XP 要求和奖励逻辑写在同一处（例如 `PetEngine.XPCurve`），否则 UI 与引擎会出现不同步；升级后要携带余量 XP。

---

## 4. 统计分析系统 (Analytics System)

### 4.1 情绪统计页面 - 天气vs情绪均值柱状图
**优先级**: Core  
**状态**: 部分完成

**问题**: `AnalysisViewModel.weatherMoodAverages()` 已实现聚合，但 `StatsRhythmSection` 中的天气图表被注释（`rhythmWeatherChart` 未实现），`StatisticsView` 无法呈现“天气 vs 情绪均值”。

**具体实施步骤**:
- 更新计算逻辑，确保数据正确聚合
- 在`StatisticsView`中添加天气vs情绪柱状图：
  - 使用SwiftUI Charts的`BarMark`
  - X轴：天气类型（sunny, cloudy, rainy, snowy, windy）
  - Y轴：各个天气情况下的平均情绪值
  - 数据来源：`AnalysisViewModel.weatherMoodAverages()`

**相关文件路径**:
- `AntiEmoPet/Features/More/StatisticsView.swift`
- `AntiEmoPet/Features/More/InsightsView.swift`
- `AntiEmoPet/Features/Statistics/StatsRhythm.swift` (已有部分实现)
- `AntiEmoPet/Features/Statistics/AnalysisViewModel.swift`
**注意事项**:
- 需要和 4.5 的日照数据共享 WeatherReport.sunEvents；注意当任务为空时要 Gracefully degrade，避免 Chart 崩溃。

---

### 4.2 情绪统计页面 - 热力图（时间段+星期几 vs 情绪均值）
**优先级**: Core  
**状态**: 未开始

**问题**: 显示热力图，展示时间段（上午/下午/傍晚/晚上）和星期几（周一到周日）组合的情绪均值。

**具体实施步骤**:
- 创建新的视图组件`MoodHeatmapView.swift`：
  - 使用SwiftUI绘制热力图（可以用`Rectangle`或第三方库）
  - X轴：星期几（周一至周日）
  - Y轴：时间段（morning, afternoon, evening, night）
  - 颜色深度：表示平均情绪值高低
- 在`AnalysisViewModel`中添加方法：
  - `timeSlotAndWeekdayMoodAverages(entries: [MoodEntry]) -> [TimeSlot: [Int: Double]]`
  - 返回每个时间段和每个星期几组合的平均情绪值
- 在`StatisticsView`中集成热力图

**相关文件路径**:
- 新建：`AntiEmoPet/Features/Statistics/MoodHeatmapView.swift`
- `AntiEmoPet/Features/Statistics/AnalysisViewModel.swift`
- `AntiEmoPet/Features/More/StatisticsView.swift`
**注意事项**:
- 数据稀疏时需提供占位提示；热力图计算会遍历大量记录，注意在主线程外处理以免阻塞 UI。

---

### 4.3 能量统计页面 - 完成任务类型占比饼图
**优先级**: Core  
**状态**: 未开始

**问题**: 能量统计页面显示"完成任务各个类型占比"饼图。

**具体实施步骤**:
- 在`EnergyStatisticsViewModel`或新建方法中添加：
  - `taskCategoryCompletionRatio(tasks: [UserTask]) -> [TaskCategory: Int]`
  - 统计每个任务类型（outdoor, indoorDigital等）的完成数量
- 创建饼图视图组件：
  - 使用SwiftUI Charts的`SectorMark`
  - 显示每个任务类型的完成占比
  - 添加图例
- 在`EnergyStatsSection`中集成饼图

**相关文件路径**:
- `AntiEmoPet/Features/Statistics/EnergyViewModel.swift`
- `AntiEmoPet/Features/Statistics/EnergyStats.swift`
- `AntiEmoPet/Features/More/StatisticsView.swift`
**注意事项**:
- 需要过滤 `status == .completed` 的任务，且任务类型来自 `TaskCategory`，请保证配色与图例在浅色/深色模式下可见。

---

### 4.4 能量统计页面 - 显示今日完成任务数量
**优先级**: Core  
**状态**: 未开始

**问题**: 显示"今日完成任务数量"，当前`EnergyStatsSection`没有显示。

**具体实施步骤**:
- 检查`EnergyViewModel.energySummary()`是否包含今日完成任务数量
- 如果没有，添加该字段到`EnergySummary`结构
- 在`EnergyStatsSection`中按照现有格式显示文字并对齐：
  - "今日完成任务数量：x"
  - "过去一周平均完成数量：xx"

**相关文件路径**:
- `AntiEmoPet/Features/Statistics/EnergyViewModel.swift`
- `AntiEmoPet/Features/Statistics/EnergyStats.swift`
**注意事项**:
- 今日完成任务数可直接来自 `AppViewModel.todayTasks` 或 `dailyMetricsCache`，务必统一来源；周均计算需考虑无数据天数。

---

### 4.5 日照时长vs情绪均值折线图
**优先级**: Core  
**状态**: 未开始

**问题**: 显示"日照时长vs情绪均值"折线图。当前代码中有`daylightMoodAverages()`方法，但逻辑有误。

**具体实施步骤**:
- 检查是weatherkit否有可调用的日照时长功能，如果没有，计算逻辑为日出到日落的时长。
- 在`AnalysisViewModel`中添加方法：
  - `daylightLengthMoodAverages`
  - 每天23.59计算当天的日照时长（小时）和当天的平均情绪值
- 创建折线图视图：
  - X轴：日照时长（小时）
  - Y轴：平均情绪值
- 在`InsightsView`中集成

**相关文件路径**:
- `AntiEmoPet/Features/Statistics/AnalysisViewModel.swift`
- `AntiEmoPet/Services/WeatherService.swift`
- `AntiEmoPet/Features/More/StatisticsView.swift`
**注意事项**:
- WeatherKit 的 `SunTimes` 只提供未来几天，需缓存历史值；图表需处理无日照信息的 fallback（例如显示“缺少日照数据”）。


---

## 5. 可选功能 (Optional Features)

### 5.1 情绪记录 - 文字版情绪（更细分，配合颜色）
**优先级**: Optional  
**状态**: 占位符

**具体实施步骤** (占位符):
- [ ] 设计情绪文字标签系统（如：激动、开心、平静、愤怒、低落、焦虑、迷茫、生病）
- [ ] 为每个情绪标签分配颜色
- [ ] 更新`MoodCaptureOverlayView`支持文字选择

**相关文件路径**:
- `AntiEmoPet/Services/MoodCaptureOverlayView.swift`（未来）
- `AntiEmoPet/App/AppViewModel.swift`
**注意事项**:
- 当前仅为占位需求，等基础情绪记录上线后再排期，避免阻塞核心功能。

---

### 5.2 任务系统 - 完成户外/社交任务后概率获得纪念品/玫瑰
**优先级**: Optional  
**状态**: 占位符

**具体实施步骤** (占位符):
- [ ] 定义纪念品/玫瑰物品类型
- [ ] 在完成任务时根据任务类型和概率决定是否掉落
- [ ] 显示获得纪念品的提示
- [ ] 将纪念品添加到库存

**相关文件路径**:
- `AntiEmoPet/Services/RewardEngine.swift`
- `AntiEmoPet/App/AppViewModel.swift`
**注意事项**:
- 依赖 2.2 的基础奖励重构，当前无需实现；等食物奖励稳定后再接入。

---

### 5.3 任务系统 - Health Access：步数达到一定数量后掉落纪念品
**优先级**: Optional  
**状态**: 占位符

**具体实施步骤** (占位符):
- [ ] 请求HealthKit权限
- [ ] 读取用户当日步数
- [ ] 达到阈值后触发纪念品掉落
- [ ] 显示提示信息

**相关文件路径**:
- 新建：`AntiEmoPet/Services/HealthAccessService.swift`
- `AntiEmoPet/App/AppViewModel.swift`
**注意事项**:
- 需要额外的 HealthKit 权限说明；暂不排期，等待核心任务系统稳定。

---

### 5.4 Petview - 静态图片切换为动图或视频
**优先级**: Optional  
**状态**: 占位符

**具体实施步骤** (占位符):
- [ ] 更新`PetView`使用动画框架
- [ ] 根据pet状态播放对应的动画

**相关文件路径**:
- `AntiEmoPet/Features/Pet/PetView.swift`
- `AntiEmoPet/Features/Pet/PetViewModel.swift`
**注意事项**:
- 动图资源尚未准备，等 UI 资源到位后统一排期；当前优先保证静态版本性能。

---

### 5.5 Petview - 宠物随机移动
**优先级**: Optional  
**状态**: 占位符

**具体实施步骤** (占位符):
- [ ] 实现宠物在屏幕下方一半范围内的随机移动
- [ ] 使用动画框架实现平滑移动
- [ ] 确保不超出边界

**相关文件路径**:
- `AntiEmoPet/Features/Pet/PetView.swift`
- `AntiEmoPet/Features/Pet/PetViewModel.swift`
**注意事项**:
- 需要依赖 5.4 的动画资产；当前优先完成交互逻辑再考虑此增强。

---

### 5.6 Petview - 背景动态（天气效果、昼夜切换）
**优先级**: Optional  
**状态**: 占位符

**具体实施步骤** (占位符):
- [ ] 实现虚拟时间系统（3-15小时随机昼夜时长）
- [ ] 实现雨天斜的下雨动态效果
- [ ] 实现雪天下雪的动态效果
- [ ] 实现背景渐变色切换
- [ ] 添加手动切换天气按钮

**相关文件路径**:
- `AntiEmoPet/Features/Pet/PetView.swift`
- `AntiEmoPet/Features/Pet/PetViewModel.swift`
**注意事项**:
- 动态背景与 WeatherService 同步会增加性能消耗，需在核心功能完成后再评估。

---

### 5.7 Petview - 背景音乐
**优先级**: Optional  
**状态**: 占位符

**具体实施步骤** (占位符):
- [ ] 准备背景音乐资源
- [ ] 实现音乐播放服务
- [ ] 添加播放/暂停控制
- [ ] 根据天气/时间切换不同音乐

**相关文件路径**:
- 新建：`AntiEmoPet/Services/AudioService.swift`
- `AntiEmoPet/Features/Pet/PetView.swift`
**注意事项**:
- 音乐播放涉及后台权限与包体积，需等核心交互完成、资源确定后再规划。

---

### 5.8 任务完成 - 撒花效果
**优先级**: Optional  
**状态**: 占位符

**具体实施步骤** (占位符):
- [ ] 实现粒子效果或动画
- [ ] 在任务完成时触发
- [ ] 确保动画流畅且不影响性能

**相关文件路径**:
- `AntiEmoPet/Features/Pet/PetView.swift`
- `AntiEmoPet/Features/Pet/Tasks/TasksView.swift`
**注意事项**:
- 需要依赖任务完成逻辑稳定后插入，避免干扰强制情绪反馈弹窗的呈现。

---

### 5.9 经验升级 - 解锁新动作（撒娇）
**优先级**: Optional  
**状态**: 占位符

**具体实施步骤** (占位符):
- [ ] 定义动作系统
- [ ] 根据等级解锁不同动作
- [ ] 实现动作触发和播放

**相关文件路径**:
- `AntiEmoPet/Features/Pet/PetView.swift`
- `AntiEmoPet/Services/PetEngine.swift`
**注意事项**:
- 依赖 3.6 的等级系统完成后才能设计解锁阈值；暂不排期。

---

## 6. 代码优化和重构

### 6.1 未使用的函数和重复功能
**优先级**: Core  
**状态**: 未开始

**问题**:
- `RewardEngine.purchase()` 在调用 `EnergyEngine.spend()` 后又手动 `stats.totalEnergy -= cost`，实际会双倍扣能量（现网 bug）。
- `AppViewModel.allTasks` 只是返回 `todayTasks`，目前仅 `StatsRhythm` 使用，如不清理会继续造成困惑。

**具体实施步骤**:
- [ ] 移除 `RewardEngine.purchase()` 中的重复扣减，并补齐单元测试确认能量一致。
- [ ] 搜索 `allTasks` 使用处（目前在 `StatsRhythmSection`），评估是否直接改用 `todayTasks`，然后删除该属性或加注释。
- [ ] 扫描类似的重复逻辑，补充代码注释，列入代码规范。

**相关文件路径**:
- `AntiEmoPet/Services/RewardEngine.swift`
- `AntiEmoPet/App/AppViewModel.swift`
- `AntiEmoPet/Features/Statistics/StatsRhythm.swift`
**注意事项**:
- 修复能量扣减时需验证购买 UI 与库存同步；删除属性需逐一替换，避免 SwiftUI `@Published` 依赖发生变化。

---

### 6.2 可以模块化的功能
**优先级**: Optional  
**状态**: 未开始

**问题**: 情绪记录、任务状态、统计聚合分散在多个 View/ViewModel 中，导致逻辑重复且难以测试。

**具体实施步骤**:
- [ ] 抽取 `MoodCaptureService`：封装弹窗展示、重复检测与 `MoodEntry` 保存。
- [ ] 抽取 `TaskStateManager`：管理 `UserTask` buffer/倒计时/刷新限制逻辑。
- [ ] 抽取 `StatisticsAggregator`：统一 Mood/Energy/Task 的聚合输出，供 4.x 图表与 1.2 上传共用。

**相关文件路径**:
- `AntiEmoPet/App/AppViewModel.swift`
- `AntiEmoPet/Features/Statistics/*.swift`
- 新建：`AntiEmoPet/Services/MoodCaptureService.swift`
**注意事项**:
- 模块化改造属于中期工作，需在 1-4 章节的核心功能完成后再实施，避免并行 refactor 影响交付。

---

## 总结

### 核心功能待办事项 (必须完成)
- [ ] MoodEntry数据模型扩展
- [ ] 应用打开时强制情绪记录
- [ ] 任务完成后强制情绪反馈
- [ ] 任务Buffer/状态机与刷新限制
- [ ] 任务完成后食物奖励
- [ ] 数据聚合与上传（user_timeslot_summary）
- [ ] 每天0点关系值下降
- [ ] 宠物抚摸手势交互 + 抚摸限制
- [ ] 轻惩罚逻辑（未完成时段扣bonding）
- [ ] 统计图表（天气柱状、热力图、任务类型饼图、日照折线）

### 可选功能
- 所有标记为Optional的功能在文档中占位，当前阶段不需要实现

---
