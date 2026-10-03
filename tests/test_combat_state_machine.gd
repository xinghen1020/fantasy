@tool
extends McpTestSuite

## 票02 缝A单测：动作承诺规则机。纯逻辑毫秒级，不依赖场景树。
## 断言外部行为：阶段、发起可用性、前冲、锁定——不碰内部计时字段。

const TICK := 1.0 / 60.0


func suite_name() -> String:
	return "combat_rules"


func _start(machine: CombatStateMachine) -> CombatStateMachine:
	machine.start_attack(MoveTable.LIGHT_ATTACK_1)
	return machine

func _advance(machine: CombatStateMachine, seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		machine.tick(minf(left, TICK))
		left -= TICK


func _move_params() -> Dictionary:
	return MoveTable.MOVES[MoveTable.LIGHT_ATTACK_1]


func test_attack_starts_into_windup() -> void:
	var m := _start(CombatStateMachine.new())
	assert_eq(m.phase, CombatStateMachine.Phase.WINDUP, "发起攻击应进入前摇")
	assert_eq(m.current_move_name, MoveTable.LIGHT_ATTACK_1, "当前招式应为轻攻击1段")
	assert_true(m.is_locked(), "攻击发起后应锁死移动")


func test_windup_rejects_cancel_and_keeps_progress() -> void:
	var m := _start(CombatStateMachine.new())
	_advance(m, 0.10)  # 前摇中段
	assert_false(m.start_attack(MoveTable.LIGHT_ATTACK_1), "前摇内攻击输入应被拒绝（动作承诺）")
	assert_eq(m.phase, CombatStateMachine.Phase.WINDUP, "被拒绝的输入不应改变阶段")
	_advance(m, _move_params()["windup"] - 0.10 + 0.02)
	assert_eq(m.phase, CombatStateMachine.Phase.ACTIVE, "被拒绝的输入不应吞掉阶段推进")


func test_active_and_recovery_reject_attack() -> void:
	var m := _start(CombatStateMachine.new())
	_advance(m, _move_params()["windup"] + 0.02)
	assert_eq(m.phase, CombatStateMachine.Phase.ACTIVE, "前摇结束应进入判定段")
	assert_false(m.start_attack(MoveTable.LIGHT_ATTACK_1), "判定段内攻击输入应被拒绝")
	_advance(m, _move_params()["active"] + 0.02)
	assert_eq(m.phase, CombatStateMachine.Phase.RECOVERY, "判定段结束应进入后摇")
	assert_false(m.start_attack(MoveTable.LIGHT_ATTACK_1), "后摇内攻击输入应被拒绝")
	_advance(m, _move_params()["recovery"] + 0.02)
	assert_true(m.start_attack(MoveTable.LIGHT_ATTACK_1), "回到自由后攻击应重新可用")


func test_full_phase_cycle() -> void:
	var m := _start(CombatStateMachine.new())
	_advance(m, _move_params()["windup"] + 0.02)
	assert_eq(m.phase, CombatStateMachine.Phase.ACTIVE)
	_advance(m, _move_params()["active"] + 0.02)
	assert_eq(m.phase, CombatStateMachine.Phase.RECOVERY)
	_advance(m, _move_params()["recovery"] + 0.02)
	assert_eq(m.phase, CombatStateMachine.Phase.FREE)
	assert_false(m.is_locked(), "整招结束后应回到自由")


func test_lunge_and_lock_windows() -> void:
	var m := _start(CombatStateMachine.new())
	assert_true(m.is_locked(), "前摇应锁死")
	assert_gt(m.lunge_speed(), 0.0, "前摇应有前冲")
	_advance(m, _move_params()["windup"] + 0.02)
	assert_gt(m.lunge_speed(), 0.0, "判定段应保持前冲")
	_advance(m, _move_params()["active"] + 0.02)
	assert_eq(m.lunge_speed(), 0.0, "后摇应收势站定")
	assert_true(m.is_locked(), "后摇仍锁死")
	_advance(m, _move_params()["recovery"] + 0.02)
	assert_false(m.is_locked(), "回到自由后解锁")
	assert_eq(m.lunge_speed(), 0.0, "自由状态无前冲")


func test_unknown_move_rejected_in_free() -> void:
	var m := CombatStateMachine.new()
	assert_false(m.start_attack("not_a_move"), "未知招式应被拒绝")
	assert_eq(m.phase, CombatStateMachine.Phase.FREE, "拒绝后应保持自由")


func _params(move_name: String) -> Dictionary:
	return MoveTable.MOVES[move_name]


## 推进到当前招式的派生窗口（后摇段）
func _drive_to_recovery(m: CombatStateMachine) -> void:
	var p := _params(m.current_move_name)
	_advance(m, p["windup"] + p["active"] + 0.02)


func test_combo_chains_by_table_and_ends_free() -> void:
	var m := _start(CombatStateMachine.new())
	_drive_to_recovery(m)
	assert_eq(m.phase, CombatStateMachine.Phase.RECOVERY, "应进入派生窗口")
	m.notify_light_pressed()
	assert_eq(m.current_move_name, MoveTable.LIGHT_ATTACK_2, "窗口内派生应接到第2段")
	assert_eq(m.phase, CombatStateMachine.Phase.WINDUP, "派生应立即进入第2段前摇")
	_drive_to_recovery(m)
	m.notify_light_pressed()
	assert_eq(m.current_move_name, MoveTable.LIGHT_ATTACK_3, "第2段派生应接到第3段")
	_drive_to_recovery(m)
	m.notify_light_pressed()
	assert_eq(m.current_move_name, MoveTable.LIGHT_ATTACK_3, "第3段后轻攻击派生应无效果（连段到头）")
	assert_eq(m.phase, CombatStateMachine.Phase.RECOVERY, "无派生时窗口保持")
	_advance(m, _params(MoveTable.LIGHT_ATTACK_3)["recovery"] + 0.02)
	assert_eq(m.phase, CombatStateMachine.Phase.FREE, "第3段结束后应回到自由")


func test_buffer_stored_outside_window_consumed_at_open() -> void:
	var m := _start(CombatStateMachine.new())
	_advance(m, 0.10)  # 前摇中段
	m.notify_light_pressed()
	assert_eq(m.current_move_name, MoveTable.LIGHT_ATTACK_1, "窗口外输入不应立即生效")
	assert_eq(m.phase, CombatStateMachine.Phase.WINDUP, "缓冲不改变当前阶段")
	_advance(m, _move_params()["windup"] - 0.10 + _move_params()["active"] + 0.01)
	assert_eq(m.current_move_name, MoveTable.LIGHT_ATTACK_2, "缓冲应在窗口开启瞬间消费")
	assert_eq(m.phase, CombatStateMachine.Phase.WINDUP, "消费后立即起手下一招")


func test_direct_input_during_window_derives_immediately() -> void:
	var m := _start(CombatStateMachine.new())
	_drive_to_recovery(m)
	m.notify_light_pressed()
	assert_eq(m.phase, CombatStateMachine.Phase.WINDUP, "窗口内直按应立即派生，不经缓冲延迟")


func test_buffer_discarded_when_no_derivation() -> void:
	var m := _start(CombatStateMachine.new())
	# 用窗口内直按推到第3段
	_drive_to_recovery(m)
	m.notify_light_pressed()
	_drive_to_recovery(m)
	m.notify_light_pressed()
	assert_eq(m.current_move_name, MoveTable.LIGHT_ATTACK_3)
	_advance(m, 0.10)
	m.notify_light_pressed()  # 第3段前摇中连打
	_advance(m, _params(MoveTable.LIGHT_ATTACK_3)["windup"] - 0.10 + _params(MoveTable.LIGHT_ATTACK_3)["active"] + 0.01)
	assert_eq(m.current_move_name, MoveTable.LIGHT_ATTACK_3, "无派生时缓冲应被弃置，不循环回第1段")
	assert_eq(m.phase, CombatStateMachine.Phase.RECOVERY)


func test_buffer_single_slot_overwrite() -> void:
	var m := _start(CombatStateMachine.new())
	_advance(m, 0.05)
	m.notify_light_pressed()
	m.notify_light_pressed()
	m.notify_light_pressed()  # 密集连打
	_advance(m, _move_params()["windup"] - 0.05 + _move_params()["active"] + 0.01)
	assert_eq(m.current_move_name, MoveTable.LIGHT_ATTACK_2, "单槽缓冲：窗口消费一次")
	_advance(m, _params(MoveTable.LIGHT_ATTACK_2)["windup"] + _params(MoveTable.LIGHT_ATTACK_2)["active"] + _params(MoveTable.LIGHT_ATTACK_2)["recovery"] + 0.02)
	assert_eq(m.phase, CombatStateMachine.Phase.FREE, "多余点按不应排队，第2段后无输入则归自由")


func test_recovery_animation_from_table() -> void:
	var m := _start(CombatStateMachine.new())
	assert_eq(m.current_animation(), _move_params()["animation"], "前摇段应播挥砍动画")
	_advance(m, _move_params()["windup"] + _move_params()["active"] + 0.02)
	assert_eq(m.current_animation(), _move_params()["recovery_animation"], "后摇段应播数据表配置的收招动画")
	assert_eq(m.current_move_name, MoveTable.LIGHT_ATTACK_1, "后摇仍属同一招")
