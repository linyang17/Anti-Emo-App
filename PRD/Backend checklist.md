
# Anti Emo App – Supabase-Only Backend Architecture & Implementation Checklist

> **方案 A：全部基于 Supabase（Postgres + Edge Functions + Scheduler）**  
> 技术栈：Supabase Postgres + SQL + TypeScript Edge Functions（少量）  
> 前端：你现有的 App（本地逻辑 + 调 Supabase REST/Function）

---

## 0. 总体架构概览

- **数据层：Supabase Postgres**
  - 所有业务数据表：`users`, `user_day_timeslots`, `upload_logs`, `user_daily_stats`, `user_insight_features`。
  - 使用视图 / SQL 聚合做统计查询。
- **API 层：Supabase 自动 REST + Edge Functions**
  - 简单 CRUD → 直接用 Supabase 自动生成的 REST 接口（PostgREST）。
  - 复杂逻辑（幂等上传、聚合、AI 建议等）→ 写成 Edge Functions（TypeScript）。
- **定时任务（cron）：Supabase Scheduler**
  - 定时调用 Edge Functions：
    - 每天聚合当天/昨天数据 → 写入 `user_daily_stats`。
    - 计算基线/异常 → 写入 `user_insight_features`。
- **鉴权 & 安全**
  - 用户端用匿名 `user_id`（UUID）+ Supabase auth（可选）。
  - Row Level Security（RLS）保证用户只能访问自己的数据。
  - Edge Functions 用 Service Role Key 调用数据库，不受 RLS 限制（内部逻辑）。

---

## 1. 数据模型设计（Postgres 表）

### 1.1 `users` – 用户基础信息（匿名）

- 用于：
  - 保存用户的地区、时区信息。
  - 后续做人群分析 / 统计时按维度拆分。

**字段：**

- `id` (uuid, PK)：匿名 user_id。
- `gender` (varchar)。
- `age_group` (varchar)：如 `18-24`。
- `country_region` (varchar)。
- `timezone` (varchar)。
- `created_at` (timestamptz)。

---

### 1.2 `user_day_timeslots` – 每天按时段的 summary 压缩记录

- 对应前端本地每天 0 点上传的“昨日”统计。
- 每条记录代表：某用户在某日的某个 time_slot 的综合信息。

**关键字段：**

- `id` (bigserial, PK)。
- `user_id` (uuid, FK → users.id)。
- `local_date` (date)：用户本地日期。
- `time_slot` (varchar)：`morning`, `afternoon`, `evening` …。
- `day_length_min` (int)：日照总分钟数。
- `timeslot_weather` (varchar)：任务生成时的天气。
- `avg_mood` (numeric)：该时段平均心情。
- `task_feedback` (jsonb)：
  - 结构建议：`{ "outdoor": [published, completed, mood_delta_sum], ... }`
- `energy_delta_sum` (int)。
- `tasks_published` (int)。
- `tasks_completed` (int)。
- `upload_batch_id` (uuid)：本次上传批次 id。
- `created_at` / `updated_at`。

---

### 1.3 `upload_logs` – 上传批次日志

- 用于幂等控制（防止重复插入同一天数据）。
- 每个 `(user_id, target_date)` 最多一条成功记录。

**关键字段：**

- `id` (bigserial, PK)。
- `user_id` (uuid, FK)。
- `upload_batch_id` (uuid)。
- `target_date` (date)。
- `record_count` (int)：本次上传包含多少 `time_slot` 记录。
- `status` (varchar)：`success` / `partial` / `failed`。
- `error_message` (text)。
- `created_at`。

---

### 1.4 `user_daily_stats` – 每日聚合统计（由定时任务生成）

- 用于统计页面快速展示、减少实时计算压力。

**关键字段：**

- `id` (bigserial, PK)。
- `user_id` (uuid, FK)。
- `local_date` (date, unique with `user_id`)。
- `mood_avg` (numeric)：当日情绪均值。
- `mood_entries` (int)：当日情绪记录数量。
- `energy_gain_total` (int)：当日能量总增量。
- `tasks_completed` (int)。
- `mood_week_avg` / `energy_week_avg` / `tasks_week_avg`（可选预计算）。
- `created_at` / `updated_at`。

---

### 1.5 `user_insight_features` – 高级分析特征（定时任务生成，可后期添加）

**关键字段：**

- `id` (bigserial, PK)。
- `user_id` (uuid, FK)。
- `feature_date` (date)。
- `mood_baseline` (numeric)。
- `mood_sigma` (numeric)。
- `mood_energy_corr` (numeric)。
- `avg_recovery_days` (numeric)。
- `last_anomaly_date` (date)。
- `created_at` / `updated_at`。

---

## 2. API & 功能设计（基于 Supabase）

### 2.1 用户信息上传

#### 接口：`POST /rest/v1/users`

- 类型：直接使用 Supabase REST。
- 操作：
  - 前端在 onboarding 完成后，写入/更新 `users`。
  - 通过 upsert（`on_conflict: id`）实现重复调用容错。

#### 请求体示例：

```json
{
  "id": "uuid-string",
  "gender": "female",
  "age_group": "24-30",
  "country_region": "UK-London",
  "timezone": "Europe/London"
}
```

---

### 2.2 每日 summary 上传（建议用 Edge Function 封装）

> 因为需要幂等控制 + 多表写入 → 用 Edge Function 比直接 Rest 简单。

#### 设计：Edge Function `summary_daily`

- **输入（来自前端）：**

```json
{
  "user_id": "uuid-string",
  "target_date": "2025-12-10",
  "upload_batch_id": "uuid-string",
  "slots": [
    {
      "time_slot": "morning",
      "timeslot_weather": "sunny",
      "day_length_min": 520,
      "avg_mood": 68.5,
      "task_feedback": {
        "outdoor": [2, 1, 10],
        "physical": [1, 1, 5]
      },
      "energy_delta_sum": 24,
      "tasks_published": 3,
      "tasks_completed": 2
    }
  ],
  "mood_entries": 8
}
```

- **逻辑：**
  1. 检查 `upload_logs` 中 `(user_id, target_date)` 是否已有 `status='success'`：
     - 有 → 直接返回 `{ ok: true, skipped: true }`。
  2. 删除该用户该日期已有的 `user_day_timeslots` 记录（如果存在）。
  3. 批量插入 `slots[]` 对应记录至 `user_day_timeslots`。
  4. 写入/更新 `upload_logs`：
     - `record_count = slots.length`，`status='success'`。
  5. 可选：顺便更新 `user_daily_stats` 的当日值（快速统计）。

---

### 2.3 统计 API（前端可直接查 REST 或视图）

#### 2.3.1 Mood 统计

**做法建议：**

- 在数据库里创建视图 `view_user_mood_stats`，聚合 `user_daily_stats`。
- 前端通过 `GET /rest/v1/view_user_mood_stats?user_id=eq.<uuid>&local_date=gte.<from>&local_date=lte.<to>` 查询。

视图逻辑示例（伪 SQL）：

```sql
CREATE VIEW view_user_mood_stats AS
SELECT
  user_id,
  local_date,
  mood_avg,
  mood_entries,
  -- 可计算 rolling，或只提供原始数据给前端
  created_at
FROM user_daily_stats;
```

前端用这些数据画折线图、柱状图即可。

#### 2.3.2 Energy 统计

同理创建视图 `view_user_energy_stats`：

- 包含：
  - `energy_gain_total`
  - `tasks_completed`
  - 可通过 JSONB 聚合任务类型完成情况（如需要可做成单独视图）。

---

### 2.4 Insights API

可选做法：

1. **轻量做法：**  
   - 直接用多张视图 + REST 查询：
     - `view_mood_heatmap`（weekday + time_slot → avg_mood）。
     - `view_weather_mood`。
     - `view_daylength_mood`。
     - `view_task_type_mood`。
2. **稍复杂做法：**  
   - 写 Edge Function `insights_get`：
     - 一次查询多种数据，整理成更适合前端渲染的结构返回。

> 由于你现在更关注落地和维护成本，视图 + REST 是最简单可靠的方式，Edge Function 只在多步逻辑需要时才用。

---

### 2.5 AI 建议 API

#### 方案：Edge Function `ai_advice`

- 输入：
  - `user_id`
  - `scope`（`today` / `week` / `month`）
  - `focus`（`mood` / `energy` / `both`）
- Edge Function 内部：
  1. 从 `user_daily_stats` + `user_insight_features` 取数据。
  2. 构造 prompt（模板固化在代码里）。
  3. 调用 OpenAI / 其他 LLM。
  4. 返回「简洁建议文案」。

> 这样前端只需要调用一个 Function，不必了解复杂统计细节。

---

## 3. 定时任务（cron）设计 – 使用 Supabase Scheduler

> 理解：Scheduler = “让某个 Edge Function 在某个频率自动跑”。

### 3.1 Job 1：每日聚合统计 `cron_daily_stats`

- **Edge Function 名称：** `cron_daily_stats`
- **调度：**
  - 每天 02:00（UTC 或你固定的时区）。
- **逻辑：**
  1. 计算目标日期：`target_date = today - 1 day`（昨天）。
  2. 找出昨天有成功上传 summary 的用户（查 `upload_logs`）。
  3. 对每个用户：
     - 从 `user_day_timeslots` 聚合出：
       - `mood_avg`
       - `energy_gain_total`
       - `tasks_completed`
       - `mood_entries`（可以从上传参数中带上或统计）。
     - 写入/更新 `user_daily_stats`。
  4. 可选：计算最近 7 天的平均，写入 `mood_week_avg` 等字段。

### 3.2 Job 2：计算基线与异常 `cron_insight_features`（可后期添加）

- **Edge Function 名称：** `cron_insight_features`
- **调度：**
  - 每天 03:00。
- **逻辑：**
  1. 对最近 N 天有活跃数据的用户循环：
     - 取最近 30 天 `mood_avg` → 计算 `baseline` & `sigma`。
     - 取最近 60 天 `mood_avg` & `energy_gain_total` → 计算 `mood_energy_corr`。
     - 计算是否存在异常日（低于 baseline - k*sigma）。
  2. 写入 `user_insight_features`（`feature_date = today`）。

---

## 4. 权限与安全（RLS 与 Edge Functions）

### 4.1 Row Level Security（RLS）

- 对核心表（`users`, `user_day_timeslots`, `user_daily_stats`, ...）启用 RLS。
- 为每张表添加如下策略（示例）：

```sql
CREATE POLICY "Users can only see their own data"
ON user_daily_stats
FOR SELECT
USING (auth.uid() = user_id);
```

> 如果你采用 Supabase Auth 的匿名用户（`auth.uid()` = `user_id`），前端可以直接用 Supabase 客户端访问这些表/视图。

### 4.2 Edge Functions 权限

- Edge Functions 使用 Service Role Key 访问 Postgres：
  - 不受 RLS 限制，可以读写所有用户数据。
  - 注意部署时不要在前端暴露 Service Role Key。
- 对外暴露的 Edge Functions（如 `summary_daily`, `ai_advice`）：
  - 使用 JWT 验证当前用户身份（Supabase JS 客户端会自动带 token）。
  - 在函数里校验：请求中的 `user_id` 与 token 内的 `sub` 一致。

---

## 5. 实施阶段 & 待办清单（可勾选）

> 建议按阶段推进，每一阶段都能自测一部分功能。

### 阶段 1：Supabase 项目初始化 & 数据库建表

- [ ] 在 Supabase 控制台创建新项目（Anti Emo App）。
- [ ] 在 `Database` → `SQL Editor` 中执行建表脚本：
  - [ ] 创建表 `users`。
  - [ ] 创建表 `user_day_timeslots`。
  - [ ] 创建表 `upload_logs`。
  - [ ] 创建表 `user_daily_stats`。
  - [ ] （可选）创建表 `user_insight_features`。
- [ ] 为频繁查询字段建索引：
  - [ ] `user_day_timeslots(user_id, local_date, time_slot)`。
  - [ ] `upload_logs(user_id, target_date)`（唯一约束）。
  - [ ] `user_daily_stats(user_id, local_date)`（唯一约束）。
- [ ] 启用这些表的 RLS，并添加基础策略（仅允许本人访问）。

### 阶段 2：前端直连 Supabase（基础读写打通）

- [ ] 在前端集成 Supabase JS SDK。
- [ ] 建立匿名登录或简单 auth（如 `signInAnonymously` 或魔术链接/匿名策略）。
- [ ] 在 onboarding 完成时：
  - [ ] 调用 `supabase.from('users').upsert(...)` 写入用户信息。
- [ ] 在本地调试模式下确认：
  - [ ] `users` 表成功出现新纪录。
  - [ ] RLS 生效（不同用户看不到对方数据）。

### 阶段 3：实现每日 summary 上传 Edge Function

- [ ] 在 Supabase 本地开发环境（或 CLI）初始化 Edge Functions。
- [ ] 新建 Edge Function：`summary_daily`。
  - [ ] 校验请求中的 JWT（确认 user 身份）。
  - [ ] 解析 body 中的 `user_id`, `target_date`, `upload_batch_id`, `slots[]`。
  - [ ] 检查 `upload_logs` 是否已有 `status='success'` 记录：
    - [ ] 若有 → 返回 `{ ok: true, skipped: true }`。
  - [ ] 删除该用户该日已有的 `user_day_timeslots`。
  - [ ] 批量插入 `slots[]` 记录。
  - [ ] 写入 `upload_logs`，状态 `success`。
- [ ] 在本地用 `curl` / Postman 测试这个 Function。
- [ ] 将前端“每日 0 点上传 summary”的逻辑改为调用 `summary_daily` Function。

### 阶段 4：基本统计视图 & REST 查询

- [ ] 在数据库中创建视图：
  - [ ] `view_user_mood_stats`（来自 `user_daily_stats`）。
  - [ ] `view_user_energy_stats`（来自 `user_daily_stats`）。
- [ ] 视图中仅选择当前需要的字段，保证返回结构简单。
- [ ] 为视图设置 RLS（通常继承源表的 user_id 过滤）。
- [ ] 前端：
  - [ ] 调用 `supabase.from('view_user_mood_stats').select(...)` 获取数据。
  - [ ] 绘制情绪折线图/柱状图。
  - [ ] 调用 `view_user_energy_stats` 显示能量统计图。

### 阶段 5：定时任务（Scheduler）实现每日聚合

- [ ] 在 Supabase 控制台开启 Edge Functions Scheduler。
- [ ] 新建 Edge Function：`cron_daily_stats`。
  - [ ] 逻辑：
    - [ ] 计算目标日期为昨天。
    - [ ] 查询 `upload_logs` 中昨天成功上传的 `(user_id, target_date)`。
    - [ ] 对每个用户：
      - [ ] 聚合 `user_day_timeslots`（按 `local_date` 汇总）。
      - [ ] 写入/更新 `user_daily_stats`。
- [ ] 在 Scheduler 中配置：
  - [ ] 任务名：`daily_stats_job`。
  - [ ] 时间：每天 02:00。
  - [ ] 目标函数：`cron_daily_stats`。
- [ ] 测试：
  - [ ] 手动触发一次 `cron_daily_stats`（本地或 CLI）。
  - [ ] 检查 `user_daily_stats` 中是否出现数据。

### 阶段 6：Insights 视图 & 可视化数据

- [ ] 创建视图 `view_mood_heatmap`：
  - [ ] 结构包含：`user_id`, `weekday`, `time_slot`, `avg_mood`。
- [ ] 创建视图 `view_weather_mood`：
  - [ ] 结构包含：`user_id`, `timeslot_weather`, `avg_mood`。
- [ ] 创建视图 `view_daylength_mood`：
  - [ ] 结构包含：`user_id`, `day_length_min`, `avg_mood`。
- [ ] 创建视图 `view_task_type_mood`：
  - [ ] 从 `task_feedback` JSONB 展开，统计：
    - [ ] 各任务类型完成数 & 平均情绪增量。
- [ ] 前端：
  - [ ] 对应地调视图 REST 接口绘制：
    - [ ] 时间段×星期几热力图。
    - [ ] 不同天气情绪对比图。
    - [ ] 日照时长情绪折线图。
    - [ ] 任务类型情绪反馈图。

### 阶段 7：AI 建议 Edge Function

- [ ] 新建 Edge Function：`ai_advice`。
  - [ ] 接收 `user_id`, `scope`, `focus`。
  - [ ] 查询：
    - [ ] `user_daily_stats` 最近 7–30 天数据。
    - [ ] `user_insight_features`（若已实现）。
  - [ ] 使用这些信息构造 prompt 调用 OpenAI。
  - [ ] 返回简短文本建议。
- [ ] 前端：
  - [ ] 在 Insights 页或某个“AI 建议”卡片里调用 `ai_advice`。
  - [ ] 优化 Loading/错误提示（如“今天数据较少，建议再记录几天后再看”）。

### 阶段 8：监控 & 运维最小集合

- [ ] 在 Supabase 控制台开启：
  - [ ] 数据库慢查询日志（可选）。
  - [ ] Edge Functions 日志查看。
- [ ] 定期（比如每一两周）：
  - [ ] 检查表大小、Row 数量。
  - [ ] 看下 Scheduler 任务是否有失败记录。
- [ ] 为关键函数加上简单报警（可选）：
  - [ ] 比如通过 logging + 外部监控工具。

---

## 6. 小结

- 通过 **Supabase 单平台**，你可以完成：
  - 数据存储、REST API、权限控制、定时任务和一部分业务逻辑。
- 你的主要工作流会是：
  1. 在 Supabase 里建表 & 写视图；
  2. 在 Edge Functions 里写少量 TypeScript 逻辑（上传、聚合、AI 调用）；
  3. 前端通过 Supabase 客户端或 HTTP 调这些接口。

这套方案既能满足你 PRD 的功能需求，又保持后期维护成本尽可能低，并且便于你以后用 AI agent 帮忙自动生成/重构代码。
