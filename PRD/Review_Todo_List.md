# Review TODO List (基于PRD对齐评估)

> 依据《项目全面评估（SDE/PM，基于PRD对齐版）》与三份PRD差距梳理出的执行清单。`Optional` 标签沿用 PRD 标注。

## P0
- [x] **任务归档替代删除**：在新时间段生成前，将上一时段未完成任务标记为“归档/过期”，避免 `refreshTasks` 直接删除记录，保留可导出历史。【F:PRD/Project-Review.md†L21-L39】【F:PRD/Project-Review.md†L130-L138】
- [x] **任务完成判定收敛**：`TaskStatus.isCompletable` 仅允许 `.ready`；`start/complete` 走单一入口，消除 `.pending` 可完成的边界路径。【F:PRD/Project-Review.md†L41-L70】
- [x] **任务生成使用天气适配**：为 `TaskCategory` 实现 `isEligible(for:)`，在生成算法中过滤掉雨天户外、晴天 indoorDigital/petCare 等不合规组合，同时保留固定/随机模式配置。【F:PRD/Project-Review.md†L72-L95】【F:PRD/Project-Review.md†L169-L180】
- [x] **奖励统一与商店限制**：将能量/掉落计算集中到 `RewardEngine`；`ShopView` 禁止 `snack/food` 购买，仅通过任务掉落补给，并在完成后先弹奖励再强制情绪反馈。【F:PRD/Project-Review.md†L97-L126】
- [x] **宠物羁绊边界修正**：每日无任务完成惩罚改为 -2，羁绊下限 15；梳理 `applyDailyDecay` 与 `applyDailyBondingDecayIfNeeded` 双轨入口，避免重复或偏差。【F:PRD/Project-Review.md†L142-L167】【F:PRD/Project-Review.md†L201-L212】
- [x] **分时段聚合补齐**：`DataAggregationService` 输出 `{published, completed, moodDeltaSum}` 三元组并记录“生成时天气”；明确 `DailyActivityMetrics` 只作前端缓存以消除口径双轨。【F:PRD/Project-Review.md†L154-L186】
- [x] **能量事件流落地**：新增 `EnergyEvent`（id, date, delta>0, related_task_id）并持久化，配合现有总量快照展示。【F:PRD/Project-Review.md†L188-L199】【F:PRD/Project-Review.md†L223-L231】
- [x] **本地化迁移启动**：将 `TaskCategory.title` 等文案迁移至本地化资源/字符串表，使用 `localizedTitle`，避免硬编码。【F:PRD/Project-Review.md†L215-L222】

## P1
- [ ] **随机生成时刻与通知**：时间段开始时确定随机生成时刻，结合天气窗口加权；到达时刻生成任务并调度推送，刷新限制仍为每段一次。【F:PRD/Project-Review.md†L18-L39】【F:PRD/Project-Review.md†L169-L180】
- [ ] **历史浏览与导出**：在归档基础上提供历史任务浏览与导出能力，支撑“统计/洞察/AI建议”。【F:PRD/Project-Review.md†L188-L199】
- [ ] **能量/指标上传重试**：实现 0 点上传当日 summary 的持久化队列与失败重试，上传成功后清理；尊重用户位置/天气分享开关。【F:PRD/Project-Review.md†L154-L186】【F:PRD/Project-Review.md†L233-L241】
- [ ] **命名与入口统一**：统一 `InventoryEntry.quantity/count`、`UserStats.TotalDays/Onboard` 等命名风格，移除未接入的重复入口（如 `PetEngine.applyDailyDecay`），减少歧义。【F:PRD/Project-Review.md†L203-L212】


## Optional（沿用PRD可选项）
- [ ] **开发者端数据上传** *(Optional)*：在现有聚合之上扩展开发者分析上传通道（占位，待 0.2 完成后细化）。【F:PRD/Implementation_Todos.md†L56-L93】
- [ ] **高级可选特性集** *(Optional)*：保留 PRD “可选功能”模块（如好友互动、任务共享、宠物社交等）的占位，按业务优先级择机推进。【F:PRD/Implementation_Todos.md†L557-L775】
