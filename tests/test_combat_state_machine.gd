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
