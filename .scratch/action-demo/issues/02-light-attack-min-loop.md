# 02: 轻攻击命中木桩（最小战斗闭环）

**What to build:** spec 的 tracer 弹：动作状态机骨架（自由 → 前摇 → 判定 → 后摇）+ 招式数据表中的第一招轻攻击 + 判定阶段激活攻击判定框命中木桩 → 木桩扣血 + 全局顿帧 + 受击闪白。这是本 demo 第一条完整战斗链路，动作承诺（前摇不可取消）第一次可被感知。

**Blocked by:** 01

**Status:** ready-for-human

- [x] 动作状态机为不依赖场景树的纯逻辑模块：输入（攻击事件 + tick 时间）进、（当前招式、当前阶段、可否取消）出
- [x] 招式由数据表声明：前摇/判定/后摇时长、伤害、前冲速度（本票先用占位数值）
- [x] 前摇阶段拒绝一切取消输入（动作承诺规则，缝 A 单测锁定）
- [x] 攻击期间锁移动，位移由招式前冲提供
- [x] 判定阶段激活 hitbox，与木桩 hurtbox 重叠时结算：木桩 HP 减少、受击闪白
- [x] 命中瞬间全局顿帧数帧
- [x] 场景中摆放木桩（静态、不还手）
- [x] 缝 A 单测：阶段推进、前摇锁死
- [x] 缝 B 集成测试：攻击命中后木桩 HP 减少、顿帧被调用

## Comments

- 2026-10-03 实现完成，测试全绿（combat_rules 6 + attack_dummy 4 + player3d 回归 4）。缝A：`scripts/combat/{move_table,combat_state_machine}.gd` 纯逻辑模块；缝B：命中判定用 hitbox 形状直接空间查询（`intersect_shape`，collide_with_areas），保证编辑器内手动 tick 的判定确定性；顿帧由 main.tscn 的 Feedback 节点承接 `hit_landed` 信号，编辑器/测试环境只记录不动全局时间。
- 动画名修正：standard_2 库内实际为 `Sword_Regular_A`（小写 sword_regular_a 不存在）。该库还有 `Sword_Regular_A/B/C` 及各自 `_Rec` 后摇段、`Sword_Heavy_Combo`（票03 连段素材可用）；`standard/Roll` 可作票05 翻滚动画。
- 手感观感（前摇/后摇时长、前冲距离、顿帧帧数是否成立）按票01 同口径，推迟到 08 最终试玩合并验证；数值本身是占位，届时改 move_table。
